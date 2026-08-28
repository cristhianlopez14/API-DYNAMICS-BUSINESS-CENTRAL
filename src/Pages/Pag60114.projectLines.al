page 60114 "Project Lines API"
{
    PageType = API;
    SourceTable = "Job Planning Line";

    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';

    EntityName = 'projectLine';
    EntitySetName = 'projectLines';

    Caption = 'Project Lines API';
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
                field(jobNo; Rec."Job No.")
                {
                    Caption = 'Job No.';
                }
                field(jobTaskNo; Rec."Job Task No.")
                {
                    Caption = 'Job Task No.';
                }
                field(lineNo; Rec."Line No.")
                {
                    Caption = 'Line No.';
                    Editable = false;
                }
                field(lineType; Rec."Line Type")
                {
                    Caption = 'Line Type';
                }
                field(planningDate; Rec."Planning Date")
                {
                    Caption = 'Planning Date';
                }
                field(plannedDeliveryDate; Rec."Planned Delivery Date")
                {
                    Caption = 'Planned Delivery Date';
                }
                field(documentNo; Rec."Document No.")
                {
                    Caption = 'Document No.';
                }
                field(type; Rec.Type)
                {
                    Caption = 'Type';
                }
                field(no; Rec."No.")
                {
                    Caption = 'No.';
                }
                field(description; Rec.Description)
                {
                    Caption = 'Description';
                }
                field(quantity; Rec.Quantity)
                {
                    Caption = 'Quantity';
                }
                field(unitOfMeasureCode; Rec."Unit of Measure Code")
                {
                    Caption = 'Unit of Measure Code';
                }
                field(unitCost; UnitCostBuffer)
                {
                    Caption = 'Unit Cost';
                }
                field(totalCost; TotalCostBuffer)
                {
                    Caption = 'Total Cost';
                    Editable = false;
                }
                field(unitPrice; UnitPriceBuffer)
                {
                    Caption = 'Unit Price';
                }
                field(totalPrice; TotalPriceBuffer)
                {
                    Caption = 'Total Price';
                    Editable = false;
                }
                field(currencyCode; Rec."Currency Code")
                {
                    Caption = 'Currency Code';
                }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Caption = 'Last Modified Date Time';
                    Editable = false;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        UnitCostBuffer := Rec."Unit Cost";
        UnitPriceBuffer := Rec."Unit Price";
        TotalCostBuffer := Rec."Total Cost";
        TotalPriceBuffer := Rec."Total Price";
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        // Auto-increment Line No.
        JobPlanningLine.SetRange("Job No.", Rec."Job No.");
        JobPlanningLine.SetRange("Job Task No.", Rec."Job Task No.");
        if JobPlanningLine.FindLast() then
            Rec."Line No." := JobPlanningLine."Line No." + 10000
        else
            Rec."Line No." := 10000;

        // Insert con triggers de tabla (OnInsert recalcula desde tarjeta recurso → pone todo a 0)
        Rec.Insert(true);

        ApplyCostAndPrice();

        // false = nosotros ya hicimos el Insert; BC no lo repite
        exit(false);
    end;

    trigger OnModifyRecord(): Boolean
    begin
        ApplyCostAndPrice();
        exit(false);  // nosotros ya hicimos el Modify
    end;

    local procedure ApplyCostAndPrice()
    begin
        // Validate (no solo asignación directa) es lo que recalcula correctamente Total Cost/Total
        // Cost (LCY), Total Price/Total Price (LCY) y Line Amount/Line Amount (LCY) -los campos
        // "(LCY)" son los que alimentan el rollup de la Job Task, y solo se actualizan dentro del
        // UpdateAllAmounts() que corre el OnValidate estándar de Unit Cost/Unit Price-.
        if UnitCostBuffer <> 0 then
            Rec.Validate("Unit Cost", UnitCostBuffer);
        if UnitPriceBuffer <> 0 then
            Rec.Validate("Unit Price", UnitPriceBuffer);

        // Reafirmación final: el orden exacto en que BC aplica type/no./quantity antes de este
        // trigger puede volver a derivar costo/precio desde el recurso -por eso, sin importar
        // qué haya hecho el Validate() por dentro, se fuerzan aquí los valores definitivos
        // (asume moneda base: LCY = FCY, consistente con currencyCode en blanco en este API).
        if UnitCostBuffer <> 0 then begin
            Rec."Unit Cost" := UnitCostBuffer;
            Rec."Unit Cost (LCY)" := UnitCostBuffer;
            Rec."Total Cost" := UnitCostBuffer * Rec.Quantity;
            Rec."Total Cost (LCY)" := UnitCostBuffer * Rec.Quantity;
        end;
        if UnitPriceBuffer <> 0 then begin
            Rec."Unit Price" := UnitPriceBuffer;
            Rec."Unit Price (LCY)" := UnitPriceBuffer;
            Rec."Total Price" := UnitPriceBuffer * Rec.Quantity;
            Rec."Total Price (LCY)" := UnitPriceBuffer * Rec.Quantity;
            Rec."Line Amount" := Rec."Total Price" - Rec."Line Discount Amount";
            Rec."Line Amount (LCY)" := Rec."Line Amount";
        end;

        if (UnitCostBuffer <> 0) or (UnitPriceBuffer <> 0) then
            Rec.Modify();   // sin triggers de tabla → BC no vuelve a releer el recurso
    end;

    var
        UnitCostBuffer: Decimal;
        UnitPriceBuffer: Decimal;
        TotalCostBuffer: Decimal;
        TotalPriceBuffer: Decimal;
}
