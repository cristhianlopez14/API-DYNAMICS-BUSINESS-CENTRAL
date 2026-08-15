# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**BH - API** — Extensión de Business Central (AL) que expone páginas API OData para integración con sistemas externos. Enfocada en operaciones de ventas, compras y maestros, con localización colombiana (D365LATAM).

- Publisher: Cristhian Lopez
- Versión actual: 1.2.0.7
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

El proyecto contiene principalmente **API Pages** sobre tablas estándar de BC. La única excepción es `Tab60118.budgetAmountBuffer.al` (`BH Budget Amount Buffer`), una tabla temporal propia usada como buffer de agregación (ver abajo). Todos los objetos usan el rango de IDs **60100–60149**.

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
| Purchase Invoices      | 60115 | `/bh/bh/beta/purchaseInvoices`    | Purchase Header (buffer temporal, ver abajo) + Purch. Inv. Header |
| No. Series Lines       | 60116 | `/bh/bh/beta/noSeriesLines`       | No. Series Line      |
| Purchase Invoice Lines | 60117 | `/bh/bh/beta/purchaseInvoiceLines` | Purchase Line (borrador, `Document Type = Invoice`) |
| Budget Amounts         | 60118 | `/bh/bh/beta/budgetAmounts`        | G/L Budget Entry (agregado, ver abajo) + `BH Budget Amount Buffer` (tabla propia) |
| Multiplicadores LP     | 60119 | `/bh/bh/beta/multiplicadoresLP`    | `LyL Multiplicadores_LP` (tabla 80707, extensión externa `LyLVariantsExt`) |
| Origenes LP            | 60120 | `/bh/bh/beta/origenesLP`           | `LyL OrigenLP` (tabla 80708, extensión externa `LyLVariantsExt`) |

Todos usan: `APIPublisher = 'bh'`, `APIGroup = 'bh'`, `APIVersion = 'beta'`, `ODataKeyFields = SystemId`. Todos son de lectura/escritura (`DelayedInsert = true`) excepto **Budget Amounts**, que es solo lectura (`InsertAllowed/ModifyAllowed/DeleteAllowed = false`).

## Patrones de código

**Numeración automática de líneas** (ver [Pag60102.salesInvoiceLines.al](Pag60102.salesInvoiceLines.al)):  
`OnInsertRecord()` calcula `LineNo` en incrementos de 10000 buscando el último registro con `FindLast`.

**Campos dinámicos vía RecordRef/FieldRef** (ver [Pag60104.items.al](Pag60104.items.al)):  
El campo `Origen` (field 80702 del módulo D365LATAM) no es accesible directamente; se lee/escribe con `RecordRef.FieldIndex` o `RecordRef.Field(80702)` para evitar dependencia de compilación en tiempo real.

**Dependencia a extensión de terceros en Multiplicadores LP y Origenes LP** (ver [Pag60119.multiplicadoresLP.al](Pag60119.multiplicadoresLP.al) y [Pag60120.origenesLP.al](Pag60120.origenesLP.al)):  
`LyL Multiplicadores_LP` (tabla 80707) y `LyL OrigenLP` (tabla 80708) pertenecen a la extensión externa `LyLVariantsExt` (publisher L&L Consultores, no Microsoft/D365LATAM), declarada como dependencia en `app.json`. A diferencia de los campos D365LATAM (que se acceden vía RecordRef por ser opcionales), aquí se referencian las tablas directamente por nombre porque es una dependencia obligatoria de la extensión. Ambas tablas son reales (no temporales) y ya traen `SystemId`, así que las páginas siguen el patrón simple de Vendors/Items: `SourceTable` directo, sin buffer ni lógica de inserción custom. El campo `SalesHeaderNo` (Pedido / No. Documento) es un `Code[20]` plano en ambas tablas — sin `TableRelation` en Multiplicadores LP, sin `TableRelation` tampoco en Origenes LP (a diferencia de `RegionOrigen`, que sí tiene `TableRelation` a `"LyL RegionesLP".Codigo`, y `Moneda`, que la tiene a `Currency.Code`).

**WorkDescription en Sales Invoices** (ver [Pag60103.salesInvoices.al](Pag60103.salesInvoices.al)):  
Usa `GetWorkDescription()` / `SetWorkDescription()` con una variable local `WorkDescriptionValue` en `OnAfterGetRecord` y `OnModifyRecord`.

**Totales y lookups calculados en Purchase Invoices** (ver [Pag60115.purchaseInvoices.al](Pag60115.purchaseInvoices.al)):  
`Purch. Inv. Header` no trae `Amount`/`Amount Including VAT` a nivel de cabecera, así que `ProcessPosted()` hace `CalcSums` sobre `Purch. Inv. Line` filtrando por `Document No.`. Los GUID de Vendor/Currency/Purchase Order (`vendorId`, `payToVendorId`, `currencyId`, `orderId`) se resuelven en `GetLookupIds()` buscando el registro relacionado y tomando su `SystemId`. El `status` ("Open"/"Paid") se calcula revisando `Vendor Ledger Entry."Remaining Amount"`.

**Buffer temporal + escritura a tabla real en Purchase Invoices** (mismo archivo):  
`Rec` es un `Purchase Header` temporal (`SourceTableTemporary = true`) que `PopulateBuffer()` llena en `OnOpenPage` mezclando borradores (`Purchase Header`) y contabilizadas (`Purch. Inv. Header`) para lectura conjunta bajo un solo endpoint. Como insertar/modificar/eliminar en el buffer no toca la tabla real, `OnInsertRecord`/`OnModifyRecord`/`OnDeleteRecord` traducen la operación a un `Purchase Header` real: `ApplyBufferToHeader()` mapea los campos del buffer al header real vía `Validate` (para disparar defaults de BC como direcciones o condiciones de pago), y modificar/eliminar una factura ya contabilizada se bloquea con `Error()` si `Purch. Inv. Header.GetBySystemId` la encuentra.

**Esquema estándar de Microsoft en Purchase Invoice Lines** (ver [Pag60117.purchaseInvoiceLines.al](Pag60117.purchaseInvoiceLines.al)):  
Sigue el esquema del API estándar `purchaseInvoiceLine` de Business Central (mismos nombres de campo: `documentId`, `itemId`, `accountId`, `netAmount`, etc.) sobre `Purchase Line` (solo borradores, `Document Type = Invoice`). `documentId` es el único campo de vinculación al header — se resuelve en `OnInsertRecord`/`OnModifyRecord` buscando el `Purchase Header` por `SystemId`, ya que la línea no expone el `No.` del documento directamente. Los demás Guid (`itemId`, `accountId`, `unitOfMeasureId`, `itemVariantId`) son de solo lectura, calculados en `GetReferenceIds()` a partir de `lineObjectNumber`/`unitOfMeasureCode`/`Variant Code` — para crear o modificar una línea siempre se usa `lineObjectNumber` + `lineType`, nunca los Guid. `CalcTaxAmounts()` deriva `totalTaxAmount`/`amountIncludingTax`/`netTaxAmount` a partir de `Line Amount`, `VAT %`, `Amount` y `Amount Including VAT` (los montos `net*` ya reflejan el descuento de factura vía `Inv. Discount Amount`, los que no llevan `net` son previos a ese descuento).

**Buffer de agregación en Budget Amounts** (ver [Pag60118.budgetAmounts.al](Pag60118.budgetAmounts.al) y [Tab60118.budgetAmountBuffer.al](Tab60118.budgetAmountBuffer.al)):  
La página **Budget Matrix (9203, ListPart)** de BC estándar es una matriz dinámica sobre `Dimension Code Buffer` (367) que no puede exponerse 1:1 como API OData (no soporta pivote de columnas). En su lugar, `Rec` es la tabla propia `BH Budget Amount Buffer` (temporal, `SourceTableTemporary = true`) que `PopulateBuffer()` llena en `OnOpenPage` recorriendo `G/L Budget Entry` y agregando por combinación de `Budget Name` + `Global Dimension 1 Code` + mes calendario (`CalcDate('<-CM>'/'<CM>', Date)`). Por cada combinación nueva calcula tres montos: `budgetAmount` (`CalcSums(Amount)` sobre `G/L Budget Entry`), `actualAmount` (`CalcSums(Amount)` sobre `G/L Entry` filtrando por `Global Dimension 1 Code` + `Posting Date` en el mismo periodo — lo ya contabilizado/"gastado") y `remainingAmount` (`budgetAmount - actualAmount`, lo "disponible"). El nombre de la dimensión (`Dimension Value Name`) se resuelve contra `Dimension Value` usando el código de dimensión global 1 configurado en `General Ledger Setup`. Es de **solo lectura**: no hay `OnInsertRecord`/`OnModifyRecord`/`OnDeleteRecord` porque el buffer no tiene una tabla real 1:1 a la cual escribir.

**Preservar el filtro OData al repoblar el buffer** (mismo archivo):  
Como `PopulateBuffer()` hace `Rec.Reset()` + `Rec.DeleteAll()` sobre el propio buffer, cualquier `$filter` de OData que el runtime ya haya aplicado a `Rec` antes de `OnOpenPage` se perdía al limpiar la tabla. `OnOpenPage()` captura ese filtro con `Rec.GetView(false)` antes de llamar a `PopulateBuffer()` y lo reaplica después con `Rec.SetView()`, para que filtros como `$filter=budgetName eq '2026'` sigan funcionando sobre los datos ya poblados.

**Permission Set para tablas propias** (ver [Per60100.bhApiObjects.al](Per60100.bhApiObjects.al)):  
El validador `PTECop` de BC exige que toda tabla nueva definida en esta extensión (a diferencia de las páginas, que reutilizan tablas estándar de Microsoft ya cubiertas por los permission sets base) tenga un `permissionset` propio que la cubra (`tabledata ... = RIMD` + `table ... = X`), o falla al importar el paquete con `PTE0004: ... is missing a matching permission set`. Si se agrega otra tabla propia en el futuro, hay que sumarla a este permission set (o crear uno nuevo).

## Localización Colombia (D365LATAM)

Los campos con prefijo `"D365L CO"` provienen de la dependencia **D365LATAM - Colombia Localization** (v27.0.0.17). Campos frecuentes en proveedores e ítems:

- `TipoPersona`, `TipoDocumento`, `DocumentTypeDesc` — tipo de contribuyente DIAN
- `TaxRespon`, `RequiredRSDocument` — responsabilidad tributaria
- `CodGrupoImpuesto`, `Origen` — grupos de impuesto e imputación

## Dependencias (.alpackages)

9 dependencias declaradas en `app.json`. Las más relevantes para este código:

- `D365LATAM - Colombia Localization` — campos tributarios en Vendor e Item
- `D365LATAM Documento Soporte` — soporte para documentos de compras
- `D365LATAM RetecionesArt383` — retenciones colombianas
- `Microsoft Base Application` — todas las tablas fuente (Vendor, Item, Sales Header, etc.)
- `LyLVariantsExt` (publisher L&L Consultores) — tabla `LyL Multiplicadores_LP` (80707) usada en Multiplicadores LP API
