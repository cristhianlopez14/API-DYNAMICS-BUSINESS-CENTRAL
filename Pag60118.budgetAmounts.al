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
                field(glAccountNo; Rec."G/L Account No.")
                {
                    Caption = 'G/L Account No.';
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
        AccountFilter: Text;
    begin
        // Captura el filtro OData completo (como antes) y, aparte, el filtro de glAccountNo:
        // este último se consume ANTES de agregar (ver PopulateBuffer), ya que una fila puede
        // representar la suma de varias cuentas (ej. startswith '5') y no puede reaplicarse
        // después sobre el buffer ya agregado.
        FilterView := Rec.GetView(false);
        AccountFilter := Rec.GetFilter("G/L Account No.");

        // Si el consumidor no manda glAccountNo, se usa por defecto la lista de cuentas de
        // presupuesto configurada para esta compañía (tabla "BH Budget GL Account"), en vez de
        // sumar TODAS las cuentas contables. Esto evita mandar listas largas de cuentas por la
        // URL (y el límite de nodos de OData) cuando el conjunto de cuentas es fijo por compañía.
        if AccountFilter = '' then
            AccountFilter := GetDefaultBudgetAccountFilter();

        PopulateBuffer(AccountFilter);

        // Reaplica el filtro original completo (budgetName, dimensionValueCode, periodo, etc.)
        // y luego limpia el de glAccountNo, que ya fue consumido al agregar.
        if FilterView <> '' then
            Rec.SetView(FilterView);
        Rec.SetRange("G/L Account No.");
    end;

    local procedure GetDefaultBudgetAccountFilter(): Text
    var
        BudgetGLAccount: Record "BH Budget GL Account";
        AccountFilter: Text;
    begin
        if BudgetGLAccount.FindSet() then
            repeat
                if AccountFilter <> '' then
                    AccountFilter += '|';
                AccountFilter += BudgetGLAccount."G/L Account No.";
            until BudgetGLAccount.Next() = 0;
        exit(AccountFilter);
    end;

    local procedure PopulateBuffer(AccountFilter: Text)
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

        if AccountFilter <> '' then
            GLBudgetEntry.SetFilter("G/L Account No.", AccountFilter);

        if GLBudgetEntry.FindSet() then
            repeat
                PeriodStart := CalcDate('<-CM>', GLBudgetEntry."Date");
                PeriodEnd := CalcDate('<CM>', PeriodStart);

                if not Rec.Get(GLBudgetEntry."Budget Name", GLBudgetEntry."Global Dimension 1 Code", PeriodStart) then begin
                    GLBudgetEntrySum.Reset();
                    GLBudgetEntrySum.SetRange("Budget Name", GLBudgetEntry."Budget Name");
                    GLBudgetEntrySum.SetRange("Global Dimension 1 Code", GLBudgetEntry."Global Dimension 1 Code");
                    GLBudgetEntrySum.SetRange("Date", PeriodStart, PeriodEnd);
                    if AccountFilter <> '' then
                        GLBudgetEntrySum.SetFilter("G/L Account No.", AccountFilter);
                    GLBudgetEntrySum.CalcSums(Amount);

                    GLEntry.Reset();
                    GLEntry.SetRange("Global Dimension 1 Code", GLBudgetEntry."Global Dimension 1 Code");
                    GLEntry.SetRange("Posting Date", PeriodStart, PeriodEnd);
                    if AccountFilter <> '' then
                        GLEntry.SetFilter("G/L Account No.", AccountFilter);
                    GLEntry.CalcSums(Amount);

                    Rec.Init();
                    Rec."Budget Name" := GLBudgetEntry."Budget Name";
                    // Informativo: el filtro de cuenta aplicado a esta fila (puede cubrir varias cuentas).
                    Rec."G/L Account No." := CopyStr(AccountFilter, 1, MaxStrLen(Rec."G/L Account No."));
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
    end;
}