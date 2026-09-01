pageextension 60125 "BH Sales Invoice Subform Ext" extends "Sales Invoice Subform"
{
    // DIS-2026-08-31 — habilita edición de Job No./Job Task No. (campos estándar
    // 45/1001 de Sales Line) en la línea de la Factura de venta para líneas Tipo =
    // Artículo. Confirmado por negocio (2026-08-31): se necesita también en Factura
    // para el caso de facturas creadas directamente (CA3). Al diligenciarlos, el
    // codeunit "BH Sales Job Planning Mgt." (60123) crea la Job Planning Line oculta
    // correspondiente vía event subscriber -- sin lógica de negocio nueva aquí.
    //
    // A diferencia de Sales Order Subform (Pag60124, que no tiene estos campos en el
    // layout base y por eso los agrega con addafter), Sales Invoice Subform YA trae
    // los controles "Job No."/"Job Task No." en el layout base de Microsoft, pero con
    // Editable = false y Visible = false -- descubierto al compilar (AL0155, campo
    // duplicado) al intentar agregarlos como addafter. Aquí solo se habilitan.
    layout
    {
        modify("Job No.")
        {
            ApplicationArea = All;
            Editable = true;
            Visible = true;
        }
        modify("Job Task No.")
        {
            ApplicationArea = All;
            Editable = true;
            Visible = true;
        }
    }
}
