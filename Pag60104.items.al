page 60106 "Items API"
{
    PageType = API;
    SourceTable = Item;

    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';

    EntityName = 'producto';
    EntitySetName = 'productos';

    Caption = 'Items API';
    ApplicationArea = All;

    DelayedInsert = true;
    Editable = true;

    ODataKeyFields = SystemId;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                    Editable = false;
                }
                field(number; Rec."No.")
                {
                    Caption = 'No.';
                }
                field(displayName; Rec.Description)
                {
                    Caption = 'Display Name';
                }
                field(description; Rec.Description)
                {
                    Caption = 'Description';
                }
                field(description2; Rec."Description 2")
                {
                    Caption = 'Description 2';
                }
                field(type; Rec.Type)
                {
                    Caption = 'Type';
                }
                field(itemCategoryId; ItemCategoryIdLP)
                {
                    Caption = 'Item Category Id';
                    Editable = false;
                }
                field(itemCategoryCode; Rec."Item Category Code")
                {
                    Caption = 'Item Category Code';
                }
                field(blocked; Rec.Blocked)
                {
                    Caption = 'Blocked';
                }
                field(gtin; Rec.GTIN)
                {
                    Caption = 'GTIN';
                }
                field(inventory; Rec.Inventory)
                {
                    Caption = 'Inventory';
                    Editable = false;
                }
                field(unitPrice; Rec."Unit Price")
                {
                    Caption = 'Unit Price';
                }
                field(priceIncludesTax; Rec."Price Includes VAT")
                {
                    Caption = 'Price Includes Tax';
                }
                field(unitCost; Rec."Unit Cost")
                {
                    Caption = 'Unit Cost';
                }
                field(taxGroupId; TaxGroupIdLP)
                {
                    Caption = 'Tax Group Id';
                    Editable = false;
                }
                field(taxGroupCode; Rec."Tax Group Code")
                {
                    Caption = 'Tax Group Code';
                }
                field(baseUnitOfMeasureId; BaseUnitOfMeasureIdLP)
                {
                    Caption = 'Base Unit of Measure Id';
                    Editable = false;
                }
                field(baseUnitOfMeasureCode; Rec."Base Unit of Measure")
                {
                    Caption = 'Base Unit of Measure';
                }
                field(genProdPostingGroup; Rec."Gen. Prod. Posting Group")
                {
                    Caption = 'Grupo Contable Prod Gen';
                }
                field(inventoryPostingGroup; Rec."Inventory Posting Group")
                {
                    Caption = 'Grupo Registro Inventario';
                }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Caption = 'Last Modified Date Time';
                    Editable = false;
                }

                // =========================
                // LOCALIZACIÓN COLOMBIA
                // =========================

                field(origen; OrigenLP)
                {
                    Caption = 'Origen';
                }
                field(codGrupoImpuestoVenta; Rec."D365L CO Sales Tax Group Code")
                {
                    Caption = 'Cod. Grupo Impuesto Venta';
                }
                field(codGrupoImpuestoCompra; CodGrupoImpuestoCompraLP)
                {
                    // TODO: pendiente confirmar el campo real de "Grupo Impuesto Compra" a nivel
                    // de Item en el módulo D365LATAM (no existe hoy en la versión instalada de
                    // D365LATAM - Colombia Localization). Queda como placeholder vacío.
                    Caption = 'Cod. Grupo Impuesto Compra';
                    Editable = false;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields(Inventory);
        GetOrigenLP();
        GetLookupIds();
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        Rec.Insert(true);
        SetOrigenLP();
        exit(false);
    end;

    trigger OnModifyRecord(): Boolean
    begin
        Rec.Modify(true);
        SetOrigenLP();
        exit(false);
    end;

    var
        OrigenLP: Text[100];
        CodGrupoImpuestoCompraLP: Text[20];
        ItemCategoryIdLP: Guid;
        TaxGroupIdLP: Guid;
        BaseUnitOfMeasureIdLP: Guid;

    local procedure GetLookupIds()
    var
        ItemCategory: Record "Item Category";
        TaxGroup: Record "Tax Group";
        UnitOfMeasure: Record "Unit of Measure";
    begin
        Clear(ItemCategoryIdLP);
        if Rec."Item Category Code" <> '' then
            if ItemCategory.Get(Rec."Item Category Code") then
                ItemCategoryIdLP := ItemCategory.SystemId;

        Clear(TaxGroupIdLP);
        if Rec."Tax Group Code" <> '' then
            if TaxGroup.Get(Rec."Tax Group Code") then
                TaxGroupIdLP := TaxGroup.SystemId;

        Clear(BaseUnitOfMeasureIdLP);
        if Rec."Base Unit of Measure" <> '' then
            if UnitOfMeasure.Get(Rec."Base Unit of Measure") then
                BaseUnitOfMeasureIdLP := UnitOfMeasure.SystemId;
    end;

    local procedure GetOrigenLP()
    var
        RecRef: RecordRef;
        FldRef: FieldRef;
    begin
        OrigenLP := '';
        RecRef.GetTable(Rec);
        if RecRef.FieldExist(80702) then begin
            FldRef := RecRef.Field(80702);
            OrigenLP := Format(FldRef.Value);
        end;
    end;

    local procedure SetOrigenLP()
    var
        RecRef: RecordRef;
        FldRef: FieldRef;
    begin
        RecRef.GetTable(Rec);
        if RecRef.FieldExist(80702) then begin
            FldRef := RecRef.Field(80702);
            FldRef.Value := OrigenLP;
            RecRef.Modify(true);
        end;
    end;
}
