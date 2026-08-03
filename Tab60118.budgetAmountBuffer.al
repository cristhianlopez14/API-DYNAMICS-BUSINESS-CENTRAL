table 60118 "BH Budget Amount Buffer"
{
    Caption = 'BH Budget Amount Buffer';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Budget Name"; Code[10])
        {
            Caption = 'Budget Name';
            DataClassification = CustomerContent;
        }
        field(2; "Dimension Value Code"; Code[20])
        {
            Caption = 'Dimension Value Code';
            DataClassification = CustomerContent;
        }
        field(3; "Dimension Value Name"; Text[100])
        {
            Caption = 'Dimension Value Name';
            DataClassification = CustomerContent;
        }
        field(4; "Period Start Date"; Date)
        {
            Caption = 'Period Start Date';
            DataClassification = CustomerContent;
        }
        field(5; "Period End Date"; Date)
        {
            Caption = 'Period End Date';
            DataClassification = CustomerContent;
        }
        field(6; "Budget Amount"; Decimal)
        {
            Caption = 'Budget Amount';
            DataClassification = CustomerContent;
        }
        field(7; "Actual Amount"; Decimal)
        {
            Caption = 'Actual Amount';
            DataClassification = CustomerContent;
        }
        field(8; "Remaining Amount"; Decimal)
        {
            Caption = 'Remaining Amount';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Budget Name", "Dimension Value Code", "Period Start Date")
        {
            Clustered = true;
        }
    }
}
