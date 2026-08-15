page 60120 "Origenes LP API"
{
    PageType = API;
    SourceTable = "LyL OrigenLP";

    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';

    EntityName = 'origenLP';
    EntitySetName = 'origenesLP';

    Caption = 'Origenes LP API';
    ApplicationArea = All;

    DelayedInsert = true;
    Editable = true;

    ODataKeyFields = SystemId;

    layout
    {
        area(content)
        {
            group(General)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                    Editable = false;
                }
                field(number; Rec.ID)
                {
                    Caption = 'Number';
                    Editable = false;
                }
                field(name; Rec.Nombre)
                {
                    Caption = 'Nombre';
                }
                field(logisticFactor; Rec.FactorLogistico)
                {
                    Caption = 'Factor Logistico';
                }
                field(originRegion; Rec.RegionOrigen)
                {
                    Caption = 'Region Origen';
                }
                field(currencyCode; Rec.Moneda)
                {
                    Caption = 'Moneda';
                }
                field(orderNo; Rec.SalesHeaderNo)
                {
                    Caption = 'No. Documento';
                }
                field(orderLineNo; Rec.SalesLineNo)
                {
                    Caption = 'No. Línea Documento';
                }
                field(itemNo; Rec.ItemNo)
                {
                    Caption = 'Item No.';
                }
                field(versionNo; Rec.VersionNo)
                {
                    Caption = 'Versión';
                }
                field(margin; Rec.Margen)
                {
                    Caption = 'Margen';
                }
            }
        }
    }
}
