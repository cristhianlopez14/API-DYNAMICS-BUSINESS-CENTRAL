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

    local procedure SyncJobPlanningLineLink(var SalesLine: Record "Sales Line")
    begin
        if SalesLine.Type <> SalesLine.Type::Item then
            exit;
        if not (SalesLine."Document Type" in [SalesLine."Document Type"::Order, SalesLine."Document Type"::Invoice]) then
            exit;

        if (SalesLine."Job No." = '') or (SalesLine."Job Task No." = '') then
            exit;

        if SalesLine."Job Contract Entry No." <> 0 then
            exit; // ya hay un vínculo -- propio previo, o genuino del asistente estándar de Proyectos

        CreateJobPlanningLineFromSalesLine(SalesLine);
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
}
