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
                field(totalFob; TotalFobLP)
                {
                    Caption = 'Total Fob';
                    Editable = false;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        GetTotalFob();
    end;

    var
        TotalFobLP: Decimal;

    // "LyL OrigenLP" (extensión externa LyLVariantsExt) no trae el monto Total Fob;
    // se calcula al vuelo, sin persistirlo. Se validó contra datos reales (ver
    // docs/diseños, validación 2026-09-02) que "Nombre" (ej. "INTERFACE USA",
    // "SERVICIOS") es una clasificación que agrupa VARIOS ítems distintos de la
    // misma línea de venta -- ese agrupador es Item."LyL OrigenLP" (field 80702
    // sobre Item, tableextension "LyL ItemExt" de LyLVariantsExt; es el mismo
    // campo dinámico que ya usa Pag60106.items.al vía RecordRef -- CLAUDE.md lo
    // documentaba como campo de D365LATAM, pero pertenece a LyLVariantsExt).
    // El FOB unitario ya resuelto (para ítems "Fijo" y "Calculado" por igual,
    // Item."LyL calculoLP" field 80703) vive directo en Sales Line."LyLSalesPriceCal"
    // (tableextension "LyLSalesLineExt", field 80701) -- NO hace falta cruzar contra
    // "LyL ItemVariant"/"LyL ItemVariantDetails": para ítems "Calculado" ese campo
    // ya replica "LyL ItemVariant".PrecioFOB, y para ítems "Fijo" (sin fila en
    // ItemVariant) es la única fuente real del costo. Fórmula: por cada Sales Line
    // del documento (Tipo Artículo) cuyo Item."LyL OrigenLP" = Rec.Nombre, sumar
    // "LyLSalesPriceCal" x Quantity. Se busca en Cotización, Pedido y Factura en
    // ese orden -- la primera con líneas del documento gana, porque representan
    // la misma venta en distintas etapas de su ciclo de vida (al convertir
    // Cotización a Pedido, la línea de Cotización se borra).
    //
    // Excepción validada contra producción (2026-09-07, cotización C04000, origen
    // "SERVICIOS"): el ítem "SERVINSTAL" (Servicio de Instalación) queda fuera del
    // Total Fob del "Reporte por Origenes" nativo de LyLVariantsExt (Report 80701)
    // aunque comparta Item."LyL OrigenLP" = "SERVICIOS" con "SERVTRANSP" (Servicio
    // de Transporte, que sí cuenta) -- se confirmó quitando la línea de SERVTRANSP
    // del documento: el reporte nativo dio Total Fob = 0 para SERVICIOS, mientras
    // que las líneas de SERVINSTAL seguían con "LyLSalesPriceCal" > 0 (y, para 2 de
    // sus 3 variantes, un "LyL ItemVariant".PrecioFOB real que coincide exacto con
    // ese valor -- no es un dato corrupto). Type, "LyL calculoLP", categoría, grupo
    // contable y grupo de impuesto son idénticos entre ambos ítems, así que no hay
    // otro campo consultable que distinga el caso: instalación es mano de obra
    // local post-importación, sin costo FOB por definición, a diferencia del
    // transporte. Se excluye por número de ítem explícito.
    local procedure GetTotalFob()
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        RecRef: RecordRef;
        FldRef: FieldRef;
        ItemOrigenLP: Text[100];
        SalesPriceCal: Decimal;
        DocTypesToCheck: List of [Enum "Sales Document Type"];
        DocType: Enum "Sales Document Type";
    begin
        TotalFobLP := 0;
        if Rec.Nombre = '' then
            exit;

        DocTypesToCheck.Add(SalesLine."Document Type"::Quote);
        DocTypesToCheck.Add(SalesLine."Document Type"::Order);
        DocTypesToCheck.Add(SalesLine."Document Type"::Invoice);

        foreach DocType in DocTypesToCheck do begin
            SalesLine.Reset();
            SalesLine.SetRange("Document Type", DocType);
            SalesLine.SetRange(Type, SalesLine.Type::Item);
            SalesLine.SetRange("Document No.", Rec.SalesHeaderNo);
            if SalesLine.FindSet() then begin
                repeat
                    ItemOrigenLP := '';
                    if Item.Get(SalesLine."No.") then begin
                        RecRef.GetTable(Item);
                        if RecRef.FieldExist(80702) then begin
                            FldRef := RecRef.Field(80702);
                            ItemOrigenLP := Format(FldRef.Value);
                        end;
                    end;

                    if (ItemOrigenLP = Rec.Nombre) and (SalesLine."No." <> 'SERVINSTAL') then begin
                        SalesPriceCal := 0;
                        Clear(RecRef);
                        RecRef.GetTable(SalesLine);
                        if RecRef.FieldExist(80701) then begin
                            FldRef := RecRef.Field(80701);
                            Evaluate(SalesPriceCal, Format(FldRef.Value));
                        end;
                        TotalFobLP += SalesPriceCal * SalesLine.Quantity;
                    end;
                until SalesLine.Next() = 0;
                exit;
            end;
        end;
    end;
}
