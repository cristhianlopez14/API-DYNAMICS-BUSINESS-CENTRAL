page 60121 "BH Budget GL Accounts"
{
    PageType = List;
    SourceTable = "BH Budget GL Account";
    Caption = 'Cuentas de Presupuesto (BH)';
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = true;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("G/L Account No."; Rec."G/L Account No.")
                {
                }
                field("G/L Account Name"; Rec."G/L Account Name")
                {
                }
            }
        }
    }
}
