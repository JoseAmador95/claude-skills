# Skills

Repositorio de **skills de Claude Code** y sus dependencias (subagentes y
comandos), empaquetadas como **bundles autocontenidos**: cada skill es una
carpeta de primer nivel que lleva dentro todo lo que necesita.

## Skills disponibles

### [`task-orchestrator/`](task-orchestrator/)

Orquesta una tarea de desarrollo de principio a fin con un flujo disciplinado:
análisis del repo con subagentes, plan con gate de aprobación, implementación
delegada, verificación independiente y escéptica, commits atómicos, PR y
vigilancia del CI.

El bundle es autocontenido:

| Ruta | Qué es |
|---|---|
| `SKILL.md` | La skill (el flujo de 12 fases). |
| `INSTALL.md` | Cómo instalarla a nivel proyecto o usuario. |
| `agents/` | Los 4 subagentes: `task-analyzer`, `task-implementer`, `task-verifier`, `task-dreamer`. |
| `commands/task-execute.md` | Comando de relevo para ejecutar un plan aprobado en una sesión fresca. |
| `hooks/` | Gates deterministas: bloqueo de la rama default, tests antes de push, auto-formato. |
| `assets/` | Plantillas (log de tarea, ADR, cuerpo de PR). |
| `references/` | Documentación de apoyo (subagentes, logging, ADRs). |

**Instalación:** ver [`task-orchestrator/INSTALL.md`](task-orchestrator/INSTALL.md).
Resumen a nivel usuario:

```bash
cp -r task-orchestrator ~/.claude/skills/
cp task-orchestrator/agents/*.md ~/.claude/agents/
cp task-orchestrator/commands/task-execute.md ~/.claude/commands/
```

## Estructura del repositorio

```
.
├── README.md
└── task-orchestrator/        # bundle autocontenido (una carpeta por skill)
    ├── SKILL.md
    ├── INSTALL.md
    ├── agents/
    ├── commands/
    ├── hooks/
    ├── assets/
    └── references/
```

Para añadir otra skill, créala como una carpeta hermana de `task-orchestrator/`
con la misma convención.
