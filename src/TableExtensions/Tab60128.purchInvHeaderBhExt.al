tableextension 60128 "BH Purch Inv Header Ext" extends "Purch. Inv. Header"
{
    fields
    {
        field(60127; "BH CUFE"; Text[100])
        {
            Caption = 'CUFE';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }

    keys
    {
        key(BHCufe; "BH CUFE")
        {
        }
    }
}
