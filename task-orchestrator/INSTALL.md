# Instalación — task-orchestrator

Esta carpeta es una **skill de Claude Code** más sus tres subagentes y plantillas.

## 1. Instalar la skill

A nivel de proyecto (se comparte con el equipo vía git):

```bash
mkdir -p .claude/skills
cp -r task-orchestrator .claude/skills/
```

O a nivel de usuario (todas tus sesiones):

```bash
mkdir -p ~/.claude/skills
cp -r task-orchestrator ~/.claude/skills/
```

## 2. Instalar los subagentes

Los subagentes van en `.claude/agents/` (no dentro de la skill):

```bash
# proyecto
cp task-orchestrator/agents/*.md .claude/agents/
# o usuario
cp task-orchestrator/agents/*.md ~/.claude/agents/
```

Verifica con `/agents` dentro de Claude Code que aparezcan `task-analyzer`,
`task-implementer`, `task-verifier` y `task-dreamer`.

> Si prefieres no instalar los agentes como archivos, puedes borrar la carpeta
> `agents/` del bundle: el SKILL.md también explica cómo lanzar subagentes
> equivalentes con la tool `Task` y prompts inline (ver `references/subagents.md`).

## 3. Instalar los hooks (gates deterministas, opcional pero recomendado)

Los hooks imponen las reglas que no quieres dejar a criterio del modelo:
bloquear commits/push en la rama default, exigir tests en verde antes de push, y
auto-formatear lo editado.

```bash
# Los scripts ya vienen en la skill; solo hay que cablearlos en settings.json.
# Pega el contenido de hooks/settings.snippet.json en .claude/settings.json
# (fusionándolo con tus hooks existentes si los hay).
chmod +x .claude/skills/task-orchestrator/hooks/*.sh   # por si acaso
```

Requieren `jq`. El comando de test del gate de push se ajusta con la env var
`TASK_TEST_CMD` (default `npm test`). Los hooks fallan "en seguro": si falta `jq`
o un formateador, no rompen nada.

## 4. Instalar el comando de relevo (opcional)

Para el reset duro de contexto (ejecutar un plan aprobado en sesión fresca):

```bash
mkdir -p .claude/commands
cp task-orchestrator/commands/task-execute.md .claude/commands/
```

Uso: en una sesión nueva, `/task-execute <slug>`.

## 5. Requisitos

- `gh` (GitHub CLI) autenticado, para issues, PRs y CI.
- `git` con worktrees (incluido en git moderno) si usas el patrón paralelo.
- `jq` para los hooks. Formateadores opcionales (prettier, ruff, gofmt…) según tu stack.

## 6. Uso

Dentro de Claude Code:

```
Trabaja el issue #42 siguiendo el workflow de task-orchestrator
```

o simplemente describe una tarea y pide "resuélvela con el flujo completo". La
skill se encarga de las 12 fases, deteniéndose a pedir aprobación antes de hacer
push, abrir el PR y mergear.
