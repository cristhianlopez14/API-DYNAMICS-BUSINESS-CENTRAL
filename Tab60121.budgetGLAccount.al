table 60121 "BH Budget GL Account"
{
    Caption = 'BH Budget GL Account';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "G/L Account No."; Code[20])
        {
            Caption = 'G/L Account No.';
            TableRelation = "G/L Account";
            DataClassification = CustomerContent;
        }
        field(2; "G/L Account Name"; Text[100])
        {
            Caption = 'G/L Account Name';
            FieldClass = FlowField;
            CalcFormula = lookup("G/L Account".Name where("No." = field("G/L Account No.")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "G/L Account No.")
        {
            Clustered = true;
        }
    }
}
