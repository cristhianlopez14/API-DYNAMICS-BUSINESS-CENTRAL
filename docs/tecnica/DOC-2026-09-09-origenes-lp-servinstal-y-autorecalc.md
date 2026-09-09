# Origenes LP API — exclusión de SERVINSTAL y recálculo automático al convertir Cotización a Pedido

**Versión:** 1.0
**Fecha:** 2026-09-09
**Extensión:** BH - API (v1.2.0.8)
**Objetos documentados:** `page 60120 "Origenes LP API"` (modificado) y `codeunit 60126 "BH LyL Origenes Convert Sync"` (nuevo)

## Resumen ejecutivo

Este documento cubre dos correcciones relacionadas sobre el campo calculado `totalFob` del endpoint `/bh/bh/beta/origenesLP`, documentado originalmente en [DOC-2026-09-03-origenes-lp.md](DOC-2026-09-03-origenes-lp.md). Ambas fueron encontradas y validadas contra datos reales de producción del mismo flujo de negocio: el costeo FOB por origen de compra que las empresas del grupo con **LyLVariantsExt** usan en sus cotizaciones/pedidos de venta, y que un flujo de Power Automate lee para llevar presupuesto FOB al Proyecto relacionado.

- **Cambio 1:** se excluye el ítem `SERVINSTAL` (Servicio de Instalación) del cálculo de `totalFob` para el origen `SERVICIOS`, replicando un comportamiento del "Reporte por Origenes" nativo de LyLVariantsExt que no tiene un campo consultable que lo explique.
- **Cambio 2:** se agrega `codeunit 60126 "BH LyL Origenes Convert Sync"`, que dispara automáticamente el recálculo de precios de LyLVariantsExt al convertir una Cotización de venta en Pedido, para que `totalFob` quede correcto en el Pedido nuevo sin intervención manual.

Ninguno de los dos cambios modifica el contrato OData del endpoint (mismos campos, misma entidad) — ambos afectan únicamente el **valor** que `totalFob` reporta en ciertos escenarios.

## Objetos AL

| Tipo | ID | Nombre | Propósito |
|---|---|---|---|
| Page (API) | 60120 | `Origenes LP API` | Modificado: `local procedure GetTotalFob()` ahora excluye explícitamente el ítem `SERVINSTAL` de la suma de `totalFob`. |
| Codeunit | 60126 | `BH LyL Origenes Convert Sync` | Nuevo. Event subscriber que dispara `CalculateSalesPrice` de LyLVariantsExt tras convertir Cotización en Pedido. |
| Permission Set | 60100 | `BH API - Objects` | Modificado: se agrega `codeunit "BH LyL Origenes Convert Sync" = X` a la lista de `Permissions`. |

No se crean ni modifican tablas ni tableextensions en esta entrega.

**Dependencias externas involucradas (sin modificar):**

| Objeto | Extensión | Uso |
|---|---|---|
| `Sales Line."LyLSalesPriceCal"` (field 80701) | LyLVariantsExt | Ya documentado en DOC-2026-09-03; ahora también relevante para entender por qué SERVINSTAL sí tiene datos aunque se excluya. |
| `Item."LyL calculoLP"` / `LyL ItemVariant.PrecioFOB` | LyLVariantsExt | Consultados en la investigación del Cambio 1 para descartar que fuera un problema de datos. |
| `Codeunit 80701 "LyLUnitPriceCalculation"`, procedure `CalculateSalesPrice(SalesHeaderNo: Code[20])` | LyLVariantsExt | Invocado por el Cambio 2. Referenciado directo por nombre (dependencia obligatoria en `app.json`, mismo patrón que las tablas de Multiplicadores LP/Origenes LP). |
| `Codeunit 86 "Sales-Quote to Order"`, evento `OnAfterOnRun` | Microsoft Base Application | Punto de enganche del Cambio 2. |
| `Report 80701 "LyLOrigenesRep"` ("Reporte por Origenes" / "Reporte Costos - Multiplicadores y Origen") | LyLVariantsExt | Comportamiento de referencia contra el que se validaron ambos cambios. |

## Cambio 1: exclusión de SERVINSTAL en el cálculo de `totalFob`

### Contexto previo

El endpoint `origenesLP` (page 60120) calcula `totalFob` sumando `Sales Line."LyLSalesPriceCal" × Quantity` para cada línea de venta Tipo Artículo cuyo `Item."LyL OrigenLP"` coincide con el origen consultado (`Rec.Nombre`). Esta lógica ya estaba documentada y validada contra la cotización C03980 (ver DOC-2026-09-03-origenes-lp.md).

### Hallazgo

Validado el 2026-09-07 contra la cotización **C04000**, origen `SERVICIOS`: el ítem `SERVINSTAL` (Servicio de Instalación, `Type = Service`) comparte `Item."LyL OrigenLP" = "SERVICIOS"` con `SERVTRANSP` (Servicio de Transporte, también `Type = Service`), pero el "Reporte por Origenes" nativo de LyLVariantsExt (`Report 80701 "LyLOrigenesRep"`) **no cuenta** las líneas de `SERVINSTAL` en el Total Fob de `SERVICIOS` — solo cuenta `SERVTRANSP`.

Se confirmó de forma concluyente borrando la línea de `SERVTRANSP` del documento: el reporte nativo pasó a dar Total Fob = 0 para `SERVICIOS`, mientras que las 3 líneas de `SERVINSTAL` seguían teniendo `Sales Line."LyLSalesPriceCal" > 0` (valores 11500.01, 9000.01, 7100.01, con cantidades 6, 6 y 7 respectivamente).

No es un dato corrupto: 2 de las 3 variantes de `SERVINSTAL` en `LyL ItemVariant` (campo `PrecioFOB`) tienen un valor real que coincide exacto con esos montos de `LyLSalesPriceCal` (11500.01 y 9000.01). La tercera variante (`0000011379`) no tenía registro en `LyL ItemVariant` en absoluto — pero eso tampoco explica por qué se excluyen las 3 líneas.

### Comparación exhaustiva

Se comparó `SERVINSTAL` contra `SERVTRANSP` en todos los campos consultables vía API/RecordRef, sin encontrar ninguno que distinga el caso:

| Campo | SERVINSTAL | SERVTRANSP |
|---|---|---|
| `Type` | Service | Service |
| `Item."LyL calculoLP"` | Calculado | Calculado |
| `itemCategoryCode` | SERVICIOS | SERVICIOS |
| `genProdPostingGroup` | SERVICIOS | SERVICIOS |
| `taxGroupCode` | V_SERVSGRAVADOS19% | V_SERVSGRAVADOS19% |

### Conclusión de negocio

FOB (Free On Board) es un costo de importación/logística. La instalación es mano de obra local post-importación, sin costo FOB por definición; el transporte, en cambio, sí es parte del costeo logístico de traer la mercancía. Se asume que la exclusión de `SERVINSTAL` es intencional en el trigger compilado del reporte nativo de LyLVariantsExt, al cual no se tiene acceso al código fuente.

### Fix aplicado

En `local procedure GetTotalFob()` (`Pag60120.origenesLP.al`), se agrega una exclusión explícita por número de ítem a la condición del `if` que suma al acumulador:

```al
if (ItemOrigenLP = Rec.Nombre) and (SalesLine."No." <> 'SERVINSTAL') then begin
    ...
    TotalFobLP += SalesPriceCal * SalesLine.Quantity;
end;
```

**Limitación conocida:** no existe otro campo disponible para distinguir el caso de forma genérica, así que el fix es un hardcode por número de ítem. Si en el futuro aparece otro ítem de "instalación" con un número distinto, o si LyLVariantsExt agrega un campo real que sí distinga el caso, este hardcode debe revisarse.

### Validación

Tras el fix, se probó contra dos documentos independientes — la cotización **C04000 versión 6** y el pedido de venta **P01414** resultante de convertirla — y los 8 orígenes de cada documento coincidieron exacto contra el "Reporte por Origenes" nativo, incluyendo `SERVICIOS`.

## Cambio 2: recálculo automático de LyL al convertir Cotización en Pedido

### Problema de negocio

Un flujo de Power Automate lee `totalFob` del endpoint `origenesLP` al convertir una Cotización de venta en Pedido, para llevar el presupuesto FOB al Proyecto relacionado. Al convertir Cotización→Pedido en Business Central, el Pedido resultante recibe un número de documento **nuevo** (de la serie de Pedidos; ej. `C04000` → `P01414`, no reutiliza el número de la cotización).

Se validó (2026-09-09, contra ese mismo par C04000/P01414) que **LyLVariantsExt no traslada ni recalcula automáticamente** los registros `LyL OrigenLP` (tabla 80708) ni el campo `Sales Line."LyLSalesPriceCal"` para el nuevo número de Pedido: `totalFob` daba 0 en los 8 orígenes del Pedido nuevo hasta que el usuario corría manualmente la acción **"Calcular Precios de Venta"** de LyLVariantsExt (menú "Ajustes Listas de Precios" de la ficha del Pedido). Esto rompía la automatización del flujo, que no puede depender de un clic manual antes de leer los datos.

### Investigación de causa raíz

Se extrajeron y analizaron los símbolos compilados (`SymbolReference.json`) del paquete `.app` de LyLVariantsExt (publisher L&L Consultores, sin código fuente disponible) para identificar el codeunit/procedimiento detrás del botón "Calcular Precios de Venta". Ese botón vive en `pageextension`s sobre las páginas estándar "Sales Order" y "Sales Quote" (`Pag-Ext80706.LyLSalesOrderExt.al` / `Pag-Ext80707.LyLSalesQuoteExt.al`), agrupado junto a "Ajustar Multiplicadores" y "Ajustar Origen" bajo el menú "Ajustes Listas de Precios".

La extensión solo tiene 3 codeunits en total, y el único procedimiento público cuyo nombre coincide con el caption del botón es `Codeunit 80701 "LyLUnitPriceCalculation".CalculateSalesPrice(SalesHeaderNo: Code[20])`.

No fue posible confirmar (sin código fuente del trigger del botón) si "Ajustar Multiplicadores"/"Ajustar Origen" llaman procedimientos adicionales no expuestos como públicos. Se decidió implementar la hipótesis más fundamentada (llamar solo a `CalculateSalesPrice`) y validarla empíricamente contra un documento real antes de darla por buena.

### Fix aplicado

`codeunit 60126 "BH LyL Origenes Convert Sync"` se suscribe al evento `OnAfterOnRun` de `Codeunit 86 "Sales-Quote to Order"` (Microsoft Base Application), que dispara al final de toda la conversión de Cotización a Pedido, con el Pedido ya insertado, sus líneas ya transferidas, y el parámetro `SalesOrderHeader` trayendo el número de documento definitivo del Pedido nuevo:

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Quote to Order", OnAfterOnRun, '', false, false)]
local procedure RecalculateLylOnAfterConvertToOrder(var SalesHeader: Record "Sales Header"; var SalesOrderHeader: Record "Sales Header")
begin
    LylUnitPriceCalculation.CalculateSalesPrice(SalesOrderHeader."No.");
end;
```

`LylUnitPriceCalculation` es una variable global `Codeunit LyLUnitPriceCalculation`, referenciada directo por nombre — mismo patrón usado para las tablas de LyLVariantsExt en Multiplicadores LP/Origenes LP, por tratarse de una dependencia obligatoria declarada en `app.json`.

### Validación

El usuario probó convirtiendo una cotización a pedido **sin tocar ningún botón manual** de LyLVariantsExt y confirmó que funcionó: el endpoint `origenesLP` quedó con los datos correctos automáticamente tras la conversión.

**Limitación conocida:** no se pudo verificar contra el código fuente de LyLVariantsExt que `CalculateSalesPrice` sea suficiente en todos los casos — por ejemplo, si "Ajustar Origen" hace algo adicional no cubierto en escenarios aún no probados. Si en el futuro se detecta un Pedido convertido con `totalFob` incorrecto pese a este subscriber, hay que investigar si hace falta replicar también el efecto de "Ajustar Origen", posiblemente contactando a L&L Consultores (proveedor de LyLVariantsExt) para pedir código fuente o documentación de esos tres botones.

## Endpoint de API

No hay cambios al contrato del endpoint `origenesLP` (mismo `EntityName`/`EntitySetName`/campos que en DOC-2026-09-03-origenes-lp.md). Ambos cambios de esta entrega afectan únicamente el **valor** calculado de `totalFob` en tiempo de lectura:

- Para el origen `SERVICIOS`, `totalFob` ya no incluye las líneas de `SERVINSTAL`.
- Para un Pedido recién convertido desde Cotización, `totalFob` ahora refleja datos correctos sin requerir una acción manual previa en el cliente BC.

## Permisos requeridos

- Se agrega `codeunit "BH LyL Origenes Convert Sync" = X` a `permissionset 60100 "BH API - Objects"`. Es obligatorio: BC exige permiso `Execute` explícito sobre codeunits propios para que sus event subscribers corran para usuarios no-SUPER; sin él, la conversión Cotización→Pedido falla con "Su licencia no le concede los siguientes permisos... Execute".
- El Cambio 1 (exclusión de SERVINSTAL) no requiere cambios de permisos — es lógica interna de una página API ya cubierta por los permisos estándar sobre `Sales Line`/`Item`.
- Cualquier usuario o cuenta de servicio con permiso para ejecutar la acción estándar "Convertir en pedido" sobre Cotizaciones debe tener asignado (directa o indirectamente) el permission set `BH API - Objects` para que el recálculo automático no falle.

## Instrucciones de uso / despliegue

1. Publicar la extensión BH - API con la versión actualizada de `Per60100.bhApiObjects.al` y el nuevo `Cod60126.lylOrigenesConvertSync.al` — requiere republicar el paquete completo (nuevo objeto codeunit + cambio de permission set), no es solo lógica interna de una página existente.
2. Verificar que los usuarios/cuentas de servicio que convierten Cotizaciones en Pedidos tengan asignado el permission set `BH API - Objects` (o uno que incluya `codeunit "BH LyL Origenes Convert Sync" = X`).
3. No requiere migración de datos ni republicar dependencias (`LyLVariantsExt` sigue siendo la misma versión ya declarada en `app.json`).
4. Para el flujo de Power Automate que consume `totalFob` tras convertir Cotización→Pedido: ya no es necesario esperar ni disparar manualmente "Calcular Precios de Venta" antes de leer el endpoint — el recálculo ocurre de forma síncrona dentro de la misma transacción de conversión.
5. Al consumir `origenesLP` para el origen `SERVICIOS`, tener en cuenta que `totalFob` excluye intencionalmente `SERVINSTAL` — no es un dato faltante.

## Discrepancias diseño vs. código

No se identificó un diseño (`docs/diseños/DIS-*.md`) específico para ninguno de los dos cambios — las decisiones de implementación e investigación quedaron documentadas directamente como comentarios en el código (`Pag60120.origenesLP.al`, comentario sobre `GetTotalFob()`; `Cod60126.lylOrigenesConvertSync.al`, comentario de cabecera del codeunit) y reflejadas en `CLAUDE.md`. No hay discrepancia entre lo documentado aquí y lo implementado: se leyó el código fuente publicado y coincide exactamente con la descripción de este documento.

Ambos cambios comparten una misma limitación estructural: dependen de comportamiento no documentado de una extensión de terceros (LyLVariantsExt) inferido por comparación empírica de datos y análisis de símbolos compilados, sin acceso a su código fuente. Se señala explícitamente en cada sección para que futuras revisiones sepan qué validar si LyLVariantsExt cambia de versión.

## Historial de cambios

| Fecha | Autor | Descripción |
|---|---|---|
| 2026-09-09 | Cristhian López | Documentación de dos correcciones sobre `totalFob` en Origenes LP API (endpoint 60120): (1) exclusión del ítem `SERVINSTAL` del cálculo para el origen `SERVICIOS`, validada contra cotización C04000 y pedido P01414 (2026-09-07/09); (2) nuevo `codeunit 60126 "BH LyL Origenes Convert Sync"` que dispara `CalculateSalesPrice` de LyLVariantsExt automáticamente al convertir Cotización en Pedido, agregado también a `Per60100.bhApiObjects.al`. |
