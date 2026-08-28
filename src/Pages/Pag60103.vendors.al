page 60103 Vendor
{
    PageType = API;
    SourceTable = Vendor;

    APIPublisher = 'bh';
    APIGroup = 'bh';
    APIVersion = 'beta';

    EntityName = 'vendor';
    EntitySetName = 'vendors';

    Caption = 'Vendors API';
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

                field(number; Rec."No.")
                {
                    Caption = 'Number';
                }

                field(name; Rec.Name)
                {
                    Caption = 'Name';
                }

                field(address; Rec.Address)
                {
                    Caption = 'Address';
                }

                field(address2; Rec."Address 2")
                {
                    Caption = 'Address 2';
                }

                field(country; Rec.County)
                {
                    Caption = 'Pais';
                }
                field(city; Rec.City)
                {
                    Caption = 'City';
                }

                field(postCode; Rec."Post Code")
                {
                    Caption = 'Post Code';
                }

                field(countryRegionCode; Rec."Country/Region Code")
                {
                    Caption = 'Country Region Code';
                }

                field(phoneNo; Rec."Phone No.")
                {
                    Caption = 'Phone No.';
                }

                field(email; Rec."E-Mail")
                {
                    Caption = 'Email';
                }
                // =========================
                // LOCALIZACIÓN COLOMBIA
                // =========================

                field(tipoPersona; Rec."D365L CO DIAN Entity type")
                {
                    Caption = 'Tipo Persona';
                }
                field(tipoDocumento; Rec."D365L CO DIAN Ident. Type")
                {
                    Caption = 'Tipo Documento';
                }
                field(documentTypeDesc; Rec."D365L CO Document Type Desc")
                {
                    Caption = 'Descripción Tipo Documento';
                }

                field(numberCO; Rec."D365L CO VAT Registration No.")
                {
                    Caption = 'NIT / VAT';
                }
                field(NitVAT; Rec."VAT Registration No.")
                {
                    Caption = 'NIT / VAT';
                }
                field(TaxRespon; Rec."D365L CO Desc Tax Resp. DIAN")
                {
                    Caption = 'Tax Responsible DIAN';
                }
                field(RequiredRSDocument; Rec."D365L CO Required RS Document")
                {
                    Caption = 'Required RS Document';
                }
                field(GenPostingGroup; Rec."Gen. Bus. Posting Group")
                {
                    Caption = 'General Business Posting Group';
                }
                field(VendorPostingGroup; Rec."Vendor Posting Group")
                {
                    Caption = 'Vendor Posting Group';
                }
                field(PaymentTermsCode; Rec."Payment Terms Code")
                {
                    Caption = 'Payment Terms Code';
                }
                field(PaymentMethodCode; Rec."Payment Method Code")
                {
                    Caption = 'Payment Method Code';
                }

            }
        }
    }
}
