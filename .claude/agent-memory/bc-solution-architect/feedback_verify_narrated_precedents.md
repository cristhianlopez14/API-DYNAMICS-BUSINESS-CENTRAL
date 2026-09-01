---
name: precedente-narrado-no-verificable
description: Cuando el usuario cita un precedente técnico (codeunit, extensión, campo custom) de memoria/conversación previa, verificar que exista en código/ambiente real antes de tratarlo como restricción de diseño firme — puede ser un diseño solo conversado en otra sesión, nunca implementado.
metadata:
  type: feedback
---

**Regla:** cuando el usuario (Cristhian López) menciona un objeto AL específico como precedente ("igual que hicimos en el Codeunit X para Compras") pero ese objeto no aparece en este repositorio ni en sus dependencias, no asumir automáticamente que existe en "otra extensión no revisada" — investigar activamente antes de dejarlo como pregunta abierta bloqueante indefinida. La investigación debe cubrir: sistema de archivos local completo del usuario (incluyendo todas las cuentas de nube sincronizadas), `.alpackages/` del repo actual, listado de repos del usuario en GitHub, y verificación directa en "Extensiones instaladas" de los ambientes reales de Business Central (sandbox y producción).

**Por qué:** en el caso de `Codeunit 50100 "OnBeforePostPurchaseDoc"` (diseño DIS-2026-08-31-jobs-sales-integration.md), tras esa investigación se confirmó que el precedente nunca existió como código real — fue un diseño conversado en una sesión previa con Claude.ai (chat web, no Claude Code) que nunca se implementó ni publicó. El usuario lo recordaba y lo citaba como si fuera código existente, sin darse cuenta de que esa sesión anterior nunca llegó a producción. Sin esta verificación, el diseño habría quedado bloqueado indefinidamente esperando "confirmar la ubicación real" de algo que no existe.

**Cómo aplicar:** cuando surja este patrón (precedente citado de memoria, sin ruta de archivo ni repo concreto), tratar la pregunta como investigable por el propio agente/usuario en paralelo (no puramente bloqueante para el arranque del diseño) — avanzar con el supuesto más razonable derivado de decompilar/leer el comportamiento estándar de BC, dejar el supuesto explícito y documentado, y solo bloquear la implementación en los puntos donde el supuesto realmente cambiaría el código (no todo el plan). Una vez verificado que el precedente no existe, cerrar la pregunta formalmente en el documento de diseño con la evidencia de la investigación, no solo borrarla.

**Ver también:** [[pattern-hidden-billable-job-planning-line]] — el diseño donde se originó esta lección.
