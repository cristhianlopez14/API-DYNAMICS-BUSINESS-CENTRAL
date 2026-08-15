permissionset 60100 "BH API - Objects"
{
    Assignable = true;
    Caption = 'BH API - Objects';

    Permissions = tabledata "BH Budget Amount Buffer" = RIMD,
                  table "BH Budget Amount Buffer" = X,
                  page "Budget Amounts API" = X,
                  tabledata "BH Budget GL Account" = RIMD,
                  table "BH Budget GL Account" = X,
                  page "BH Budget GL Accounts" = X;
}
