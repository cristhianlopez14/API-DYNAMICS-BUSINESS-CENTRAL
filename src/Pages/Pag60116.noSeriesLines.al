page 60116 "No. Series Lines API"
{
    PageType = API;
    SourceTable = "No. Series Line";

    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';

    EntityName = 'noSeriesLine';
    EntitySetName = 'noSeriesLines';

    Caption = 'No. Series Lines API';
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
                field(seriesCode; Rec."Series Code")
                {
                    Caption = 'Series Code';
                }
                field(lineNo; Rec."Line No.")
                {
                    Caption = 'Line No.';
                }
                field(startingDate; Rec."Starting Date")
                {
                    Caption = 'Starting Date';
                }
                field(startingNo; Rec."Starting No.")
                {
                    Caption = 'Starting No.';
                }
                field(endingNo; Rec."Ending No.")
                {
                    Caption = 'Ending No.';
                }
                field(warningNo; Rec."Warning No.")
                {
                    Caption = 'Warning No.';
                }
                field(incrementByNo; Rec."Increment-by No.")
                {
                    Caption = 'Increment-by No.';
                }
                field(lastNoUsed; Rec."Last No. Used")
                {
                    Caption = 'Last No. Used';
                }
                field(lastDateUsed; Rec."Last Date Used")
                {
                    Caption = 'Last Date Used';
                }
                field(open; Rec."Open")
                {
                    Caption = 'Open';
                }
                field(implementation; Rec."Implementation")
                {
                    Caption = 'Implementation';
                }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        NoSeriesLine: Record "No. Series Line";
    begin
        if Rec."Line No." = 0 then begin
            NoSeriesLine.SetRange("Series Code", Rec."Series Code");
            if NoSeriesLine.FindLast() then
                Rec."Line No." := NoSeriesLine."Line No." + 10000
            else
                Rec."Line No." := 10000;
        end;
        exit(true);
    end;
}
