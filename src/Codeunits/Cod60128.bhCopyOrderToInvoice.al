codeunit 60128 "BH Copy Order To Invoice"
{
    // Copia las lineas de un Pedido de compra a una Factura de compra BORRADOR.
    // Nunca llama a rutinas de registro (Purch.-Post); solo Codeunit "Copy Document Mgt.".

    procedure CopyFromOrder(InvoiceSystemId: Guid; OrderNo: Code[20]; var InvoiceHeader: Record "Purchase Header"): Integer
    var
        OrderHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        CopyDocMgt: Codeunit "Copy Document Mgt.";
        FromDocType: Enum "Purchase Document Type From";
    begin
        // Bloquear la cabecera y releerla: dos llamadas simultaneas no pueden ver ambas "sin lineas".
        InvoiceHeader.LockTable();
        if not InvoiceHeader.GetBySystemId(InvoiceSystemId) then
            Error('La factura de compra destino no existe.');

        if InvoiceHeader."Document Type" <> InvoiceHeader."Document Type"::Invoice then
            Error('El documento %1 no es una factura de compra.', InvoiceHeader."No.");

        CheckNotPosted(InvoiceHeader);

        if InvoiceHeader.Status <> InvoiceHeader.Status::Open then
            Error('La factura %1 no esta abierta (estado: %2). Reabrala antes de copiar.', InvoiceHeader."No.", InvoiceHeader.Status);

        PurchLine.SetRange("Document Type", InvoiceHeader."Document Type");
        PurchLine.SetRange("Document No.", InvoiceHeader."No.");
        if not PurchLine.IsEmpty() then
            Error('La factura %1 ya tiene lineas; no se copia de nuevo.', InvoiceHeader."No.");

        if not OrderHeader.Get(OrderHeader."Document Type"::Order, OrderNo) then
            Error('El pedido de compra %1 no existe.', OrderNo);

        if not (OrderHeader.Status in [OrderHeader.Status::Open, OrderHeader.Status::Released]) then
            Error('El pedido %1 no esta abierto ni liberado (estado: %2).', OrderNo, OrderHeader.Status);

        if OrderHeader."Buy-from Vendor No." <> InvoiceHeader."Buy-from Vendor No." then
            Error('El proveedor del pedido %1 (%2) no coincide con el de la factura %3 (%4).',
                OrderNo, OrderHeader."Buy-from Vendor No.", InvoiceHeader."No.", InvoiceHeader."Buy-from Vendor No.");

        if OrderHeader."Currency Code" <> InvoiceHeader."Currency Code" then
            Error('La moneda del pedido %1 (%2) no coincide con la de la factura %3 (%4).',
                OrderNo, CurrencyOrLCY(OrderHeader."Currency Code"), InvoiceHeader."No.", CurrencyOrLCY(InvoiceHeader."Currency Code"));

        CheckOrderNotAlreadyInvoiced(OrderHeader);
        CheckDuplicateVendorInvoiceNo(InvoiceHeader);

        // IncludeHeader = false, RecalculateLines = false; HideDialog = true.
        CopyDocMgt.SetProperties(false, false, false, false, true, false, false);
        FromDocType := FromDocType::Order;
        CopyDocMgt.CopyPurchDoc(FromDocType, OrderNo, InvoiceHeader);

        InvoiceHeader.Get(InvoiceHeader."Document Type", InvoiceHeader."No.");
        InvoiceHeader.CalcFields(Amount, "Amount Including VAT");

        PurchLine.Reset();
        PurchLine.SetRange("Document Type", InvoiceHeader."Document Type");
        PurchLine.SetRange("Document No.", InvoiceHeader."No.");
        exit(PurchLine.Count());
    end;

    // Rechaza un Vendor Invoice No. repetido para el mismo proveedor (borradores y registradas).
    procedure CheckDuplicateVendorInvoiceNo(InvoiceHeader: Record "Purchase Header")
    var
        OtherHeader: Record "Purchase Header";
        PostedHeader: Record "Purch. Inv. Header";
    begin
        if InvoiceHeader."Vendor Invoice No." = '' then
            exit;
        if InvoiceHeader."Buy-from Vendor No." = '' then
            exit;

        OtherHeader.SetRange("Document Type", OtherHeader."Document Type"::Invoice);
        OtherHeader.SetRange("Buy-from Vendor No.", InvoiceHeader."Buy-from Vendor No.");
        OtherHeader.SetRange("Vendor Invoice No.", InvoiceHeader."Vendor Invoice No.");
        OtherHeader.SetFilter("No.", '<>%1', InvoiceHeader."No.");
        if not OtherHeader.IsEmpty() then
            Error('Ya existe un borrador de factura (%1) del proveedor %2 con el Vendor Invoice No. %3.',
                OtherHeader."No.", InvoiceHeader."Buy-from Vendor No.", InvoiceHeader."Vendor Invoice No.");

        PostedHeader.SetRange("Buy-from Vendor No.", InvoiceHeader."Buy-from Vendor No.");
        PostedHeader.SetRange("Vendor Invoice No.", InvoiceHeader."Vendor Invoice No.");
        if not PostedHeader.IsEmpty() then
            Error('Ya existe una factura registrada del proveedor %1 con el Vendor Invoice No. %2.',
                InvoiceHeader."Buy-from Vendor No.", InvoiceHeader."Vendor Invoice No.");
    end;

    local procedure CheckNotPosted(InvoiceHeader: Record "Purchase Header")
    var
        PostedHeader: Record "Purch. Inv. Header";
    begin
        PostedHeader.SetRange("Pre-Assigned No.", InvoiceHeader."No.");
        if not PostedHeader.IsEmpty() then
            Error('La factura %1 ya fue registrada.', InvoiceHeader."No.");
    end;

    // "Copiar documento" copia la cantidad completa; si alguna linea ya tiene cantidad facturada,
    // copiarla duplicaria el gasto (Quantity Invoiced + Quantity > Quantity).
    local procedure CheckOrderNotAlreadyInvoiced(OrderHeader: Record "Purchase Header")
    var
        OrderLine: Record "Purchase Line";
    begin
        OrderLine.SetRange("Document Type", OrderHeader."Document Type");
        OrderLine.SetRange("Document No.", OrderHeader."No.");
        OrderLine.SetFilter("Quantity Invoiced", '<>0');
        if OrderLine.FindFirst() then
            Error('El pedido %1 ya tiene cantidades facturadas (linea %2: %3 de %4); copiarlo superaria lo pedido.',
                OrderHeader."No.", OrderLine."Line No.", OrderLine."Quantity Invoiced", OrderLine.Quantity);
    end;

    local procedure CurrencyOrLCY(CurrencyCode: Code[10]): Text
    begin
        if CurrencyCode = '' then
            exit('moneda local');
        exit(CurrencyCode);
    end;
}
