permissionset 60100 "BH API - Objects"
{
    Assignable = true;
    Caption = 'BH API - Objects';

    Permissions = tabledata "BH Budget Amount Buffer" = RIMD,
                  table "BH Budget Amount Buffer" = X,
                  page "Budget Amounts API" = X,
                  tabledata "BH Budget GL Account" = RIMD,
                  table "BH Budget GL Account" = X,
                  page "BH Budget GL Accounts" = X,
                  codeunit "BH Sales Job Planning Mgt." = X,
                  codeunit "BH LyL Origenes Convert Sync" = X;
    // Nota (review 2026-09-01): tableextension 60123 ("BH Job Planning Line Ext") y
    // pageextension 60124/60125 no admiten entrada propia en un permission set -- el compilador
    // rechaza "tableextension"/"pageextension" como tipo de objeto válido dentro de Permissions
    // (AL0104/AL0301, verificado compilando). Solo modifican un objeto base (Job Planning Line /
    // Sales Order Subform / Sales Invoice Subform) ya cubierto por los permission sets base de
    // Microsoft para Jobs y Ventas -- el campo nuevo y los controles de layout no necesitan
    // permiso adicional propio. El codeunit sí es un objeto nuevo y requiere Execute (X)
    // explícito para que sus event subscribers corran para usuarios no-SUPER.
}
