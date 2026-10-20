tableextension 60127 "BH Purchase Header Ext" extends "Purchase Header"
{
    fields
    {
        // CUFE del documento electronico recibido del proveedor. No se reutiliza el campo
        // "D365L CO DS CUFE" (80885) de Documento Soporte: ese existe solo en Purch. Inv. Header
        // y es el CUFE del documento soporte que emite la propia empresa, no el del proveedor.
        field(60127; "BH CUFE"; Text[100])
        {
            Caption = 'CUFE';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(BHCufe; "BH CUFE")
        {
        }
    }
}
