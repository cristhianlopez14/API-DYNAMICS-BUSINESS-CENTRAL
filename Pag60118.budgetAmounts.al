page 60118 "Budget Amounts API"
{
    PageType = API;
    SourceTable = "BH Budget Amount Buffer";
    SourceTableTemporary = true;

    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';

    EntityName = 'budgetAmount';
    EntitySetName = 'budgetAmounts';

    Caption = 'Budget Amounts API';
    ApplicationArea = All;

    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

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
                }
                field(budgetName; Rec."Budget Name")
                {
                    Caption = 'Budget Name';
                }
                field(dimensionValueCode; Rec."Dimension Value Code")
                {
                    Caption = 'Dimension Value Code';
                }
                field(dimensionValueName; Rec."Dimension Value Name")
                {
                    Caption = 'Dimension Value Name';
                }
                field(periodStartDate; Rec."Period Start Date")
                {
                    Caption = 'Period Start Date';
                }
                field(periodEndDate; Rec."Period End Date")
                {
                    Caption = 'Period End Date';
                }
                field(budgetAmount; Rec."Budget Amount")
                {
                    Caption = 'Budget Amount';
                }
                field(actualAmount; Rec."Actual Amount")
                {
                    Caption = 'Actual Amount';
                }
                field(remainingAmount; Rec."Remaining Amount")
                {
                    Caption = 'Remaining Amount';
                }
            }
        }
    }

    trigger OnOpenPage()
    var
        FilterView: Text;
    begin
        // Captura el filtro OData ($filter) que llega antes de que el buffer se llene,
        // ya que Reset()/DeleteAll() en PopulateBuffer lo eliminarían.
        FilterView := Rec.GetView(false);

        PopulateBuffer();

        // Reaplica el filtro original sobre el buffer ya poblado.
        if FilterView <> '' then
            Rec.SetView(FilterView);
    end;

    local procedure PopulateBuffer()
    var
        GLBudgetEntry: Record "G/L Budget Entry";
        GLBudgetEntrySum: Record "G/L Budget Entry";
        GLEntry: Record "G/L Entry";
        DimValue: Record "Dimension Value";
        GLSetup: Record "General Ledger Setup";
        PeriodStart: Date;
        PeriodEnd: Date;
    begin
        Rec.Reset();
        Rec.DeleteAll();

        GLSetup.Get();

        if GLBudgetEntry.FindSet() then
            repeat
                PeriodStart := CalcDate('<-CM>', GLBudgetEntry."Date");
                PeriodEnd := CalcDate('<CM>', PeriodStart);

                if not Rec.Get(GLBudgetEntry."Budget Name", GLBudgetEntry."Global Dimension 1 Code", PeriodStart) then begin
                    GLBudgetEntrySum.Reset();
                    GLBudgetEntrySum.SetRange("Budget Name", GLBudgetEntry."Budget Name");
                    GLBudgetEntrySum.SetRange("Global Dimension 1 Code", GLBudgetEntry."Global Dimension 1 Code");
                    GLBudgetEntrySum.SetRange("Date", PeriodStart, PeriodEnd);
                    GLBudgetEntrySum.CalcSums(Amount);

                    GLEntry.Reset();
                    GLEntry.SetRange("Global Dimension 1 Code", GLBudgetEntry."Global Dimension 1 Code");
                    GLEntry.SetRange("Posting Date", PeriodStart, PeriodEnd);
                    GLEntry.CalcSums(Amount);

                    Rec.Init();
                    Rec."Budget Name" := GLBudgetEntry."Budget Name";
                    Rec."Dimension Value Code" := GLBudgetEntry."Global Dimension 1 Code";

                    Rec."Dimension Value Name" := '';
                    if GLSetup."Global Dimension 1 Code" <> '' then
                        if DimValue.Get(GLSetup."Global Dimension 1 Code", GLBudgetEntry."Global Dimension 1 Code") then
                            Rec."Dimension Value Name" := DimValue.Name;

                    Rec."Period Start Date" := PeriodStart;
                    Rec."Period End Date" := PeriodEnd;
                    Rec."Budget Amount" := GLBudgetEntrySum.Amount;
                    Rec."Actual Amount" := GLEntry.Amount;
                    Rec."Remaining Amount" := Rec."Budget Amount" - Rec."Actual Amount";
                    Rec.SystemId := CreateGuid();
                    Rec.Insert(false);
                end;
            until GLBudgetEntry.Next() = 0;

        // Nota: se removió el Rec.Reset() final que existía en el original.
        // Ya no es necesario aquí y, de mantenerse, anularía el SetView()
        // que se aplica después de regresar de este procedimiento.
    end;
}