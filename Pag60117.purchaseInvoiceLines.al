page 60117 "Purchase Invoice Lines API"
{
    PageType = API;
    SourceTable = "Purchase Line";

    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';

    EntityName = 'purchaseInvoiceLine';
    EntitySetName = 'purchaseInvoiceLines';

    Caption = 'Purchase Invoice Lines API';
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
                    Editable = false;
                }
                field(documentId; DocumentIdLP)
                {
                    Caption = 'Document Id';

                    trigger OnValidate()
                    var
                        Header: Record "Purchase Header";
                    begin
                        if IsNullGuid(DocumentIdLP) then
                            exit;

                        if not Header.GetBySystemId(DocumentIdLP) then
                            Error('No se encontró una factura de compra en borrador con el documentId indicado.');

                        if Header."Document Type" <> Header."Document Type"::Invoice then
                            Error('El documentId indicado no corresponde a una factura de compra.');

                        Rec."Document Type" := Header."Document Type";
                        Rec."Document No." := Header."No.";
                    end;
                }
                field(sequence; Rec."Line No.")
                {
                    Caption = 'Sequence';
                }
                field(itemId; ItemIdLP)
                {
                    Caption = 'Item Id';
                    Editable = false;
                }
                field(accountId; AccountIdLP)
                {
                    Caption = 'Account Id';
                    Editable = false;
                }
                field(lineType; Rec.Type)
                {
                    Caption = 'Line Type';
                }
                field(lineObjectNumber; Rec."No.")
                {
                    Caption = 'Line Object Number';
                }
                field(description; Rec.Description)
                {
                    Caption = 'Description';
                }
                field(unitOfMeasureId; UnitOfMeasureIdLP)
                {
                    Caption = 'Unit of Measure Id';
                    Editable = false;
                }
                field(unitOfMeasureCode; Rec."Unit of Measure Code")
                {
                    Caption = 'Unit of Measure Code';
                }
                field(unitCost; Rec."Direct Unit Cost")
                {
                    Caption = 'Unit Cost';
                }
                field(quantity; Rec.Quantity)
                {
                    Caption = 'Quantity';
                }
                field(discountAmount; Rec."Line Discount Amount")
                {
                    Caption = 'Discount Amount';
                }
                field(discountPercent; Rec."Line Discount %")
                {
                    Caption = 'Discount Percent';
                }
                field(discountAppliedBeforeTax; DiscountAppliedBeforeTaxLP)
                {
                    Caption = 'Discount Applied Before Tax';
                    Editable = false;
                }
                field(amountExcludingTax; Rec."Line Amount")
                {
                    Caption = 'Amount Excluding Tax';
                    Editable = false;
                }
                field(taxCode; Rec."Tax Group Code")
                {
                    Caption = 'Tax Code';
                }
                field(taxPercent; Rec."VAT %")
                {
                    Caption = 'Tax Percent';
                    Editable = false;
                }
                field(totalTaxAmount; TotalTaxAmountLP)
                {
                    Caption = 'Total Tax Amount';
                    Editable = false;
                }
                field(amountIncludingTax; AmountIncludingTaxLP)
                {
                    Caption = 'Amount Including Tax';
                    Editable = false;
                }
                field(invoiceDiscountAllocation; Rec."Inv. Discount Amount")
                {
                    Caption = 'Invoice Discount Allocation';
                    Editable = false;
                }
                field(netAmount; Rec.Amount)
                {
                    Caption = 'Net Amount';
                    Editable = false;
                }
                field(netTaxAmount; NetTaxAmountLP)
                {
                    Caption = 'Net Tax Amount';
                    Editable = false;
                }
                field(netAmountIncludingTax; Rec."Amount Including VAT")
                {
                    Caption = 'Net Amount Including Tax';
                    Editable = false;
                }
                field(expectedReceiptDate; Rec."Expected Receipt Date")
                {
                    Caption = 'Expected Receipt Date';
                }
                field(itemVariantId; ItemVariantIdLP)
                {
                    Caption = 'Item Variant Id';
                    Editable = false;
                }
                field(shortcutDimension1Code; Rec."Shortcut Dimension 1 Code")
                {
                    Caption = 'Shortcut Dimension 1 Code';
                }
            
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        Header: Record "Purchase Header";
    begin
        Clear(DocumentIdLP);
        if Header.Get(Rec."Document Type", Rec."Document No.") then
            DocumentIdLP := Header.SystemId;

        GetReferenceIds();
        CalcTaxAmounts();
        GetDiscountAppliedBeforeTax();
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        PurchaseLine: Record "Purchase Line";
    begin
        if Rec."Document No." = '' then
            Error('Debe indicar documentId con el Id de una factura de compra en borrador.');

        if Rec."Line No." = 0 then begin
            PurchaseLine.SetRange("Document Type", Rec."Document Type");
            PurchaseLine.SetRange("Document No.", Rec."Document No.");
            if PurchaseLine.FindLast() then
                Rec."Line No." := PurchaseLine."Line No." + 10000
            else
                Rec."Line No." := 10000;
        end;

        Rec.Validate("Direct Unit Cost", Rec."Direct Unit Cost");

        exit(true);
    end;

    trigger OnModifyRecord(): Boolean
    begin
        if Rec."Document No." = '' then
            Error('Debe indicar documentId con el Id de una factura de compra en borrador.');

        Rec.Validate("Direct Unit Cost", Rec."Direct Unit Cost");

        exit(true);
    end;

    var
        DocumentIdLP: Guid;
        ItemIdLP: Guid;
        AccountIdLP: Guid;
        UnitOfMeasureIdLP: Guid;
        ItemVariantIdLP: Guid;
        DiscountAppliedBeforeTaxLP: Boolean;
        TotalTaxAmountLP: Decimal;
        AmountIncludingTaxLP: Decimal;
        NetTaxAmountLP: Decimal;

    local procedure GetReferenceIds()
    var
        Item: Record Item;
        GLAccount: Record "G/L Account";
        UnitOfMeasure: Record "Unit of Measure";
        ItemVariant: Record "Item Variant";
    begin
        Clear(ItemIdLP);
        Clear(AccountIdLP);
        if Rec."No." <> '' then
            case Rec.Type of
                Rec.Type::Item:
                    if Item.Get(Rec."No.") then
                        ItemIdLP := Item.SystemId;
                Rec.Type::"G/L Account":
                    if GLAccount.Get(Rec."No.") then
                        AccountIdLP := GLAccount.SystemId;
            end;

        Clear(UnitOfMeasureIdLP);
        if Rec."Unit of Measure Code" <> '' then
            if UnitOfMeasure.Get(Rec."Unit of Measure Code") then
                UnitOfMeasureIdLP := UnitOfMeasure.SystemId;

        Clear(ItemVariantIdLP);
        if (Rec."No." <> '') and (Rec."Variant Code" <> '') then
            if ItemVariant.Get(Rec."No.", Rec."Variant Code") then
                ItemVariantIdLP := ItemVariant.SystemId;
    end;

    local procedure CalcTaxAmounts()
    begin
        TotalTaxAmountLP := Round(Rec."Line Amount" * Rec."VAT %" / 100, 0.01);
        AmountIncludingTaxLP := Rec."Line Amount" + TotalTaxAmountLP;
        NetTaxAmountLP := Rec."Amount Including VAT" - Rec.Amount;
    end;

    local procedure GetDiscountAppliedBeforeTax()
    var
        Header: Record "Purchase Header";
    begin
        Clear(DiscountAppliedBeforeTaxLP);
        if Header.Get(Rec."Document Type", Rec."Document No.") then
            DiscountAppliedBeforeTaxLP := Header."VAT Base Discount %" <> 0;
    end;
}
