# DIS-2026-10-13 — Proyectos: tipo de línea en compras con proyecto (Cambio 1) y consumo de inventario diferido a la venta (Cambio 2)

| Campo | Valor |
|---|---|
| Fecha de la reunión | 2026-10-09 ("PROYECTOS - EZGO", prueba del flujo de compras con proyecto) |
| Elaborado | 2026-10-13 (bc-solution-architect) |
| Estado | **BORRADOR PARA APROBACIÓN. No implementar** hasta responder las preguntas bloqueantes de la sección 9 (en especial Q1, Q2, Q4, Q5 y Q6) y ejecutar el spike de la sección 7.2 |
| Entorno de verificación | Código fuente de `Microsoft_Base Application_28.4.53241.54676.app` (extraído de `.alpackages`, citas `Archivo : procedimiento (L<n>)`). `SandboxBHv2` = BC 28.4. Producción: versión exacta `[NO VERIFICADO]` |
| Audiencia | Cristhian (decisiones), `bc-implementer` (sección 7), `al-code-reviewer` (sección 8) |
| Relación con otros diseños | Continúa `DIS-2026-08-31-jobs-sales-integration.md` y `DIS-2026-09-14-jobs-invoice-posting-fixes.md` (lado ventas, ya implementado). **Choca en parte con `DIS-2026-10-06-jobs-compras-costo-real.md` (borrador sin implementar, sin trackear):** ver sección 3.4, este documento **reemplaza** sus mejoras 1 y 2 y sus IDs 60127-60133 se reutilizan |

**Etiquetas:** `[VERIFICADO]` leído en el código fuente 28.4 (o en este repo); `[NO VERIFICADO]` hay que probarlo en sandbox (sección 7.2 y 6); `[INFERIDO]` deducción sin prueba directa.

## Correspondencia con la estructura estándar de 8 secciones y con el entregable pedido

| Sección estándar | Dónde | Entregable pedido |
|---|---|---|
| 1 Requerimiento | 1 | — |
| 2 Supuestos y preguntas | 2 y 9 | 4 (preguntas) |
| 3 Análisis de lo existente | 3 | **1 Hallazgos del código** |
| 4 Solución propuesta | 4 (y 4.4 convivencia de flujos) | **2 Diseño por cambio** |
| 5 Especificación técnica | 5 | 2 |
| 6 Plan de implementación | 7 | **5 Qué entregar a bc-implementer** |
| 7 Criterios de aceptación y pruebas | 6 | **4 Plan de pruebas** |
| 8 Riesgos | 8 (y 4.5 impacto en costos/WIP/inventario/reporte) | **3 Impacto** · 4 · 5 (al-code-reviewer) |

---

## 1. Requerimiento

**Cambio 1.** En una línea de compra (pedido, factura, y lo que de ellas derive) que lleva `Job No.` + `Job Task No.`, el "tipo de línea de proyecto" debe quedar en **Facturable** por defecto y de forma obligatoria. Un usuario normal no puede cambiarlo; solo el usuario de Cristhian o quien tenga un permission set específico que él administre. Objetivo declarado: una compra real solo afecta el "real" del proyecto, **nunca el presupuesto**.

**Cambio 2.** La factura de compra con proyecto hoy genera movimiento de compra **más** un ajuste negativo de inventario (consumo). Debe generar **solo** el movimiento de compra. La salida de inventario debe nacer solo al registrar la factura de venta con proyecto (ya implementado en `Cod60123`: allí no se hace ajuste positivo). Razón de negocio: el inventario permanece en almacén hasta facturar al cliente, con una sola factura desde el pedido de venta, no una por línea consumida.

**Punto crítico.** Puede chocar con el "Flujo A" ya definido (compra con proyecto = Compra +1 y Ajuste negativo −1, para gastos no facturables al cliente, p. ej. tornillería adicional). Hay que decidir si conviven y cómo se distinguen, y compararlo con el "Flujo B" (compra sin proyecto a inventario; venta con proyecto desde la factura de venta).

## 2. Supuestos y preguntas abiertas

**Supuestos (se corrigen si la sección 9 dice otra cosa):**

- S-1. "Tipo de línea de planificación Facturable" = campo `Job Line Type` (campo 1002) de `Purchase Line`, valor `Billable`. `[VERIFICADO]` el enum tiene `" "`, Budget, Billable, Both Budget and Billable.
- S-2. "Movimiento de compra" = `Item Ledger Entry` tipo Compra. Si además se espera que el **costo real** aparezca en el proyecto (`Job Ledger Entry` tipo Consumo) al registrar la compra, es la decisión Q2 (la más importante de este documento).
- S-3. "Ajuste negativo" = `Item Ledger Entry` `Entry Type = Negative Adjmt.` con `Job No.` que BC genera al registrar una línea de compra con proyecto. `[VERIFICADO]` (3.1).
- S-4. La salida de inventario en la venta es el `Item Ledger Entry` tipo **Venta** que ya genera `Cod60123` (`RestoreItemPostingForJobContractLine`), no un "ajuste negativo". Hay que confirmar que contabilidad espera "Venta" y no "Ajuste" (Q8).
- S-5. Multiempresa: aplica a las 4 empresas del grupo (EZGO, Laboratorio WR, Nueva Vansolix, Casa La Mantilla), con interruptor por empresa, apagado por defecto.
- S-6. La extensión "Proyecto Obligatorio en Compras" (Codeunit 50100) **no está disponible como código fuente** (3.5). Se diseña sin depender de ella y se pide su fuente (Q6).
- S-7. El presupuesto del proyecto sale de la cotización comercial (líneas de planificación Presupuesto, creadas por flujo de Power Automate vía `projectLines`), como en el diseño del 2026-10-06.

---

## 3. Análisis de lo existente (entregable 1: hallazgos del código actual)

### 3.1 Qué hace BC hoy al registrar una línea de compra con proyecto `[VERIFICADO 28.4]`

**Recepción y factura de un Producto con `Job No.`:**

1. `Purch.-Post : PostItemJnlLine` (L1548-1574) llama a `PostItemJnlLineJobConsumption` siempre que `PurchLine."Job No." <> ''` (antes de la compra si es devolución, después si no).
2. `PostItemJnlLineJobConsumption` (L5889-5950) toma el Item Journal Line de la compra y lo convierte en consumo: `Entry Type := Negative Adjmt.`, `Source Type := Customer`, `Source No. := Job."Bill-to Customer No."`, y lo registra con `RunItemJnlPostLineWithReservation` (**ajuste negativo, a la recepción y/o a la factura**). Después, si `QtyToBeInvoiced <> 0`, llama a `PrepareJobLine` (L5948), que desemboca en `Job Post-Line : PostJobOnPurchaseLine`.
3. El ILE de la compra nace con `Job No.`, `Job Task No.` y `"Job Purchase" = true` (`ItemJournalLine.Table.al : CopyFromPurchLine`, L2799-2801; `ItemJnlPostLine : ILE."Job Purchase"`, L2018). El ILE de consumo se aplica específicamente a ese ILE de compra (`ItemJnlPostLine : SetFilter ... "Job Purchase"`, L1727-1731).

**El `Job Ledger Entry` (JLE) de un Producto no es independiente del ajuste negativo (hallazgo clave):**

4. `Job Jnl.-Post Line : PostItem` (L406-500): como el job journal line viene con `"Job Posting Only" = true` (`PostJobOnPurchaseLine`, L396-405), **no** vuelve a mover inventario; busca el **Value Entry del consumo ya registrado** (`GetJobConsumptionValueEntry`, L673) y crea el JLE desde ese Value Entry (`CreateJobLedgEntryFromPostItem`, L483-495; la cantidad es `-ValueEntry."Invoiced Quantity"`). **Si no existe el ajuste negativo, `PostItem` no crea ningún JLE.**
5. Para líneas **Cuenta C/G** (`G/L Account`) no hay ILE: el JLE se crea directo (`PostGLAccICLine`, `PurchPost` L1244-1252 → `PostJobPurchaseLines`, `JobPostLine` L496-519). No les afecta el Cambio 2.
6. Líneas Cargo (Item Charge), Activo fijo y Recurso: `PostJobOnPurchaseLine` descarta todo lo que no sea Producto o Cuenta C/G (`ShouldSkipLine`, L376-379). `[VERIFICADO]` (coincide con H3 del diseño 2026-10-06). **No existe tipo Recurso en `Purchase Line`**: los recursos viven en el Diario de Proyecto y en líneas de planificación, no en compras.

**Costo del JLE:** `Job Transfer Line : FromPurchaseLineToJnlLine` (L655-690): el `Unit Cost` sale de la línea de compra, **salvo** artículos con `Inventory Value Zero` (costo 0) o `Costing Method = Standard` (toma `Standard Cost`). El importe en moneda extranjera se convierte con el tipo de cambio de `PurchHeader."Posting Date"`. `[VERIFICADO]`

### 3.2 Qué hace BC con `Job Line Type` (hallazgo que invalida el supuesto del Cambio 1) `[VERIFICADO 28.4]`

| Situación al crear el JLE de consumo | Resultado nativo | Fuente |
|---|---|---|
| `Job Planning Line No. = 0`, Line Type **Facturable**, no hay JPL "Ambos" elegible | **BC crea una línea de planificación tipo "Ambos" (Presupuesto + Facturable) con el costo real.** Es decir, **sube el presupuesto** | `Job Link Usage : CreateJobPlanningLine` (L242-285; `Billable → "Both Budget and Billable"` en L255-256) |
| Idem con Line Type **Presupuesto** | Crea una JPL Presupuesto con el costo real (presupuesto = real) | misma rutina, `Line Type ' ' → Budget` L252-254; `Job Post-Line : InsertPlLineFromLedgEntry` L50-74 |
| Idem con Line Type en **blanco** | No crea JPL. Pide `Confirm()` ("el uso no se vinculará..."): aborta la API/Power Automate | `MatchUsageUnspecified` L50-70; `PurchPost : ValidateJobLineType` L8582-8598 |
| `Job Planning Line No. <> 0` | Solo acepta JPL con `Usage Link = true`, y una JPL Facturable pura **no puede** tener Usage Link. El tipo de la línea de compra lo pone BC desde la JPL | `Purchase Line : "Job Planning Line No." OnValidate` L2511-2545 (asignación en L2539); `Job Planning Line : "Usage Link" OnValidate` L1053-1061 |
| Con vínculo y cantidad total > cantidad de la JPL | BC **sube la cantidad (y el presupuesto)** de la JPL | `JobLinkUsage : HandleMatchUsageSpecifiedJobPlanningLine` (L149-155 del archivo 28.4: `Validate(Quantity ...)`) |

**Conclusión:** forzar `Facturable` tal cual **no** logra el objetivo "nunca el presupuesto". En el flujo nativo una compra Facturable **sin** vínculo crea una JPL "Ambos" (infla presupuesto y además queda como línea facturable al cliente); y **con** vínculo no es posible porque la JPL Facturable pura no admite Usage Link. Esta es muy probablemente una de las causas de que "el informe real vs presupuesto no cuadre" (4.5 y 6.3). Para lograr el objetivo hay que **cortar el enlace de uso** además de poner el tipo (sección 4.1, evento `OnBeforeApplyUsageLink`, `Job Jnl.-Post Line` L357-373).

Hechos que sí ayudan: `Job Line Type` **no tiene valor por defecto**; se llena por digitación, por asignación interna del vínculo, por `TransferSavedJobFields` (cambio de proveedor) o por "Obtener líneas de recepción" (copia de la línea de la **orden**, `PurchRcptLine.Table.al : CopyFromPurchRcptLine` L1033). Con `Job Task No.` en blanco, BC lo pone en `" "` (L2178-2182 del borrador de 28.4: `"Job Line Type" := " "`).

### 3.3 Herencia pedido → recepción → factura y qué pasa si cambian o borran el proyecto `[VERIFICADO]`

| Paso | Qué ocurre con `Job No.` / `Job Task No.` / `Job Line Type` |
|---|---|
| Pedido de compra | Los 3 campos están en `Purchase Line`. `Job No.` y `Job Task No.` se validan con `TestStatusOpen`, `TestField("Receipt No.", '')` y, en Pedido, `TestField("Quantity Received", 0)` (L1134-1141 y L2154-2170) |
| Recepción | `Purch. Rcpt. Line` guarda copia de los campos de proyecto (campos 45, 1001, 1002, 1019...) |
| Factura con "Obtener líneas de recepción" | Copia los campos de la **línea de la orden**, no de la recepción (`CopyFromPurchRcptLine`, L1033: `PurchLine := PurchOrderLine`). Como la línea queda con `Receipt No. <> ''`, **`Job No.`/`Job Task No.` quedan bloqueados** en la factura |
| Factura directa (sin orden) | Los campos son editables mientras no haya recepción |
| Usuario **cambia** `Job Task No.` | Pone `Job Planning Line No. = 0`; **no** limpia `Job Line Type` (solo se limpia cuando la tarea queda en blanco). Bloqueado tras recibir (Pedido) |
| Usuario **borra** `Job No.` | `InitJobFields` limpia tarea y JPL (L4465-4478); `Job Line Type` queda en `" "`. La línea pasa a ser compra "a stock" |
| Usuario **borra la tarea** | `Job Line Type := " "`; el posteo falla con `TestPurchLineJob` (`TestField("Job Task No.")`, L2663-2674) si `Job No.` sigue lleno |
| Copiar documento / Cambio de proveedor / API de Excel | Pueden dejar `Job Line Type` en cualquier valor sin pasar por `Validate` de campo: por eso la regla debe vivir también en el **posteo** |

### 3.4 Objetos propios y diseños previos relacionados (este repo)

| Objeto / documento | Relación con este diseño |
|---|---|
| `codeunit 60123 "BH Sales Job Planning Mgt."` (`src/Codeunits/Cod60123.salesJobPlanningMgt.al`, SingleInstance) | Lado **ventas** (Factura con proyecto): crea JPL Facturable oculta (`"BH Auto-Created From Sales"`), restaura el ILE de venta (`RestoreItemPostingForJobContractLine`, L559-580) y estampa `Job No.`/`Job Task No.` en el ILE. **No toca compras. No cambia con este diseño.** Es el punto donde "nace la salida de inventario" en el Flujo B |
| `src/PageExtensions/Pag60125.salesInvoiceSubformExt.al` | Solo Factura de venta (el Pedido de venta se retiró el 2026-09-14). Ver Q5 |
| `Pag60117 purchaseInvoiceLines` (BH-API) | **No expone** ningún campo de proyecto: una línea creada por API (Power Automate) nunca lleva proyecto hoy. No hay riesgo de bypass por esta API mientras no se agreguen los campos |
| `Pag60114 projectLines` | Crea JPL por API; no expone `Usage Link` ni `Line Type` de compras |
| `Per60100` | Único permission set; hoy solo cubre las 2 tablas propias y los codeunits 60123/60126 |
| `DIS-2026-10-06-jobs-compras-costo-real.md` | **Borrador sin implementar** (nada en `src/`; `git status` lo marca sin trackear). Sus mejoras 1 y 2 exigían un vínculo **obligatorio a una JPL Presupuesto** (Usage Link) y `Job Line Type` derivado de la JPL. **El Cambio 1 de la reunión del 9-oct lo contradice** (tipo Facturable, sin vínculo). Este documento lo sustituye; si se aprueba, conviene actualizar el diseño del 6-oct: mejoras 1, 2 (guard de cantidad) y la página 60138 que mide el real por JPL (`Posted Total Cost`) dejan de aplicar en líneas sin vínculo (se mide por JLE) |
| IDs | `app.json`: rango 60100-60149. El diseño del 6-oct ya **asignó los 26 IDs libres** (60101, 60102, 60124, 60127-60149) en papel. Aquí se **reutilizan** los IDs 60127, 60128, 60129, 60131 y 60149 y se usa el reservado 60135; y se pide ampliar `idRanges` (sección 5.1) |

### 3.5 Extensión "Proyecto Obligatorio en Compras" (Codeunit 50100): dónde está

Busqué en este repo y en las carpetas hermanas y no existe código fuente:

| Ubicación | Resultado |
|---|---|
| Este repo (`src/`, `docs/`, historial git) | Cero objetos 50100. Solo documentos que la mencionan |
| `C:\Users\Cristhian López\Documents\AL\GeneratedProject1` | `app.json` con rango **50100-50149**, publisher `Default Publisher`, dependencia `D365LATAM Recepción Documentos 1.0.0.64`, `.snapshots` (Snapshot Debugger), **sin ningún archivo `.al`**. Es el único rastro; parece un proyecto de depuración |
| `...\Documents\AL\ALProject1`, `ALTablaProduccionBH` (50800-50849), `InformeInventarioBH` (60150-60199) | Sin objetos 50100-50149 |
| `...\OneDrive - ezgosa.com\2026\DESARROLLOS\CRM` (rango 50100-50199) | Codeunits 50110-50114 (BH Lead); **ningún 50100**. Ojo: su rango **incluye** 50100, riesgo de colisión si el 50100 existe como extensión instalada |
| Resto de OneDrive/Desktop/Downloads | Sin `.al` con "Proyecto Obligatorio" |

`DIS-2026-08-31` (Pregunta 1, cerrada el 2026-09-01) ya concluyó que no existe en ningún repositorio ni entorno revisado. **Hallazgo:** si la extensión existe hoy en el tenant (como PTE instalada o solo publicada sin repositorio), **su código no es verificable desde aquí**. Consecuencias: (a) no se sabe qué eventos suscribe ni si choca con estas reglas; (b) bloquear "líneas de costo sin Job No." choca de frente con el Cambio 2 si el inventario comprado "para el proyecto" luego se retiene en stock (Flujo B); (c) hay que obtener el fuente (Extensiones instaladas → Descargar fuente, o `GeneratedProject1` con símbolos) antes de implementar (Q6).

---

## 4. Solución propuesta

### 4.1 Cambio 1: tipo de línea Facturable por defecto y bloqueado

**Hallazgo que reorienta el cambio:** poner el campo en Facturable no basta (3.2). La solución tiene dos piezas inseparables: (A) el campo queda en Facturable y protegido; (B) los JLE nacidos de esas líneas **no se enlazan ni crean líneas de planificación** (así el presupuesto nunca se toca).

**Opciones**

| Opción | Descripción | Pros | Contras |
|---|---|---|---|
| **1A. Solo campo (literal)** | Forzar `Job Line Type = Billable` y bloquearlo | Cero lógica de posteo | **No cumple el objetivo:** crea JPL "Ambos" (infla presupuesto y crea una línea facturable). Descartada |
| **1B. Facturable + corte del enlace de uso (recomendada)** | Campo Facturable/bloqueado **y** un marcador en el job journal line que hace `IsHandled := true` en `OnBeforeApplyUsageLink`. El JLE de consumo se crea y **no** se vincula ni crea JPL | Cumple "solo afecta el real"; usa un evento nativo pequeño; el informe Actual-to-Budget no depende del Usage Link (agrupa JLE y JPL por tarea/tipo/No., `JobDifferenceBuffer.Table.al`) | El real **no** actualiza `Qty. Posted`/`Posted Total Cost` de ninguna JPL (se mide por JLE, no por línea de planificación). Si se necesita real por línea de presupuesto, usar 1C |
| **1C. Vínculo obligatorio a JPL Presupuesto** (diseño 6-oct, mejoras 1-2) | El tipo lo dicta la JPL (Presupuesto/Ambos) y la compra se enlaza a una JPL existente | Real **por línea** de presupuesto en la propia JPL; no crea JPL nuevas | **Contradice el requerimiento** (tipo Facturable); exige que toda compra tenga JPL presupuestada; el exceso de cantidad **sube el presupuesto** (H14 del diseño del 6-oct) salvo guard adicional; más trabajo operativo |

**Recomendación: 1B.** Es la forma más simple de cumplir literalmente lo pedido (tipo Facturable, bloqueado) sin que el presupuesto se mueva. 1C queda como evolución si Costos pide real por línea (Q1).

**Quién puede modificarlo (permisos).** El patrón recomendado es **permiso sobre una tabla propia consultado con `Record.WritePermission()`**: la tabla `BH Job Rules Setup` (singleton por empresa). `Per60100` (que usan todos) concede solo `R`; el permission set nuevo `BH JOB OVERRIDES` concede `RIMD`. Un usuario "puede sobrescribir" si tiene `WritePermission` sobre la tabla. Cristhian administra quién tiene el set (asignación por empresa en BC). Limitación: los usuarios SUPER también pasan. Si se quiere "solo estos usuarios por nombre", se agrega un campo `Override User ID` (Q10).

**Qué hace cuando el usuario con permiso lo cambia.** El valor distinto de Facturable activa un indicador en la línea (`BH Rule Override = true`), con lo que (a) el posteo no lo bloquea y (b) el corte de enlace **no** aplica: se comporta como BC nativo (responsabilidad de quien lo cambió). Así el permiso es una válvula de escape real y auditable (`SystemModifiedBy`).

### 4.2 Cambio 2: la factura de compra con proyecto solo genera el movimiento de compra

**Qué hay que evitar.** En 3.1 el ajuste negativo es el mecanismo nativo de consumo. Para retener el inventario hay que **no registrar** ese ajuste (ni a la recepción ni a la factura) en las líneas marcadas "retener". Pero el JLE de Productos nace de ese ajuste (3.1 punto 4): suprimirlo suprime también el JLE, es decir, el "real" del Cambio 1.

**Opciones**

| Opción | Qué registra la compra con proyecto | Pros | Contras |
|---|---|---|---|
| **2A. Retener inventario + JLE analítico sin ILE (recomendada, sujeta al spike 7.2)** | ILE Compra (con `Job No.` para trazabilidad) y **JLE de consumo creado sin ILE** (Ledger Entry Type en blanco). El inventario sigue en almacén; el real del proyecto refleja la compra. En la venta, `Cod60123` hace ILE Venta + JLE Venta | Cumple Cambio 1 y 2 a la vez; reutiliza `PostJobOnPurchaseLine` (API pública) y 4 eventos nativos | Se interviene el posteo de compras con eventos (3 puntos); el JLE no se reajusta con "Adjust Cost" ni "Update Job Item Cost" (queda al costo de la factura); sin asiento contable "Job Costs Applied": **validar con Contabilidad** (Q7). Requiere spike |
| **2B. Retener inventario sin JLE** | Solo ILE Compra. El proyecto no ve costo hasta la venta (JLE Venta con snapshot de costo) | Cambio mínimo: solo `IsHandled := true` en un evento; sin JLE sin ILE | **Contradice "afecta el real"** (el proyecto queda sin costo real hasta vender) y empeora el informe real vs presupuesto en proyectos con compras sin vender |
| **2C. Política, sin código de posteo** | Las compras para stock **no llevan proyecto** (Flujo B puro). La regla de proyecto obligatorio se limita a líneas de consumo directo | El menos riesgoso técnicamente | Se pierde la trazabilidad compra → proyecto que pidió la reunión; depende de disciplina y de la extensión 50100 (desconocida) |

**Recomendación: 2A**, condicionada a que el spike (7.2) confirme que BC acepta un JLE de Producto creado sin ILE sin romper el posteo, la cancelación (nota de crédito) ni los reportes. Si el spike falla: **2B** (y se acepta que el real llega al vender) o **2C**. Antes de elegir, responder Q2.

### 4.3 Convivencia con el Flujo A (entregable "punto crítico")

**Flujos (definiciones usadas):**

| | Flujo A (consumo en la compra) | Flujo B (compra a stock, venta con proyecto) | Nuevo "A-retenido" (Cambio 2) |
|---|---|---|---|
| Compra | Con `Job No.`; ILE Compra **+ ILE Ajuste negativo (−1)** | **Sin** `Job No.`; ILE Compra | Con `Job No.`; ILE Compra (con `Job No.`); **sin** ajuste negativo |
| JLE al comprar | Consumo, desde el ajuste | **Ninguno** | Consumo analítico, sin ILE (opción 2A) |
| Salida de inventario | En la compra (ajuste negativo) | En la factura de venta (ILE Venta, `Cod60123`) | En la factura de venta (ILE Venta, `Cod60123`) |
| Real en el proyecto | Al registrar la factura de compra | Solo el snapshot de costo del JLE Venta | Al registrar la factura de compra |
| Uso típico | Gasto del proyecto no facturable al cliente (tornillería extra) | Compra normal de inventario, regla "una compra no lleva proyecto" | Compra de mercancía que se venderá luego al cliente del proyecto |

**Cómo se distinguen A y A-retenido.** Opciones:

| # | Discriminador | Pros | Contras |
|---|---|---|---|
| D1 | **Campo nuevo en la línea de compra** `BH Job Cost Treatment` (Retener en inventario / Consumir en la compra) | Explícito, auditable, por línea; la tornillería y la mercancía pueden convivir en el mismo documento; independiente de `Job Line Type`; lo pueden leer reportes | Un campo más que capturar (se llena por defecto) |
| D2 | Reutilizar `Job Line Type` (Facturable = retener, Presupuesto = consumir) | Cero campos nuevos | Sobrecarga el significado (el campo ya es "obligatorio Facturable y bloqueado"); un valor distinto a Facturable **crearía presupuesto** (3.2). Descartada |
| D3 | Atributo del **Artículo** (`BH Consume On Purchase`) | Automático para tornillería | Rígido: el mismo artículo puede ser mercancía en un proyecto y gasto en otro; mantenimiento de datos |
| D4 | Tipo de artículo / categoría | Sin campos | El tornillo es inventariable igual que la mercancía; no distingue |
| D5 | **Concepto de la tarea** (diseño 6-oct: 1000 Mercancía vs 3000 Gastos) | Sin campo por línea; coherente con la estructura por concepto | Depende de que exista y esté poblado `BH Concept` (otro diseño sin aprobar); proyectos existentes no lo tienen |

**Recomendación: D1**, con valor por defecto **Retener** para Productos inventariables con proyecto (y `No aplica` para cuentas C/G, servicios y no inventariables: no hay inventario que retener). El valor **Consumir en la compra** se reserva al mismo permission set de override (Q4): así las excepciones tipo tornillería pasan por Cristhian o por quien él autorice. Evolución posible: D3 como **valor por defecto** del campo (no como regla), y D5 cuando exista el concepto de tarea. **Ambos flujos conviven**: el Flujo A sigue existiendo con comportamiento nativo (ajuste negativo + JLE), solo se le aplica el corte del enlace de uso (4.1) para que tampoco infle presupuesto.

**Comparación con Flujo B.** B no necesita código de compras (la compra no lleva proyecto) pero deja el proyecto **sin costo real** hasta que se factura la venta. A-retenido (2A) añade trazabilidad y real inmediato, a costa de intervenir el posteo de compras. Si el negocio acepta que el real llegue al vender, **B + política "las compras a stock no llevan proyecto" (2C) es la solución más simple** y no requiere el spike. Esto es la decisión Q2.

### 4.4 Qué pasa en cada documento (resumen con las opciones recomendadas: 1B + 2A + D1)

| Paso | Qué se registra |
|---|---|
| Teclear proyecto y tarea en la línea del pedido/factura | `Job Line Type := Facturable` (obligatorio, bloqueado); `BH Job Cost Treatment := Retener` (Producto inventariable) |
| Recibir el pedido | ILE Compra (con `Job No.`, `Job Task No.`). **Sin** ajuste negativo. Sin JLE (el JLE nace al facturar, como hoy) |
| Facturar la compra | Value entry de la compra; **JLE de consumo** (Facturable, sin enlace a JPL, sin ILE). Presupuesto intacto |
| Pedido/Factura de venta con proyecto (ya existe) | JPL oculta Facturable → JLE Venta + **ILE Venta** (aquí sale el inventario) |
| Nota de crédito / devolución de compra | Mismas reglas; ver caso borde 5.5 (documentos históricos con ajuste negativo ya registrado) |

### 4.5 Impacto en costos reales, WIP, inventario y en el informe real vs presupuesto (entregable 3)

| Área | Hoy | Con 1B + 2A | Observación |
|---|---|---|---|
| JLE de consumo (real) | Nace del ajuste negativo, al facturar; el Line Type que traiga puede crear JPL | Nace al facturar, **sin enlace**; Line Type Facturable; sin ILE | El real por línea de JPL (`Qty. Posted`, `Posted Total Cost`) **no se actualiza** (1B) |
| Presupuesto (JPL con `Schedule Line`) | Puede subir por JPL "Ambos"/Presupuesto auto-creadas y por exceso de cantidad en líneas vinculadas | **No cambia** por compras | Las JPL auto-creadas **ya existentes** no se limpian (diagnóstico en 6.3) |
| Inventario | Sale en la compra (ajuste negativo) | Permanece hasta la venta; sale como ILE **Venta** | El ILE Compra queda con `Job No.` y `"Job Purchase" = true`: `[NO VERIFICADO]` su efecto en disponibilidad y costeo (prueba N-8) |
| Contabilidad (G/L) | Ajuste negativo con `Job No.` postea el consumo del inventario | Compra: Inventario/CxP. Venta: COGS por el ILE Venta | JLE analítico sin asiento: **Contabilidad debe validar** que la cuenta "costo de proyecto aplicado" y el WIP no queden descuadrados (Q7). `[NO VERIFICADO]` |
| WIP | El costo (`Usage`) entra a WIP al facturar la compra | Igual en el momento (al facturar la compra), pero el costo ya no tiene contrapartida en el asiento de consumo | El método WIP (Cost Value/POC) lee JLE y JPL, no asientos: `JobCalculateWIP` no cambia, pero **el asiento de WIP a G/L** debe probarse (N-12) |
| Costeo | Adjust Cost reescribe el costo del JLE vía el ILE de consumo (`Update Job Item Cost`) | El JLE queda al costo de la **factura de compra** (no se reajusta). `UpdateJobItemCost` lo ignora (no tiene ILE: `Ledger Entry No.` vacío) | Costos adicionales por Cargo de producto no llegan al JLE (ya era así en Flujo B). Artículos Standard: el JLE toma `Standard Cost` |
| Moneda extranjera (USD) | JLE en moneda del proyecto/LCY con tipo de cambio de la fecha de registro | Igual; `TestField("Job Currency Code", Job."Currency Code")` sigue activo | El costo del JLE usa el tipo de cambio de la fecha de factura; el ILE usa el costo final; pueden diferir centavos (prueba N-6) |

**Por qué el informe real vs presupuesto hoy no cuadra (hipótesis a verificar, en orden de probabilidad)**

1. **JPL auto-creadas por compras.** Compras con `Line Type` Facturable/Presupuesto sin vínculo crean JPL "Ambos"/Presupuesto con el costo real (3.2): el "presupuesto" crece con cada compra y real = presupuesto en esas líneas. *Verificar:* Líneas de planificación del proyecto con `Schedule Line` y que **no** vienen de la cotización (buscar por `Usage Link = true` + existencia de `Job Usage Link` + `SystemCreatedAt` posterior a la cotización).
2. **JPL ocultas de ventas** (`"BH Auto-Created From Sales"`, `Cod60123`) entran en el total de contrato; no son presupuesto pero distorsionan columnas de precio.
3. **JLE de consumo sin JPL por tarea/artículo** (agrupación por Tarea+Tipo+No.+Almacén+Variante+UM en `JobDifferenceBuffer`): real y presupuesto aparecen en renglones distintos.
4. **Costeo Standard** o `Inventory Value Zero`: el JLE no refleja el costo de la factura (3.1).
5. **Mezcla de monedas** (proyecto en USD, costos en LCY) y recepciones sin facturar (el real no aparece hasta facturar).
6. **JLE Venta** (snapshot de costo de la línea de venta) mezclado con consumo si el informe no filtra `Entry Type`.

Estas hipótesis se descartan con 3 consultas a las páginas estándar (JLE filtrado por `Entry Type`/`Line Type`, JPL filtrada por origen, y el informe Actual to Budget por tarea). **Este diseño corrige la causa 1** (y reduce la 3 al no crear JPL nuevas); no corrige las demás.

---

## 5. Especificación técnica (entregable 2)

### 5.1 Registro de objetos e IDs

Las IDs reutilizan las del diseño del 6-oct (que no está implementado). Se pide ampliar `app.json` `idRanges` con **60200-60249** (hoy 60100-60149 totalmente asignado en papel; 60150-60199 es de `InformeInventarioBH`; 50100-50199 de CRM/otros): **Q13**.

| Tipo | ID | Nombre | Archivo propuesto | Propósito |
|---|---|---|---|---|
| table | 60127 | `BH Job Rules Setup` | `src/Tables/Tab60127.jobRulesSetup.al` | Singleton por empresa. Campos mínimos: `Primary Key` Code[10]; `Enforce Purchase Job Rules` Boolean (false); `Hold Inventory Until Sale` Boolean (false); `Rules Effective Date` Date. `procedure GetSetup()` = `if not Get() then Init()`; **nunca** `Insert` dentro de un posteo |
| page | 60128 | `BH Job Rules Setup` | `src/Pages/Pag60128.jobRulesSetup.al` | Ficha (Card, `UsageCategory = Administration`), ToolTips en español; acción "Normalizar líneas abiertas" (5.6) |
| enum | 60149 | `BH Job Cost Treatment` | `src/Enums/Enum60149.jobCostTreatment.al` | `" "` (No aplica), `Hold` (Retener en inventario hasta la venta), `Consume` (Consumir en la compra). `Extensible = false` |
| tableextension | 60131 | `BH Purchase Line Ext` | `src/TableExtensions/Tab60131.purchaseLineExt.al` | Campo 60101 `BH Job Cost Treatment` (enum 60149) y 60102 `BH Rule Override` Boolean. (El campo 60100 queda reservado al `BH Destination` del diseño del 6-oct) |
| tableextension | 60200 | `BH Job Journal Line Ext` | `src/TableExtensions/Tab60200.jobJournalLineExt.al` | Campos 60100 `BH Skip Usage Link` Boolean y 60101 `BH No Item Ledger` Boolean (marcadores). Viajan con el registro temporal que usa `Job Post-Line` |
| tableextension | 60201 | `BH Job Ledger Entry Ext` | `src/TableExtensions/Tab60201.jobLedgerEntryExt.al` | Campo 60100 `BH Cost Treatment` (enum 60149) copiado al JLE (`OnBeforeJobLedgEntryInsert`). Recomendado para reportes que separen Flujo A de A-retenido. Opcional en v1 |
| codeunit | 60129 | `BH Purchase Job Mgt.` | `src/Codeunits/Cod60129.purchaseJobMgt.al` | Todos los subscribers (5.3). **No necesita `SingleInstance`**: ninguna variable compartida entre eventos; los marcadores viajan en los **registros** (job journal line, línea de compra). Si un cambio futuro comparte estado entre subscribers, **debe** ser `SingleInstance` (lección del repo) |
| pageextension | 60132 | `BH Purch Inv Subform Ext` | `src/PageExtensions/Pag60132.purchInvSubformExt.al` | Sobre `Purch. Invoice Subform` (nombre exacto `[verificar en símbolos]`): `Job Line Type` y `BH Rule Override` no editables salvo permiso; muestra `BH Job Cost Treatment` |
| pageextension | 60133 | `BH Purch Order Subform Ext` | `src/PageExtensions/Pag60133.purchOrderSubformExt.al` | Idem en `Purchase Order Subform`; (nota de crédito y orden de devolución: ampliar si se usan, sección 5.5) |
| permissionset | 60135 | `BH JOB OVERRIDES` | `src/PermissionSets/Per60135.bhJobOverrides.al` | `tabledata "BH Job Rules Setup" = RIMD`. Este es el permiso que concede el derecho a cambiar el tipo de línea y el tratamiento. Lo administra Cristhian |

**`Per60100` (modificación, sin ID nuevo):** agregar `tabledata "BH Job Rules Setup" = R, table "BH Job Rules Setup" = X, page "BH Job Rules Setup" = X, codeunit "BH Purchase Job Mgt." = X`. Las `tableextension`/`pageextension`/`enum` **no** admiten entrada (AL0104/AL0301, ya documentado en `Per60100`). Sin la entrada del codeunit los subscribers no corren para usuarios no-SUPER (error de licencia/Execute, visto con `codeunit 60123`/`60126`). PTECop (`PTE0004`) exige que la tabla nueva tenga un permission set que la cubra: lo cumplen `Per60100` (R) y `BH JOB OVERRIDES` (RIMD).

### 5.2 Campos nuevos: reglas de captura

- `BH Job Cost Treatment` (Purchase Line, campo 60101): `OnValidate` propio. Reglas: solo aplica con `Job No. <> ''` y `Type = Item` con `Item.IsInventoriableType()`; cualquier otro caso fuerza `" "`. Valor `Consume` solo editable con `WritePermission` sobre `BH Job Rules Setup` (mismo permiso que el override). Bloqueado tras recibir (`TestField("Quantity Received", 0)` en Pedido, `Receipt No.` vacío) para no cambiar el criterio a mitad del ciclo.
- `BH Rule Override` (campo 60102): lo pone el subscriber cuando un usuario **con** permiso cambia `Job Line Type` o `Job Planning Line No.` a algo distinto del default. No editable por UI.

### 5.3 Subscribers en `codeunit 60129 "BH Purchase Job Mgt."` (firmas verificadas en 28.4)

Todos salen de inmediato si `BH Job Rules Setup."Enforce Purchase Job Rules" = false` (o si la fecha del documento es anterior a `Rules Effective Date`, 5.5).

| # | Publisher y evento (firma exacta) | Acción | Cambio |
|---|---|---|---|
| E1 | `Table "Purchase Line"`, `OnAfterValidateEvent` campo `'Job Task No.'` `(var Rec; var xRec; CurrFieldNo)` | Con `Job Task No. <> ''` y `Job Line Type = " "` → `Validate`-free assign `Rec."Job Line Type" := Billable`; calcula `BH Job Cost Treatment` por defecto (Hold si Producto inventariable y `Hold Inventory Until Sale`; si no, `" "`). Con tarea en blanco, BC ya limpia el tipo: se limpia también el tratamiento y `BH Rule Override` | 1, 2 |
| E2 | `Table "Purchase Line"`, `OnBeforeValidateEvent` `'Job Line Type'` `(var Rec; var xRec; CurrFieldNo)` | Si `CurrFieldNo = FieldNo("Job Line Type")` y no hay permiso → `Error("El tipo de línea de proyecto es Facturable y no se puede modificar.")` | 1 |
| E3 | `Table "Purchase Line"`, `OnAfterValidateEvent` `'Job Line Type'` | Si el usuario tiene permiso y el valor ≠ Facturable → `"BH Rule Override" := true`; si vuelve a Facturable → `false` | 1 |
| E4 | `Table "Purchase Line"`, `OnBeforeValidateEvent` `'Job Planning Line No.'` | Si `CurrFieldNo <> 0`, nuevo valor ≠ 0 y sin permiso → `Error`. Evita el bypass: BC asigna el tipo desde la JPL (L2539) y rompería la regla. Con permiso: `BH Rule Override := true` | 1 |
| E5 | `Codeunit "Purch.-Post"`, `OnAfterTestPurchLine(PurchHeader; PurchLine; WhseReceive; WhseShip)` (L9258) | Fase de validación **antes de cualquier asiento**: si `Job No. <> ''` → exige `Job Task No.`, `Job Line Type = Billable` y `Job Planning Line No. = 0`, salvo `BH Rule Override = true`. Cubre línea copiada, cambio de proveedor, edición por API/Excel con `CurrFieldNo = 0`. Aplica a recepción, factura, nota de crédito y devolución | 1 |
| E6 | `Codeunit "Release Purchase Document"`, `OnBeforeReleasePurchaseDoc(var PurchaseHeader; PreviewMode; var SkipCheckReleaseRestrictions; var IsHandled; SkipWhseRequestOperations)` | Aviso temprano con la misma validación (Order, Invoice, Credit Memo, Return Order). Salir si `PreviewMode` | 1 |
| E7 | `Codeunit "Purch.-Post"`, `OnPostItemJnlLineJobConsumption(PurchHeader; var PurchLine; ItemJournalLine; var TempPurchReservEntry; QtyToBeInvoiced; QtyToBeReceived; var TempTrackingSpecification; PurchItemLedgEntryNo; var IsHandled; var ItemJnlPostLine; var PurchInvHeader; var PurchCrMemoHeader; SrcCode)` (declaración L10317, llamada L5897) | Si la línea es `Hold` y no es override: `IsHandled := true` (**no se registra el ajuste negativo**, ni a la recepción ni a la factura, ni en devolución: el procedimiento se salta entero). Si `QtyToBeInvoiced <> 0`: `PurchLine."Qty. to Invoice" := QtyToBeInvoiced;` y `JobPostLine.PostJobOnPurchaseLine(PurchHeader; PurchInvHeader; PurchCrMemoHeader; PurchLine; SrcCode)` (procedimiento público, L365-415) para crear el JLE analítico (opción 2A). Con la opción 2B no se llama a `PostJobOnPurchaseLine` | 2 |
| E8 | `Codeunit "Job Post-Line"`, `OnPostJobOnPurchaseLineOnAfterJobTransferLineFromPurchaseLineToJnlLine(var PurchHeader; var PurchInvHeader; var PurchCrMemoHdr; PurchLine; var JobJnlLine)` (L709) | Pone marcadores en el job journal line: `BH Skip Usage Link := (PurchLine."Job Line Type" = Billable) and not "BH Rule Override"`; `BH No Item Ledger := (Treatment = Hold) and Type = Item`. Los marcadores viajan al registro temporal de las líneas C/G (`InsertTempJobJournalLine`) | 1, 2 |
| E9 | `Codeunit "Job Jnl.-Post Line"`, `OnCodeOnAfterCalcShouldPostUsage(var JobJournalLine2; var ShouldPostUsage; var JobLedgEntryNo)` (L907) | Si `BH No Item Ledger`: `ShouldPostUsage := false` → BC ejecuta `CreateJobLedgEntry(JobJnlLine2)` directo (L146-147), sin buscar Value Entry de consumo | 2 |
| E10 | `Codeunit "Job Jnl.-Post Line"`, `OnCreateJobLedgerEntryOnAfterAssignLedgerEntryTypeAndNo(var JobLedgEntry; JobJournalLine; GLEntryNo)` (L917) | Si `BH No Item Ledger`: `"Ledger Entry Type" := " "; "Ledger Entry No." := 0` (BC lo pone `Item` con número 0 para Productos, L330-335: evita un JLE con enlace roto) | 2 |
| E11 | `Codeunit "Job Jnl.-Post Line"`, `OnBeforeApplyUsageLink(var JobLedgerEntry; var JobJournalLine; var IsHandled)` (L837; llamada L360) | Si `BH Skip Usage Link`: `IsHandled := true` → no se llama a `ApplyUsage` ni a `InsertPlLineFromLedgEntry`: **no se crea ni se toca ninguna JPL** | 1 |
| E12 | `Codeunit "Job Jnl.-Post Line"`, `OnBeforeJobLedgEntryInsert(var JobLedgerEntry; JobJournalLine)` (L857) | Copia `BH Cost Treatment` al JLE (si se aprueba la tableextension 60201) | informe |

Notas de diseño:
- Los puntos E8-E11 comparten estado por el **registro** `Job Journal Line` (campos de la tableextension 60200), no por variables: no hace falta `SingleInstance`. `[VERIFICADO]` que `Job Jnl.-Post Line` copia `JobJnlLine2 := JobJnlLine` (L117-122) y que `PostJobPurchaseLines` reutiliza el registro temporal completo (L500-518).
- E7 con `IsHandled := true` salta **todo** `PostItemJnlLineJobConsumption`, incluida la validación `ValidateMatchingJobPlanningLine`: no hay diálogo `Confirm()` en el camino (con Facturable no se alcanzaba de todos modos).
- El **ILE de compra** conserva `Job No.`/`Job Task No.`/`"Job Purchase"`. No se modifica en v1 (decisión explícita; prueba N-8). Alternativa si N-8 muestra efectos adversos: `OnPostItemJnlLineOnAfterPrepareItemJnlLine(var ItemJournalLine; ...)` (L10327) y `ItemJournalLine."Job Purchase" := false` para líneas `Hold`.
- Con 1B y el campo Facturable la **JPL no se enlaza** pero el `Job Line Type` del JLE queda Facturable; para reportes de "no facturable al cliente" usar `BH Cost Treatment = Consume` (JLE ext).

### 5.4 Compatibilidad con `Cod60123` (ventas) y con el diseño del 6-oct

- `Cod60123` **no cambia**. Una JPL oculta nunca compite con compras (no puede tener Usage Link, H16 del 6-oct) y las compras no crean JPL (1B), así que **no hay colisión**. La salida de inventario de A-retenido es el ILE Venta que ya genera `RestoreItemPostingForJobContractLine`.
- Mejoras 1 y 2 del diseño del 6-oct quedan **sustituidas** (4.1, opción 1B). Las mejoras 3 a 7 y los pendientes del 6-oct son independientes (la 7, "Obtener líneas de recepción", se cubre aquí en 3.3 y E5).

### 5.5 Casos borde

| Caso | Tratamiento |
|---|---|
| Usuario cambia `Job Task No.` antes de recibir | E1 reaplica Facturable solo si el tipo quedó en blanco; el tratamiento se recalcula. Bloqueado tras recibir (Pedido) |
| Usuario borra `Job No.` o la tarea | BC limpia el tipo; E1 limpia tratamiento y override. Con `Job No.` y sin tarea el posteo falla con claridad (E5 + `TestPurchLineJob`) |
| Línea heredada pedido → recepción → factura | Los campos viajan desde la línea de la **orden** (3.3). `BH Job Cost Treatment`/`BH Rule Override` también (están en `Purchase Line`); como la factura queda con `Receipt No.`, no se pueden alterar |
| Documentos abiertos antes de activar | Líneas con `Job No.` y tipo en blanco/Presupuesto: E5 las bloquea al registrar. Mitigación: acción "Normalizar líneas abiertas" en la página 60128 (asigna Facturable por `Modify(false)` donde no hay recepción; las ya recibidas se listan para revisión manual). Q9 |
| **Nota de crédito / devolución de compras antiguas** | Una compra registrada **antes** del cambio ya tiene ajuste negativo; si la nota de crédito se trata como `Hold`, E7 se salta y deja el ajuste huérfano. Mitigación: `Rules Effective Date` aplicado a la fecha de la compra original y, en notas de crédito/devoluciones, usar `Hold` solo si **no** existe `Item Ledger Entry` `Negative Adjmt.` con `Job No.` ligado a la recepción original (mismo filtro que usa `PostItemJnlLineJobConsumption`, L5906-5918). Prueba N-11 |
| Línea sin Producto inventariable (servicio, no inventariable, C/G) | `BH Job Cost Treatment = " "`. E7 no actúa; el JLE se crea como hoy (C/G directo); el corte de enlace (E11) sí aplica |
| Cargo de producto, activo fijo | Siguen sin admitir proyecto (L7765-7776 de `PurchaseLine`, H3 del 6-oct) |
| Ubicaciones con almacén (bins) | El ajuste negativo no se registra, así que tampoco su movimiento de almacén; el stock permanece en el bin. `[NO VERIFICADO]` (N-10) |
| Moneda extranjera (USD) | Sin cambios de lógica; ver N-6 |
| Costeo Standard / `Inventory Value Zero` | El JLE analítico toma `Standard Cost`/0 (3.1). Mantener la recomendación del 6-oct de prohibir Standard en artículos comprados con proyecto, o aceptar la diferencia (Q11) |
| Usuarios con override que eligen Presupuesto/Ambos | Se comporta como BC nativo (crea/consume JPL): es la válvula de escape consciente y queda marcada (`BH Rule Override`) |
| Excepciones Flujo A | El usuario autorizado cambia `BH Job Cost Treatment` a `Consume` antes de recibir; BC hace el ajuste negativo nativo y el JLE sale del ajuste (E7 no actúa, E11 sí corta el enlace) |

### 5.6 Cambios en la BH-API

Ninguno en v1. `Pag60117 purchaseInvoiceLines` no expone `jobNo`/`jobTaskNo`; si el 6-oct o una versión futura los agrega, el orden de aplicación debe ser Job No. → Tarea → (no JPL) y el tipo no se expone. Cualquier campo nuevo sería aditivo y de solo lectura para `jobLineType`/`bhJobCostTreatment`; nada se renombra ni elimina en `beta`.

---

## 6. Criterios de aceptación y plan de pruebas (entregable 4, parte pruebas)

### 6.1 Convenciones
Sandbox `SandboxBHv2` (BC 28.4). Datos: proyecto en **USD** y otro en LCY; tareas 1000 Mercancía y 3000 Gastos; JPL Presupuesto de cotización (p. ej. 10 de ADPRSR5D); Producto inventariable A (FIFO/Average), Producto Standard B, Producto de servicio, Cuenta C/G de flete. Antes de cada prueba anotar: JLE, JPL, ILE y Value Entries del proyecto/artículo. **Lección del repo:** los diagnósticos con `Error()` dentro de un subscriber de posteo abortan la transacción; confirmar el resultado final siempre con un posteo real sin `Error()`.

### 6.2 Casos de prueba

| # | Caso | Resultado esperado |
|---|---|---|
| **N-0** | **Línea base nativa (sin la extensión activada):** pedido de compra con proyecto/tarea, Line Type Facturable, sin vínculo; recibir y facturar | **Confirma 3.2:** se crea una JPL "Ambos" con el costo real; hay ILE Compra + ILE Ajuste negativo; JLE tipo Consumo. Documentar para el diagnóstico del informe |
| N-1 | Teclear proyecto y tarea en línea de pedido (regla activa) | `Job Line Type = Facturable`; `BH Job Cost Treatment = Hold` (Producto inventariable). Usuario normal no puede editarlo (campo bloqueado y `Error` si lo cambia por API) |
| N-2 | Usuario con `BH JOB OVERRIDES` cambia el tipo a Presupuesto | Permitido; `BH Rule Override = true`; el posteo no lo bloquea y se comporta nativo |
| N-3 | Usuario normal elige una JPL por lookup | `Error` (E4) |
| N-4 | Línea heredada: pedido → recibir → factura con "Obtener líneas de recepción" | La factura trae Facturable y `Hold`; `Job No.`/tarea no editables; al facturar no se crea JPL |
| N-5 | Cambiar tarea antes de recibir; borrar tarea; borrar proyecto | Conforme a 5.5; con proyecto y sin tarea el posteo falla con mensaje claro |
| **N-6** | **USD:** proyecto, compra y artículo en USD; recibir con tipo de cambio X y facturar con tipo Y | JLE en LCY y USD con el tipo de la fecha de factura; sin error `Job Currency Code`; documentar diferencia vs costo del ILE |
| **N-7** | **Cambio 2 (A-retenido):** pedido `Hold`, recibir 10, facturar 10 | ILE Compra de 10 con `Job No.`; **ningún ILE Ajuste negativo**; JLE de consumo de 10 (Facturable, `Ledger Entry Type` en blanco) sin enlace a JPL; la JPL de cotización y todas las JPL **sin cambios** |
| N-8 | Efecto del ILE Compra con `"Job Purchase" = true` sin consumo | Disponibilidad del artículo = 10; `Adjust Cost - Item Entries` corre sin errores; un pedido de venta posterior puede consumir ese stock; documentar si hace falta limpiar `Job Purchase` |
| N-9 | **Ciclo completo:** pedido de compra → recibir → factura de compra → pedido/factura de venta con proyecto (una sola factura de venta, `Cod60123`) | Compra: solo ILE Compra + JLE Consumo. Venta: JPL oculta Facturable, JLE **Venta**, ILE **Venta** (sale el inventario, con `Job No.`/`Job Task No.` en el ILE). Stock final = 0; costo real del proyecto = costo de la factura de compra; sin doble conteo en JLE Consumo |
| N-10 | Ubicación con almacén (bins) | Sin movimiento negativo de almacén al comprar; stock en el bin hasta la venta |
| N-11 | Nota de crédito sobre la compra N-7, y sobre una compra **anterior al cambio** (con ajuste negativo ya registrado) | La primera revierte compra y JLE sin tocar ajustes. La segunda revierte también el ajuste negativo (no queda huérfano) |
| N-12 | WIP (método Cost Value y POC), **calcular y contabilizar** en el proyecto de N-9; revisar G/L Entries | Sin errores; `Recognized Costs`/`WIP Amount` razonables; **Contabilidad valida** que la cuenta de costo aplicado/WIP no queda descuadrada (Q7) |
| **N-13** | **Flujo A (excepción):** usuario autorizado marca `Consume` en una línea de tornillería; compra con proyecto | ILE Compra + ILE Ajuste negativo + JLE desde el ajuste; **sin** JPL creada ni modificada; inventario baja en la compra |
| N-14 | **Flujo B regresión:** compra **sin** proyecto, venta con proyecto (`Cod60123`) | Idéntico a hoy (FEN002043/FEN002045 como referencia): ILE Venta con `Job No.`, JLE Venta |
| N-15 | **Ítems y recursos:** (a) Producto servicio y no inventariable con proyecto; (b) línea Cuenta C/G (flete) con proyecto/tarea 3000; (c) **recursos:** una JPL Recurso Presupuesto en el proyecto y un uso de recurso por Diario de Proyecto | (a)/(b): `Treatment = " "`, JLE directo, sin JPL nueva. (c) El Diario de Proyecto no se ve afectado (el recurso no existe en compras) |
| N-16 | Artículo Standard y `Inventory Value Zero` | JLE con `Standard Cost`/0; documentado |
| N-17 | Interruptor apagado en otra empresa del grupo | Comportamiento 100 % nativo (regresión) |
| N-18 | Posteo en vista previa (Preview Posting) | Sin error en E5-E11 (los subscribers no hacen `Insert` en tablas propias) |

### 6.3 Criterios de aceptación (por cambio)

- **CA-1.1** Con proyecto+tarea, `Job Line Type = Facturable` en el 100 % de líneas nuevas; un usuario sin el permiso no puede cambiarlo por UI ni por API (N-1, N-3).
- **CA-1.2** Ninguna compra registrada con la regla activa crea, modifica ni consume una JPL (conteo y checksum de JPL del proyecto antes/después = igual) (N-7, N-9).
- **CA-1.3** El permission set `BH JOB OVERRIDES` concede el cambio y deja `BH Rule Override` (N-2).
- **CA-2.1** Factura de compra `Hold` genera ILE Compra, sin ILE Ajuste negativo, y JLE de consumo (si Q2 = 2A) (N-7).
- **CA-2.2** El inventario sale solo con el ILE Venta de `Cod60123` y el stock final es 0 (N-9).
- **CA-2.3** `Consume` conserva el comportamiento del Flujo A (N-13).
- **CA-3.1** Informe real vs presupuesto del proyecto de prueba cuadra: presupuesto = suma de JPL de cotización; real = suma de JLE Consumo (N-9, N-12).

---

## 7. Plan de implementación (entregable 5: qué entregar a `bc-implementer`)

### 7.1 Orden y puertas

**Puerta 0 (no escribir código hasta cumplirla):** (a) Q1, Q2, Q4, Q5 y Q6 respondidas; (b) spike 7.2 aprobado; (c) rango `idRanges` ampliado si se acepta Q13.

### 7.2 Spike (sin código en producción, en `SandboxBHv2`)

1. Ejecutar N-0 y documentar con capturas (confirma 3.2: JPL "Ambos" creada).
2. Prototipo **descartable** (extensión de pruebas, no en este repo) que suscribe E7-E11 y verifica N-7 y N-9 con un Producto USD. Preguntas que debe contestar: ¿acepta BC un JLE de Producto con `Ledger Entry Type` en blanco?; ¿falla `JobJnlCheckLine` o `PostATO`?; ¿signo de `Quantity` correcto en factura y nota de crédito?; ¿efecto en G/L (Q7)?
3. Si el spike falla, la ruta es 2B (solo `IsHandled := true` en E7) o 2C.

### 7.3 Pasos (cada uno pequeño y verificable)

| # | Paso | Verificación |
|---|---|---|
| 1 | Obtener el fuente de la extensión 50100 y listar sus suscriptores (Q6) | Documento con eventos y reglas del 50100 |
| 2 | Ampliar `app.json` `idRanges` (60200-60249) si Q13 sí | `AL: Package` compila |
| 3 | Crear enum 60149 y `table 60127` + `page 60128` (campos 5.1) | Compila; la ficha abre; `GetSetup()` no inserta en posteo |
| 4 | `tableextension 60131` (campos 60101, 60102) y `tableextension 60200` (60100, 60101) | Campos visibles en `Purchase Line` / `Job Journal Line` |
| 5 | Actualizar `Per60100`; crear `permissionset 60135 "BH JOB OVERRIDES"` | Importa sin `PTE0004`; usuario sin set no escribe en 60127 |
| 6 | `codeunit 60129`: helper `CanOverride()` (`SetupRec.WritePermission()`) + E1-E4 (captura) | N-1, N-2, N-3 en sandbox |
| 7 | `pageextension 60132/60133` (campos bloqueados y tratamiento visible) | UI: usuario normal no edita el tipo |
| 8 | E5 y E6 (validación al registrar y al liberar) | N-4, N-5, N-17, N-18 |
| 9 | E8, E11 (corte de enlace): solo corte, sin tocar inventario | N-7 parcial: ninguna JPL cambia (CA-1.2) |
| 10 | E7, E9, E10 (retener inventario + JLE analítico) **detrás** de `Hold Inventory Until Sale` | N-7, N-8, N-10 |
| 11 | `tableextension 60201` + E12 (opcional) | JLE trae `BH Cost Treatment` |
| 12 | Acción "Normalizar líneas abiertas" (5.5) | Líneas antiguas con proyecto pasan a Facturable salvo las ya recibidas |
| 13 | Pruebas de ciclo completo y regresión | N-9, N-11, N-12, N-13, N-14, N-15, N-16 |
| 14 | Actualizar `CLAUDE.md` (nueva sección "Compras con proyecto"), `README` y el diseño del 6-oct (mejoras 1-2 sustituidas) | Revisión de doc |
| 15 | Activación por empresa: encender en `SandboxBHv2`, luego una empresa del grupo, luego las demás | Interruptor apagado = comportamiento nativo |

### 7.4 Lo que NO se entrega todavía
Reutilización de la JPL comercial (3b del 6-oct), anticipos, concepto de tarea y la API de proyectos del 6-oct. Son independientes.

---

## 8. Riesgos y qué revisaría `al-code-reviewer`

### 8.1 Riesgos

| # | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| R-1 | El requerimiento literal (Facturable) **crea presupuesto** si se implementa sin el corte de enlace (3.2) | Alta | Alto | Opción 1B; prueba N-0/N-7. Aceptación CA-1.2 |
| R-2 | JLE de Producto sin ILE (2A) no soportado o con efectos en WIP/G/L | Media | Alto | Spike 7.2; Q7 con Contabilidad; fallback 2B/2C |
| R-3 | Eventos de `Purch.-Post` y `Job Jnl.-Post Line` cambian de firma en versiones 28.x/29 (ya pasó con `OnInsertInvLineFromRcptLineOnAfterCalcShouldProcessAsRegularLine` en 28.4) | Media | Alto | Recompilar contra la versión de producción; N-9 en cada actualización |
| R-4 | Extensión 50100 desconocida (no hay fuente): puede bloquear compras a stock sin proyecto o duplicar reglas | Media | Alto | Q6; interruptor apagado; orden de suscriptores entre apps no está garantizado |
| R-5 | Notas de crédito/devoluciones de compras previas al cambio dejan ajuste negativo huérfano | Media | Medio | 5.5, `Rules Effective Date`, N-11 |
| R-6 | Mantener el ILE Compra con `"Job Purchase" = true` sin consumo | Media | Medio | N-8; alternativa documentada (5.3) |
| R-7 | JLE no se reajusta con Adjust Cost (queda al costo de factura); diferencias con costo de inventario/COGS | Alta | Medio | Documentar; Q7/Q11 |
| R-8 | Informe real vs presupuesto sigue sin cuadrar por otras causas (4.5, hipótesis 2-6) | Media | Medio | Diagnóstico previo con 3 consultas; no prometer que este diseño lo resuelve entero |
| R-9 | Límite de IDs: los 26 IDs del rango ya están asignados al diseño del 6-oct | Alta | Bajo | Q13 (ampliar `idRanges`); revisar solapes con CRM (50100-50199) y `InformeInventarioBH` (60150-60199) |
| R-10 | `WritePermission` incluye SUPER: más usuarios de los esperados pueden sobrescribir | Media | Bajo | Q10 (lista de usuarios opcional) |
| R-11 | Rendimiento | Baja | Bajo | 1 lectura de una fila de setup por llamada; los subscribers de `Job Jnl.-Post Line` filtran por marcador de registro; sin recorridos de tablas grandes |
| R-12 | Multiempresa: reglas activadas en una empresa y no en otra | Media | Bajo | Interruptor por empresa; plan de activación gradual (paso 15) |
| R-13 | Se deja de poder diagnosticar con `Error()` dentro de subscribers de posteo (aborta) | — | — | Pruebas finales siempre con posteo real; registrar con `Message()`/telemetría |

### 8.2 Qué revisaría `al-code-reviewer`

1. Que **ningún** subscriber modifique estado sin marcador de registro; si alguno usa variable global, el codeunit debe ser `SingleInstance`.
2. Que E7 con `IsHandled := true` no deje de postear la **cantidad facturada** ni el cargo/asientos (comparar con el procedimiento nativo L5889-5950).
3. Que E8 filtre por línea y por `Type` correcto y no marque líneas C/G con `BH No Item Ledger`.
4. Que los guardas de campo filtren por `CurrFieldNo` (el posteo llama `Validate("Job Planning Line No.")` internamente, `JobTransferLine` L619) para no fallar el posteo propio.
5. `Per60100`: entradas para tabla y codeunit (PTE0004); `tableextension`/`pageextension`/`enum` sin entrada.
6. Que `GetSetup()` nunca haga `Insert` en un posteo y tolere el registro inexistente (tabla vacía).
7. Que el corte de enlace solo aplique con `Job Line Type = Facturable` y sin `BH Rule Override` (la válvula de escape no puede quedar anulada).
8. Casos borde de 5.5: documentos previos, notas de crédito, ubicaciones con almacén, USD, Preview Posting.
9. Nombres con prefijo BH, `ToolTip`/captions en español, IDs reutilizados del diseño del 6-oct sin duplicados.

---

## 9. Preguntas abiertas (requieren decisión de negocio antes de implementar)

| # | Pregunta | Opciones / recomendación |
|---|---|---|
| **Q1** | ¿Se acepta que "Facturable bloqueado" se logre **cortando el enlace de uso** (el JLE de compra no se vincula a ninguna línea de planificación) y que el real por línea de presupuesto (`Qty. Posted` en la JPL) deje de actualizarse? | 1B (recomendada) o 1C (vínculo a JPL Presupuesto, contradice el requerimiento) |
| **Q2** | ¿"Solo el movimiento de compra" significa que el **costo real sigue apareciendo en el proyecto** al facturar la compra (JLE de consumo sin ILE, 2A), o que el proyecto no ve costo hasta vender (2B)? ¿O las compras a stock no llevan proyecto (2C)? | 2A condicionada al spike; 2C si no se necesita real inmediato |
| **Q3** | ¿"Movimiento de compra" incluye solo el ILE Compra o también el JLE? (depende de Q2) | — |
| **Q4** | Discriminador A vs A-retenido y **quién** puede marcar `Consume` | D1 (campo por línea), mismo permiso de override. Alternativa: dejarlo editable para Compras |
| **Q5** | "Una sola factura **desde el pedido de venta**": hoy `Cod60123` solo cubre **Factura** de venta (el Pedido se retiró el 2026-09-14 porque `Sales-Post` rechaza `Job No.` en Pedidos con envío y factura). ¿Cómo facturan el pedido hoy? | Si necesitan Pedido, el lado ventas necesita un diseño aparte (Ruta A del `DIS-2026-08-31`) |
| **Q6** | Entregar el fuente / ubicación de la extensión "Proyecto Obligatorio en Compras" (Codeunit 50100), o confirmar que no existe | Descargar fuente desde Extensiones instaladas; retirarla o eximir compras a stock |
| **Q7** | Contabilidad: ¿el JLE de consumo **sin asiento** de costo aplicado es aceptable (el costo contable va por inventario/COGS en la venta)? ¿Qué método de WIP se usa (Cost Value / POC)? | Prueba N-12 con Contabilidad presente |
| **Q8** | La salida en la venta es ILE tipo **Venta** (no "Ajuste negativo"): ¿se acepta? | Es la que ya genera `Cod60123` y da mejor trazabilidad |
| **Q9** | Documentos abiertos antes de activar y notas de crédito de compras anteriores: ¿fecha de corte (`Rules Effective Date`) y normalización de líneas abiertas? | Fecha de corte + acción de normalización |
| **Q10** | Permiso: ¿basta el permission set `BH JOB OVERRIDES` (incluye SUPER) o se requiere lista de usuarios por nombre? ¿En qué empresas lo asigna Cristhian? | Permission set |
| **Q11** | Costeo Standard / `Inventory Value Zero` en artículos comprados con proyecto: ¿prohibir o aceptar la diferencia? | Prohibir (como el diseño del 6-oct) |
| **Q12** | Servicios, no inventariables y cuentas C/G con proyecto: ¿se mantienen como hoy (sin retener nada)? | Sí |
| **Q13** | Ampliar `idRanges` de `app.json` a 60200-60249 (hoy no quedan IDs libres) | Sí |
| **Q14** | Confirmar que el diseño del 6-oct, mejoras 1 y 2 (vínculo obligatorio a JPL Presupuesto), queda **sustituido** por este | Sí |

---

## 10. Registro de verificación (lo leído en el código 28.4 para este diseño)

| Afirmación | Evidencia |
|---|---|
| El ajuste negativo es el consumo nativo y se llama siempre con `Job No.` | `PurchPost.Codeunit.al : PostItemJnlLine L1548-1574; PostItemJnlLineJobConsumption L5889-5950` |
| El JLE de Producto se crea desde el Value Entry del consumo | `JobJnlPostLine.Codeunit.al : PostItem L406-500; GetJobConsumptionValueEntry L673; CreateJobLedgEntryFromPostItem L383-392` |
| Facturable sin vínculo crea JPL "Ambos" | `JobLinkUsage.Codeunit.al : CreateJobPlanningLine L242-285 (L255)` |
| Facturable pura no admite Usage Link | `JobPlanningLine.Table.al : field(1053 "Usage Link") OnValidate` |
| `Job Line Type` de compra no tiene default; lo asigna el vínculo | `PurchaseLine.Table.al : field(1002) L2205; "Job Planning Line No." OnValidate L2511-2545` |
| `Job No.`/`Job Task No.` bloqueados tras recibir | `PurchaseLine.Table.al : field(45) L1118; field(1001) L2154` |
| `ApplyUsage` solo se evita con `IsHandled` en `OnBeforeApplyUsageLink` | `JobJnlPostLine.Codeunit.al L357-373, evento L837` |
| `ShouldPostUsage` modificable | `JobJnlPostLine.Codeunit.al L135-148, evento L907` |
| `PostJobOnPurchaseLine` es público y usa `Job Posting Only = true` | `JobPostLine.Codeunit.al L365-415` |
| El ILE de compra lleva `Job Purchase` y se aplica el consumo contra él | `ItemJournalLine.Table.al L2799-2801; ItemJnlPostLine.Codeunit.al L1727, L2018` |
| `Update Job Item Cost` ignora JLE sin ILE | `UpdateJobItemCost.Report.al L22-45 (DataItemLink con Ledger Entry No.)` |
| "Obtener líneas de recepción" copia de la orden | `PurchRcptLine.Table.al : CopyFromPurchRcptLine L1033` |
| Costo Standard / Inventory Value Zero en el JLE | `JobTransferLine.Codeunit.al L667-679` |
| `Cod60123` es solo Factura de venta, ILE Venta con `Job No.` | `src/Codeunits/Cod60123.salesJobPlanningMgt.al L559-580` |
| La extensión 50100 no existe en ningún fuente local | Búsqueda en repo, `Documents\AL`, OneDrive (3.5) |

**No verificado (a probar en sandbox):** JLE de Producto sin ILE (spike), efecto en G/L/WIP, efecto de `Job Purchase = true` sin consumo, almacén con bins, notas de crédito de documentos históricos, versión de producción.
