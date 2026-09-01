codeunit 60123 "BH Sales Job Planning Mgt."
{
    // DIS-2026-08-31 — Integración Proyectos (Jobs) con Pedido/Factura de venta,
    // líneas Tipo = Artículo. Ver docs/diseños/DIS-2026-08-31-jobs-sales-integration.md.
    //
    // Patrón de fondo: cuando el usuario diligencia Job No./Job Task No. en una línea
    // de venta Tipo = Artículo, se crea una Job Planning Line "oculta" (Line Type =
    // Billable, marcada "BH Auto-Created From Sales") para que el motor nativo de
    // Jobs (Job Post-Line) genere el Job Ledger Entry tipo Sale al postear la línea,
    // exactamente igual que si viniera de una línea de planificación facturable real
    // transferida por el asistente estándar de Proyectos.

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
    begin
        if SalesLine.Type <> SalesLine.Type::Item then
            exit;
        if not (SalesLine."Document Type" in [SalesLine."Document Type"::Order, SalesLine."Document Type"::Invoice]) then
            exit;

        if (SalesLine."Job No." = '') or (SalesLine."Job Task No." = '') then begin
            // Caso de limpieza: el usuario borró Job No. o Job Task No. -- si había un vínculo
            // propio de este desarrollo, se elimina la Job Planning Line oculta.
            RemoveAutoCreatedJobPlanningLine(SalesLine);
            exit;
        end;

        if SalesLine."Job Contract Entry No." <> 0 then
            exit; // ya hay un vínculo -- propio previo, o genuino del asistente estándar de Proyectos

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
        if not JobPlanningLine.FindFirst() then
            exit;
        if not JobPlanningLine."BH Auto-Created From Sales" then
            exit; // línea de Job Contract genuina (asistente estándar de Proyectos) -- no tocar

        JobPlanningLineInvoice.SetRange("Job No.", JobPlanningLine."Job No.");
        JobPlanningLineInvoice.SetRange("Job Task No.", JobPlanningLine."Job Task No.");
        JobPlanningLineInvoice.SetRange("Job Planning Line No.", JobPlanningLine."Line No.");
        JobPlanningLineInvoice.DeleteAll();

        JobPlanningLine.Delete(true);

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

        JobPlanningLine."BH Auto-Created From Sales" := true;
        JobPlanningLine.Insert(true);

        JobPlanningLineInvoice.InitFromJobPlanningLine(JobPlanningLine);
        JobPlanningLineInvoice.InitFromSales(SalesHeader, JobPlanningLine."Planning Date", SalesLine."Line No.");
        // FIX obligatorio (hallazgo sección 3 del diseño): InitFromSales solo asigna
        // "Document Type" := Invoice cuando SalesHeader."Document Type" YA es Invoice/Credit Memo.
        // Este subscriber también corre con SalesHeader."Document Type" = Order (Job Task No.
        // tecleado en el Pedido), así que se fuerza explícitamente para que el Get() de
        // Job Post-Line.PostInvoiceContractLine (Ruta A, ver subscribers de posteo más abajo)
        // encuentre el registro al momento de postear. Idempotente si SalesHeader."Document Type"
        // ya era Invoice (CA3, Factura creada directamente).
        JobPlanningLineInvoice."Document Type" := JobPlanningLineInvoice."Document Type"::Invoice;
        JobPlanningLineInvoice.Insert();

        // Re-sincronización final de seguridad (mismo patrón "belt-and-suspenders" que usa
        // Microsoft en Codeunit 1303 antes del Insert() de la línea de planificación).
        JobPlanningLine.UpdateQtyToTransfer();
        JobPlanningLine.Modify();

        SalesLine.Validate("Job Contract Entry No.", JobPlanningLine."Job Contract Entry No.");
    end;

    // --- Sincronización de cantidad/costo/precio (sección 5.2) ---
    // Si la línea de venta ya está vinculada a una Job Planning Line propia, replica el cambio
    // sobre esa línea de planificación para que quede alineada mientras el documento sigue
    // siendo un borrador (Pedido o Factura no contabilizados).

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
    // Si ya fue facturada (caso raro: se borra la línea de Pedido después de una facturación
    // parcial), se deja intacta para revisión manual y se deja rastro en el log de telemetría.

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterDeleteEvent, '', false, false)]
    local procedure CleanupOnAfterDeleteSalesLine(var Rec: Record "Sales Line"; RunTrigger: Boolean)
    var
        JobPlanningLine: Record "Job Planning Line";
        JobPlanningLineInvoice: Record "Job Planning Line Invoice";
    begin
        if Rec."Job Contract Entry No." = 0 then
            exit;

        JobPlanningLine.SetCurrentKey("Job Contract Entry No.");
        JobPlanningLine.SetRange("Job Contract Entry No.", Rec."Job Contract Entry No.");
        if not JobPlanningLine.FindFirst() then
            exit;
        if not JobPlanningLine."BH Auto-Created From Sales" then
            exit; // línea de Job Contract genuina -- no tocar

        JobPlanningLine.CalcFields("Qty. Transferred to Invoice");

        JobPlanningLineInvoice.SetRange("Job No.", JobPlanningLine."Job No.");
        JobPlanningLineInvoice.SetRange("Job Task No.", JobPlanningLine."Job Task No.");
        JobPlanningLineInvoice.SetRange("Job Planning Line No.", JobPlanningLine."Line No.");
        JobPlanningLineInvoice.SetFilter("Document Type", '%1|%2',
            JobPlanningLineInvoice."Document Type"::"Posted Invoice",
            JobPlanningLineInvoice."Document Type"::"Posted Credit Memo");

        if (JobPlanningLine."Qty. Transferred to Invoice" <> 0) or not JobPlanningLineInvoice.IsEmpty() then begin
            Session.LogMessage('BH-JOBS-0001', StrSubstNo(OrphanedJobPlanningLineTelemetryTxt, JobPlanningLine."Job No.",
                JobPlanningLine."Job Task No.", JobPlanningLine."Line No."), Verbosity::Warning,
                DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', 'BH Jobs Sales Integration');
            exit;
        end;

        JobPlanningLineInvoice.SetRange("Document Type"); // se reutiliza la variable: ahora sin filtro, para borrar todos los borradores propios
        JobPlanningLineInvoice.DeleteAll();

        JobPlanningLine.Delete(true);
    end;

    // --- Ruta A (sección 4.3/5.2b del diseño) — enganche real al posteo combinado ---
    // El Pedido de venta nunca cambia "Document Type" durante "Enviado y Facturado" en un
    // paso (permanece en Order de principio a fin), pero Codeunit 80 "Sales-Post" exige, vía
    // TestField, que "Job Contract Entry No." sea 0 en todo documento que no sea Invoice/Credit
    // Memo. Los dos subscribers siguientes interceptan el posteo, únicamente para líneas
    // marcadas "BH Auto-Created From Sales", para resolver ese choque sin tocar el objeto base.

    // Firma verificada contra el fuente decompilado de Codeunit 80 "Sales-Post"
    // (.alpackages/Microsoft_Base Application_27.5.46862.52525.app,
    // src/Sales/Posting/SalesPost.Codeunit.al, línea ~11393).
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", OnPostJobContractLineBeforeTestFields, '', false, false)]
    local procedure AllowOrderPostingForJobContractLine(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; var IsHandled: Boolean)
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        if SalesHeader."Document Type" <> SalesHeader."Document Type"::Order then
            exit; // ya es Invoice/Credit Memo: flujo nativo de Microsoft, no tocar

        if SalesLine."Job Contract Entry No." = 0 then
            exit;

        JobPlanningLine.SetCurrentKey("Job Contract Entry No.");
        JobPlanningLine.SetRange("Job Contract Entry No.", SalesLine."Job Contract Entry No.");
        if not JobPlanningLine.FindFirst() then
            exit;
        if not JobPlanningLine."BH Auto-Created From Sales" then
            exit; // no es una línea de este desarrollo, no intervenir

        if not SalesHeader.Invoice then begin
            // Ship-only en esta corrida (fuera del alcance real de negocio, pero no debe fallar,
            // ver CA9): no se factura todavía, se salta el TestField y el PrepareJobLine de esta
            // corrida sin error; el vínculo queda pendiente para cuando sí se facture.
            IsHandled := true;
            exit;
        end;

        // Mutación LOCAL, contenida al stack frame de PostJobContractLine (verificado: ningún
        // parámetro es "var" en la cadena de llamadas hasta este punto) -- no persiste en BD, no
        // afecta el resto del posteo (envío, numeración, G/L). A partir de aquí,
        // PostJobContractLine hace el resto solo: salta el TestField, asigna
        // SalesLine."Document No." := SalesInvHeader."No.", y llama
        // InvoicePostingInterface.PrepareJobLine(...).
        SalesHeader."Document Type" := SalesHeader."Document Type"::Invoice;
    end;

    // Firma verificada contra el fuente decompilado de Codeunit 80 "Sales-Post"
    // (mismo paquete, procedimiento PostItemJnlLine, línea ~10805).
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

        ShouldPostItemJnlLine := true; // restaura el posteo normal de inventario/COGS para esta línea
    end;

    var
        OrphanedJobPlanningLineTelemetryTxt: Label 'Se borró una Sales Line vinculada a la Job Planning Line %1/%2/%3 (BH Auto-Created From Sales), pero ya tenía facturación asociada -- no se eliminó, requiere revisión manual.', Comment = '%1 = Job No., %2 = Job Task No., %3 = Line No.';
}
