tableextension 60123 "BH Job Planning Line Ext" extends "Job Planning Line"
{
    // DIS-2026-08-31 — marca las Job Planning Line creadas automáticamente por
    // "BH Sales Job Planning Mgt." (codeunit 60123) al teclear Job No./Job Task No.
    // en una línea de venta Tipo = Artículo, para que:
    //  - el codeunit de sincronización (5.2) nunca toque una línea de planificación
    //    real tecleada por un Project Manager.
    //  - los subscribers de posteo (5.2b) solo actúen sobre líneas de este desarrollo,
    //    sin interferir con el comportamiento estándar de Microsoft para Job Contract
    //    Lines genuinas (Recurso/Cuenta C/G facturadas vía "Crear factura de venta").
    fields
    {
        field(60100; "BH Auto-Created From Sales"; Boolean)
        {
            Caption = 'Creado automáticamente desde Ventas';
            Editable = false;
            DataClassification = SystemMetadata;
        }
    }
}
