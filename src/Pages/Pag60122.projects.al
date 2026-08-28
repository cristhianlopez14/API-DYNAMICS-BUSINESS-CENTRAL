page 60122 "Projects API"
{
    PageType = API;
    SourceTable = Job;

    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';

    EntityName = 'project';
    EntitySetName = 'projects';

    Caption = 'Projects API';
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
                field(status; Rec.Status)
                {
                    Caption = 'Status';
                }
                field(billToCustomerNo; Rec."Bill-to Customer No.")
                {
                    Caption = 'Bill-to Customer No.';
                }
                field(sellToCustomerNo; Rec."Sell-to Customer No.")
                {
                    Caption = 'Sell-to Customer No.';
                }
                field(personResponsible; Rec."Person Responsible")
                {
                    Caption = 'Person Responsible';
                }
                field(startingDate; Rec."Starting Date")
                {
                    Caption = 'Starting Date';
                }
                field(endingDate; Rec."Ending Date")
                {
                    Caption = 'Ending Date';
                }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Caption = 'Last Modified Date Time';
                    Editable = false;
                }
            }
        }
    }

    // Equivalente API a la acción estándar "Copiar tareas de proyecto desde..." de la Ficha
    // Proyecto: reutiliza Codeunit "Copy Job" (1006), la misma lógica que corre la página
    // "Copy Job Tasks" (1041), sobre el proyecto ya existente identificado por Rec (destino).
    // CopyPlanningLines = false reproduce la opción "None" del wizard estándar: JobPlanningLineSource
    // recibe un valor (2) que no matchea ninguna rama del case interno de Codeunit "Copy Job", por lo
    // que copia únicamente las Job Task (estructura/fechas), sin generar Job Planning Line alguna.
    [ServiceEnabled]
    procedure copyProjectTasks(var ActionContext: WebServiceActionContext; SourceProjectNo: Code[20]; FromProjectTaskNo: Code[20]; ToProjectTaskNo: Code[20]; CopyPlanningLines: Boolean; CopyQuantity: Boolean; CopyDimensions: Boolean)
    var
        SourceJob: Record Job;
        CopyJob: Codeunit "Copy Job";
        JobPlanningLineSource: Option "Job Planning Lines","Job Ledger Entries","None";
        JobPlanningLineType: Option " ",Budget,Billable;
        JobLedgerEntryType: Option " ",Usage,Sale;
    begin
        if not SourceJob.Get(SourceProjectNo) then
            Error(SourceProjectNoNotFoundErr, SourceProjectNo);

        if CopyPlanningLines then
            JobPlanningLineSource := JobPlanningLineSource::"Job Planning Lines"
        else
            JobPlanningLineSource := JobPlanningLineSource::None;

        CopyJob.SetCopyOptions(false, CopyQuantity, CopyDimensions, JobPlanningLineSource, JobPlanningLineType::" ", JobLedgerEntryType::" ");
        CopyJob.SetJobTaskRange(FromProjectTaskNo, ToProjectTaskNo);
        CopyJob.CopyJobTasks(SourceJob, Rec);

        ActionContext.SetObjectType(ObjectType::Page);
        ActionContext.SetObjectId(Page::"Projects API");
        ActionContext.AddEntityKey(Rec.FieldNo(SystemId), Rec.SystemId);
        ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
    end;

    var
        SourceProjectNoNotFoundErr: Label 'No se encontró un proyecto %1 para copiar las tareas.', Comment = '%1 = Project No.';
}
