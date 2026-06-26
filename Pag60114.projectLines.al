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

        // MODIFY sin triggers: escribe los valores que envió el usuario
        // por encima de lo que calculó el OnInsert de la tabla
        if UnitCostBuffer <> 0 then begin
            Rec."Unit Cost" := UnitCostBuffer;
            Rec."Unit Cost (LCY)" := UnitCostBuffer;
            Rec."Total Cost" := UnitCostBuffer * Rec.Quantity;
        end;
        if UnitPriceBuffer <> 0 then begin
            Rec."Unit Price" := UnitPriceBuffer;
            Rec."Unit Price (LCY)" := UnitPriceBuffer;
            Rec."Total Price" := UnitPriceBuffer * Rec.Quantity;
        end;
        if (UnitCostBuffer <> 0) or (UnitPriceBuffer <> 0) then
            Rec.Modify();   // sin triggers → BC no vuelve a releer el recurso

        // false = nosotros ya hicimos el Insert; BC no lo repite
        exit(false);
    end;

    trigger OnModifyRecord(): Boolean
    begin
        if UnitCostBuffer <> Rec."Unit Cost" then begin
            Rec."Unit Cost" := UnitCostBuffer;
            Rec."Unit Cost (LCY)" := UnitCostBuffer;
            Rec."Total Cost" := UnitCostBuffer * Rec.Quantity;
        end;
        if UnitPriceBuffer <> Rec."Unit Price" then begin
            Rec."Unit Price" := UnitPriceBuffer;
            Rec."Unit Price (LCY)" := UnitPriceBuffer;
            Rec."Total Price" := UnitPriceBuffer * Rec.Quantity;
        end;
        Rec.Modify();
        exit(false);  // nosotros ya hicimos el Modify
    end;

    var
        UnitCostBuffer: Decimal;
        UnitPriceBuffer: Decimal;
        TotalCostBuffer: Decimal;
        TotalPriceBuffer: Decimal;
}
