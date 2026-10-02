# DIS-2026-09-14 — Correcciones de posteo en la integración Proyectos ↔ Factura de venta

> Continúa `docs/diseños/DIS-2026-08-31-jobs-sales-integration.md` (referencia obligatoria de contexto: patrón de fondo, decisiones de alcance, y los tres hallazgos previos ya registrados en memoria del arquitecto — `pattern-hidden-billable-job-planning-line`, `finding-job-contract-entry-no-exclusive-to-invoice-documents`, `finding-sales-line-edit-guard-on-job-contract-entry`). Este documento cubre tres problemas encontrados en la sesión de pruebas del 2026-09-14 sobre el proyecto **P005174** y el documento **P01414**, con la extensión ya publicada en `SandboxBH` en su alcance reducido (solo Factura de venta, sin Pedido — ver cabecera de `Cod60123.salesJobPlanningMgt.al`).

## 1. Requerimiento

Al intentar registrar (postear) el documento P01414 con líneas Tipo=Artículo vinculadas al proyecto P005174, el posteo falla con un error nativo de Business Central. Por separado, durante la investigación manual en la ficha del Proyecto, un clic en la celda "N.º mov. contrato proyecto" de una línea de planificación provocó el borrado de las 14 líneas Facturables de esa tarea. Además, negocio espera que el posteo genere dos `Job Ledger Entry` (Consumo y Venta) por línea, pero el diseño actual solo produce uno (Venta). Se pide diagnosticar la causa raíz de cada problema y especificar la corrección.

## 2. Supuestos y preguntas abiertas

**Supuesto crítico que sostiene todo el diagnóstico de la Falla 1 — requiere confirmación de 10 segundos en el cliente BC antes de tocar código:**

> **P01414 es, con altísima probabilidad, un Pedido de venta (`Document Type = Order`), no una Factura de venta.** Evidencia independiente encontrada en este mismo repositorio: `docs/tecnica/DOC-2026-09-09-origenes-lp-servinstal-y-autorecalc.md`, líneas 82 y 88, documenta explícitamente **"el pedido de venta P01414"**, resultado de convertir la cotización **C04000** el 2026-09-07/09 (para una prueba de la funcionalidad Origenes LP, completamente ajena a Jobs). Es el mismo número de documento que esta sesión describe como "una Factura de venta con 14 líneas". Dado que Business Central nunca reutiliza un número de Pedido como número de Factura dentro de la misma serie, y que este identificador aparece documentado sin ambigüedad como Pedido apenas 5 días antes de esta sesión, la conclusión más razonable es que es el **mismo documento**, y que quien ejecutó la prueba lo llama coloquialmente "la Factura" porque la acción que intentó fue "Contabilizar → Facturar/Enviar y facturar" sobre ese Pedido — no porque haya creado una Factura de venta nueva y directa (que es el único camino soportado hoy por `Cod60123`).
>
> **Acción requerida antes de implementar nada:** abrir P01414 en el cliente BC y confirmar si la ficha que se abre es "Pedido de venta" o "Factura de venta". Todo el diagnóstico de la sección 3.1 y el plan de la sección 6 asumen que es un Pedido. Si resultara ser genuinamente una Factura (`Document Type = Invoice` desde su creación), la sección 3.1 queda invalidada y hace falta una sesión de depuración en vivo (Snapshot Debugger) — ver Plan B al final de la sección 6.

**Otros supuestos:**
- Se asume que el ítem de las 14 líneas de P01414 es un ítem estándar (sin seguimiento por número de serie/lote) — no se investigó el flujo de "Available - Sales Lines"/reserva interactiva porque no aplica a un posteo directo sin intervención manual de reserva. Si alguna línea tiene tracking obligatorio, revisar por separado.
- Se asume que ninguna de las 14 líneas usa Tipo = Cargo (Item Charge) ni Activo Fijo (los chequeos `TestSalesLineItemCharge`/`TestSalesLineFixedAsset` sí exigen `Job No. = ''` de forma incondicional, sección 3.1).
- Sobre la Falla 2, no fue posible reproducir con certeza absoluta el mecanismo exacto sin depuración en vivo (ver sección 3.2) — se documenta la evidencia encontrada y dos hipótesis, con la mitigación recomendada siendo válida para ambas.

**Pregunta abierta para Cristhian / negocio (no bloqueante para implementar, sí para cerrar):** una vez limpiado P01414 (sección 6), ¿el proyecto P005174 necesita reflejar retroactivamente el valor de esas 14 líneas, o basta con que el Pedido se postee "limpio" (sin vínculo a proyecto) y el vínculo se pierda para esta venta puntual? La sección 6 asume la segunda opción (más simple, coherente con que Pedido está fuera de alcance) — si la respuesta es la primera, hace falta un ajuste manual de presupuesto en el proyecto, fuera del alcance de este documento.

## 3. Análisis de lo existente

### 3.1 Falla 1 — causa raíz con cita de código

**Investigación realizada (exhaustiva, con código real, no de memoria):** se decompiló `Microsoft_Base Application_27.5.46862.52525.app` (mismo paquete ya usado en el diseño anterior) y se revisaron, uno por uno, con evidencia de código, **todos** los `TestField("Job No.", ...)` existentes en Base Application más las extensiones D365LATAM y LyLVariantsExt (búsqueda repo-wide, ~25 ocurrencias). Se descartaron explícitamente por no aplicar al escenario (Tipo=Artículo, posteo directo, sin cargos de ítem/activo fijo/drop-shipment/reserva interactiva):

| Ubicación | Por qué no aplica |
|---|---|
| `SalesPost.Codeunit.al:1075` (`PostSalesLine`) | Excluido explícitamente para `Document Type in [Invoice, Credit Memo]` — **pero solo si el documento realmente es Invoice** (ver más abajo, es la pieza clave) |
| `SalesPost.Codeunit.al:5733` (`PostJobContractLine`) | Mismo patrón — excluido para Invoice/Credit Memo |
| `SalesPost.Codeunit.al:2575` (`TestSalesLineJob`) | Mismo patrón — excluido para Invoice/Credit Memo |
| `SalesPost.Codeunit.al:1972/2182/2206` (cargos de ítem por Pedido/Albarán/Devolución) | Solo aplica a Tipo = Cargo (Item Charge) |
| `SalesPost.Codeunit.al:2542/2557` (`TestSalesLineItemCharge`/`TestSalesLineFixedAsset`) | Solo aplican a Tipo = Cargo/Activo Fijo, no a Tipo = Artículo |
| `SalesPost.Codeunit.al:4340` (`CopyAndCheckItemCharge`) | El bucle se filtra a `Type::"Charge (Item)"`; si no hay cargos, `exit()` inmediato |
| `SalesLine.Table.al:1397` (`OnValidate` de `Drop Shipment`) | Solo se dispara al editar ese campo, y exige `TestField("Document Type", Order)` antes — no se ejecuta durante un posteo directo |
| `SalesHeader.Table.al:897` (`OnValidate` de `Prices Including VAT`) | Solo se dispara al editar ese campo en la cabecera, no durante el posteo |
| `SalesHeader.Table.al:6659` (`TestSalesLineFieldsBeforeRecreate`) | Solo se dispara al recrear líneas por cambio de campo de cabecera (ej. Cliente), no durante el posteo |
| `SalesLineReserve.Codeunit.al:999` (`TestSourceTableFields`) | Solo se dispara desde la página interactiva de Reserva (`Page::Reservation`), no durante el posteo automático |
| `SalesExplodeBOM.Codeunit.al:254` (`CheckSalesLine`) | Solo se dispara al ejecutar manualmente la acción "Explotar lista de materiales" |
| `GenJnlCheckLine.Codeunit.al:668` (`CheckJobNoIsEmpty`, vía `CheckAccountNo`/`CheckBalAccountNo`) | Se invoca para las líneas de Gen. Journal Line derivadas del posteo de Factura, pero **solo si `"Bal. Account No." <> ''`** (`GenJnlCheckLine.Codeunit.al:157-158`) — la línea de ingreso (revenue) construida por `InvoicePostingBuffer` no lleva Bal. Account (se balancea por documento, no por cuenta contraria) y la línea de cliente (`SalesPostInvoice.Codeunit.al` `PostLedgerEntry`) nunca copia `"Job No."` — verificado que ese campo queda en blanco por diseño en ambas |
| D365LATAM (Colombia Localization, Documento Soporte, RetencionesArt383) | Cero subscribers sobre `Sales-Post`/`Sales Line` relacionados con `Job No.` (grep repo-wide sobre los 3 paquetes decompilados) |
| LyLVariantsExt | Cero referencias a `Job No.` en todo el paquete decompilado |

**Conclusión de la tabla anterior:** para un documento cuyo `Document Type` es genuinamente `Invoice` desde su creación, **ningún** chequeo nativo (ni de Microsoft, ni de las localizaciones instaladas) exige `Job No. = ''`. El diseño actual (`Cod60123`, alcance Invoice-only) es, en teoría, correcto y suficiente para ese caso.

**La pieza que sí explica el error exacto reportado, si el documento es un Pedido (hipótesis de la sección 2):**

```al
// SalesPost.Codeunit.al, procedure PostSalesLine, línea ~1071-1075
IsHandled := false;
OnPostSalesLineOnBeforeTestJobNo(SalesLine, IsHandled);
if not IsHandled then
    if not (SalesLine."Document Type" in [SalesLine."Document Type"::Invoice, SalesLine."Document Type"::"Credit Memo"]) then
        SalesLine.TestField("Job No.", '');
```

Este `TestField` es **incondicional respecto a `"Job Contract Entry No."`** — no le importa si la línea tiene o no un vínculo de proyecto resuelto; solo mira `Document Type` y `Job No.`. Un Pedido de venta **nunca** cambia `Document Type` durante el posteo (permanece en `Order` de principio a fin, incluso en "Enviado y Facturado" — ver `finding-job-contract-entry-no-exclusive-to-invoice-documents`, ya en memoria del arquitecto). Si P01414 es ese Pedido y sus 14 líneas conservan `"Job No." <> ''` desde la época (2026-09-01 al 2026-09-14) en que el alcance de `Cod60123` sí cubría Pedido — este `TestField` reproduce **exactamente** el mensaje reportado: *"N.º proyecto debe ser igual a '' en Lín. venta: ..., El valor actual es 'Z'"* (`FieldCaption("Job No.")` = "N.º proyecto", `TableCaption` de `Sales Line` = "Lín. venta").

**Por qué esto NO es un defecto del diseño actual (Invoice-only):** el 2026-09-14 se retiró de `Cod60123` el subscriber `AllowOrderPostingForJobContractLine` (sobre `OnPostJobContractLineBeforeTestFields`) y el subscriber `OnPostSalesLineOnBeforeTestJobNo` que existían específicamente para permitir que un Pedido con vínculo de proyecto posteara sin chocar contra este `TestField` — se retiraron porque negocio confirmó que Pedido queda fuera de alcance (ver cabecera de `Cod60123.salesJobPlanningMgt.al`, comentario 2026-09-14). P01414 es un Pedido que quedó con datos "a mitad de camino": se le asignó `Job No.` cuando el código todavía lo permitía y lo sabía postear, pero el código que lo sabía postear ya no existe. **Es un problema de datos residuales de un Pedido, no un bug de la Factura.**

### 3.2 Falla 2 — investigación de la página nativa "Job Planning Lines"

Se confirmó (grep repo-wide, ya hecho en sesiones anteriores y repetido en esta) que **no existe ningún `OnDrillDown` en este repositorio**, y se verificó además el campo nativo en el Base Application decompilado:

```al
// JobPlanningLines.Page.al, línea 497
field("Job Contract Entry No."; Rec."Job Contract Entry No.")
{
    ApplicationArea = Jobs;
    ToolTip = 'Specifies the entry number of the project planning line that the sales line is linked to.';
    Visible = false;
}
```

Es un campo `Integer` plano, **sin `TableRelation`, sin `trigger OnDrillDown`, sin `trigger OnAssistEdit`, y `Visible = false` por defecto** (el usuario tuvo que exponerlo vía personalización para verlo, algo esperable dado que el plan de pruebas del diseño anterior pedía verificarlo). No hay ningún mecanismo de "lookup" nativo asociado a este campo — un clic en su valor no dispara ninguna navegación ni acción en sí mismo.

**Hallazgo relevante sobre el borrado en sí — protección nativa existente que hace sospechoso el resultado reportado:**

```al
// JobPlanningLine.Table.al, trigger OnDelete, línea 1407
trigger OnDelete()
begin
    ConfirmDeletion();
    PreventDeleteIfPurchaseExists(Rec);
    ValidateModification(true, 0);
    CheckRelatedJobPlanningLineInvoice();   // <-- clave
    ...
end;

// línea 2801
local procedure CheckRelatedJobPlanningLineInvoice()
begin
    ...
    JobPlanningLineInvoice.SetRange("Job No.", "Job No.");
    JobPlanningLineInvoice.SetRange("Job Task No.", "Job Task No.");
    JobPlanningLineInvoice.SetRange("Job Planning Line No.", "Line No.");
    if not JobPlanningLineInvoice.IsEmpty() then
        Error(NotPossibleJobPlanningLineErr);
end;
```

Este chequeo **bloquea con `Error()` cualquier intento de borrar una `Job Planning Line` mientras exista un registro `Job Planning Line Invoice` asociado — sin distinguir entre borrador (`Document Type = Invoice`) y contabilizado (`"Posted Invoice"`)**. Nuestro propio `CreateJobPlanningLineFromSalesLine` (`Cod60123`) **siempre** inserta un `Job Planning Line Invoice` borrador en el mismo momento en que crea la línea de planificación oculta. Dado que el posteo de P01414 falló (Falla 1) antes de completarse, ese borrador debería seguir existiendo — por lo que, en teoría, **el borrado manual de las 14 líneas desde la ficha de Proyecto debería haber sido bloqueado por este chequeo nativo**, con un mensaje distinto ("No es posible eliminar..."), no completarse en silencio.

Esta contradicción no se pudo resolver con certeza mediante análisis estático. Dos hipótesis, ambas compatibles con la mitigación recomendada:

- **Hipótesis A (más probable):** el borrado no ocurrió realmente arrastrando el clic sobre la celda "N.º mov. contrato proyecto" como causa directa — el usuario probablemente seleccionó varias filas (Ctrl/Shift+clic, un patrón común al revisar una columna recién agregada por personalización) y presionó la tecla Suprimir o una acción "Eliminar línea" con esas filas seleccionadas. Si en ese momento **alguna** de las 14 líneas ya no tenía su `Job Planning Line Invoice` (por ejemplo, si un intento de posteo previo llegó a insertar el registro `"Posted Invoice"` para algunas líneas antes de fallar en otra — escenario poco probable pero no descartable si el posteo no es 100% atómico en ese tramo), el chequeo no las habría protegido.
- **Hipótesis B:** el borrado ocurrió en realidad desde el lado de la Factura/Pedido (borrando las Sales Line, lo que sí dispara `CleanupOnAfterDeleteSalesLine` en `Cod60123`, que borra correctamente el `Job Planning Line Invoice` primero y luego la `Job Planning Line`), y el usuario lo percibió/relató como si hubiera ocurrido al hacer clic en la ficha de Proyecto, por estar navegando entre ambas pantallas durante la misma sesión de prueba.

**Independientemente de cuál sea la causa exacta**, el hallazgo de `CheckRelatedJobPlanningLineInvoice()` confirma que **borrar una `Job Planning Line` "BH Auto-Created From Sales" desde la ficha de Proyecto nunca debería ser una operación segura ni deseable** — el punto de verdad debe ser siempre la Sales Invoice Line (mandato explícito de la tarea). Se diseña una mitigación defensiva (sección 5.2) independientemente de la causa exacta.

### 3.3 Pregunta de negocio — Job Ledger Entry Consumo + Venta

Se decompiló `Codeunit 1001 "Job Post-Line"` y `Codeunit "Job Jnl.-Post Line"` para confirmar si `"Line Type" = "Both Budget and Billable"` (en vez de `Billable` puro) haría que el posteo de la Factura generara también una entrada tipo *Usage* (Consumo).

```al
// JobPostLine.Codeunit.al, procedure PostInvoiceContractLine, línea 225-229
IsHandled := false;
OnPostInvoiceContractLineOnBeforePostJobOnSalesLine(JobPlanningLine, JobPlanningLineInvoice, SalesHeader, SalesLine, IsHandled);
if not IsHandled then
    if JobPlanningLine.Type <> JobPlanningLine.Type::Text then
        PostJobOnSalesLine(JobPlanningLine, SalesHeader, SalesLine, "Job Journal Line Entry Type"::Sale);
```

Esta llamada — la única que genera un `Job Ledger Entry` durante el posteo de una Factura de venta — **usa el literal `"Job Journal Line Entry Type"::Sale` de forma incondicional**. No hay ningún `case JobPlanningLine."Line Type" of` que decida entre `Sale`/`Usage` aquí. Es decir: **`Line Type = "Both Budget and Billable"` no cambiaría nada en este punto** — el posteo de una Factura de venta jamás genera una entrada `Usage`, sin importar el `Line Type` de la línea de planificación.

Se investigó además dónde SÍ se usa `"Both Budget and Billable"` para confirmar qué hace realmente ese valor, y resultó ser un mecanismo **completamente distinto**, no relacionado con el posteo de Facturas:

```al
// JobPostLine.Codeunit.al, procedure PostPlanningLine, línea 76-109
// (usada por InsertPlLineFromLedgEntry: convierte un Job Ledger Entry YA CONTABILIZADO
//  -por ejemplo desde un Diario de Proyecto o una Factura de compra con N.º proyecto-
//  en una nueva Job Planning Line)
if JobPlanningLine."Line Type" = JobPlanningLine."Line Type"::"Both Budget and Billable" then begin
    ...
    JobPlanningLine.Validate("Line Type", JobPlanningLine."Line Type"::Budget);
    JobPlanningLine.Insert(true);          // <- la línea de Presupuesto (consumo ya ocurrido)
    ...
    JobPlanningLine."Line No." := JobPlanningLine."Line No." + 10000;
    JobPlanningLine.Validate("Line Type", JobPlanningLine."Line Type"::Billable);  // <- una SEGUNDA línea nueva, Facturable
end;
```

`"Both Budget and Billable"` es una instrucción para **el motor que traduce un `Job Ledger Entry` de Consumo ya posteado (típicamente desde una Factura de compra o un Diario de Proyecto) en DOS `Job Planning Line` separadas** (una de Presupuesto que registra el costo ya incurrido, y una nueva Facturable para poder facturarlo después) — no es un interruptor que, al postear una Factura de venta contra una línea Facturable existente, produzca dos asientos.

**Conclusión, con evidencia de código, sin ambigüedad:** el diseño actual (Billable puro, confirmado en firme por negocio el 2026-09-01) es **correcto y es el único posible** para lograr que el posteo de la Factura genere el `Job Ledger Entry` tipo Venta — cambiar a `"Both Budget and Billable"` no agrega la entrada de Consumo ni tiene ningún efecto en este flujo. **La expectativa de negocio de "2 Job Ledger Entries por línea" no es alcanzable posteando únicamente la Factura de venta.** Para que exista una entrada `Usage`, tiene que existir, en algún momento, un posteo independiente que represente el costo/consumo del ítem para el proyecto — típicamente un Diario de Proyecto (Job Journal) con `Entry Type = Usage`, o una Factura de compra con `Job No.` diligenciado (que dispara `Job Post-Line.PostJobOnPurchaseLine(..., Usage)` — visto en el mismo codeunit, no citado en detalle por quedar fuera de alcance). Generar esa segunda entrada automáticamente implicaría un **segundo posteo** (Diario de Proyecto) con sus propias implicaciones de costo/inventario — explícitamente fuera de alcance de esta corrección puntual, tal como ya lo anticipaba la instrucción de la tarea.

## 4. Solución propuesta

**Falla 1 — no requiere código nuevo en `Cod60123`.** Es un problema de datos residuales sobre un documento (P01414) que quedó en un estado híbrido al recortarse el alcance el 2026-09-14. La solución es un **saneamiento de datos, de una sola vez**, sobre cualquier Pedido de venta que aún conserve `Job No.`/`Job Contract Entry No.` de la época en que Pedido sí estaba soportado — no solo P01414, sino cualquier otro Pedido creado/editado en esa ventana (2026-09-01 a 2026-09-14). Se especifica un procedimiento de limpieza puntual (sección 5.1) que replica exactamente la lógica que ya usa `CleanupOnAfterDeleteSalesLine` (borra primero el `Job Planning Line Invoice` borrador, luego la `Job Planning Line`, luego limpia la `Sales Line`), aplicado a cualquier línea de Pedido encontrada en ese estado — en vez de repetirla a mano línea por línea.

**Falla 2 — mitigación defensiva permanente, independiente de la causa exacta.** Se agrega un event subscriber sobre `OnBeforeDeleteEvent` de `Job Planning Line`, acotado al marcador `"BH Auto-Created From Sales" = true`, que bloquea cualquier intento de borrado que no provenga de los dos procedimientos de limpieza ya existentes en `Cod60123` (`RemoveAutoCreatedJobPlanningLine`, `CleanupOnAfterDeleteSalesLine`) — usando el mismo patrón de "flag de contexto controlado" que Microsoft ya usa en la propia tabla (`SuspendDeletionCheck`/`CalledFromHeader`, ver cita en sección 3.2). Esto convierte a la Sales Invoice Line en el único punto de verdad real, cerrando la puerta a que un Project Manager borre estas líneas sin darse cuenta desde la ficha de Proyecto — cumple exactamente el mandato de la tarea.

**Job Ledger Entry Consumo+Venta — no se rediseña en este documento.** Se documenta la conclusión (sección 3.3) para que negocio ajuste su expectativa o encargue, como desarrollo aparte, el diseño de un segundo posteo (Diario de Proyecto) — explícitamente fuera de alcance aquí.

## 5. Especificación técnica

### 5.1 Saneamiento de datos — Pedidos con `Job No.` residual (temporal, no queda en producción)

**No es un objeto permanente de la extensión.** Se ejecuta una única vez desde el cliente BC (`Herramientas de diseño → Ejecutar código de AL` / codeunit temporal descartable tipo "one-shot", o bien un pequeño report/página de acción temporal) — a discreción del implementador, siempre que quede fuera de `Cod60123` y se elimine del código fuente tras usarse (no se publica como parte de BH-API).

Pseudocódigo del procedimiento de limpieza (una sola pasada, sin parámetros de usuario, revisa TODOS los Pedidos, no solo P01414):

```al
SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
SalesLine.SetFilter("Job No.", '<>%1', '');
if SalesLine.FindSet() then
    repeat
        if SalesLine."Job Contract Entry No." <> 0 then begin
            JobPlanningLine.SetCurrentKey("Job Contract Entry No.");
            JobPlanningLine.SetRange("Job Contract Entry No.", SalesLine."Job Contract Entry No.");
            if JobPlanningLine.FindFirst() and JobPlanningLine."BH Auto-Created From Sales" then begin
                JobPlanningLineInvoice.SetRange("Job No.", JobPlanningLine."Job No.");
                JobPlanningLineInvoice.SetRange("Job Task No.", JobPlanningLine."Job Task No.");
                JobPlanningLineInvoice.SetRange("Job Planning Line No.", JobPlanningLine."Line No.");
                JobPlanningLineInvoice.DeleteAll();     // borra el/los borrador(es) — nunca habrá "Posted" aquí, el posteo de P01414 nunca se completó
                JobPlanningLine.Delete(true);
            end;
        end;
        SalesLine."Job No." := '';
        SalesLine."Job Task No." := '';
        SalesLine."Job Contract Entry No." := 0;        // asignación directa, no Validate() — mismo criterio que RemoveAutoCreatedJobPlanningLine
        SalesLine.Modify();
    until SalesLine.Next() = 0;
```

**Antes de correrlo:** confirmar (sección 2) que P01414 es en efecto un Pedido, y hacer una copia de seguridad del listado de las 14 líneas (No. de ítem, cantidad, precio) por si negocio decide más adelante recrear el vínculo manualmente sobre una Factura nueva.

### 5.2 `Cod60123.salesJobPlanningMgt.al` — nuevo subscriber defensivo (Falla 2)

Nuevo campo global de single-instance en el mismo codeunit (o variable de módulo estándar, ya que los event subscribers de un mismo codeunit comparten estado dentro de la misma sesión/transacción):

```al
var
    AllowInternalJobPlanningLineDeletion: Boolean;
```

Nuevo subscriber:

```al
[EventSubscriber(ObjectType::Table, Database::"Job Planning Line", OnBeforeDeleteEvent, '', false, false)]
local procedure BlockManualDeleteOfAutoCreatedJobPlanningLine(var Rec: Record "Job Planning Line"; RunTrigger: Boolean)
begin
    if AllowInternalJobPlanningLineDeletion then
        exit; // borrado disparado por nuestros propios procedimientos de limpieza — permitido

    if not Rec."BH Auto-Created From Sales" then
        exit; // línea de Job Contract genuina (asistente estándar de Proyectos) -- no tocar

    Error(CannotDeleteFromJobErr);
end;
```

`CannotDeleteFromJobErr` — nuevo `Label`, texto sugerido: *"Esta línea de planificación fue creada automáticamente desde una línea de Factura de venta y no se puede eliminar desde aquí. Para quitar el vínculo, borre el N.º proyecto/N.º tarea proyecto directamente en la línea de la Factura de venta."*

**Modificación necesaria en los dos procedimientos de limpieza existentes** (`RemoveAutoCreatedJobPlanningLine` y `CleanupOnAfterDeleteSalesLine`): envolver cada `JobPlanningLine.Delete(true)` con el flag:

```al
AllowInternalJobPlanningLineDeletion := true;
JobPlanningLine.Delete(true);
AllowInternalJobPlanningLineDeletion := false;
```

**Por qué es seguro:** el flag es una variable de instancia del propio codeunit — solo se pone en `true` inmediatamente antes de la llamada a `Delete(true)` que nosotros mismos controlamos, y se restaura a `false` justo después (patrón try/finally simplificado; si `Delete(true)` lanza una excepción, el flag quedaría en `true` para el resto de esa transacción fallida, pero como la transacción se revierte por completo, no hay fuga real hacia otra operación). No interfiere con `Job Planning Line` genuinas (`"BH Auto-Created From Sales" = false`) bajo ninguna circunstancia — el primer `if not Rec."BH Auto-Created From Sales" then exit` las deja completamente intactas, igual que el resto de los subscribers de este codeunit.

**Nota sobre la salvaguarda nativa `CheckRelatedJobPlanningLineInvoice`:** este nuevo subscriber corre en `OnBeforeDeleteEvent`, que se dispara **antes** que el propio `trigger OnDelete()` de la tabla (y por tanto antes de `CheckRelatedJobPlanningLineInvoice`) — es una capa de protección adicional, no un reemplazo. Sigue siendo cierto que, si por alguna razón nuestro subscriber no cubriera un camino de borrado (por ejemplo, un `DeleteAll()` sin `RunTrigger`), la protección nativa de Microsoft seguiría intentando bloquear mientras exista el `Job Planning Line Invoice` — pero no hay que depender de eso en exclusiva, de ahí la razón de este punto 5.2.

### 5.3 Consecuencia ya explicada — `Job Contract Entry No.` huérfano tras un borrado ya ocurrido

Se confirmó, leyendo `RemoveAutoCreatedJobPlanningLine` y `CleanupOnAfterDeleteSalesLine` en el archivo actual, que **ambos hacen `JobPlanningLine.FindFirst()` sin manejar el caso "no existe"** — si `Job Contract Entry No.` en la Sales Line ya no tiene una `Job Planning Line` real detrás (por ejemplo, por el incidente de la Falla 2 antes de aplicar la mitigación de 5.2), `FindFirst()` simplemente no encuentra nada y el `if JobPlanningLine.FindFirst() then` (falso) hace que el `exit` temprano se tome — **no hay error, pero tampoco se limpia `Sales Line."Job Contract Entry No."`**, que queda apuntando a un registro inexistente. Esto explica exactamente el síntoma reportado: *"No hay Línea de planificación de proyecto dentro del filtro..."* al reintentar postear (`Job Post-Line.PostInvoiceContractLine`, `JobPlanningLine.FindFirst()` sin chequeo de existencia, ver `DIS-2026-08-31-jobs-sales-integration.md` sección 3).

**No se diseña una corrección nueva para este síntoma** — se resuelve solo, para casos futuros, en cuanto la mitigación de 5.2 esté activa (ya no debería ser posible llegar a este estado). Como salvaguarda adicional de bajo costo, se recomienda (opcional, no bloqueante) que `RemoveAutoCreatedJobPlanningLine`/`CleanupOnAfterDeleteSalesLine` limpien `SalesLine."Job Contract Entry No." := 0` también en la rama `if not JobPlanningLine.FindFirst() then` (hoy ese `exit` no lo hace) — puramente defensivo, útil para sanear cualquier línea que ya haya quedado huérfana **antes** de este documento (incluidas posiblemente algunas de las 14 líneas de P01414, si Falla 2 ya corrió sobre ellas antes de la Falla 1). Si se decide incluir, agregar:

```al
local procedure RemoveAutoCreatedJobPlanningLine(var SalesLine: Record "Sales Line")
begin
    if SalesLine."Job Contract Entry No." = 0 then
        exit;

    JobPlanningLine.SetCurrentKey("Job Contract Entry No.");
    JobPlanningLine.SetRange("Job Contract Entry No.", SalesLine."Job Contract Entry No.");
    if not JobPlanningLine.FindFirst() then begin
        SalesLine."Job Contract Entry No." := 0;   // <-- nuevo: sanea el huérfano en vez de dejarlo intacto
        exit;
    end;
    ...
```//comprobar equivalente en CleanupOnAfterDeleteSalesLine

## 6. Plan de implementación

1. **(Bloqueante, hacer primero)** Abrir P01414 en el cliente BC (`SandboxBH`) y confirmar si es "Pedido de venta" o "Factura de venta". Si es Factura, detener aquí y escalar de vuelta al arquitecto — el diagnóstico de la sección 3.1 no aplicaría y hace falta una sesión de Snapshot Debugger (usar la configuración "AL: Generated Snapshot request" de `launch.json`) capturando el clic de "Registrar" para obtener la pila de llamadas real.
2. Si se confirma que es un Pedido: correr una consulta de solo lectura (`Sales Line WHERE "Document Type" = Order AND "Job No." <> ''`) para dimensionar el problema — ¿es solo P01414 o hay más Pedidos residuales de la ventana 2026-09-01/2026-09-14?
3. Escribir y ejecutar, una sola vez, el procedimiento de limpieza de la sección 5.1 (codeunit temporal, se borra después de usarse) sobre todos los Pedidos encontrados en el paso 2. Verificar tras correrlo: `Sales Line` de esos Pedidos con `Job No./Job Task No./Job Contract Entry No.` en blanco/0, y que no quedan `Job Planning Line`/`Job Planning Line Invoice` huérfanas asociadas a esos `Job Contract Entry No.` (buscar por el rango de entry no. que tenían antes de limpiar, anotado en el paso 2).
4. Postear P01414 (ya limpio, sin vínculo a proyecto) como un Pedido normal — debe completarse sin error, confirmando que la Falla 1 no era un defecto de código.
5. Agregar el campo `AllowInternalJobPlanningLineDeletion` y el subscriber `BlockManualDeleteOfAutoCreatedJobPlanningLine` (sección 5.2) en `Cod60123.salesJobPlanningMgt.al`. Envolver los dos `JobPlanningLine.Delete(true)` existentes (`RemoveAutoCreatedJobPlanningLine`, `CleanupOnAfterDeleteSalesLine`) con el flag.
6. (Opcional, recomendado) Agregar el saneamiento de huérfanos de la sección 5.3 en ambos procedimientos.
7. Probar Falla 2 corregida: crear una Factura de venta nueva, línea Tipo=Artículo, asignar proyecto (se crea la `Job Planning Line` oculta) — ir a la ficha de Proyecto → Líneas de planificación, intentar borrar esa línea manualmente (con la columna "N.º mov. contrato proyecto" visible, igual que en el incidente) → debe fallar con el nuevo mensaje `CannotDeleteFromJobErr`, sin borrar nada.
8. Control de regresión: sobre una `Job Planning Line` facturable genuina (creada por el asistente estándar "Crear factura de venta", NO por este desarrollo), confirmar que SIGUE pudiéndose borrar con normalidad desde la ficha de Proyecto (el nuevo subscriber no debe interferir).
9. Control de regresión: borrar una línea de una Factura de venta (borrador) que tenga proyecto asignado — confirmar que `CleanupOnAfterDeleteSalesLine` sigue funcionando (borra la `Job Planning Line` oculta sin que el nuevo guard se interponga, gracias al flag).
10. Crear una Factura de venta nueva y directa (sin ningún Pedido de por medio, siguiendo el único camino soportado hoy), línea Tipo=Artículo con proyecto, y postearla de punta a punta — confirmar que NO reproduce la Falla 1 (validación de que el diagnóstico de la sección 3.1 es correcto y el problema estaba acotado a Pedidos residuales, no al flujo de Factura soportado).
11. Documentar en `CLAUDE.md`, sección de la integración Jobs↔Ventas, el hallazgo de la sección 3.3 (Job Ledger Entry Sale-only) como una limitación de diseño conocida y confirmada — para que no se re-investigue en el futuro sin releer este documento.
12. Llevar la conclusión de la sección 3.3 a Cristhian/negocio como una decisión pendiente: ajustar la expectativa a "1 Job Ledger Entry tipo Venta por línea" (sin cambios), o encargar como desarrollo aparte un posteo de Diario de Proyecto (Usage) adicional — con sus propias implicaciones de costo/inventario a diseñar.

## 7. Criterios de aceptación

- **CA1:** P01414, tras el saneamiento, postea como Pedido normal sin ningún error relacionado con `Job No.`.
- **CA2:** una Factura de venta nueva y directa, con línea Tipo=Artículo y proyecto asignado, postea de punta a punta sin la Falla 1 (genera `Job Ledger Entry` tipo Venta + `Item Ledger Entry` normal, igual que documentado en `DIS-2026-08-31-jobs-sales-integration.md` CA2/CA3).
- **CA3:** intentar borrar, desde la ficha de Proyecto → Líneas de planificación, una `Job Planning Line` con `"BH Auto-Created From Sales" = true` falla con el mensaje `CannotDeleteFromJobErr`, sin eliminar el registro.
- **CA4:** una `Job Planning Line` facturable genuina (no creada por este desarrollo) sigue pudiendo borrarse con normalidad desde la ficha de Proyecto.
- **CA5:** borrar una línea de Factura de venta (borrador) con proyecto asignado sigue eliminando correctamente su `Job Planning Line` oculta asociada (el guard de 5.2 no bloquea la limpieza legítima).
- **CA6:** tras postear una Factura de venta con proyecto (CA2), se confirma que se genera exactamente **1** `Job Ledger Entry` (tipo Venta) por línea — no 2 — documentando esto como comportamiento esperado, no como defecto pendiente.

## 8. Riesgos

- **Riesgo del supuesto central (sección 2):** todo el diagnóstico de la Falla 1 depende de que P01414 sea efectivamente un Pedido. Si la verificación del paso 1 del plan lo contradice, este documento debe volver al arquitecto para una segunda ronda de diagnóstico con Snapshot Debugger antes de tocar código.
- **Riesgo de datos:** el procedimiento de limpieza de la sección 5.1 borra registros (`Job Planning Line Invoice`, `Job Planning Line`) y modifica `Sales Line`. Ejecutarlo primero en modo de solo-lectura/reporte (paso 2 del plan) antes de la limpieza real, y conservar el listado de las 14 líneas por si negocio pide reconstruir el vínculo manualmente después.
- **Riesgo residual del `OnBeforeDeleteEvent`:** es un evento de extensibilidad público y estable en v27, pero interno de Base Application (`Table 1003 "Job Planning Line"`), sin garantía de firma estable en versiones futuras — mismo criterio de mitigación que los demás eventos ya usados en este codeunit (repetir verificación al actualizar de versión mayor de BC).
- **Multiempresa:** tanto el saneamiento (5.1) como el subscriber (5.2) aplican igual en todas las empresas del grupo — el saneamiento debe ejecutarse por separado en cada empresa donde existan Pedidos residuales de la ventana 2026-09-01/2026-09-14 (probablemente solo EZGO, donde se hicieron las pruebas, pero verificar).
- **Breaking changes en la BH-API:** ninguno — este documento no toca ningún endpoint de la BH-API.
- **Expectativa de negocio no satisfecha (sección 3.3):** el hallazgo de "solo 1 Job Ledger Entry, no 2" no es un riesgo técnico sino una brecha de expectativa que debe comunicarse explícitamente (plan, paso 12) para evitar que se reporte como un bug pendiente en el futuro.
