pageextension 60124 "BH Sales Order Subform Ext" extends "Sales Order Subform"
{
    // DIS-2026-08-31 — habilita edición de Job No./Job Task No. (campos estándar
    // 45/1001 de Sales Line, Editable = false de fábrica) en la línea del Pedido de
    // venta para líneas Tipo = Artículo. Al diligenciarlos, el codeunit
    // "BH Sales Job Planning Mgt." (60123) crea la Job Planning Line oculta
    // correspondiente vía event subscriber -- sin lógica de negocio nueva aquí.
    layout
    {
        addafter(Description)
        {
            field("Job No."; Rec."Job No.")
            {
                ApplicationArea = All;
                Caption = 'Job No.';
                Editable = true;
                ToolTip = 'Specifies the number of the related project. Solo aplica a líneas Tipo = Artículo.';
            }
            field("Job Task No."; Rec."Job Task No.")
            {
                ApplicationArea = All;
                Caption = 'Job Task No.';
                Editable = true;
                ToolTip = 'Specifies the number of the related project task. Solo aplica a líneas Tipo = Artículo.';
            }
        }
    }
}
