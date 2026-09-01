---
name: reference-al-permissionset-object-types
description: Qué tipos de objeto AL admite (y cuáles no) la lista Permissions de un permissionset — tableextension/pageextension no son válidos
metadata:
  type: reference
---

La propiedad `Permissions` de un `permissionset` en AL solo acepta estos tipos de objeto como miembro de la lista: `tabledata`, `table`, `page`, `codeunit`, `report`, `query`, `xmlport`, `system`, `entitlement`. **`tableextension` y `pageextension` NO son tipos válidos ahí** — intentar `tableextension "Nombre" = X` o `pageextension "Nombre" = X` falla con `AL0104: Syntax error, 'tabledata' expected` / `AL0301: A list must end with a member; not a separator ,` (verificado compilando con alc.exe en este proyecto, ver [[reference-al-compiler-cli-location]]).

Razón de fondo: un `tableextension`/`pageextension` no es un objeto ejecutable independiente, solo agrega campos/controles a un objeto base ya cubierto por el permission set de ese objeto base (p. ej. campos nuevos en `Job Planning Line` quedan cubiertos por los permission sets de Jobs de Microsoft, no por el PTE que declaró el `tableextension`). Confirmado también por inspección: ningún `.PermissionSet.al` decompilado de las dependencias de este proyecto (Base Application, System Application) tiene entradas `tableextension`/`pageextension`.

**Cómo aplicar:** cuando un diseño o un reviewer pida "agregar el tableextension/pageextension X al permission set", la corrección correcta es NO agregarlo (el compilador lo rechaza) — documentar en un comentario por qué no aplica y, si el diseño trae un `codeunit` nuevo en el mismo lote, ese sí necesita entrada `codeunit "Nombre" = X` explícita para que sus event subscribers corran para usuarios no-SUPER. Caso real: correcciones de review a DIS-2026-08-31 (`src/PermissionSets/Per60100.bhApiObjects.al`), 2026-09-01. Ver [[project-dis-2026-08-31-jobs-sales-blocked]].
