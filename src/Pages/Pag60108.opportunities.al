page 60108 "Opportunities API"
{
    PageType = API;
    SourceTable = Opportunity;

    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';

    EntityName = 'opportunity';
    EntitySetName = 'opportunities';

    Caption = 'Opportunities API';
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
                field(no; Rec."No.")
                {
                    Caption = 'No.';
                }
                field(description; Rec.Description)
                {
                    Caption = 'Description';
                }
                field(contactNo; Rec."Contact No.")
                {
                    Caption = 'Contact No.';
                }
                field(contactName; Rec."Contact Name")
                {
                    Caption = 'Contact Name';
                }
                field(salespersonCode; Rec."Salesperson Code")
                {
                    Caption = 'Salesperson Code';
                }
                field(status; Rec.Status)
                {
                    Caption = 'Status';
                }
                field(probabilityPct; Rec."Probability %")
                {
                    Caption = 'Probability %';
                }
                field(estimatedValue; Rec."Estimated Value (LCY)")
                {
                    Caption = 'Estimated Value';
                }
                field(estimatedClosingDate; Rec."Estimated Closing Date")
                {
                    Caption = 'Estimated Closing Date';
                }
                field(creationDate; Rec."Creation Date")
                {
                    Caption = 'Creation Date';
                }
                field(campaignNo; Rec."Campaign No.")
                {
                    Caption = 'Campaign No.';
                }
            }
        }
    }
}
