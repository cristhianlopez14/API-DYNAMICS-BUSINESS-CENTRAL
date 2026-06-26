# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**BH - API** — Extensión de Business Central (AL) que expone páginas API OData para integración con sistemas externos. Enfocada en operaciones de ventas, compras y maestros, con localización colombiana (D365LATAM).

- Publisher: Cristhian Lopez
- Versión actual: 1.2.0.5
- BC Application: v27 (Dynamics 365 Business Central 2024 Wave 2)
- Runtime AL: 16.0

## Desarrollo

No hay CLI de build. Todo se hace desde VS Code con la extensión AL Language:

- **Compilar y publicar**: `Ctrl+Shift+P` → `AL: Publish` (o `F5` para publicar con debugger)
- **Descargar símbolos**: `Ctrl+Shift+P` → `AL: Download Symbols`
- **Snapshot debug**: usar la configuración "AL: Generated Snapshot request" en `launch.json`
- El entorno de sandbox está configurado en [launch.json](.vscode/launch.json): `sandbox1012`, tenant `10657a47-53a7-4493-b90b-033cc0505242`

No hay tests unitarios en este proyecto. La validación se hace publicando al sandbox y probando los endpoints directamente.

## Arquitectura

El proyecto contiene únicamente **API Pages** (sin tablas ni codeunits propios). Todos los objetos usan el rango de IDs **60100–60149**.

| Página | ID | Endpoint | Fuente |
|--------|----|----------|--------|
| Vendors (inglés) | 60102 | `/bh/bh/beta/vendors` | Vendor |
| Proveedores (español) | 60103 | `/bh/bh/beta/proveedores` | Vendor |
| Sales Invoice Lines | 60104 | `/bh/bh/beta/salesInvoiceLines` | Sales Line |
| Sales Invoices | 60105 | `/bh/bh/beta/salesInvoices` | Sales Header |
| Productos | 60106 | `/bh/bh/beta/productos` | Item |
| BOM Components | 60107 | `/bh/bh/beta/bomComponents` | BOM Component |
| Opportunities        | 60108 | `/bh/bh/beta/opportunities`       | Opportunity          |
| Sales Quotes         | 60109 | `/bh/bh/beta/salesQuotes`         | Sales Header (Quote) |
| Sales Orders         | 60110 | `/bh/bh/beta/salesOrders`         | Sales Header (Order) |
| Customers            | 60111 | `/bh/bh/beta/customers`           | Customer             |
| Salespersons         | 60112 | `/bh/bh/beta/salespersonPurchasers` | Salesperson/Purchaser |
| Payment Journal Lines | 60113 | `/bh/bh/beta/paymentJournalLines` | Gen. Journal Line    |
| Project Lines         | 60114 | `/bh/bh/beta/projectLines`        | Job Planning Line    |

Todos usan: `APIPublisher = 'bh'`, `APIGroup = 'bh'`, `APIVersion = 'beta'`, `ODataKeyFields = SystemId`, `DelayedInsert = true`.

## Patrones de código

**Numeración automática de líneas** (ver [Pag60102.salesInvoiceLines.al](Pag60102.salesInvoiceLines.al)):  
`OnInsertRecord()` calcula `LineNo` en incrementos de 10000 buscando el último registro con `FindLast`.

**Campos dinámicos vía RecordRef/FieldRef** (ver [Pag60104.items.al](Pag60104.items.al)):  
El campo `Origen` (field 80702 del módulo D365LATAM) no es accesible directamente; se lee/escribe con `RecordRef.FieldIndex` o `RecordRef.Field(80702)` para evitar dependencia de compilación en tiempo real.

**WorkDescription en Sales Invoices** (ver [Pag60103.salesInvoices.al](Pag60103.salesInvoices.al)):  
Usa `GetWorkDescription()` / `SetWorkDescription()` con una variable local `WorkDescriptionValue` en `OnAfterGetRecord` y `OnModifyRecord`.

## Localización Colombia (D365LATAM)

Los campos con prefijo `"D365L CO"` provienen de la dependencia **D365LATAM - Colombia Localization** (v27.0.0.17). Campos frecuentes en proveedores e ítems:

- `TipoPersona`, `TipoDocumento`, `DocumentTypeDesc` — tipo de contribuyente DIAN
- `TaxRespon`, `RequiredRSDocument` — responsabilidad tributaria
- `CodGrupoImpuesto`, `Origen` — grupos de impuesto e imputación

## Dependencias (.alpackages)

8 dependencias declaradas en `app.json`. Las más relevantes para este código:

- `D365LATAM - Colombia Localization` — campos tributarios en Vendor e Item
- `D365LATAM Documento Soporte` — soporte para documentos de compras
- `D365LATAM RetecionesArt383` — retenciones colombianas
- `Microsoft Base Application` — todas las tablas fuente (Vendor, Item, Sales Header, etc.)
