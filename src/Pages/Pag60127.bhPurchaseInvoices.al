page 60127 "BH Purchase Invoices API"
{
    PageType = API;
    SourceTable = "Purchase Header";
    SourceTableView = where("Document Type" = const(Invoice));

    APIPublisher = 'bh';
    APIGroup = 'causacion';
    APIVersion = 'v1.0';

    EntityName = 'bhPurchaseInvoice';
    EntitySetName = 'bhPurchaseInvoices';

    Caption = 'BH Purchase Invoices API';
    ApplicationArea = All;

    Editable = true;
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = false;
    DelayedInsert = true;

    ODataKeyFields = SystemId;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                    Editable = false;
                }
                field(number; Rec."No.")
                {
                    Caption = 'No.';
                    Editable = false;
                }
                field(vendorNumber; VendorNoLP)
                {
                    Caption = 'Vendor No.';
                }
                field(vendorInvoiceNumber; Rec."Vendor Invoice No.")
                {
                    Caption = 'Vendor Invoice No.';
                }
                field(cufe; Rec."BH CUFE")
                {
                    Caption = 'CUFE';
                }
                field(postingDate; Rec."Posting Date")
                {
                    Caption = 'Posting Date';
                }
                field(invoiceDate; Rec."Document Date")
                {
                    Caption = 'Invoice Date';
                }
                field(dueDate; Rec."Due Date")
                {
                    Caption = 'Due Date';
                }
                field(currencyCode; Rec."Currency Code")
                {
                    Caption = 'Currency Code';
                    Editable = false;
                }
                field(status; Rec.Status)
                {
                    Caption = 'Status';
                    Editable = false;
                }
                field(totalAmountExcludingTax; Rec.Amount)
                {
                    Caption = 'Total Amount Excluding Tax';
                    Editable = false;
                }
                field(totalAmountIncludingTax; Rec."Amount Including VAT")
                {
                    Caption = 'Total Amount Including Tax';
                    Editable = false;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        VendorNoLP := Rec."Buy-from Vendor No.";
        Rec.CalcFields(Amount, "Amount Including VAT");
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        Clear(VendorNoLP);
        Rec."Document Type" := Rec."Document Type"::Invoice;
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        CopyMgt: Codeunit "BH Copy Order To Invoice";
        DocDate: Date;
        PostDate: Date;
        DueDate: Date;
    begin
        if VendorNoLP = '' then
            Error('vendorNumber es obligatorio.');

        // Insert(true) y la validacion del proveedor recalculan fechas; se conservan las enviadas.
        DocDate := Rec."Document Date";
        PostDate := Rec."Posting Date";
        DueDate := Rec."Due Date";

        Rec."Document Type" := Rec."Document Type"::Invoice;
        Rec."Buy-from Vendor No." := '';
        Rec.Insert(true);
        Rec.Validate("Buy-from Vendor No.", VendorNoLP);
        if PostDate <> 0D then
            Rec.Validate("Posting Date", PostDate);
        if DocDate <> 0D then
            Rec.Validate("Document Date", DocDate);
        if DueDate <> 0D then
            Rec."Due Date" := DueDate;

        CopyMgt.CheckDuplicateVendorInvoiceNo(Rec);
        Rec.Modify(true);
        exit(false);
    end;

    trigger OnModifyRecord(): Boolean
    var
        CopyMgt: Codeunit "BH Copy Order To Invoice";
    begin
        if Rec."Buy-from Vendor No." <> VendorNoLP then
            Rec.Validate("Buy-from Vendor No.", VendorNoLP);
        CopyMgt.CheckDuplicateVendorInvoiceNo(Rec);
        exit(true);
    end;

    /// <summary>
    /// POST .../bhPurchaseInvoices(id)/Microsoft.NAV.copyFromOrder  body: {"orderNo":"..."}
    /// Devuelve JSON con las lineas copiadas y el total del documento. No registra nada.
    /// </summary>
    [ServiceEnabled]
    procedure copyFromOrder(orderNo: Code[20]): Text
    var
        CopyMgt: Codeunit "BH Copy Order To Invoice";
        Result: JsonObject;
        ResultText: Text;
        LinesCopied: Integer;
    begin
        LinesCopied := CopyMgt.CopyFromOrder(Rec.SystemId, orderNo, Rec);

        Result.Add('invoiceNumber', Rec."No.");
        Result.Add('orderNumber', orderNo);
        Result.Add('linesCopied', LinesCopied);
        Result.Add('totalAmountExcludingTax', Rec.Amount);
        Result.Add('totalAmountIncludingTax', Rec."Amount Including VAT");
        Result.WriteTo(ResultText);
        exit(ResultText);
    end;

    var
        VendorNoLP: Code[20];
}
