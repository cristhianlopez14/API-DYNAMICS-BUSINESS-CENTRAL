page 60113 "Payment Journal Lines API"
{
    PageType = API;
    SourceTable = "Gen. Journal Line";

    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';

    EntityName = 'paymentJournalLine';
    EntitySetName = 'paymentJournalLines';

    Caption = 'Payment Journal Lines API';
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
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                    Editable = false;
                }
                field(journalId; JournalId)
                {
                    Caption = 'Journal Id';
                    Editable = false;
                }
                field(journalDisplayName; Rec."Journal Batch Name")
                {
                    Caption = 'Journal Display Name';
                }
                field(lineNumber; Rec."Line No.")
                {
                    Caption = 'Line Number';
                }
                field(accountType; Rec."Account Type")
                {
                    Caption = 'Account Type';
                }
                field(accountId; AccountId)
                {
                    Caption = 'Account Id';
                    Editable = false;
                }
                field(accountNumber; Rec."Account No.")
                {
                    Caption = 'Account Number';
                }
                field(postingDate; Rec."Posting Date")
                {
                    Caption = 'Posting Date';
                }
                field(documentNumber; Rec."Document No.")
                {
                    Caption = 'Document Number';
                }
                field(externalDocumentNumber; Rec."External Document No.")
                {
                    Caption = 'External Document Number';
                }
                field(amount; Rec.Amount)
                {
                    Caption = 'Amount';
                }
                field(description; Rec.Description)
                {
                    Caption = 'Description';
                }
                field(paymentMethodCode; Rec."Payment Method Code")
                {
                    Caption = 'Payment Method Code';
                }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Caption = 'Last Modified Date Time';
                    Editable = false;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        GenJournalBatch: Record "Gen. Journal Batch";
        GLAccount: Record "G/L Account";
        BankAccount: Record "Bank Account";
        Customer: Record Customer;
        Vendor: Record Vendor;
    begin
        // Resolve journalId → SystemId del Gen. Journal Batch
        if GenJournalBatch.Get(Rec."Journal Template Name", Rec."Journal Batch Name") then
            JournalId := GenJournalBatch.SystemId
        else
            Clear(JournalId);

        // Resolve accountId → SystemId según el tipo de cuenta
        Clear(AccountId);
        if Rec."Account No." <> '' then
            case Rec."Account Type" of
                Rec."Account Type"::"G/L Account":
                    if GLAccount.Get(Rec."Account No.") then
                        AccountId := GLAccount.SystemId;
                Rec."Account Type"::"Bank Account":
                    if BankAccount.Get(Rec."Account No.") then
                        AccountId := BankAccount.SystemId;
                Rec."Account Type"::Customer:
                    if Customer.Get(Rec."Account No.") then
                        AccountId := Customer.SystemId;
                Rec."Account Type"::Vendor:
                    if Vendor.Get(Rec."Account No.") then
                        AccountId := Vendor.SystemId;
            end;
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        GenJournalLine: Record "Gen. Journal Line";
    begin
        GenJournalLine.SetRange("Journal Template Name", Rec."Journal Template Name");
        GenJournalLine.SetRange("Journal Batch Name", Rec."Journal Batch Name");
        if GenJournalLine.FindLast() then
            Rec."Line No." := GenJournalLine."Line No." + 10000
        else
            Rec."Line No." := 10000;
        exit(true);
    end;

    var
        JournalId: Guid;
        AccountId: Guid;
}
