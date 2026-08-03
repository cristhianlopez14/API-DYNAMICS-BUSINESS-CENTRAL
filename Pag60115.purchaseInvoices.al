page 60115 "Purchase Invoice API"
{
    PageType = API;
    SourceTable = "Purchase Header";
    SourceTableTemporary = true;

    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';

    EntityName = 'purchaseInvoice';
    EntitySetName = 'purchaseInvoices';

    Caption = 'Purchase Invoice API';
    ApplicationArea = All;

    Editable = true;
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = true;
    DelayedInsert = true;

    ODataKeyFields = SystemId;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                }
                field(number; Rec."No.")
                {
                    Caption = 'Number';
                }
                field(invoiceDate; Rec."Document Date")
                {
                    Caption = 'Invoice Date';
                }
                field(postingDate; Rec."Posting Date")
                {
                    Caption = 'Posting Date';
                }
                field(dueDate; Rec."Due Date")
                {
                    Caption = 'Due Date';
                }
                field(vendorInvoiceNumber; Rec."Vendor Invoice No.")
                {
                    Caption = 'Vendor Invoice Number';
                }
                field(vendorId; VendorIdLP)
                {
                    Caption = 'Vendor Id';
                }
                field(vendorNumber; Rec."Buy-from Vendor No.")
                {
                    Caption = 'Vendor Number';
                }
                field(vendorName; Rec."Buy-from Vendor Name")
                {
                    Caption = 'Vendor Name';
                }
                field(payToName; Rec."Pay-to Name")
                {
                    Caption = 'Pay-to Name';
                }
                field(payToContact; Rec."Pay-to Contact")
                {
                    Caption = 'Pay-to Contact';
                }
                field(payToVendorId; PayToVendorIdLP)
                {
                    Caption = 'Pay-to Vendor Id';
                }
                field(payToVendorNumber; Rec."Pay-to Vendor No.")
                {
                    Caption = 'Pay-to Vendor Number';
                }
                field(shipToName; Rec."Ship-to Name")
                {
                    Caption = 'Ship-to Name';
                }
                field(shipToContact; Rec."Ship-to Contact")
                {
                    Caption = 'Ship-to Contact';
                }
                field(buyFromAddressLine1; Rec."Buy-from Address")
                {
                    Caption = 'Buy-from Address Line 1';
                }
                field(buyFromAddressLine2; Rec."Buy-from Address 2")
                {
                    Caption = 'Buy-from Address Line 2';
                }
                field(buyFromCity; Rec."Buy-from City")
                {
                    Caption = 'Buy-from City';
                }
                field(buyFromCountry; Rec."Buy-from Country/Region Code")
                {
                    Caption = 'Buy-from Country';
                }
                field(buyFromState; Rec."Buy-from County")
                {
                    Caption = 'Buy-from State';
                }
                field(buyFromPostCode; Rec."Buy-from Post Code")
                {
                    Caption = 'Buy-from Post Code';
                }
                field(shipToAddressLine1; Rec."Ship-to Address")
                {
                    Caption = 'Ship-to Address Line 1';
                }
                field(shipToAddressLine2; Rec."Ship-to Address 2")
                {
                    Caption = 'Ship-to Address Line 2';
                }
                field(shipToCity; Rec."Ship-to City")
                {
                    Caption = 'Ship-to City';
                }
                field(shipToCountry; Rec."Ship-to Country/Region Code")
                {
                    Caption = 'Ship-to Country';
                }
                field(shipToState; Rec."Ship-to County")
                {
                    Caption = 'Ship-to State';
                }
                field(shipToPostCode; Rec."Ship-to Post Code")
                {
                    Caption = 'Ship-to Post Code';
                }
                field(payToAddressLine1; Rec."Pay-to Address")
                {
                    Caption = 'Pay-to Address Line 1';
                }
                field(payToAddressLine2; Rec."Pay-to Address 2")
                {
                    Caption = 'Pay-to Address Line 2';
                }
                field(payToCity; Rec."Pay-to City")
                {
                    Caption = 'Pay-to City';
                }
                field(payToCountry; Rec."Pay-to Country/Region Code")
                {
                    Caption = 'Pay-to Country';
                }
                field(payToState; Rec."Pay-to County")
                {
                    Caption = 'Pay-to State';
                }
                field(payToPostCode; Rec."Pay-to Post Code")
                {
                    Caption = 'Pay-to Post Code';
                }
                field(currencyId; CurrencyIdLP)
                {
                    Caption = 'Currency Id';
                }
                field(currencyCode; Rec."Currency Code")
                {
                    Caption = 'Currency Code';
                }
                field(orderId; OrderIdLP)
                {
                    Caption = 'Order Id';
                }
                field(orderNumber; OrderNumberLP)
                {
                    Caption = 'Order Number';
                }
                field(pricesIncludeTax; Rec."Prices Including VAT")
                {
                    Caption = 'Prices Include Tax';
                }
                field(discountAmount; Rec."Invoice Discount Amount")
                {
                    Caption = 'Discount Amount';
                }
                field(discountAppliedBeforeTax; DiscountAppliedBeforeTaxLP)
                {
                    Caption = 'Discount Applied Before Tax';
                }
                field(totalAmountExcludingTax; TotalAmountExcludingTaxLP)
                {
                    Caption = 'Total Amount Excluding Tax';
                }
                field(totalTaxAmount; TotalTaxAmountLP)
                {
                    Caption = 'Total Tax Amount';
                }
                field(totalAmountIncludingTax; TotalAmountIncludingTaxLP)
                {
                    Caption = 'Total Amount Including Tax';
                }
                field(status; StatusLP)
                {
                    Caption = 'Status';
                }
                field(lastModifiedDateTime; LastModifiedLP)
                {
                    Caption = 'Last Modified Date Time';
                }
                field(postingDescription; Rec."Posting Description")
                {
                    Caption = 'Posting Description';
                }
                field(postingNoSeries; Rec."Posting No. Series")
                {
                    Caption = 'Posting No. Series';
                }
                field(invoiceReceivedDate; Rec."Invoice Received Date")
                {
                    Caption = 'Invoice Received Date';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        PopulateBuffer();
    end;

    trigger OnAfterGetRecord()
    var
        PostedHeader: Record "Purch. Inv. Header";
    begin
        Clear(LastModifiedLP);
        if PostedHeader.GetBySystemId(Rec.SystemId) then
            ProcessPosted(PostedHeader)
        else
            ProcessDraft();

        GetLookupIds();
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        NewHeader: Record "Purchase Header";
    begin
        NewHeader.Init();
        NewHeader."Document Type" := NewHeader."Document Type"::Invoice;
        if Rec."No." <> '' then
            NewHeader."No." := Rec."No.";
        NewHeader.Insert(true);

        ApplyBufferToHeader(NewHeader);
        NewHeader.Modify(true);

        Rec."No." := NewHeader."No.";
        Rec.SystemId := NewHeader.SystemId;
        Rec.Insert(false);
        exit(false);
    end;

    trigger OnModifyRecord(): Boolean
    var
        PostedHeader: Record "Purch. Inv. Header";
        DraftHeader: Record "Purchase Header";
    begin
        if PostedHeader.GetBySystemId(Rec.SystemId) then
            Error('No se puede modificar una factura de compra ya contabilizada.');

        if not DraftHeader.GetBySystemId(Rec.SystemId) then
            Error('No se encontró la factura de compra en borrador.');

        ApplyBufferToHeader(DraftHeader);
        DraftHeader.Modify(true);
        exit(true);
    end;

    trigger OnDeleteRecord(): Boolean
    var
        PostedHeader: Record "Purch. Inv. Header";
        DraftHeader: Record "Purchase Header";
    begin
        if PostedHeader.GetBySystemId(Rec.SystemId) then
            Error('No se puede eliminar una factura de compra ya contabilizada.');

        if DraftHeader.GetBySystemId(Rec.SystemId) then
            DraftHeader.Delete(true);

        exit(true);
    end;

    var
        VendorIdLP: Guid;
        PayToVendorIdLP: Guid;
        CurrencyIdLP: Guid;
        OrderIdLP: Guid;
        TotalAmountExcludingTaxLP: Decimal;
        TotalTaxAmountLP: Decimal;
        TotalAmountIncludingTaxLP: Decimal;
        DiscountAppliedBeforeTaxLP: Boolean;
        StatusLP: Text[30];
        LastModifiedLP: DateTime;
        OrderNumberLP: Code[20];

    local procedure PopulateBuffer()
    var
        DraftHeader: Record "Purchase Header";
        PostedHeader: Record "Purch. Inv. Header";
    begin
        Rec.Reset();
        Rec.DeleteAll();

        DraftHeader.SetRange("Document Type", DraftHeader."Document Type"::Invoice);
        if DraftHeader.FindSet() then
            repeat
                Rec := DraftHeader;
                Rec.SystemId := DraftHeader.SystemId;
                Rec.Insert(false);
            until DraftHeader.Next() = 0;

        if PostedHeader.FindSet() then
            repeat
                MapPostedHeader(PostedHeader);
            until PostedHeader.Next() = 0;
    end;

    local procedure MapPostedHeader(PostedHeader: Record "Purch. Inv. Header")
    begin
        Rec.Init();
        Rec."Document Type" := Rec."Document Type"::Invoice;
        Rec."No." := PostedHeader."No.";
        Rec."Document Date" := PostedHeader."Document Date";
        Rec."Posting Date" := PostedHeader."Posting Date";
        Rec."Due Date" := PostedHeader."Due Date";
        Rec."Vendor Invoice No." := PostedHeader."Vendor Invoice No.";
        Rec."Buy-from Vendor No." := PostedHeader."Buy-from Vendor No.";
        Rec."Buy-from Vendor Name" := PostedHeader."Buy-from Vendor Name";
        Rec."Pay-to Name" := PostedHeader."Pay-to Name";
        Rec."Pay-to Contact" := PostedHeader."Pay-to Contact";
        Rec."Pay-to Vendor No." := PostedHeader."Pay-to Vendor No.";
        Rec."Ship-to Name" := PostedHeader."Ship-to Name";
        Rec."Ship-to Contact" := PostedHeader."Ship-to Contact";
        Rec."Buy-from Address" := PostedHeader."Buy-from Address";
        Rec."Buy-from Address 2" := PostedHeader."Buy-from Address 2";
        Rec."Buy-from City" := PostedHeader."Buy-from City";
        Rec."Buy-from Country/Region Code" := PostedHeader."Buy-from Country/Region Code";
        Rec."Buy-from County" := PostedHeader."Buy-from County";
        Rec."Buy-from Post Code" := PostedHeader."Buy-from Post Code";
        Rec."Ship-to Address" := PostedHeader."Ship-to Address";
        Rec."Ship-to Address 2" := PostedHeader."Ship-to Address 2";
        Rec."Ship-to City" := PostedHeader."Ship-to City";
        Rec."Ship-to Country/Region Code" := PostedHeader."Ship-to Country/Region Code";
        Rec."Ship-to County" := PostedHeader."Ship-to County";
        Rec."Ship-to Post Code" := PostedHeader."Ship-to Post Code";
        Rec."Pay-to Address" := PostedHeader."Pay-to Address";
        Rec."Pay-to Address 2" := PostedHeader."Pay-to Address 2";
        Rec."Pay-to City" := PostedHeader."Pay-to City";
        Rec."Pay-to Country/Region Code" := PostedHeader."Pay-to Country/Region Code";
        Rec."Pay-to County" := PostedHeader."Pay-to County";
        Rec."Pay-to Post Code" := PostedHeader."Pay-to Post Code";
        Rec."Currency Code" := PostedHeader."Currency Code";
        Rec."Prices Including VAT" := PostedHeader."Prices Including VAT";
        Rec."Invoice Discount Amount" := PostedHeader."Invoice Discount Amount";
        Rec."VAT Base Discount %" := PostedHeader."VAT Base Discount %";
        Rec."Posting Description" := PostedHeader."Posting Description";
        Rec.SystemId := PostedHeader.SystemId;
        Rec.Insert(false);
    end;

    local procedure ProcessDraft()
    var
        DraftHeader: Record "Purchase Header";
    begin
        if DraftHeader.Get(Rec."Document Type", Rec."No.") then begin
            DraftHeader.CalcFields(Amount, "Amount Including VAT");
            TotalAmountExcludingTaxLP := DraftHeader.Amount;
            TotalAmountIncludingTaxLP := DraftHeader."Amount Including VAT";
            LastModifiedLP := DraftHeader.SystemModifiedAt;
            StatusLP := Format(DraftHeader.Status);
        end;
        TotalTaxAmountLP := TotalAmountIncludingTaxLP - TotalAmountExcludingTaxLP;
        DiscountAppliedBeforeTaxLP := Rec."VAT Base Discount %" <> 0;
        Clear(OrderNumberLP);
    end;

    local procedure ProcessPosted(PostedHeader: Record "Purch. Inv. Header")
    var
        PurchInvLine: Record "Purch. Inv. Line";
        VendorLedgerEntry: Record "Vendor Ledger Entry";
    begin
        PurchInvLine.SetRange("Document No.", PostedHeader."No.");
        PurchInvLine.CalcSums(Amount, "Amount Including VAT");
        TotalAmountExcludingTaxLP := PurchInvLine.Amount;
        TotalAmountIncludingTaxLP := PurchInvLine."Amount Including VAT";
        TotalTaxAmountLP := TotalAmountIncludingTaxLP - TotalAmountExcludingTaxLP;
        DiscountAppliedBeforeTaxLP := Rec."VAT Base Discount %" <> 0;
        LastModifiedLP := PostedHeader.SystemModifiedAt;
        OrderNumberLP := PostedHeader."Order No.";

        StatusLP := 'Open';
        VendorLedgerEntry.SetRange("Document Type", VendorLedgerEntry."Document Type"::Invoice);
        VendorLedgerEntry.SetRange("Document No.", PostedHeader."No.");
        if VendorLedgerEntry.FindFirst() then begin
            VendorLedgerEntry.CalcFields("Remaining Amount");
            if VendorLedgerEntry."Remaining Amount" = 0 then
                StatusLP := 'Paid';
        end;
    end;

    local procedure GetLookupIds()
    var
        Vendor: Record Vendor;
        Currency: Record Currency;
        OrderHeader: Record "Purchase Header";
    begin
        Clear(VendorIdLP);
        if Rec."Buy-from Vendor No." <> '' then
            if Vendor.Get(Rec."Buy-from Vendor No.") then
                VendorIdLP := Vendor.SystemId;

        Clear(PayToVendorIdLP);
        if Rec."Pay-to Vendor No." <> '' then
            if Vendor.Get(Rec."Pay-to Vendor No.") then
                PayToVendorIdLP := Vendor.SystemId;

        Clear(CurrencyIdLP);
        if Rec."Currency Code" <> '' then
            if Currency.Get(Rec."Currency Code") then
                CurrencyIdLP := Currency.SystemId;

        Clear(OrderIdLP);
        if OrderNumberLP <> '' then
            if OrderHeader.Get(OrderHeader."Document Type"::Order, OrderNumberLP) then
                OrderIdLP := OrderHeader.SystemId;
    end;

    local procedure ApplyBufferToHeader(var Header: Record "Purchase Header")
    begin
        if Rec."Buy-from Vendor No." <> '' then
            Header.Validate("Buy-from Vendor No.", Rec."Buy-from Vendor No.");

        if Rec."Document Date" <> 0D then
            Header.Validate("Document Date", Rec."Document Date");

        if Rec."Posting Date" <> 0D then
            Header.Validate("Posting Date", Rec."Posting Date");

        if Rec."Due Date" <> 0D then
            Header.Validate("Due Date", Rec."Due Date");

        if Rec."Vendor Invoice No." <> '' then
            Header.Validate("Vendor Invoice No.", Rec."Vendor Invoice No.");

        if Rec."Currency Code" <> Header."Currency Code" then
            Header.Validate("Currency Code", Rec."Currency Code");

        if Rec."Pay-to Vendor No." <> '' then
            Header.Validate("Pay-to Vendor No.", Rec."Pay-to Vendor No.");

        Header."Posting Description" := Rec."Posting Description";
        Header."Prices Including VAT" := Rec."Prices Including VAT";

        if Rec."Posting No. Series" <> '' then
            Header.Validate("Posting No. Series", Rec."Posting No. Series");

        if Rec."Invoice Received Date" <> 0D then
            Header.Validate("Invoice Received Date", Rec."Invoice Received Date");
    end;
}
