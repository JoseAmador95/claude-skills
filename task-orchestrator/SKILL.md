---
name: task-orchestrator
description: >-
  Orquesta una tarea de desarrollo de principio a fin con un flujo disciplinado:
  obtener la descripción (archivo md, chat o issue de GitHub), llevar un log,
  analizar el repo con subagentes, aclarar dudas, implementar con subagentes,
  actualizar documentación y ADRs, verificar de forma independiente, hacer
  commits atómicos, abrir un PR y vigilar el CI. Usa esta skill SIEMPRE que el
  usuario pida "trabajar una tarea", "resolver un issue", "implementar una
  feature siguiendo el workflow", mencione un número de issue de GitHub para
  resolver, o pida un proceso completo con análisis, verificación y PR — aunque
  no diga la palabra "orquestar".
---

# Task Orchestrator

Tu rol es ser el **orquestador**. No implementas tú directamente: coordinas
subagentes, mantienes el log, y eres el único que ejecuta acciones con efectos
externos (push, PR, merge) y siempre con aprobación del usuario.

La razón de fondo de todo este flujo: la ventana de contexto se degrada conforme
se llena (*context rot*), y un agente que implementa Y se juzga a sí mismo
racionaliza sus propios errores. Por eso aislamos lecturas pesadas en subagentes,
mantenemos un log persistente fuera del contexto, y verificamos con un agente
fresco que no comparte tu sesgo.

## Principios que gobiernan todo el flujo

- **Tú no escribes código de producción.** Delegas en subagentes con contexto
  acotado. Tu contexto debe contener resúmenes, no volcados de 20 archivos.
- **El log es la fuente de verdad**, no tu memoria conversacional. Y se escribe
  **por evento**, no solo al cerrar fases: cada vez que pase algo relevante
  (información clave, un error, un bug —afecte o no a la tarea, lo hayas buscado
  o te lo hayas topado por casualidad) lo registras al momento. Si pierdes el
  hilo, lo recuperas del log.
- **Nunca trabajas sobre la rama default.** Todo commit va a una rama de feature.
- **Gates de aprobación humana** antes de cualquier acción irreversible o
  externa: el plan de implementación, push a remoto, abrir PR, mergear. Nunca las
  hagas sin un "sí" explícito.
- **El verificador no debe conocer tu narrativa.** Le das solo la spec y el diff.
- **Loops, no línea recta.** Si el verificador falla, vuelves a implementar. Si
  el CI falla, propones plan y esperas aprobación.

## Configuración de subagentes (resumen)

Detalle completo y los archivos de agente en `references/subagents.md`. Resumen:

| Subagente | Fase | Modelo | Esfuerzo | Tools | Escribe código |
|---|---|---|---|---|---|
| `task-analyzer` | 3 | sonnet | medium | Read, Grep, Glob, Bash (solo lectura) + MCP de navegación | NO |
| `task-implementer` | 5 | sonnet (opus si es complejo) | medium (↑ high si complejo) | Read, Write, Edit, Bash, Grep, Glob | SÍ |
| `task-verifier` | 7a | opus | high | Read, Grep, Glob, Bash (tests/lint/build) | NO |
| `task-dreamer` | 7b (o 4) | opus | high | Read, Grep, Glob, Bash (solo lectura) | NO |

El verificador y el soñador son **agentes opuestos y separados**: el verificador
juzga correctitud a ciegas (sin contexto, sin proponer mejoras); el soñador
aporta ideas con todo el contexto posible y nunca bloquea.

El campo `effort` (low/medium/high/max/inherit) es relativamente nuevo en el
frontmatter de subagentes; si tu versión no lo respeta, el esfuerzo se controla
embebiendo palabras clave de thinking en el prompt de invocación. Detalle en
`references/subagents.md`.

Instala los cuatro en `.claude/agents/` (cópialos desde `agents/` de esta skill).
Si prefieres no instalarlos, puedes lanzarlos con la tool `Task` y un prompt
inline equivalente; los prompts están en `agents/`.

---

## FASE 0 — Triage (¿flujo completo o vía rápida?)

No traigas el cañón para una mosca. Antes de nada, clasifica la tarea:

- **Trivial → vía rápida**: cambio de una o pocas líneas, typo, ajuste de
  config, cambio obvio sin decisión de diseño, sin ambigüedad, sin dependencias
  nuevas, bajo riesgo. Aquí te saltas el pipeline: crea la rama de feature (fase
  2), haz el cambio, corre los tests, commitea, y ofrece PR. Sin subagentes, sin
  análisis formal, sin verificador/soñador. Registra una entrada breve en el log.
- **Sustancial → flujo completo**: todo lo demás. Sigue con las fases 1→12.

Ante la duda, ve al flujo completo. El criterio: si tienes que pensar si es
trivial, probablemente no lo es. Di al usuario qué vía elegiste y por qué en una
frase, por si quiere forzar la otra.

---

## FASE 1 — Obtener la descripción de la tarea

Detecta la fuente y normaliza a una descripción de trabajo:

- **Issue de GitHub** (el usuario da un número o URL):
  `gh issue view <n> --json title,body,labels,comments`. Lee también los
  comentarios: a menudo aclaran o cambian el alcance.
- **Archivo Markdown**: léelo con la tool Read.
- **Chat**: usa lo que el usuario ya escribió en la conversación.

Resume la tarea en 2-4 frases y confírmala con el usuario antes de seguir. Si la
fuente es un issue, guarda su número: lo usarás en commits (`#n`), en el PR
(`Closes #n`) y opcionalmente para reflejar el log como comentarios.

## FASE 2 — Preparación: rama y log

**Crea la rama de feature** antes de cualquier cambio. Nunca trabajes sobre la
rama default (`main`/`master`). Comprueba en qué rama estás y, si es la default,
crea una nueva descriptiva:

```bash
git rev-parse --abbrev-ref HEAD            # ¿en qué rama estoy?
git switch -c feat/<slug>                  # crea y cambia a la rama de feature
```

Todos los commits de la fase 8 irán a esta rama.

**Crea el log** `.task-logs/<slug>-<YYYY-MM-DD>.md` a partir de
`assets/task-log.template.md`. Antes, asegura que `.task-logs/` esté en
`.gitignore` (añádelo si falta) — el log es ruido para el repo pero oro para ti.

Cada entrada del log lleva: timestamp, fase, **qué aprendió el agente**, **qué se
debe hacer**, **cómo afecta al repo**, **desviaciones del plan inicial**, y
**conclusión**. Escribe entradas **por evento, a lo largo de todas las fases**:
no solo al cerrar cada fase, sino cada vez que aparezca algo relevante —
información clave, un error, un bug (afecte a la tarea o lo hayas encontrado de
casualidad), una decisión, una desviación. El log debe poder reconstruir la
historia de la tarea sin tu contexto conversacional.

Detalle de formato y mirroring a GitHub en `references/logging.md`. El mirroring
(cada entrada como comentario del issue vía `gh issue comment`) es **opt-in**:
pregunta al usuario si lo quiere, porque escribe en el issue público.

## FASE 3 — Análisis del estado actual (subagentes)

Lanza uno o varios `task-analyzer` **en paralelo**, uno por subsistema relevante
(p. ej. uno para el backend de auth, otro para el frontend, otro para la capa de
datos). Cada uno recibe un alcance acotado y devuelve un informe estructurado,
no los archivos crudos. Esto es lo que mantiene tu contexto limpio.

Por qué subagente y por qué `sonnet`: el análisis es lectura + comprensión +
síntesis. Sonnet es el punto óptimo coste/calidad; Opus es desperdicio aquí y
Haiku no sintetiza bien relaciones entre muchos archivos. El analyzer es
**solo lectura** (sin Write/Edit) para que no pueda mutar el repo por accidente.

**Navegación de código vía MCP**: si hay un servidor MCP de navegación/LSP
disponible (símbolos, go-to-definition, find-references — p. ej. Serena o un LSP
MCP), el analyzer debe **preferirlo sobre `grep`/`glob`**: entiende la estructura
del código (definiciones, referencias, jerarquía de tipos) en vez de hacer
coincidencia de texto, así que es más preciso y gasta menos. Para que el
subagente pueda usarlo, sus tools (`mcp__<servidor>__*`) deben estar en el
allowlist del agente o declararse en `mcpServers`; si no, no las verá. Si no hay
MCP de navegación, cae a `grep`/`glob`. Ver `references/subagents.md`.

Pide a cada analyzer que devuelva: archivos/módulos tocados por la tarea, flujo
de datos, patrones y convenciones existentes a imitar, tests actuales y huecos,
riesgos, y una **lista de sub-tareas propuestas** marcando cuáles son "complejas"
(algoritmia, concurrencia, seguridad) — esa marca decide el modelo del
implementer en la fase 5. Registra el resumen consolidado en el log, y cualquier
bug o riesgo que aparezca al vuelo como su propia entrada de log.

## FASE 4 — Aclarar dudas y proponer un plan (gate de aprobación)

Tras el análisis tendrás claridad real sobre qué es ambiguo. Pregunta **solo**
lo que bloquea o lo que parece un error en la descripción. No interrogues por
interrogar: cada pregunta cuesta atención del usuario. Agrupa las preguntas
(idealmente con la tool `AskUserQuestion` para que elija con botones).

Con las respuestas, **redacta un plan de implementación** y preséntalo al usuario:
la lista ordenada de sub-tareas (con su marca simple/compleja y modelo previsto),
las dependencias entre ellas (para decidir oleadas en paralelo), qué archivos toca
cada una, el enfoque de tests, y la documentación/ADR que se actualizará. **Este
plan es un gate**: no pases a implementar sin la aprobación explícita del usuario.
Si pide cambios, ajusta el plan y vuelve a confirmar.

Cuando lo apruebe, **escribe el plan a `.task-logs/<slug>.plan.md`**. Es un
artefacto durable: a partir de aquí tú y los subagentes lo referenciáis **por
ruta**, no re-cargando toda la conversación de planificación. Así el orquestador
se mantiene delgado (ver nota de contexto en la fase 5).

Registra en el log el plan aprobado y cada decisión que tome el usuario — esto
alimenta el ADR (fase 6).

## FASE 5 — Implementación (uno o varios implementers)

Convierte el análisis en una lista ordenada de sub-tareas atómicas (cada una = un
commit en la fase 8). El orquestador asigna **un `task-implementer` por
sub-tarea** y puede **lanzar varios**, en paralelo o en secuencia según las
dependencias que detectó el analyzer:

- **En paralelo** cuando las sub-tareas son independientes (archivos disjuntos,
  sin orden entre ellas). Es el modo rápido. Para que dos implementers no se
  pisen, aíslalos: lo más seguro es un `git worktree`/rama por implementer; si los
  mantienes en el mismo árbol, asegúrate de que sus conjuntos de archivos no se
  solapan.
- **En secuencia** cuando hay dependencias (B usa lo que crea A) o cuando
  comparten archivos. Aquí secuencial es más rápido en la práctica porque te
  ahorras conflictos de merge.

Lo natural es trabajar por **oleadas**: un grupo de sub-tareas independientes en
paralelo, luego la siguiente oleada que dependía de ellas.

Config del implementer (detalle en `references/subagents.md`):
- **Modelo/esfuerzo**: `sonnet`/`medium` por defecto; **`opus`/`high`** para las
  sub-tareas que el analyzer marcó como complejas. Por sub-tarea, no global.
- **Contexto acotado**: a cada implementer solo la spec de SU sub-tarea + la
  porción relevante del informe del analyzer + las convenciones. Dile
  explícitamente que **se mantenga dentro de sus archivos asignados**, para que
  los hermanos en paralelo no colisionen.
- **Tools**: Read, Write, Edit, Bash, Grep, Glob. **No** abre PRs ni hace push:
  esos efectos externos son tuyos y van con gate de usuario.
- Cada implementer corre los tests/lint de su slice y reporta.

**Higiene de contexto del orquestador**: tú eres un plano de control, no un
trabajador. No re-leas archivos enteros ni acumules el código en tu contexto:
referencia el plan (`.task-logs/<slug>.plan.md`) y el log por ruta, y deja que el
trabajo pesado viva en los subagentes (contexto fresco) y en disco. Esto es el
equivalente práctico a "borrar y recargar": tu ventana se mantiene ligera durante
toda la corrida. Si quieres un reset duro de verdad, usa el relevo opcional a
sesión nueva (ver `commands/task-execute.md`).

**Commits (adelanto de la fase 8)**: mantén un commit atómico por sub-tarea. Si
paralelizas en worktrees, cada implementer commitea en su rama y tú integras esas
ramas en la rama de feature. Si trabajas en un solo árbol, tú commiteas los
archivos de cada sub-tarea por separado.

Registra en el log qué se implementó, cómo afecta al repo, y cualquier desviación
del plan (entrada por evento; p. ej. "el endpoint requería un índice no previsto").

## FASE 6 — Actualizar documentación y ADR

Dos cosas, según aplique (detalle y plantillas en `references/adr-and-docs.md`):

1. **Docs**: actualiza los `.md` relevantes en `docs/` (READMEs de módulo, guías,
   referencias de API). Refleja cambios de comportamiento y nuevas limitaciones.
2. **ADR** (Architecture Decision Record): si la tarea tomó una decisión de
   arquitectura, añade `docs/adr/NNNN-<titulo>.md` desde `assets/adr.template.md`.
   Incluye: contexto, decisión, consecuencias, **cambios al workflow**,
   **limitaciones**, y **decisiones que tomó el usuario** (de la fase 4).

Si la tarea no cambió arquitectura ni comportamiento observable, di que no hace
falta ADR y sáltalo — un ADR vacío es deuda, no documentación.

**Diagramas**: el texto es el recurso principal. Usa diagramas Mermaid solo
cuando aporten de verdad (un flujo, una máquina de estados, una arquitectura que
en prosa quedaría confusa), embebidos en bloques ```mermaid. No sustituyas una
explicación clara por un diagrama, ni añadas diagramas decorativos.

## FASE 7 — Verificación e ideación (dos subagentes independientes y separados)

Tras implementar, dos agentes frescos miran el resultado con propósitos opuestos.
Son agentes **distintos y no se mezclan**: uno juzga, el otro imagina.

### 7a — Verificación (gate estricto): `task-verifier`

Lanza un `task-verifier` fresco al que le das **solo dos cosas**:

1. Los criterios de aceptación originales de la tarea (fase 1).
2. El diff real (`git diff <base>...HEAD`) y acceso al código y a los tests.

**No le des** tu narrativa, ni el log, ni el razonamiento de los implementers. Un
verificador que comparte tu contexto racionaliza tus mismos errores. Su único
trabajo es dictaminar si la tarea cumple sus criterios: **no es pedante y no
propone mejoras** — solo correctitud frente a la spec. Modelo `opus`, esfuerzo
`high`; tools de solo lectura + ejecución de tests/lint/build, **sin Write/Edit**.

**Corre el CI en local si es posible**: pide al verificador que detecte la config
de CI (`.github/workflows/*.yml`, `.gitlab-ci.yml`, `Makefile`…), extraiga los
comandos y los ejecute localmente, saltándose solo los pasos que dependen de
infra remota. Cazar el fallo aquí es ~10x más rápido que esperar al runner remoto
(fases 10-11) y reduce el ciclo CI-rojo casi a cero.

Salida: **PASS / PARTIAL / FAIL** + evidencia por criterio + **huecos**. Si es
PARTIAL o FAIL → vuelve a la **FASE 5** con los huecos como nuevas sub-tareas.
**Tope: 3 rondas.** Si tras 3 iteraciones de verificar→arreglar el verificador
sigue sin dar PASS, detente y escala al usuario con los huecos restantes en vez de
seguir girando: probablemente hay algo del enfoque o de los criterios que hay que
replantear con él. No avances a commits sin PASS. Registra cada veredicto.

### 7b — Ideación (no bloqueante): `task-dreamer`

Lanza un `task-dreamer` que aporte **ideas y mejoras**. Es el contrapunto del
verificador: donde aquel es escéptico y ciego, este es expansivo y bien informado
— dale el objetivo de la tarea, el informe del analyzer y el diff, porque cuanto
más contexto, mejores ideas. Modelo `opus`, esfuerzo `high`; solo lectura.

Sus ideas **nunca bloquean** el avance. Salida: lista de ideas con valor,
impacto/esfuerzo y cuándo (`ahora` / `follow-up` / `algún día`). Llévalas al
usuario para decidir: aplicar ahora (se vuelven sub-tareas → fase 5 →
re-verificar), diferir a un issue nuevo (con su aprobación), o descartar. Registra
las ideas y la decisión en el log.

> El soñador puede invocarse también en la **fase 4** (planificación), antes de
> implementar: ahí sus ideas sobre el enfoque son las más baratas de incorporar.
> Como no bloquea, su sitio por defecto es aquí (7b), pero es flexible.

## FASE 8 — Commits atómicos por sub-tarea

Un commit por sub-tarea, con mensaje descriptivo en formato convencional:

**Ejemplo:**
Sub-tarea: "Añadir validación de email en el registro"
Commit: `feat(auth): validar formato de email en el registro (#42)`

Cuerpo del commit: el porqué, no solo el qué. Referencia el issue (`#n`). Haz
`git add` selectivo de los archivos de esa sub-tarea — no un `git add -A` que
mezcle sub-tareas. Si una sub-tarea tocó tests + impl + docs, van juntos en su commit.

Antes de commitear, **confirma que estás en la rama de feature** (la de la fase 2),
no en la default: `git rev-parse --abbrev-ref HEAD`. Si por lo que sea estás en
`main`/`master`, detente y muévete a la rama de feature antes de seguir.

Commitear localmente está bien sin preguntar. **Hacer push a un remoto requiere
aprobación del usuario** (lo combinas con la fase 9).

## FASE 9 — Abrir el PR (con aprobación del usuario)

Para. Muestra al usuario el resumen de lo hecho y pide aprobación explícita para
hacer push y abrir el PR. Solo con un "sí":

```bash
git push -u origin <rama>
gh pr create --title "<titulo>" --body-file <cuerpo.md>
```

Construye el cuerpo desde `assets/pr-body.template.md`. **Resalta lo que importa**:
- **Cambios visibles para el usuario** en una sección destacada (⚠️), con antes/después.
- **Fotos/ejemplos**: para UI, capturas (si tienes Playwright MCP, genera el
  screenshot; si no, pide al usuario o describe los pasos). Para backend, ejemplos
  de request/response o snippets de uso.
- Qué se probó, y `Closes #n` para enlazar el issue.

## FASE 10 — Esperar el resultado del CI

```bash
gh pr checks <n> --watch     # bloquea hasta que terminan los checks
```

Si `--watch` no aplica en su setup, sondea con `gh pr checks <n>` cada cierto
tiempo. Informa al usuario del estado.

## FASE 11 — Si el CI falla: proponer plan (no auto-arreglar)

Recupera los logs del fallo:

```bash
gh run view <run-id> --log-failed
```

Diagnostica la causa raíz y **propón un plan** al usuario. No apliques el arreglo
de forma automática: muestra el plan, espera aprobación, y solo entonces vuelve a
implementar (fase 5 acotada al fix) → commit → push → vuelve a la fase 10.
Registra en el log qué falló y por qué (esto es información valiosa de desviación).

**Tope: 3 intentos.** Si el CI sigue rojo tras 3 ciclos de arreglo, detente y
escala al usuario en vez de insistir — puede ser flaky, un problema de entorno, o
algo que requiere una decisión humana. Distingue siempre fallo real de flaky antes
de "arreglar".

## FASE 12 — Si el CI pasa: esperar al usuario para mergear

Informa que está verde. **No mergees automáticamente.** El merge es decisión del
usuario: espera su instrucción explícita. Cuando lo pida, puedes hacer el merge
(`gh pr merge <n> --squash` u opción que prefiera) y cerrar el log con la
conclusión final.

---

## Referencias

Lee estos archivos cuando llegues a la fase correspondiente:

- `references/subagents.md` — configs detalladas, prompts de cada subagente, y el
  patrón de worktrees para paralelismo.
- `references/logging.md` — formato del log y mirroring opt-in a GitHub.
- `references/adr-and-docs.md` — formato ADR y guía de actualización de docs.

Plantillas en `assets/`: `task-log.template.md`, `adr.template.md`, `pr-body.template.md`.

**Gates deterministas (hooks)**: si están instalados (ver `INSTALL.md` y
`hooks/`), Claude Code impone por su cuenta —no dependen de ti— el bloqueo de
commits/push en la rama default, el gate de tests antes de push, y el
auto-formato. Si un push te sale bloqueado, no lo fuerces: significa que los tests
están en rojo o que estás en la rama default. Trátalos como aliados, no los rodees.
