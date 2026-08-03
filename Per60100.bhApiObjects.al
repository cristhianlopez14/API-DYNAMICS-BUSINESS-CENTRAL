permissionset 60100 "BH API - Objects"
{
    Assignable = true;
    Caption = 'BH API - Objects';

    Permissions = tabledata "BH Budget Amount Buffer" = RIMD,
                  table "BH Budget Amount Buffer" = X,
                  page "Budget Amounts API" = X;
}
