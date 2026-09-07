# BH - API

Extensión de **Business Central** (AL) que expone páginas API OData personalizadas para integrar Business Central con sistemas externos (ERPs, Power Automate, portales, BI, etc.), cubriendo ventas, compras, maestros y procesos de proyectos, con soporte para la localización colombiana (D365LATAM).

- **Publisher:** Cristhian Lopez
- **Versión actual:** 1.2.0.8
- **Business Central:** v27 (2024 Wave 2)
- **Runtime AL:** 16.0

## Objetivo

Business Central no siempre expone vía API estándar los procesos o campos que un integrador externo necesita (por ejemplo, presupuestos por dimensión, campos de la localización colombiana, o acciones como "copiar tareas de proyecto"). Esta extensión agrega un conjunto de **endpoints API custom** bajo un publisher/group propio (`bh`) para cubrir esos casos puntuales, sin modificar ni depender de los objetos estándar de Microsoft más allá de lo necesario.

Todos los endpoints comparten:

```
APIPublisher = bh
APIGroup     = bh
APIVersion   = beta
```

## Endpoints disponibles

| Recurso | Endpoint | Tabla origen | Notas |
|---|---|---|---|
| Vendors | `/vendors` | Vendor | |
| Customers | `/customers` | Customer | |
| Salespersons | `/salespersonPurchasers` | Salesperson/Purchaser | |
| Productos | `/productos` | Item | |
| BOM Components | `/bomComponents` | BOM Component | |
| Opportunities | `/opportunities` | Opportunity | |
| Sales Quotes | `/salesQuotes` | Sales Header (Quote) | |
| Sales Orders | `/salesOrders` | Sales Header (Order) | |
| Sales Invoices | `/salesInvoices` | Sales Header | |
| Sales Invoice Lines | `/salesInvoiceLines` | Sales Line | |
| Purchase Invoices | `/purchaseInvoices` | Purchase Header + Purch. Inv. Header | Borradores y contabilizadas bajo un solo endpoint |
| Purchase Invoice Lines | `/purchaseInvoiceLines` | Purchase Line | Solo borradores (`Document Type = Invoice`) |
| Payment Journal Lines | `/paymentJournalLines` | Gen. Journal Line | |
| No. Series Lines | `/noSeriesLines` | No. Series Line | |
| Projects | `/projects` | Job | Acción bound `copyProjectTasks` (ver abajo) |
| Project Lines | `/projectLines` | Job Planning Line | |
| Budget Amounts | `/budgetAmounts` | G/L Budget Entry (agregado) | Solo lectura |
| Multiplicadores LP | `/multiplicadoresLP` | `LyL Multiplicadores_LP` | Requiere extensión externa `LyLVariantsExt` |
| Origenes LP | `/origenesLP` | `LyL OrigenLP` | Requiere extensión externa `LyLVariantsExt`. Expone `totalFob`, calculado al vuelo por documento de venta — ver [docs/tecnica/DOC-2026-09-03-origenes-lp.md](docs/tecnica/DOC-2026-09-03-origenes-lp.md) |

Todos son de lectura/escritura excepto **Budget Amounts**, que es solo lectura.

## Requisitos

- Business Central Online, sandbox o producción, v27+.
- App registration en Microsoft Entra ID (Azure AD) con permisos de API de Business Central (`Financials.ReadWrite.All` o el scope equivalente configurado en tu tenant).
- La extensión **BH - API** publicada en el ambiente (ver [`/releases`](releases) para los paquetes `.app` compilados, o compilar desde [`app.json`](app.json) con AL Language en VS Code).

## Cómo se usa

### 1. Arma la URL base

```
https://api.businesscentral.dynamics.com/v2.0/<tenantId>/<environment>/api/bh/bh/beta/companies(<companyId>)/<endpoint>
```

- `<tenantId>`: id de tu tenant de Microsoft Entra ID.
- `<environment>`: nombre del ambiente de Business Central (ej. `Production`, `SandboxBH`).
- `<companyId>`: GUID de la company — se obtiene con `GET .../api/v2.0/companies`.
- `<endpoint>`: cualquiera de la tabla de arriba, ej. `vendors`, `projects`, `projectLines`.

### 2. Autenticación

Todas las llamadas requieren un **Bearer token** OAuth2 (client credentials o delegado) contra tu app registration de Entra ID, igual que cualquier API estándar de Business Central:

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

### 3. Ejemplos de prueba

**Consultar proveedores:**
```http
GET /bh/bh/beta/companies(<companyId>)/vendors?$top=5
```

**Buscar un proyecto por número:**
```http
GET /bh/bh/beta/companies(<companyId>)/projects?$filter=number eq 'P005045_P01390'
```

**Consultar líneas de planificación de un proyecto:**
```http
GET /bh/bh/beta/companies(<companyId>)/projectLines?$filter=jobNo eq 'P005045_P01390'
```

**Crear una línea de factura de compra en borrador:**
```http
POST /bh/bh/beta/companies(<companyId>)/purchaseInvoiceLines
Content-Type: application/json

{
  "documentId": "<systemId-de-la-factura-borrador>",
  "lineType": "Item",
  "lineObjectNumber": "1000",
  "quantity": 10
}
```

**Copiar tareas de un proyecto a otro (acción bound `copyProjectTasks`):**

Equivalente API a la acción estándar "Copiar tareas de proyecto desde..." de la Ficha Proyecto. Requiere el `id` (SystemId) del proyecto **destino**:

```http
POST /bh/bh/beta/companies(<companyId>)/projects(<id-proyecto-destino>)/Microsoft.NAV.copyProjectTasks
Content-Type: application/json

{
  "sourceProjectNo": "P005045_P01390",
  "fromProjectTaskNo": "",
  "toProjectTaskNo": "",
  "copyPlanningLines": false,
  "copyQuantity": false,
  "copyDimensions": false
}
```

- Deja `fromProjectTaskNo`/`toProjectTaskNo` vacíos para copiar todas las tareas del proyecto origen.
- `copyPlanningLines: false` copia solo la estructura de tareas (número, descripción, fechas), sin generar líneas de planificación/presupuesto.
- `copyPlanningLines: true` además copia las Job Planning Line del origen (ajusta `copyQuantity`/`copyDimensions` según el caso).

### 4. Desde Power Automate

El [conector "Dynamics 365 Business Central"](https://learn.microsoft.com/connectors/dynamicssmbsaas/) soporta APIs custom de forma nativa:

- **Get records (V3) / Find records (V3) / Get record (V3)**: para leer, con `API category = bh/bh/beta` y `Table name = <endpoint>` (ej. `projects`).
- **Create record (V3) / Update record (V3)**: para escribir.
- **Run action (V3)**: para invocar acciones bound como `copyProjectTasks` — selecciona `API category = bh/bh/beta`, `Action name = project-copyProjectTasks`, el `Id` del registro destino, y completa los parámetros dinámicos (`SourceProjectNo`, `CopyPlanningLines`, etc.).

## Desarrollo

No hay CLI de build — todo se hace desde VS Code con la extensión **AL Language**:

- **Compilar y publicar:** `Ctrl+Shift+P` → `AL: Publish` (o `F5`)
- **Descargar símbolos:** `Ctrl+Shift+P` → `AL: Download Symbols`

No hay tests unitarios; la validación se hace publicando al sandbox y probando los endpoints directamente (ver ejemplos arriba).

## Estructura del repositorio

```
src/
  Pages/           Páginas API (Pag601xx) y páginas internas de soporte
  Tables/          Tablas propias (Tab601xx)
  PermissionSets/  Permission sets propios (Per601xx)
releases/          Paquetes .app compilados (historial de versiones)
```

Los objetos usan el rango de IDs **60100–60149**. Ver [CLAUDE.md](CLAUDE.md) para el detalle de arquitectura y patrones de código de cada endpoint.

## Localización Colombia (D365LATAM)

Varios endpoints (Vendors, Productos) exponen campos con prefijo `D365L CO` provenientes de la dependencia **D365LATAM - Colombia Localization**: tipo de contribuyente DIAN, responsabilidad tributaria, grupos de impuesto, etc.

## Documentación

Documentación técnica detallada por entrega, en `docs/tecnica/` (Markdown) con su equivalente en PDF en `docs/pdf/`:

| Fecha | Documento | Tema |
|---|---|---|
| 2026-09-03 | [DOC-2026-09-03-origenes-lp](docs/tecnica/DOC-2026-09-03-origenes-lp.md) ([PDF](docs/pdf/DOC-2026-09-03-origenes-lp.pdf)) | Origenes LP API (60120): campo calculado `totalFob` |
