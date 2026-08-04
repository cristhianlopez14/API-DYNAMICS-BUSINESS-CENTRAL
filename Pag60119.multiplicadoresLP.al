page 60119 "Multiplicadores LP API"
{
    PageType = API;
    SourceTable = "LyL Multiplicadores_LP";

    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';

    EntityName = 'multiplicadorLP';
    EntitySetName = 'multiplicadoresLP';

    Caption = 'Multiplicadores LP API';
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
                field(orderNo; Rec.SalesHeaderNo)
                {
                    Caption = 'Order No.';
                }
                field(trmUsd; Rec.TRM_USD)
                {
                    Caption = 'TRM USD-COP';
                }
                field(trmEuro; Rec.TRM_EURO)
                {
                    Caption = 'TRM EURO-COP';
                }
                field(trmEurUsd; Rec.TRM_EUR_USD)
                {
                    Caption = 'TRM EURO-USD';
                }
                field(trmUsdEuro; Rec.TRM_USD_EURO)
                {
                    Caption = 'TRM USD-EURO';
                }
                field(trmCopUsd; Rec.TRM_COP_USD)
                {
                    Caption = 'TRM COP-USD';
                }
                field(installationAndTransport; Rec.InstTransporte)
                {
                    Caption = 'Instalación y Transporte';
                }
                field(administrativeCost; Rec.CostoAdmin)
                {
                    Caption = 'Costo Administrativo';
                }
                field(insurance; Rec.Polizas)
                {
                    Caption = 'Polizas';
                }
                field(commercialCommission; Rec.ComisionComercial)
                {
                    Caption = 'Comisión Comercial';
                }
                field(designCommission; Rec.ComisionDiseno)
                {
                    Caption = 'Comisión Diseño';
                }
                field(financing; Rec.Financiacion)
                {
                    Caption = 'Financiación';
                }
                field(margin; Rec.Margen)
                {
                    Caption = 'Margen';
                }
                field(versionNo; Rec.VersionNo)
                {
                    Caption = 'Versión';
                }
            }
        }
    }
}
