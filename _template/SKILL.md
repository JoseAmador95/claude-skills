---
name: <nombre-skill>
description: >-
  <Una o dos frases que expliquen qué hace esta skill y cuándo debe
  activarse. El modelo usa este texto para decidir si invocarla.>
---

# <Nombre legible de la skill>

<!-- Describe aquí el rol que toma el modelo al ejecutar esta skill. -->

## Objetivo

<!-- Qué problema resuelve y qué resultado produce. -->

## Flujo

<!-- Enumera las fases o pasos del flujo. Por ejemplo: -->

1. **Análisis** — ...
2. **Planificación** — ...
3. **Implementación** — ...
4. **Verificación** — ...

## Subagentes

<!-- Lista los subagentes que usa este flujo y en qué fase se invocan.
     Sus definiciones viven en agents/. -->

| Subagente | Fase | Qué hace |
|---|---|---|
| `<nombre-agente>` | Fase X | ... |

## Reglas y restricciones

<!-- Qué no debe hacer el modelo aunque pueda. -->

- ...
