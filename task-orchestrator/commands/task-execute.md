---
description: Ejecuta un plan de tarea ya aprobado en una sesión fresca (reset duro de contexto)
argument-hint: <slug del plan, p. ej. google-oauth>
---

Vas a ejecutar un plan de implementación ya aprobado, en una sesión limpia. Este
es el "reset duro" de contexto: no arrastras la conversación de planificación,
solo el plan en disco.

1. Lee el plan en `.task-logs/$1.plan.md` y el log en `.task-logs/$1-*.md`.
2. Retoma el flujo de `task-orchestrator` a partir de la **FASE 5**
   (implementación): el análisis, las preguntas y el plan ya están hechos y
   aprobados; no los repitas.
3. Mantén las mismas reglas: rama de feature, implementers por sub-tarea
   (paralelo/secuencial según el plan), verificador estricto (tope 3 rondas),
   soñador, docs/ADR, commits atómicos, y gates de usuario para push/PR/merge.
4. Sigue registrando en el log por evento.

Si el plan o el log no existen, dilo y no inventes: probablemente la tarea no
llegó a aprobar plan y hay que empezar por la FASE 0.
