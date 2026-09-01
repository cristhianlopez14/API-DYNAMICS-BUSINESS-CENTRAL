---
name: reference-al-decompile-base-app
description: Cómo extraer el código fuente AL real de Microsoft Base Application (y otras dependencias) desde los .app en .alpackages para verificar diseños contra el comportamiento real de BC
metadata:
  type: reference
---

Este proyecto tiene `resourceExposurePolicy.allowDownloadingSource = true` en `app.json`, y los `.app` en `.alpackages/` (p. ej. `Microsoft_Base Application_27.5.46862.52525.app`) traen el código fuente AL completo embebido, no solo símbolos. Un `.app` de BC es un header `NAVX` (8 bytes) seguido de un ZIP estándar — `zipfile.ZipFile` de Python lo abre directo sin necesidad de quitar el header:

```python
import zipfile, io
data = open(r'.alpackages/Microsoft_Base Application_27.5.46862.52525.app','rb').read()
z = zipfile.ZipFile(io.BytesIO(data))
z.namelist()  # rutas tipo src/Projects/Project/Planning/JobPlanningLine.Table.al
content = z.read('src/Sales/Posting/SalesPost.Codeunit.al').decode('utf-8', errors='replace')
```

**Cómo aplicar:** antes de dar por buena una premisa de un diseño que dice "esto ya lo hace BC estándar sin cambios" (p. ej. propagación automática de un campo, gates de un `TestField`, orden de inicialización de un `Codeunit`), extraer y leer el archivo fuente real en vez de confiar solo en el texto del documento de diseño — el documento puede tener un análisis incompleto de una guarda condicional aunque haya citado la función correcta. Ver caso real donde esto encontró un bloqueador: [[project-dis-2026-08-31-jobs-sales-blocked]].
