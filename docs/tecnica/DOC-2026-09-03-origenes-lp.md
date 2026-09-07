# Origenes LP API — cálculo de Total Fob

**Versión:** 1.0
**Fecha:** 2026-09-03
**Extensión:** BH - API (v1.2.0.8)
**Objeto documentado:** `page 60120 "Origenes LP API"` — endpoint `/bh/bh/beta/origenesLP`

## Resumen ejecutivo

Este endpoint expone la tabla `LyL OrigenLP` (80708), propiedad de la extensión externa **LyLVariantsExt** (publisher L&L Consultores), que agrupa las líneas de un documento de venta por "origen" de compra del ítem (por ejemplo `INTERFACE USA`, `INTERFACE CH`, `INTERFACE KOR`, `SERVICIOS`). Lo usan las empresas del grupo que operan con LyLVariantsExt para el costeo FOB de sus cotizaciones/pedidos/facturas de venta con ítems importados.

El cambio documentado aquí agrega el campo calculado **`totalFob`**: el monto Total Fob agrupado por origen para el documento de venta consultado. Este monto no existe como campo persistido en `LyL OrigenLP` — se calcula al vuelo en cada lectura, replicando la lógica del reporte nativo de LyLVariantsExt "Reporte Costos - Multiplicadores y Origen" (`Report 80701 "LyLOrigenesRep"`).

También se corrige una imprecisión de documentación (no de código): el campo `Item."LyL OrigenLP"` (80702), que ya se usaba en el endpoint Productos (`Pag60106.items.al`), estaba catalogado en `CLAUDE.md` como campo de la localización D365LATAM. Es en realidad un campo de **LyLVariantsExt** (`tableextension "LyL ItemExt"`). Se corrigió en `CLAUDE.md`; no hay cambio de comportamiento.

## Objetos AL

| Tipo | ID | Nombre | Propósito |
|---|---|---|---|
| Page (API) | 60120 | `Origenes LP API` | Endpoint OData de solo consulta agregada por origen, con `totalFob` calculado. Objeto ya existente; esta entrega solo agrega el campo `totalFob` y su lógica. |

No se crean ni modifican tablas, tableextensions ni codeunits en este cambio — toda la lógica vive en un `local procedure` de la propia página.

**Dependencias externas involucradas (sin modificar):**

| Tabla / Campo | Extensión | Uso en el cálculo |
|---|---|---|
| `LyL OrigenLP` (80708) | LyLVariantsExt | `SourceTable` de la página. `Nombre` es la clave de agrupación; `SalesHeaderNo` identifica el documento. |
| `Item."LyL OrigenLP"` (field 80702, `tableextension "LyL ItemExt"`) | LyLVariantsExt | Clasifica cada ítem bajo un origen. Se lee vía `RecordRef.Field(80702)` (campo dinámico, igual patrón que `Pag60106.items.al`). |
| `Sales Line."LyLSalesPriceCal"` (field 80701, `tableextension "LyLSalesLineExt"`) | LyLVariantsExt | FOB unitario ya resuelto (válido tanto para ítems modo "Calculado" como "Fijo" — ver detalle abajo). Se lee vía `RecordRef.Field(80701)`. |
| `Item."LyL calculoLP"` (field 80703) | LyLVariantsExt | Referenciado solo en el comentario de diseño (no se lee en código): explica por qué no hace falta distinguir "Calculado" de "Fijo" al tomar `LyLSalesPriceCal`. |

## Endpoint de API

- **Entidad:** `origenLP`
- **EntitySetName:** `origenesLP`
- **Versión:** `bh/bh/beta`
- **Fuente:** `LyL OrigenLP` (tabla 80708, solo lectura efectiva de agregación — la tabla en sí admite lectura/escritura, `DelayedInsert = true`)
- **Clave OData:** `SystemId`

### Campos expuestos

| Campo OData | Origen | Tipo | Notas |
|---|---|---|---|
| `id` | `SystemId` | Guid | Solo lectura |
| `number` | `ID` | Integer | Solo lectura |
| `name` | `Nombre` | Text | Clave de agrupación por origen (ej. `INTERFACE USA`) |
| `logisticFactor` | `FactorLogistico` | Decimal | |
| `originRegion` | `RegionOrigen` | Code | `TableRelation` a `"LyL RegionesLP".Codigo` |
| `currencyCode` | `Moneda` | Code | `TableRelation` a `Currency.Code` |
| `orderNo` | `SalesHeaderNo` | Code[20] | No. de documento de venta (Cotización/Pedido/Factura), sin `TableRelation` |
| `orderLineNo` | `SalesLineNo` | Integer | |
| `itemNo` | `ItemNo` | Code | |
| `versionNo` | `VersionNo` | Integer | |
| `margin` | `Margen` | Decimal | |
| **`totalFob`** | **calculado** | **Decimal** | **Nuevo.** Solo lectura (`Editable = false`). Total Fob agrupado para `name` dentro del documento `orderNo`. No persiste en la tabla base. |

### Lógica de cálculo de `totalFob`

Implementada en `local procedure GetTotalFob()`, invocada desde `trigger OnAfterGetRecord()`:

1. Si `Rec.Nombre` está vacío, `totalFob = 0` (no hay agrupador que resolver).
2. Busca líneas de venta Tipo Artículo (`Sales Line.Type = Item`) con `"Document No." = Rec.SalesHeaderNo`, probando en orden **Cotización → Pedido → Factura** (`Sales Document Type` Quote, Order, Invoice) y quedándose con el **primer tipo de documento que tenga líneas** — no se suman los tres tipos entre sí. Esto es porque representan la misma venta en distintas etapas de su ciclo de vida: al convertir Cotización a Pedido, las líneas de Cotización se eliminan, así que nunca coexisten con datos para el mismo `No.` de documento.
3. Para cada línea encontrada, resuelve `Item."LyL OrigenLP"` (campo 80702) vía `RecordRef`/`FieldRef` y compara contra `Rec.Nombre`.
4. Si coincide, suma `Sales Line."LyLSalesPriceCal" (80701) × Sales Line.Quantity` al acumulador.
5. El resultado es `totalFob`.

**Por qué no se cruza contra `LyL ItemVariant`/`LyL ItemVariantDetails`:** `LyLSalesPriceCal` ya trae el FOB unitario resuelto para ambos modos de costeo del ítem (`Item."LyL calculoLP"` = "Calculado" o "Fijo"). Para ítems "Calculado", ese campo replica `LyL ItemVariant.PrecioFOB`; para ítems "Fijo" (sin fila en `LyL ItemVariant`), es la única fuente real de costo disponible. Cruzar contra esas tablas sería redundante y rompería el cálculo para los ítems en modo "Fijo".

**Validación:** contra datos reales de producción (2026-09-02), cotización C03980 — orígenes `INTERFACE CH`, `INTERFACE KOR`, `INTERFACE USA` (con y sin ítems "Fijo") y `SERVICIOS` — comparado exacto contra el "Reporte Costos - Multiplicadores y Origen" nativo de LyLVariantsExt (`Report 80701 "LyLOrigenesRep"`).

### Ejemplo de request/response OData

```http
GET /bh/bh/beta/companies(<companyId>)/origenesLP?$filter=orderNo eq 'C03980'
```

```json
{
  "value": [
    {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "number": 12,
      "name": "INTERFACE USA",
      "logisticFactor": 1.15,
      "originRegion": "USA",
      "currencyCode": "USD",
      "orderNo": "C03980",
      "orderLineNo": 10000,
      "itemNo": "",
      "versionNo": 1,
      "margin": 0.25,
      "totalFob": 4820.50
    }
  ]
}
```

> Nota: `totalFob` se recalcula en cada lectura (`OnAfterGetRecord`); no se puede filtrar ni ordenar por él vía OData `$filter`/`$orderby` porque no es un campo persistido de la fuente.

## Permisos requeridos

No hay cambios de permisos en esta entrega. El endpoint sigue requiriendo:

- Acceso de lectura a `LyL OrigenLP`, `Item`, `Sales Line` (cubierto por los permission sets estándar de LyLVariantsExt/BC ya asignados al usuario/aplicación integradora).
- No aplica el permission set propio `Per60100 "BH API - Objects"` — ese cubre únicamente tablas propias de esta extensión (`BH Budget Amount Buffer`, `BH Budget GL Account`), y `LyL OrigenLP` no es una tabla propia de BH - API.

## Instrucciones de uso / despliegue

1. Publicar la extensión BH - API (ya contiene este endpoint desde una versión previa) — este cambio no requiere republicar dependencias ni symbols nuevos, es lógica interna de la página existente.
2. No requiere migración de datos: `totalFob` se calcula en tiempo de lectura.
3. Al consumir desde Power Automate / integraciones externas, usar `$filter=orderNo eq '<No. Documento>'` para acotar resultados — sin ese filtro, `totalFob` se recalcula fila por fila igual, pero cada fila corresponde a una combinación distinta de origen + documento, por lo que agregarlos por fuera del endpoint puede duplicar montos si un mismo origen aparece en más de un documento en el listado.

## Discrepancias diseño vs. código

No se identificó un diseño (`docs/diseños/DIS-*.md`) específico para este endpoint — la validación y las decisiones de implementación quedaron documentadas directamente como comentario en el código (`Pag60120.origenesLP.al`, líneas 90-108) y en `CLAUDE.md`. No hay discrepancia entre lo documentado y lo implementado: se leyó el código fuente y coincide exactamente con la descripción de este documento.

## Historial de cambios

| Fecha | Autor | Descripción |
|---|---|---|
| 2026-09-03 | Cristhian López | Documentación inicial del campo calculado `totalFob` en Origenes LP API (endpoint 60120), agregado y validado contra producción (cotización C03980, 2026-09-02). Corrige en `CLAUDE.md` la atribución del campo `Item."LyL OrigenLP"` (80702) de D365LATAM a LyLVariantsExt. |
