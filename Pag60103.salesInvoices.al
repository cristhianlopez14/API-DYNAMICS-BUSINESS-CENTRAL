page 60105 "Sales Invoice API"
{
    PageType = API;
    SourceTable = "Sales Header";
    SourceTableView = where("Document Type" = const(Invoice));
    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';
    EntityName = 'salesInvoice';
    EntitySetName = 'salesInvoices';
    Caption = 'Sales Invoice API';
    ApplicationArea = All;
    DelayedInsert = true;
    Editable = true;
    ODataKeyFields = SystemId;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field(id; Rec.SystemId) { Caption = 'Id'; Editable = false; }
                field(documentType; Rec."Document Type") { Caption = 'Document Type'; }
                field(number; Rec."No.") { Caption = 'Number'; }
                // customerNumber ya existía — apunta a Sell-to Customer No.
                field(customerNumber; Rec."Sell-to Customer No.") { Caption = 'Customer Number'; }
                field(sellToCustomerName; Rec."Sell-to Customer Name") { Caption = 'Sell-to Customer Name'; }
                field(salespersonCode; Rec."Salesperson Code") { Caption = 'Salesperson Code'; }
                field(invoiceDate; Rec."Document Date") { Caption = 'Invoice Date'; }
                field(postingDate; Rec."Posting Date") { Caption = 'Posting Date'; }
                field(dueDate; Rec."Due Date") { Caption = 'Due Date'; }
                field(currencyCode; Rec."Currency Code") { Caption = 'Currency Code'; }
                field(amount; Rec.Amount) { Caption = 'Amount'; }
                field(amountIncludingVAT; Rec."Amount Including VAT") { Caption = 'Amount Including VAT'; }
                field(status; Rec.Status) { Caption = 'Status'; }
                field(paymentTermsCode; Rec."Payment Terms Code") { Caption = 'Payment Terms Code'; }
                field(workDescription; WorkDescriptionValue) { Caption = 'Work Description'; }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        Rec.SetWorkDescription(WorkDescriptionValue);
        exit(true);
    end;

    trigger OnModifyRecord(): Boolean
    begin
        Rec.SetWorkDescription(WorkDescriptionValue);
        exit(true);
    end;

    trigger OnAfterGetRecord()
    begin
        WorkDescriptionValue := Rec.GetWorkDescription();
    end;

    var
        WorkDescriptionValue: Text;
}
