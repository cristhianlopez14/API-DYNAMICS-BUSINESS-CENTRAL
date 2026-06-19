page 60107 "BOM Components API"
{
    PageType = API;
    SourceTable = "BOM Component";

    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';

    EntityName = 'bomComponent';
    EntitySetName = 'bomComponents';

    Caption = 'BOM Components API';
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
                // Producto ensamble padre
                field(parentItemNo; Rec."Parent Item No.")
                {
                    Caption = 'Parent Item No.';
                }
                // Tipo (Item, Resource)
                field(type; Rec.Type)
                {
                    Caption = 'Type';
                }
                // Nº componente
                field(no; Rec."No.")
                {
                    Caption = 'No.';
                }
                // Descripción del componente
                field(description; Rec.Description)
                {
                    Caption = 'Description';
                }
                // Cantidad por ensamble
                field(quantityPer; Rec."Quantity per")
                {
                    Caption = 'Quantity per';
                }
                field(unitOfMeasureCode; Rec."Unit of Measure Code")
                {
                    Caption = 'Unit of Measure Code';
                }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        BOMComp: Record "BOM Component";
    begin
        // Calcular Line No. en incrementos de 10000 por producto padre
        BOMComp.SetRange("Parent Item No.", Rec."Parent Item No.");
        if BOMComp.FindLast() then
            Rec."Line No." := BOMComp."Line No." + 10000
        else
            Rec."Line No." := 10000;

        // Defaultear Type = Item si no se envió (evita el error de validación BC)
        if Rec.Type = Rec.Type::" " then
            Rec.Type := Rec.Type::Item;

        exit(true);
    end;
}
