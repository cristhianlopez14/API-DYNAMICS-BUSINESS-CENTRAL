permissionset 60129 "BH-API-CAUSACION"
{
    Assignable = true;
    Caption = 'BH API - Causacion';

    // Minimo para crear borradores de factura de compra y copiar un pedido. A PROPOSITO no incluye
    // ningun permiso de ejecucion sobre los codeunits de registro de compras (Purch.-Post y
    // derivados): BC debe impedir registrar ademas de que el codigo no lo haga.
    // Los permisos de abajo son el punto de partida; se afinan con la prueba real en el sandbox.
    Permissions = tabledata "Purchase Header" = RIM,
                  tabledata "Purchase Line" = RIM,
                  tabledata "Purch. Inv. Header" = R,
                  tabledata "Purch. Inv. Line" = R,
                  tabledata Vendor = R,
                  tabledata "Vendor Posting Group" = R,
                  tabledata Currency = R,
                  tabledata "Payment Terms" = R,
                  tabledata "Purchases & Payables Setup" = R,
                  tabledata "General Ledger Setup" = R,
                  tabledata "No. Series" = R,
                  tabledata "No. Series Line" = RM,
                  tabledata "Dimension Value" = R,
                  tabledata "Default Dimension" = R,
                  tabledata "Dimension Set Entry" = RI,
                  tabledata "Dimension Set Tree Node" = RIM,
                  codeunit "Copy Document Mgt." = X,
                  codeunit "BH Copy Order To Invoice" = X,
                  page "BH Purchase Invoices API" = X;
}
