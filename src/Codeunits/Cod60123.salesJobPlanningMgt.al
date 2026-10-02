codeunit 60123 "BH Sales Job Planning Mgt."
{
    // Hallazgo definitivo (2026-09-15, cuarta ronda de diagnóstico en vivo): confirmado con un
    // subscriber temporal que `LastSalesDocPostingStarted` (variable de codeunit puesta en
    // `MarkSalesDocPostingStarted`, sobre `OnBeforePostSalesDoc`) llegaba VACÍA al leerla desde
    // `CleanupOnAfterDeleteSalesLine` (sobre `OnAfterDeleteEvent` de Sales Line) -- es decir, el
    // subscriber de escritura y el de lectura NO comparten la misma instancia del codeunit
    // durante un mismo posteo. Esto confirma, con evidencia directa, la sospecha que ya se había
    // planteado (y descartado sin poder probarla) para el guard de borrado de Job Planning Line
    // más abajo: los subscribers de un codeunit que NO es `SingleInstance` pueden ejecutarse en
    // instancias automáticas separadas entre sí, incluso dentro de la misma operación de negocio
    // (aquí, un mismo posteo). `SingleInstance = true` garantiza una única instancia persistente
    // para toda la sesión del cliente, para que las variables de codeunit (como
    // `LastSalesDocPostingStarted`) se compartan de forma confiable entre TODOS los subscribers de
    // este codeunit, sin importar en qué evento/tabla/codeunit distinto se disparen.
    SingleInstance = true;

    // DIS-2026-08-31 — Integración Proyectos (Jobs) con Factura de venta, líneas
    // Tipo = Artículo. Ver docs/diseños/DIS-2026-08-31-jobs-sales-integration.md.
    //
    // Alcance reducido (2026-09-14, soporte post-publicación): el diseño original
    // (y su implementación inicial) también cubría el Pedido de venta, con una "Ruta A"
    // de subscribers sobre Codeunit 80 "Sales-Post" para permitir el posteo combinado
    // "Enviado y Facturado" en un solo paso. Negocio confirmó que **no** quiere el
    // vínculo desde Pedido -- solo desde Factura de venta (creada directamente, sin
    // pasar por Pedido). Se eliminó `Pag60124.salesOrderSubformExt.al` (ya no se puede
    // editar Job No./Job Task No. en la línea del Pedido) y los 3 subscribers de Ruta A
    // que solo existían para el caso Pedido: `BlockShipOnlyPostingForJobContractLine`,
    // `AllowOrderPostingForJobContractLine`, y `SkipJobNoTestFieldForAutoCreatedLine`
    // (agregado el mismo día, retirado horas después al reducirse el alcance). Se
    // conserva `RestoreItemPostingForJobContractLine` porque esa supresión de
    // `Item Ledger Entry` la hace `Codeunit 80` para cualquier línea con
    // `"Job Contract Entry No." > 0`, sin importar el `Document Type` -- también afecta
    // a la Factura.
    //
    // Patrón de fondo: cuando el usuario diligencia Job No./Job Task No. en una línea
    // de Factura de venta Tipo = Artículo, se crea una Job Planning Line "oculta" (Line
    // Type = Billable, marcada "BH Auto-Created From Sales") para que el motor nativo de
    // Jobs (Job Post-Line) genere el Job Ledger Entry tipo Sale al postear la línea,
    // exactamente igual que si viniera de una línea de planificación facturable real
    // transferida por el asistente estándar de Proyectos.

    // Marca el documento que está siendo posteado (hallazgo 2026-09-15, ver comentario completo
    // en `CleanupOnAfterDeleteSalesLine`): `OnBeforePostSalesDoc` dispara al principio de TODO el
    // posteo de `Codeunit 80 "Sales-Post"`, con la Sales Header real, antes de cualquier
    // procesamiento de línea. Se guarda el "Document No." (no un booleano) precisamente para que
    // el marcador sea auto-recuperable: si un posteo fallido no llega a limpiarlo (AL no tiene
    // try/finally para garantizar un "reset" simétrico ante cualquier error a mitad de camino),
    // el marcador simplemente queda con el número de ESE documento -- un borrado de línea
    // posterior sobre un documento DISTINTO no coincide y sigue su curso normal. Solo quedaría
    // "atascado" un falso negativo si, inmediatamente después de un posteo fallido, se borrara a
    // mano una línea del MISMO documento antes de postear otra cosa -- caso extremadamente
    // acotado, y su peor consecuencia es simplemente no limpiar una Job Planning Line huérfana
    // (ya tolerado en otras partes del codeunit), nunca borrar una que todavía se necesita.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", OnBeforePostSalesDoc, '', false, false)]
    local procedure MarkSalesDocPostingStarted(var SalesHeader: Record "Sales Header")
    begin
        if SalesHeader."Document Type" = SalesHeader."Document Type"::Invoice then
            LastSalesDocPostingStarted := SalesHeader."No.";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterValidateEvent, 'Job Task No.', false, false)]
    local procedure SyncJobPlanningLineOnAfterValidateJobTaskNo(var Rec: Record "Sales Line")
    begin
        SyncJobPlanningLineLink(Rec);
    end;

    // También se escucha 'Job No.' (caso de limpieza: el usuario borra el proyecto empezando
    // por este campo, con "Job Task No." ya diligenciado o vacío) — mismo procedimiento
    // compartido que el subscriber de 'Job Task No.', ver sección 5.2 del diseño.
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterValidateEvent, 'Job No.', false, false)]
    local procedure SyncJobPlanningLineOnAfterValidateJobNo(var Rec: Record "Sales Line")
    begin
        SyncJobPlanningLineLink(Rec);
    end;

    local procedure SyncJobPlanningLineLink(var SalesLine: Record "Sales Line")
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        if SalesLine.Type <> SalesLine.Type::Item then
            exit;
        if SalesLine."Document Type" <> SalesLine."Document Type"::Invoice then
            exit;

        if (SalesLine."Job No." = '') or (SalesLine."Job Task No." = '') then begin
            // Caso de limpieza: el usuario borró Job No. o Job Task No. -- si había un vínculo
            // propio de este desarrollo, se elimina la Job Planning Line oculta.
            RemoveAutoCreatedJobPlanningLine(SalesLine);
            exit;
        end;

        if SalesLine."Job Contract Entry No." <> 0 then begin
            // Hallazgo de revisión (2026-09-14): reasignar Job No./Job Task No. sobre una línea
            // que YA tiene vínculo no está cubierto por ningún guard nativo (a diferencia de
            // Quantity/Unit Price/Location Code/Variant Code/Unit of Measure Code, ni "Job No."
            // ni "Job Task No." están entre los 11 campos que dispara Sales Line.TestJobPlanningLine()
            // -- verificado contra el Sales Line decompilado). Sin este chequeo, la Job Planning
            // Line oculta se queda apuntando en silencio al proyecto/tarea viejo mientras la
            // Sales Line ya muestra el nuevo. Si el proyecto/tarea vinculado difiere del que
            // ahora tiene la línea, se trata como "quitar el vínculo viejo y crear uno nuevo".
            JobPlanningLine.SetCurrentKey("Job Contract Entry No.");
            JobPlanningLine.SetRange("Job Contract Entry No.", SalesLine."Job Contract Entry No.");
            if not JobPlanningLine.FindFirst() then begin
                // Segunda ronda de revisión (2026-09-14): mismo huérfano que ya se sanea arriba
                // (Job Contract Entry No. apunta a una Job Planning Line que ya no existe), pero
                // en esta rama el `and` de abajo lo habría saltado en corto sin sanear nada --
                // el usuario retipearía el proyecto/tarea y la Sales Line lo mostraría, pero
                // nunca se crearía la Job Planning Line real para el valor nuevo, sin ningún
                // error visible hasta que el posteo fallara mucho después.
                SalesLine."Job Contract Entry No." := 0;
                CreateJobPlanningLineFromSalesLine(SalesLine);
                exit;
            end;
            if JobPlanningLine."BH Auto-Created From Sales" and
               ((JobPlanningLine."Job No." <> SalesLine."Job No.") or (JobPlanningLine."Job Task No." <> SalesLine."Job Task No."))
            then begin
                RemoveAutoCreatedJobPlanningLine(SalesLine);
                CreateJobPlanningLineFromSalesLine(SalesLine);
            end;
            exit;
        end;

        CreateJobPlanningLineFromSalesLine(SalesLine);
    end;

    local procedure RemoveAutoCreatedJobPlanningLine(var SalesLine: Record "Sales Line")
    var
        JobPlanningLine: Record "Job Planning Line";
        JobPlanningLineInvoice: Record "Job Planning Line Invoice";
    begin
        if SalesLine."Job Contract Entry No." = 0 then
            exit;

        JobPlanningLine.SetCurrentKey("Job Contract Entry No.");
        JobPlanningLine.SetRange("Job Contract Entry No.", SalesLine."Job Contract Entry No.");
        if not JobPlanningLine.FindFirst() then begin
            // Huérfano (hallazgo 2026-09-14, sección 5.3 del diseño): la Job Planning Line que
            // este "Job Contract Entry No." referenciaba ya no existe (p.ej. se borró a mano
            // desde la ficha de Proyecto antes de que existiera el guard de abajo). Sin este
            // saneamiento, la Sales Line queda apuntando a un registro inexistente y el posteo
            // falla más tarde con "No hay Línea de planificación de proyecto dentro del filtro".
            SalesLine."Job Contract Entry No." := 0;
            exit;
        end;
        if not JobPlanningLine."BH Auto-Created From Sales" then
            exit; // línea de Job Contract genuina (asistente estándar de Proyectos) -- no tocar

        // Hallazgo de revisión (2026-09-14): a diferencia de CleanupOnAfterDeleteSalesLine, esta
        // rama borraba Job Planning Line Invoice sin filtrar por Document Type -- si por alguna
        // razón ya existiera una entrada Posted Invoice/Posted Credit Memo para este Job Contract
        // Entry No., el DeleteAll() de abajo la habría borrado también, en vez de abortar como
        // hace la otra rama para no destruir el rastro de auditoría. Verificado (segunda ronda de
        // revisión) que hoy no hay una ruta nativa alcanzable que produzca ese estado dado el
        // diseño 1:1 de este desarrollo (Codeunit "Correct Posted Sales Invoice" siempre asigna
        // un Job Contract Entry No. nuevo vía GetNextEntryNo(), nunca reutiliza uno existente) --
        // se deja como guard defensivo por simetría y bajo costo, no porque el escenario sea
        // alcanzable hoy.
        JobPlanningLineInvoice.SetRange("Job No.", JobPlanningLine."Job No.");
        JobPlanningLineInvoice.SetRange("Job Task No.", JobPlanningLine."Job Task No.");
        JobPlanningLineInvoice.SetRange("Job Planning Line No.", JobPlanningLine."Line No.");
        JobPlanningLineInvoice.SetFilter("Document Type", '%1|%2',
            JobPlanningLineInvoice."Document Type"::"Posted Invoice",
            JobPlanningLineInvoice."Document Type"::"Posted Credit Memo");
        if not JobPlanningLineInvoice.IsEmpty() then
            Error(CannotReassignAlreadyInvoicedErr);
        JobPlanningLineInvoice.SetRange("Document Type"); // se reutiliza la variable: ahora sin filtro, para borrar todos los borradores propios
        JobPlanningLineInvoice.DeleteAll();

        DeleteAutoCreatedJobPlanningLine(JobPlanningLine);

        // Limpieza vía asignación directa, NO Validate(): verificado contra el uso real de
        // Microsoft (Codeunit "Copy Document Mgt." decompilado, ClearSalesLineValues y
        // CopySalesDocLine) -- Sales Line."Job Contract Entry No." siempre se limpia con ":= 0"
        // directo. El OnValidate del campo 1002 no tiene guarda para el valor 0 (hace
        // FindFirst() sin condicionar), así que Validate(..., 0) fallaría o adjuntaría
        // dimensiones de una Job Planning Line ajena con Job Contract Entry No. = 0.
        SalesLine."Job Contract Entry No." := 0;
    end;

    local procedure CreateJobPlanningLineFromSalesLine(var SalesLine: Record "Sales Line")
    var
        SalesHeader: Record "Sales Header";
        JobPlanningLine: Record "Job Planning Line";
        JobPlanningLineInvoice: Record "Job Planning Line Invoice";
        LastJobPlanningLine: Record "Job Planning Line";
        NewLineNo: Integer;
    begin
        if not SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.") then
            exit;

        // Numeración de línea: mismo patrón que Pag60114 "Project Lines API" (FindLast + 10000),
        // sobre la combinación Job No./Job Task No. de destino.
        LastJobPlanningLine.SetRange("Job No.", SalesLine."Job No.");
        LastJobPlanningLine.SetRange("Job Task No.", SalesLine."Job Task No.");
        if LastJobPlanningLine.FindLast() then
            NewLineNo := LastJobPlanningLine."Line No." + 10000
        else
            NewLineNo := 10000;

        JobPlanningLine.Init();
        JobPlanningLine."Job No." := SalesLine."Job No.";
        JobPlanningLine."Job Task No." := SalesLine."Job Task No.";
        JobPlanningLine."Line No." := NewLineNo;
        JobPlanningLine.InitJobPlanningLine(); // asigna Job Contract Entry No. vía JobJnlManagement.GetNextEntryNo()

        JobPlanningLine.Validate(Type, JobPlanningLine.Type::Item);
        JobPlanningLine.Validate("No.", SalesLine."No.");

        // Hallazgo (2026-09-14, tercera ronda de soporte): `Job Post-Line.ValidateRelationship`
        // (que corre dentro de `PostInvoiceContractLine`, antes de generar el Job Ledger Entry)
        // exige que estos campos coincidan EXACTO entre la Sales Line y la Job Planning Line --
        // si no, falla con "<Campo> se ha cambiado (<valor inicial> a <valor real>)". Hasta ahora
        // solo se copiaban No./Cantidad/Costo/Precio -- si la línea de venta ya traía estos otros
        // campos poblados (p.ej. "Location Code" por defecto del almacén) ANTES de asignar el
        // proyecto, la Job Planning Line se creaba con ellos en blanco/default, sin coincidir.
        // Los subscribers de sincronización (SyncLocationCodeOnAfterValidate, etc., más abajo)
        // solo cubren CAMBIOS posteriores a la creación -- este es el faltante de la creación
        // inicial. Se sigue el mismo criterio que "Unit Cost" (solo Validate si no está en blanco
        // /0, para no pisar el default que ya calculó Type/"No." con un valor vacío).
        if SalesLine."Location Code" <> '' then
            JobPlanningLine.Validate("Location Code", SalesLine."Location Code");
        if SalesLine."Variant Code" <> '' then
            JobPlanningLine.Validate("Variant Code", SalesLine."Variant Code");
        if SalesLine."Unit of Measure Code" <> '' then
            JobPlanningLine.Validate("Unit of Measure Code", SalesLine."Unit of Measure Code");
        if SalesLine."Gen. Prod. Posting Group" <> '' then
            JobPlanningLine.Validate("Gen. Prod. Posting Group", SalesLine."Gen. Prod. Posting Group");
        if SalesLine."Line Discount %" <> 0 then
            JobPlanningLine.Validate("Line Discount %", SalesLine."Line Discount %");
        // "Work Type Code" (hallazgo de revisión) deliberadamente NO se copia: su OnValidate en
        // Job Planning Line exige TestField(Type, Type::Resource) -- como esta integración
        // siempre crea Type = Item, un Validate con valor no vacío abortaría la creación entera
        // con un TestField críptico. No hay ruta nativa que lo pueble en una Sales Line Type =
        // Item, así que en el caso sano ambos lados ya quedan en blanco por defecto; si algún día
        // aparece poblado por datos corruptos, es preferible que ValidateRelationship lo señale
        // como un FieldError claro al postear, no que la creación de la línea explote de entrada.

        // "VAT %" (campo 1041, sin OnValidate propio -- verificado): se asigna por valor directo,
        // igual que hace Microsoft en el asistente estándar (Codeunit "Job Create-Invoice",
        // JobPlanningLine."VAT %" := SalesLine."VAT %"). Sin esto, ValidateRelationship falla si
        // SalesHeader."Prices Including VAT" = true y la línea trae IVA -- no es un caso exótico
        // para D365LATAM Colombia.
        JobPlanningLine."VAT %" := SalesLine."VAT %";

        // IMPORTANTE (corrección de secuencia frente al pseudocódigo del diseño, sección 5.2):
        // "Line Type" debe fijarse ANTES de Quantity, no después. Verificado contra el blueprint
        // real de Microsoft (Codeunit 1303 "Correct Posted Sales Invoice" -> Job Planning Line.
        // InitFromJobPlanningLine, .alpackages decompilado): Quantity."OnValidate" llama
        // UpdateQtyToTransfer(), que solo calcula "Qty. to Transfer to Invoice" = Quantity si
        // "Contract Line" ya es true en ese momento -y "Contract Line" solo se pone true dentro
        // del OnValidate de "Line Type" al validarlo como Billable-. Si Quantity se valida antes
        // que Line Type (como en la transcripción original del diseño), "Qty. to Transfer to
        // Invoice" queda en 0 y el TestField("Qty. Transferred to Invoice") de
        // Job Post-Line.PostInvoiceContractLine falla al postear. El diseño mismo advertía que
        // este orden debía verificarse contra código real antes de implementar (sección 5.2).
        JobPlanningLine.Validate("Line Type", JobPlanningLine."Line Type"::Billable); // confirmado en firme por negocio (sección 2, decisión 3)
        JobPlanningLine.Validate(Quantity, SalesLine.Quantity);

        if SalesLine."Unit Cost" <> 0 then
            JobPlanningLine.Validate("Unit Cost", SalesLine."Unit Cost");
        JobPlanningLine.Validate("Unit Price", SalesLine."Unit Price");

        // Re-aplicar "Line Discount %" (hallazgo de revisión): a diferencia de "Unit Price", que
        // se vuelve a validar aquí explícitamente después de Quantity, "Line Discount %" no tenía
        // ese resguardo -- si algún día se configuran Price Lists de Job con descuento habilitado,
        // el motor de precios que corre dentro de Validate(Quantity, ...) (FindPriceAndDiscount ->
        // ApplyDiscount) puede sobrescribirlo en silencio con el descuento de la lista de precios
        // de Jobs, desalineándolo del que realmente tiene la Sales Line. Barato de repetir aquí
        // para no depender de si esa configuración está o no activa hoy.
        if SalesLine."Line Discount %" <> 0 then
            JobPlanningLine.Validate("Line Discount %", SalesLine."Line Discount %");

        JobPlanningLine."BH Auto-Created From Sales" := true;
        JobPlanningLine.Insert(true);

        JobPlanningLineInvoice.InitFromJobPlanningLine(JobPlanningLine);
        JobPlanningLineInvoice.InitFromSales(SalesHeader, JobPlanningLine."Planning Date", SalesLine."Line No.");
        // Nota: con el alcance reducido a Document Type = Invoice, InitFromSales ya asigna
        // "Document Type" := Invoice por sí solo (SalesHeader."Document Type" ya es Invoice en
        // este punto) -- la asignación explícita de abajo queda como salvaguarda idempotente,
        // sin efecto práctico distinto al que ya hace el procedimiento estándar.
        JobPlanningLineInvoice."Document Type" := JobPlanningLineInvoice."Document Type"::Invoice;
        JobPlanningLineInvoice.Insert();

        // Re-sincronización final (mismo patrón que usa Microsoft en Codeunit 1303 antes del
        // Insert() de la línea de planificación): NO es una red de seguridad para el borrador de
        // factura -- "Qty. to Transfer to Invoice" ya quedó grabado correctamente por el Validate
        // de Quantity de arriba (Line Type ya se validó antes). Es solo para mantener consistente
        // la propia Job Planning Line de cara a reportes/consultas sobre ese campo.
        JobPlanningLine.UpdateQtyToTransfer();
        JobPlanningLine.Modify();

        SalesLine.Validate("Job Contract Entry No.", JobPlanningLine."Job Contract Entry No.");
    end;

    // --- Sincronización de cantidad/costo/precio (sección 5.2) ---
    // Si la línea de venta ya está vinculada a una Job Planning Line propia, replica el cambio
    // sobre esa línea de planificación para que quede alineada mientras el documento sigue
    // siendo un borrador (Factura no contabilizada).

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterValidateEvent, 'Quantity', false, false)]
    local procedure SyncQuantityOnAfterValidate(var Rec: Record "Sales Line")
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        if not FindLinkedAutoCreatedJobPlanningLine(Rec, JobPlanningLine) then
            exit;

        JobPlanningLine.Validate(Quantity, Rec.Quantity);
        JobPlanningLine.UpdateQtyToTransfer();
        JobPlanningLine.Modify();
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterValidateEvent, 'Unit Price', false, false)]
    local procedure SyncUnitPriceOnAfterValidate(var Rec: Record "Sales Line")
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        if not FindLinkedAutoCreatedJobPlanningLine(Rec, JobPlanningLine) then
            exit;

        JobPlanningLine.Validate("Unit Price", Rec."Unit Price");
        JobPlanningLine.UpdateQtyToTransfer();
        JobPlanningLine.Modify();
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterValidateEvent, 'Unit Cost', false, false)]
    local procedure SyncUnitCostOnAfterValidate(var Rec: Record "Sales Line")
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        if not FindLinkedAutoCreatedJobPlanningLine(Rec, JobPlanningLine) then
            exit;

        JobPlanningLine.Validate("Unit Cost", Rec."Unit Cost");
        JobPlanningLine.UpdateQtyToTransfer();
        JobPlanningLine.Modify();
    end;

    // Advertencia #3 (review 2026-09-01): Job Post-Line.ValidateRelationship compara Location
    // Code/Variant Code/Unit of Measure Code (entre otros) entre Sales Line y Job Planning Line
    // al postear, y falla con FieldError genérico si difieren. Mismo patrón que
    // Quantity/Unit Price/Unit Cost arriba: si el vendedor cambia estos campos en la línea de
    // venta después de asignar el proyecto, se replica el cambio sobre la Job Planning Line
    // oculta enlazada para que no se desalineen mientras el documento sigue siendo borrador.

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterValidateEvent, 'Location Code', false, false)]
    local procedure SyncLocationCodeOnAfterValidate(var Rec: Record "Sales Line")
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        if not FindLinkedAutoCreatedJobPlanningLine(Rec, JobPlanningLine) then
            exit;

        JobPlanningLine.Validate("Location Code", Rec."Location Code");
        JobPlanningLine.UpdateQtyToTransfer();
        JobPlanningLine.Modify();
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterValidateEvent, 'Variant Code', false, false)]
    local procedure SyncVariantCodeOnAfterValidate(var Rec: Record "Sales Line")
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        if not FindLinkedAutoCreatedJobPlanningLine(Rec, JobPlanningLine) then
            exit;

        JobPlanningLine.Validate("Variant Code", Rec."Variant Code");
        JobPlanningLine.UpdateQtyToTransfer();
        JobPlanningLine.Modify();
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterValidateEvent, 'Unit of Measure Code', false, false)]
    local procedure SyncUnitOfMeasureCodeOnAfterValidate(var Rec: Record "Sales Line")
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        if not FindLinkedAutoCreatedJobPlanningLine(Rec, JobPlanningLine) then
            exit;

        JobPlanningLine.Validate("Unit of Measure Code", Rec."Unit of Measure Code");
        JobPlanningLine.UpdateQtyToTransfer();
        JobPlanningLine.Modify();
    end;

    local procedure FindLinkedAutoCreatedJobPlanningLine(SalesLine: Record "Sales Line"; var JobPlanningLine: Record "Job Planning Line"): Boolean
    begin
        if SalesLine."Job Contract Entry No." = 0 then
            exit(false);

        JobPlanningLine.SetCurrentKey("Job Contract Entry No.");
        JobPlanningLine.SetRange("Job Contract Entry No.", SalesLine."Job Contract Entry No.");
        if not JobPlanningLine.FindFirst() then
            exit(false);

        exit(JobPlanningLine."BH Auto-Created From Sales");
    end;

    // --- Limpieza al borrar la línea de venta (sección 5.2) ---
    // Si la línea borrada tenía una Job Planning Line propia vinculada y esa línea de
    // planificación no ha sido facturada todavía, se elimina también (junto con su
    // Job Planning Line Invoice borrador) para no dejarla huérfana en la ficha del Proyecto.
    // Si ya fue facturada (caso raro: se borra la línea de Factura después de una facturación
    // parcial), se deja intacta para revisión manual y se deja rastro en el log de telemetría.

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterDeleteEvent, '', false, false)]
    local procedure CleanupOnAfterDeleteSalesLine(var Rec: Record "Sales Line"; RunTrigger: Boolean)
    var
        JobPlanningLine: Record "Job Planning Line";
        JobPlanningLineInvoice: Record "Job Planning Line Invoice";
    begin
        if Rec."Job Contract Entry No." = 0 then
            exit;

        // Hallazgo confirmado con diagnóstico en vivo (2026-09-15, subscribers temporales que
        // interceptaban OnAfterDeleteEvent de Sales Line y mostraban RunTrigger + valores reales):
        // durante el posteo normal de una Factura de venta, ALGO borra la Sales Line BORRADOR
        // individualmente (con `RunTrigger = true`) ANTES de que
        // `Job Post-Line.PostInvoiceContractLine` promueva su `Job Planning Line Invoice` de
        // borrador a `"Posted Invoice"`. En ese instante, el filtro de abajo (Posted
        // Invoice/Posted Credit Memo) todavía no encuentra nada, y el código concluía
        // (incorrectamente, por eso "Bug crítico #2" de abajo se creyó código muerto) que la
        // línea nunca llegó a facturarse, borrando la Job Planning Line que el posteo, un
        // instante después en la MISMA transacción, todavía necesita.
        //
        // Origen exacto del borrado NO confirmado con certeza: el único borrado de Sales Line
        // encontrado en `Codeunit 80 "Sales-Post"` decompilado (`DeleteAfterPosting`,
        // `SalesLine.DeleteAll()`, sin `RunTrigger=true`) no debería, según la semántica estándar
        // de AL, disparar este evento -- probablemente el borrado real viene de una dependencia
        // instalada (D365LATAM, LyLVariantsExt) no decompilada. Un primer intento de arreglo
        // (buscar el `Sales Invoice Header` ya insertado por `"Pre-Assigned No."`, asumiendo que
        // `InsertPostedHeaders` corre antes del ciclo de posteo por línea) se descartó tras
        // confirmar con un segundo diagnóstico en vivo que, en el momento exacto de este borrado,
        // el header posteado de ESTA factura **todavía no existe** -- el borrado ocurre más
        // temprano de lo que `DIS-2026-08-31-jobs-sales-integration.md` documentaba.
        //
        // Se detecta en su lugar marcando el documento que está siendo posteado, vía
        // `OnBeforePostSalesDoc` de `Codeunit 80 "Sales-Post"` (dispara al principio de todo el
        // posteo, con la Sales Header real, antes de cualquier procesamiento de línea) -- ver
        // `MarkSalesDocPostingStarted` más abajo. Se usa el "Document No." como marcador (no un
        // simple booleano) para que sea auto-recuperable si algún día un posteo fallido no llega a
        // limpiar el marcador (ver comentario en esa misma sección): un borrado de línea posterior
        // sobre un documento DISTINTO simplemente no coincide y sigue su curso normal, en vez de
        // quedar bloqueado para siempre por un flag "pegado".
        if Rec."Document No." = LastSalesDocPostingStarted then
            exit;

        JobPlanningLine.SetCurrentKey("Job Contract Entry No.");
        JobPlanningLine.SetRange("Job Contract Entry No.", Rec."Job Contract Entry No.");
        if not JobPlanningLine.FindFirst() then
            exit;
        if not JobPlanningLine."BH Auto-Created From Sales" then
            exit; // línea de Job Contract genuina -- no tocar

        JobPlanningLineInvoice.SetRange("Job No.", JobPlanningLine."Job No.");
        JobPlanningLineInvoice.SetRange("Job Task No.", JobPlanningLine."Job Task No.");
        JobPlanningLineInvoice.SetRange("Job Planning Line No.", JobPlanningLine."Line No.");
        JobPlanningLineInvoice.SetFilter("Document Type", '%1|%2',
            JobPlanningLineInvoice."Document Type"::"Posted Invoice",
            JobPlanningLineInvoice."Document Type"::"Posted Credit Memo");

        // Bug crítico #2 (review 2026-09-01): "Qty. Transferred to Invoice" (FlowField 1080 de
        // Job Planning Line) se llena en cuanto se crea el BORRADOR de Job Planning Line Invoice
        // (InitFromJobPlanningLine/InitFromSales, ver CreateJobPlanningLineFromSalesLine más
        // arriba), no cuando se postea -- así que la condición "<> 0" era siempre verdadera desde
        // la creación y esta rama de borrado real nunca se alcanzaba (código muerto). La
        // comprobación correcta es solo el filtro a Posted Invoice/Posted Credit Memo de abajo.
        if not JobPlanningLineInvoice.IsEmpty() then begin
            Session.LogMessage('BH-JOBS-0001', StrSubstNo(OrphanedJobPlanningLineTelemetryTxt, JobPlanningLine."Job No.",
                JobPlanningLine."Job Task No.", JobPlanningLine."Line No."), Verbosity::Warning,
                DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'BH Jobs Sales Integration');
            exit;
        end;

        JobPlanningLineInvoice.SetRange("Document Type"); // se reutiliza la variable: ahora sin filtro, para borrar todos los borradores propios
        JobPlanningLineInvoice.DeleteAll();

        DeleteAutoCreatedJobPlanningLine(JobPlanningLine);
    end;

    // Hallazgo (2026-09-14, segunda ronda de soporte): la primera versión de este guard usaba
    // una variable global del codeunit (`AllowInternalJobPlanningLineDeletion`) para que
    // `BlockManualDeleteOfAutoCreatedJobPlanningLine` supiera cuándo el borrado venía de nuestras
    // propias rutinas de limpieza. En la práctica, el guard bloqueó también esas rutinas propias
    // (confirmado en `SandboxBH`: no se podía ni quitar el proyecto de una línea de Factura) --
    // este codeunit no es `SingleInstance`, así que no hay garantía de que la instancia que
    // ejecuta el subscriber del evento anidado (disparado por `Delete()` dentro de la misma
    // llamada) vea el mismo valor de esa variable que la instancia que la puso en `true`.
    //
    // Tercera ronda (2026-09-14): la señal se mueve a un campo del propio registro, pero
    // PERSISTIDO con `Modify()` antes del `Delete(true)` -- no basta con cambiarlo solo en el
    // buffer en memoria. Se confirmó con diagnóstico en vivo que el borrado en cascada nativo de
    // `Job Task.OnDelete` (`JobPlanningLine.DeleteAll(true)`, ver el guard más abajo) entrega un
    // `Rec` en `OnBeforeDeleteEvent` que no refleja de forma confiable el valor real en BD -- por
    // eso el guard ahora siempre hace su propio `Get()` fresco en vez de confiar en el `Rec` que
    // recibe. Si nuestra propia limpieza solo mutara el buffer en memoria sin `Modify()`, ese
    // `Get()` del guard seguiría viendo `true` en la base de datos y bloquearía nuestro propio
    // borrado autorizado. Al persistir el `false` primero, cualquier lectura fresca (la nuestra o
    // la del guard) ve el mismo valor. Ambos pasos van dentro del mismo `[TryFunction]` para que,
    // si el `Delete(true)` posterior falla, el `Modify()` también se revierta (no debe quedar una
    // línea real "desmarcada" que ya no se reconozca como propia en el resto del codeunit).
    local procedure DeleteAutoCreatedJobPlanningLine(var JobPlanningLine: Record "Job Planning Line")
    var
        DeleteSucceeded: Boolean;
    begin
        DeleteSucceeded := TryClearFlagAndDeleteJobPlanningLine(JobPlanningLine);

        if not DeleteSucceeded then
            Error(GetLastErrorText());
    end;

    [TryFunction]
    local procedure TryClearFlagAndDeleteJobPlanningLine(var JobPlanningLine: Record "Job Planning Line")
    begin
        JobPlanningLine."BH Auto-Created From Sales" := false;
        JobPlanningLine.Modify();
        JobPlanningLine.Delete(true);
    end;

    // --- Posteo de Factura — supresión de Item Ledger Entry (sección 4.3/5.2 del diseño) ---
    // `Codeunit 80 "Sales-Post"` suprime la creación del `Item Ledger Entry` (movimiento real de
    // inventario/COGS) para *cualquier* línea con `"Job Contract Entry No." > 0` (variable interna
    // `JobContractLine`) -- comportamiento correcto en el uso estándar de Microsoft (facturar una
    // `Job Planning Line` ya consumida vía `Job Journal` no debe volver a mover inventario), pero
    // incorrecto para este desarrollo, donde la Factura representa una venta real que sí debe
    // descontar inventario y contabilizar COGS con normalidad, además de generar el
    // `Job Ledger Entry` de proyecto. Este subscriber, acotado por el marcador
    // "BH Auto-Created From Sales" (nunca actúa sobre líneas de proyecto genuinas creadas por el
    // asistente estándar), restaura ese posteo normal únicamente para las líneas propias.
    //
    // A diferencia de los otros 3 subscribers de "Ruta A" que existían cuando este desarrollo
    // también cubría el Pedido de venta (retirados el 2026-09-14 al reducirse el alcance a solo
    // Factura, ver comentario al inicio del archivo), este subscriber no depende del
    // `Document Type` -- la supresión del Item Ledger Entry ocurre igual para una Factura.
    // Firma verificada contra el fuente decompilado de Codeunit 80 "Sales-Post"
    // (.alpackages/Microsoft_Base Application_27.5.46862.52525.app,
    // src/Sales/Posting/SalesPost.Codeunit.al, procedimiento PostItemJnlLine, línea ~10805).
    //
    // Falta de trazabilidad hacia el proyecto (hallazgo 2026-09-21, soporte post-publicación):
    // `PostItemJnlLinePrepareJournalLine` (que corre justo antes de este evento, sobre el mismo
    // `ItemJnlLine`) arma la línea vía `ItemJnlLine.CopyFromSalesLine(SalesLine)` -- verificado
    // contra el fuente decompilado (src/Inventory/Journal/ItemJournalLine.Table.al) que ese
    // procedimiento NO copia `"Job No."`/`"Job Task No."` (campos 1000/1001 de Item Journal
    // Line): esos dos campos solo se llenan hoy desde `TransferFieldsFromPurchLine`
    // (Purchase Line) o desde el Diario de Proyecto (`Job Jnl. Line`), nunca desde Sales Line.
    // `Item Jnl.-Post Line` (src/Inventory/Posting/ItemJnlPostLine.Codeunit.al, ~línea 1894)
    // copia esos dos campos tal cual del Item Journal Line al Item Ledger Entry resultante --
    // así que, sin este ajuste, el Item Ledger Entry de la venta quedaba con `Job No.`/
    // `Job Task No.` en blanco. Consecuencia confirmada en vivo (SandboxBH, Factura FEN002045,
    // ítem ADPRSR5D): el movimiento de inventario se generaba correcto y visible desde la Ficha
    // de artículo, pero no aparecía al consultar "Movs. producto" desde la Ficha de Proyecto,
    // porque esa vista filtra Item Ledger Entry por esos mismos campos. Se asignan aquí, antes
    // de que `ShouldPostItemJnlLine := true` deje seguir el posteo, reutilizando el mismo
    // `ItemJnlLine` por referencia que ya recibe este subscriber -- no se necesita un evento
    // adicional. No se toca `"Job Purchase"` (booleano que distingue una compra con destino a
    // proyecto, ver `ItemLedgEntry."Job Purchase" := ItemJnlLine."Job Purchase"` en el mismo
    // codeunit): no aplica a una venta y su default `false` es correcto.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", OnPostItemJnlLineOnBeforeIsJobContactLineCheck, '', false, false)]
    local procedure RestoreItemPostingForJobContractLine(var ItemJnlLine: Record "Item Journal Line"; SalesHeader: Record "Sales Header"; SalesLine: Record "Sales Line"; var ShouldPostItemJnlLine: Boolean; var ItemJnlPostLine: Codeunit "Item Jnl.-Post Line"; QtyToBeShipped: Decimal)
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        if SalesLine."Job Contract Entry No." = 0 then
            exit;

        JobPlanningLine.SetCurrentKey("Job Contract Entry No.");
        JobPlanningLine.SetRange("Job Contract Entry No.", SalesLine."Job Contract Entry No.");
        if not JobPlanningLine.FindFirst() then
            exit;
        if not JobPlanningLine."BH Auto-Created From Sales" then
            exit; // línea de Job Contract genuina (Job Create-Invoice estándar): dejar el
                  // comportamiento nativo de Microsoft (Item Ledger Entry suprimido, ya se
                  // descontó vía Job Journal Usage)

        ItemJnlLine."Job No." := SalesLine."Job No.";
        ItemJnlLine."Job Task No." := SalesLine."Job Task No.";

        ShouldPostItemJnlLine := true; // restaura el posteo normal de inventario/COGS para esta línea
    end;

    // --- Guard defensivo contra borrado manual desde la ficha de Proyecto (hallazgo 2026-09-14,
    // sección 3.2/5.2 de DIS-2026-09-14-jobs-invoice-posting-fixes.md) ---
    // Causa raíz confirmada con diagnóstico en vivo (SandboxBH): el disparador real no era el
    // posteo de la Factura, sino borrar la TAREA DE PROYECTO directamente (`Job Task`) desde la
    // ficha del Proyecto -- su `OnDelete` (`JobTask.Table.al`) hace
    // `JobPlanningLine.SetRange("Job No.", ...); SetRange("Job Task No.", ...); DeleteAll(true);`
    // sin distinguir líneas propias de genuinas, y cuando `CalledFromHeader = true` incluso
    // suspende la protección nativa (`SuspendDeletionCheck`) que en otro caso habría bloqueado el
    // borrado mientras existiera un `Job Planning Line Invoice` asociado. Un diagnóstico temporal
    // confirmó además que el `Rec` que llega a este `OnBeforeDeleteEvent` durante ese `DeleteAll`
    // en cascada trae `"BH Auto-Created From Sales"` en `false` aunque el valor real en la base de
    // datos sea `true` -- por eso la primera versión de este guard (que confiaba directo en el
    // campo del `Rec` recibido) dejaba pasar el borrado en cascada sin bloquearlo. Se corrige
    // haciendo un `Get()` propio para releer el campo directo de la base de datos, sin depender de
    // qué haya cargado quien dispara el borrado.
    //
    // Nuestros propios procedimientos de limpieza (`RemoveAutoCreatedJobPlanningLine`,
    // `CleanupOnAfterDeleteSalesLine`, vía `DeleteAutoCreatedJobPlanningLine`) ahora PERSISTEN el
    // marcador en `false` con `Modify()` antes de llamar `Delete(true)` -- justamente para que este
    // `Get()` también vea ese cambio y los deje pasar. Si solo se mutara el buffer en memoria sin
    // guardarlo, este mismo `Get()` fresco bloquearía también nuestro propio borrado autorizado.
    [EventSubscriber(ObjectType::Table, Database::"Job Planning Line", OnBeforeDeleteEvent, '', false, false)]
    local procedure BlockManualDeleteOfAutoCreatedJobPlanningLine(var Rec: Record "Job Planning Line"; RunTrigger: Boolean)
    var
        FreshRead: Record "Job Planning Line";
    begin
        if not FreshRead.Get(Rec."Job No.", Rec."Job Task No.", Rec."Line No.") then
            exit; // ya no existe en BD (huérfano de otro proceso) -- nada que proteger aquí

        if not FreshRead."BH Auto-Created From Sales" then
            exit; // línea de Job Contract genuina, o ya despojada del marcador por nuestra propia limpieza -- no tocar

        Error(CannotDeleteFromJobErr);
    end;

    var
        OrphanedJobPlanningLineTelemetryTxt: Label 'Se borró una Sales Line vinculada a la Job Planning Line %1/%2/%3 (BH Auto-Created From Sales), pero ya tenía facturación asociada -- no se eliminó, requiere revisión manual.', Comment = '%1 = Job No., %2 = Job Task No., %3 = Line No.', Locked = true;
        CannotDeleteFromJobErr: Label 'Esta línea de planificación fue creada automáticamente desde una línea de Factura de venta y no se puede eliminar desde aquí. Para quitar el vínculo, borre el N.º proyecto/N.º tarea proyecto directamente en la línea de la Factura de venta.';
        CannotReassignAlreadyInvoicedErr: Label 'No se puede quitar ni reasignar el proyecto de esta línea porque ya tiene facturación asociada. Requiere revisión manual.';
        LastSalesDocPostingStarted: Code[20];
}
