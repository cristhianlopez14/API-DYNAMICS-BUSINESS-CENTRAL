codeunit 60130 "BH Purchase Job No Consumption"
{
    // Una línea de compra de Producto con Job No. no genera el ajuste negativo (consumo) al
    // registrar: el inventario permanece en el almacén y solo queda el movimiento de compra.
    // Aun así el costo real debe verse en el proyecto, así que se crea el Job Ledger Entry de
    // consumo SIN Item Ledger Entry asociado (en BC estándar ese JLE nace del Value Entry del
    // ajuste negativo, que aquí ya no existe).
    // SingleInstance: el flag que une el subscriber de Purch.-Post con los de Job Jnl.-Post Line
    // debe compartirse entre ambos (ver CLAUDE.md, hallazgo SingleInstance).
    SingleInstance = true;

    var
        PostingJobWithoutItemLedger: Boolean;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", OnBeforePostPurchaseDoc, '', false, false)]
    local procedure ResetFlagOnBeforePostPurchaseDoc()
    begin
        // Auto-recuperación si un posteo anterior falló a mitad de camino con el flag activo.
        PostingJobWithoutItemLedger := false;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", OnPostItemJnlLineJobConsumption, '', false, false)]
    local procedure PostJobLedgerEntryWithoutItemLedger(PurchHeader: Record "Purchase Header"; var PurchLine: Record "Purchase Line"; QtyToBeInvoiced: Decimal; var IsHandled: Boolean; var PurchInvHeader: Record "Purch. Inv. Header"; var PurchCrMemoHeader: Record "Purch. Cr. Memo Hdr."; SrcCode: Code[10])
    var
        JobPostLine: Codeunit "Job Post-Line";
    begin
        if PurchLine."Job No." = '' then
            exit;

        // Sin ajuste negativo de inventario (omite el procedimiento estándar completo).
        IsHandled := true;

        // Como en el estándar, el costo real al proyecto solo se registra al facturar.
        if QtyToBeInvoiced = 0 then
            exit;

        PurchLine."Qty. to Invoice" := QtyToBeInvoiced;
        PostingJobWithoutItemLedger := true;
        JobPostLine.PostJobOnPurchaseLine(PurchHeader, PurchInvHeader, PurchCrMemoHeader, PurchLine, SrcCode);
        PostingJobWithoutItemLedger := false;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Job Jnl.-Post Line", OnCodeOnAfterCalcShouldPostUsage, '', false, false)]
    local procedure SkipItemConsumptionLookup(var JobJournalLine2: Record "Job Journal Line"; var ShouldPostUsage: Boolean)
    begin
        if not IsOwnItemLine(JobJournalLine2) then
            exit;

        // false => BC llama CreateJobLedgEntry directo, sin buscar Value Entry de consumo.
        ShouldPostUsage := false;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Job Jnl.-Post Line", OnCreateJobLedgerEntryOnAfterAssignLedgerEntryTypeAndNo, '', false, false)]
    local procedure ClearItemLedgerLink(var JobLedgEntry: Record "Job Ledger Entry"; JobJournalLine: Record "Job Journal Line")
    begin
        if not IsOwnItemLine(JobJournalLine) then
            exit;

        // No existe Item Ledger Entry: evita un JLE con enlace a un movimiento inexistente.
        JobLedgEntry."Ledger Entry Type" := JobLedgEntry."Ledger Entry Type"::" ";
        JobLedgEntry."Ledger Entry No." := 0;
    end;

    local procedure IsOwnItemLine(JobJournalLine: Record "Job Journal Line"): Boolean
    begin
        exit(
          PostingJobWithoutItemLedger and
          JobJournalLine."Job Posting Only" and
          (JobJournalLine.Type = JobJournalLine.Type::Item));
    end;
}
