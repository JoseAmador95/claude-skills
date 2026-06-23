# Configuración de subagentes

Este archivo detalla los tres subagentes del flujo. Cópialos a `.claude/agents/`
(versión canónica en la carpeta `agents/` de esta skill) o lánzalos inline con la
tool `Task` usando estos mismos prompts.

## Por qué subagentes y no hacerlo todo en la sesión principal

Un subagente corre en su **propia ventana de contexto** y devuelve solo su
resultado a la sesión principal. Esto te compra dos cosas:

1. **Aislamiento de contexto**: el analyzer puede leer 30 archivos y devolverte
   una página de resumen. Si lo hicieras en tu contexto, esos 30 archivos se
   quedarían ocupando atención el resto de la sesión (context rot).
2. **Independencia de juicio**: el verifier no ve tu razonamiento, así que no
   hereda tus sesgos ni tus errores.

## Selección de esfuerzo (effort) por subagente

Además del modelo, puedes fijar el **esfuerzo de razonamiento por agente** con el
campo `effort` del frontmatter: `low | medium | high | max | inherit`. Es lo que
permite que el analyzer y el implementer piensen lo justo (medium) mientras el
verifier piensa a fondo (high), sin pagar latencia de más donde no hace falta.

```yaml
---
name: task-verifier
model: opus
effort: high
---
```

Matices importantes:
- El campo `effort` en frontmatter es **relativamente reciente**. Durante buena
  parte de 2026 el único control era la variable global `CLAUDE_CODE_EFFORT_LEVEL`
  (afecta a toda la sesión por igual). Verifica que tu versión de Claude Code
  respeta el `effort` por agente; si no, sube de versión o usa el método de abajo.
- **Variar el esfuerzo por sub-tarea dentro del mismo agente** (simple vs
  compleja) no se hace bien solo con frontmatter, porque es un valor fijo del
  archivo. Dos opciones robustas: (a) mantener dos variantes del implementer (una
  estándar `sonnet`/`medium` y una `task-implementer-deep` `opus`/`high`), o
  (b) embeber palabras clave de thinking en el prompt de invocación —
  "think" < "think hard" < "think harder" < "ultrathink"— que escalan el
  presupuesto de razonamiento de esa invocación concreta.
- Relacionado con el modelo: `model: inherit` usa el modelo de la sesión
  principal; `CLAUDE_CODE_SUBAGENT_MODEL` fija un default para todos los
  subagentes que heredan.

## Navegación de código vía MCP (preferir sobre grep)

Si hay un servidor MCP de navegación o LSP conectado (Serena, un LSP MCP, etc.),
el analyzer debe preferir sus herramientas semánticas (símbolos,
go-to-definition, find-references, jerarquía de tipos) sobre `grep`/`glob`:
entiende la estructura del código en vez de hacer coincidencia de texto, lo que
es más preciso y gasta menos contexto.

Gotcha de instalación: un subagente con `tools` como allowlist **no ve** las
herramientas MCP a menos que las añadas explícitamente. Tienes dos vías:

```yaml
# Vía 1: añadir las tools MCP al allowlist (nombres mcp__<servidor>__<tool>)
tools: Read, Grep, Glob, Bash, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols

# Vía 2: declarar el servidor en el frontmatter
mcpServers:
  serena: { command: "uvx", args: ["--from", "git+https://github.com/oraios/serena", "serena-mcp-server"] }
```

Comprueba con `/mcp` qué servidores y herramientas tienes disponibles antes de
asumir que el analyzer puede navegar semánticamente.

---

## 1. task-analyzer (Fase 3)

**Propósito**: mapear las partes del repo relevantes a la tarea, sin tocar nada.

**Modelo: `sonnet`. Esfuerzo: `medium`.** El análisis es recuperación +
comprensión + síntesis, no razonamiento profundo de varios pasos. Sonnet acierta
el equilibrio coste/calidad. Opus encarece sin ganancia real para explorar; Haiku
encuentra archivos pero flaquea al sintetizar relaciones entre muchos. Escala a
`opus`/`high` solo si el área es genuinamente intrincada (algoritmia densa, código
heredado sin tests).

**Tools**: `Read, Grep, Glob, Bash` (+ herramientas de navegación MCP si las hay,
ver sección anterior). El Bash es **solo lectura**: `git log`, `git blame`,
`git diff`, `rg`, `ls`, `cat`, listar tests. **Sin Write/Edit/MultiEdit** — la
garantía estructural de que un explorador no muta el repo. Prefiere navegación
semántica MCP sobre `grep` cuando esté disponible.

**Paralelismo**: lanza varios a la vez, uno por subsistema, con alcances que no
se solapen. Es el mayor acelerador del flujo: lectura pesada en paralelo, contextos
aislados.

**Qué debe devolver** (pídeselo explícito):
- Archivos y módulos que la tarea tocará.
- Flujo de datos relevante y dependencias.
- Patrones/convenciones existentes a imitar (con rutas de ejemplo).
- Tests actuales que cubren la zona y huecos de cobertura.
- Riesgos y efectos colaterales potenciales.
- **Lista de sub-tareas propuestas**, marcando cada una como `simple` o `compleja`
  (algoritmia / concurrencia / seguridad / migración de datos). Esta marca decide
  el modelo del implementer en la fase 5.

---

## 2. task-implementer (Fase 5)

**Propósito**: implementar UNA sub-tarea atómica con sus tests. El orquestador
asigna uno por sub-tarea y **puede correr varios a la vez**: cada implementer es
una unidad de trabajo independiente, así que escalas lanzando más, no haciendo uno
más grande.

**Modelo y esfuerzo**: `sonnet`/`medium` por defecto (cubre el 70-90% del
trabajo). Usa **`opus`/`high`** para las sub-tareas que el analyzer marcó como
`compleja`. Decisión por sub-tarea, no global: no malgastes Opus en boilerplate
ni te quedes corto con Sonnet en un algoritmo delicado. Como el frontmatter es
fijo, para variar por sub-tarea usa una variante `task-implementer-deep` o embebe
"think harder"/"ultrathink" en la invocación (ver sección de esfuerzo arriba).

**Tools**: `Read, Write, Edit, MultiEdit, Bash, Grep, Glob`. **No** incluyas
capacidad de push ni de abrir PRs: los efectos externos los controla el
orquestador con gate de usuario.

**Contexto acotado**: dale solo (a) la spec de su sub-tarea, (b) la porción del
informe del analyzer que le concierne, y (c) las convenciones del repo (de
CLAUDE.md). No le pases la conversación entera. Un contexto fresco y enfocado
produce mejor código que uno saturado.

**Responsabilidad de tests**: cada implementer corre los tests y el linter de su
slice y reporta verde/rojo. El **commit lo hace el orquestador** (fase 8), para
controlar granularidad y mensaje. Alternativamente, si paralelizas con worktrees,
cada implementer commitea en su propia rama.

### Varios implementers en paralelo (con git worktrees)

Lanza varios implementers a la vez cuando las sub-tareas sean independientes
(módulos separados, sin archivos compartidos). Para aislarlos de verdad, da a cada
uno su `git worktree`: un checkout aislado que comparte el mismo `.git`:

```bash
git worktree add ../proj-subtask-a -b subtask-a
git worktree add ../proj-subtask-b -b subtask-b
```

Lanzas un implementer por worktree en paralelo; al terminar, mergeas las ramas
secuencialmente. El cuello de botella es el merge: con archivos compartidos
aparecen conflictos, así que 5-10 agentes es el límite práctico. En Claude Code
puedes usar `claude --worktree` y subagentes con `isolation: worktree`. Si las
sub-tareas tocan los mismos archivos, **no paralelices**: secuencial es más rápido
en la práctica porque evitas el merge hell.

---

## 3. task-verifier (Fase 7a)

**Propósito**: dictaminar de forma independiente si la tarea cumple sus criterios
de aceptación. Es el contrapeso al sesgo del orquestador. Juzga correctitud, nada
más: no es pedante y no propone mejoras (eso es trabajo del soñador, abajo).

**Modelo: `opus`. Esfuerzo: `high`.** Aquí sí: la verificación es donde más rinde
el razonamiento fuerte, corre una sola vez por tarea, y su veredicto decide si hay
re-trabajo. El coste está acotado. Sonnet es aceptable solo si el presupuesto
aprieta. La postura es **escéptica y a ciegas** a propósito.

**Tools**: `Read, Grep, Glob, Bash` (correr tests, lint, build). **Sin Write/Edit**
— su trabajo es juzgar, no arreglar. Si pudiera editar, "arreglaría" en silencio
los huecos y perderías la señal.

**Lo que recibe (y lo que NO)**:
- ✅ Los criterios de aceptación originales (fase 1).
- ✅ El diff real: `git diff <base>...HEAD`, y acceso a leer el código y ejecutar tests.
- ❌ NO tu narrativa, NO el log, NO el razonamiento de los implementers.

**Prompt con postura adversaria**: instrúyelo a asumir que la tarea NO está hecha
y a probar lo contrario o enumerar huecos. Algo como: "Eres un revisor escéptico e
independiente. No confíes en ninguna afirmación de que esto funciona; verifícalo
contra los criterios y el código real."

**Salida**:
- Veredicto: `PASS` / `PARTIAL` / `FAIL`.
- Por cada criterio de aceptación: cumplido/no, con evidencia (archivo:línea, o
  salida de test).
- **Huecos**: defectos que bloquean el PASS, respecto a los criterios (accionables).

`PARTIAL` o `FAIL` → el orquestador vuelve a la fase 5 con los huecos como nuevas
sub-tareas. No se avanza a commits/PR sin `PASS`.

---

## 4. task-dreamer (Fase 7b, opcionalmente fase 4)

**Propósito**: aportar ideas y mejoras. Es el rol generativo que se separó del
verificador. Donde el verificador es escéptico, ciego y bloqueante, el soñador es
expansivo, bien informado y **nunca bloquea**.

**Modelo: `opus`. Esfuerzo: `high`.** Las buenas ideas (pensamiento divergente y
luego filtrado) son justo donde rinde el modelo fuerte. Corre una vez, coste acotado.

**Tools**: `Read, Grep, Glob, Bash` de solo lectura (+ navegación MCP si la hay).
**Sin Write/Edit**: propone, no implementa.

**Lo que recibe** (lo contrario del verificador — cuanto más contexto, mejor):
el objetivo de la tarea, el informe del analyzer, y el diff si ya se implementó.

**Salida**: lista de ideas, cada una con valor, impacto/esfuerzo, y cuándo
(`ahora` / `follow-up` / `algún día`), ordenadas por valor. Si no hay nada que
mejorar, que lo diga — es válido.

El orquestador lleva las ideas al usuario, que decide por cada una: aplicarla ahora
(se vuelve sub-tarea → fase 5 → re-verificar), diferirla a un issue nuevo, o
descartarla. Como no bloquea, el soñador puede correr en paralelo al verificador,
o en la fase 4 para que sus ideas sobre el enfoque entren en el plan aprobado.
