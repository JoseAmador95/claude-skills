# Documentación y ADR

Dos artefactos distintos, según lo que la tarea haya cambiado.

## 1. Documentación (`docs/`)

Actualiza los `.md` afectados cuando la tarea cambie comportamiento observable,
contratos de API, configuración, o introduzca limitaciones nuevas. Ejemplos:
README de un módulo, guía de uso, referencia de endpoints, notas de configuración.

Regla práctica: si alguien que use el proyecto dentro de un mes necesitaría saber
esto, va a docs. Si es solo un detalle interno que se infiere leyendo el código,
no lo dupliques.

**Diagramas (Mermaid)**: el texto es el recurso principal. Un diagrama Mermaid es
bienvenido cuando aclara algo que en prosa quedaría enrevesado —un flujo, una
máquina de estados, las relaciones de una arquitectura— pero nunca como sustituto
de una explicación clara ni como adorno. Embébelo en un bloque ```mermaid dentro
del `.md`. Si dudas de si el diagrama aporta, probablemente no aporta: déjalo en texto.

## 2. ADR (Architecture Decision Record)

Un ADR captura **una decisión de arquitectura** y su porqué, para que el futuro
equipo (o tú dentro de seis meses) entienda por qué las cosas son como son.

**Cuándo crear uno**: la tarea eligió entre alternativas con consecuencias a largo
plazo (un patrón, una librería, un trade-off de diseño, un cambio de contrato).

**Cuándo NO**: cambios triviales, fixes sin decisión de fondo. Un ADR vacío es
deuda, no documentación — sáltalo y dilo.

**Ubicación y numeración**: `docs/adr/NNNN-<titulo-en-kebab>.md`, con `NNNN`
incremental de cuatro dígitos (mira el último existente y suma uno). Usa
`assets/adr.template.md`.

**Campos específicos de este flujo** (además de los estándar Contexto / Decisión /
Consecuencias):
- **Cambios al workflow**: cómo cambia la forma de trabajar el equipo, si aplica.
- **Limitaciones**: qué NO resuelve esta decisión, restricciones conocidas.
- **Decisiones que tomó el usuario**: las respuestas de la fase 4 que moldearon el
  resultado. Atribúyelas explícitamente — son contexto que se pierde si no se anota.

El estado del ADR suele empezar en `Propuesto` y pasar a `Aceptado` al mergear.
