---
name: reference-al-compiler-cli-location
description: Cómo compilar este proyecto AL desde la línea de comandos usando el alc.exe embebido en la extensión de VS Code, sin necesidad de publicar a un sandbox de BC
metadata:
  type: reference
---

CLAUDE.md dice "No hay CLI de build" (cierto en el sentido de que no hay un script/tarea configurada), pero el compilador `alc.exe` de la extensión oficial `ms-dynamics-smb.al` de VS Code SÍ está disponible localmente y permite compilar sin publicar a un entorno BC:

```
"/c/Users/Cristhian López/.vscode/extensions/ms-dynamics-smb.al-17.0.2273547/bin/win32/alc.exe" \
  "/project:c:\Users\Cristhian López\API-DYNAMICS-BUSINESS-CENTRAL" \
  "/packagecachepath:c:\Users\Cristhian López\API-DYNAMICS-BUSINESS-CENTRAL\.alpackages" \
  "/out:<ruta_temporal>\_build_test.app"
```

Notas:
- La versión exacta de la carpeta de la extensión puede cambiar si se actualiza VS Code; buscar con `find "$HOME/.vscode/extensions" -maxdepth 1 -iname "*al*"` si el path deja de existir.
- `/project` y `/packagecachepath` deben ser rutas absolutas completas (con el espacio en "Cristhian López" sin escapar raro, solo comillas dobles alrededor de todo el argumento `/flag:ruta`) — con ruta relativa (`.` / `.alpackages`) desde bash a veces falla con `AL1049: A project without a manifest must have the /out option specified` aunque el `app.json` exista en el cwd.
- Salida exitosa: `Compilation ended at 'HH:MM:SS.mmm'.` sin líneas `error ALxxxx` entre inicio y fin, exit code 0. Los `.alpackages/` tienen versiones duplicadas de varias dependencias (27.3.x y 27.5.x) pero el compilador no se queja de ambigüedad — usa la más reciente sin advertencia.
- Borrar el `.app` de salida después de compilar (es solo para verificar, no es un artefacto de release real — esos van en `releases/` con su propio proceso).
- Esto NO reemplaza probar en el sandbox real: valida sintaxis, tipos, y existencia/firma de eventos de extensibilidad contra los símbolos descargados, pero no ejecuta ningún trigger (ver [[project-dis-2026-08-31-jobs-sales-blocked]] para un caso donde el orden de `Validate()` en runtime causaba un fallo que la compilación no detectaba).
