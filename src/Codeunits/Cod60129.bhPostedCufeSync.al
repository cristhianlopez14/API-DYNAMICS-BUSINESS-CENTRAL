codeunit 60129 "BH Posted CUFE Sync"
{
    // Solo copia un campo propio a la factura registrada. No registra ni dispara registro alguno.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", OnAfterPurchInvHeaderInsert, '', false, false)]
    local procedure CopyCufeOnAfterPurchInvHeaderInsert(var PurchInvHeader: Record "Purch. Inv. Header"; var PurchHeader: Record "Purchase Header"; PreviewMode: Boolean)
    begin
        if PurchHeader."BH CUFE" = '' then
            exit;

        PurchInvHeader."BH CUFE" := PurchHeader."BH CUFE";
        PurchInvHeader.Modify();
    end;
}
