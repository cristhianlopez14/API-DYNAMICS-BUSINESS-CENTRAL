page 60102 "ApiP Proveedores"
{
    PageType = API;
    Caption = 'API Proveedores BH';
    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';
    EntityName = 'vendor';
    EntitySetName = 'vendors';
    SourceTable = Vendor;
    DelayedInsert = true;
    
    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field(number; rec."No.")
                {
                    Caption = 'No.';
                    
                }
                field(name; rec.Name)
                {
                    Caption = 'Nombre Proveedor';
                }
                field("No"; rec."No. of Orders")
                {
                    Caption = 'Número de órdenes';
                }
                
            }
        }
    }

}