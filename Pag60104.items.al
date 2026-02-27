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
                field(itemCategoryCode; Rec."Item Category Code")
                {
                    Caption = 'Item Category Code';
                }
                field(taxGroupCode; Rec."Tax Group Code")
                {
                    Caption = 'Tax Group Code';
                }
                field(baseUnitOfMeasure; Rec."Base Unit of Measure")
                {
                    Caption = 'Base Unit of Measure';
                }
                field(genProdPostingGroup; Rec."Gen. Prod. Posting Group")
                {
                    Caption = 'Gen. Prod. Posting Group';
                }
                field(inventoryPostingGroup; Rec."Inventory Posting Group")
                {
                    Caption = 'Inventory Posting Group';
                }

                // =========================
                // LOCALIZACIÓN COLOMBIA
                // =========================

                field(origen; OrigenLP)
                {
                    Caption = 'Origen';
                }
                field(codGrupoImpuesto; Rec."D365L CO Sales Tax Group Code")
                {
                    Caption = 'Cod. Grupo Impuesto';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        GetOrigenLP();
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
