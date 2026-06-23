# Contribuir a este repositorio

Gracias por tu interés en contribuir. Este documento explica las convenciones
del repo para que cualquier skill nueva encaje sin fricciones con las existentes.

---

## Principio fundamental: el bundle autocontenido

Cada skill es una **carpeta de primer nivel** que lleva dentro todo lo que
necesita para funcionar: la skill propiamente dicha, sus subagentes, sus
comandos slash, sus hooks, sus plantillas y su documentación de apoyo. No hay
dependencias implícitas entre skills distintas.

```
<nombre-skill>/
├── SKILL.md              # La skill (frontmatter + instrucciones del flujo)
├── INSTALL.md            # Cómo instalarla
├── agents/               # Subagentes del flujo (dependencias internas)
│   └── *.md
├── commands/             # Comandos slash (dependencias internas)
│   └── *.md
├── hooks/                # Scripts de gate deterministas
│   ├── *.sh
│   └── settings.snippet.json
├── assets/               # Plantillas que usa la skill en tiempo de ejecución
└── references/           # Documentación de apoyo (no se instala, es guía)
```

### Qué va en cada carpeta

| Carpeta | Contenido |
|---|---|
| `agents/` | Un `.md` por subagente. Son **dependencias del flujo**: viven dentro del bundle y se copian a `.claude/agents/` al instalar. |
| `commands/` | Un `.md` por comando slash. También son dependencias internas; se copian a `.claude/commands/` al instalar. |
| `hooks/` | Scripts bash que se cablea en `settings.json`. Incluye `settings.snippet.json` con el fragmento listo para fusionar. |
| `assets/` | Plantillas (markdown, JSON, YAML…) que la skill crea o lee en tiempo de ejecución. |
| `references/` | Documentación de apoyo que el modelo puede leer pero que no se instala en ningún lado. |

---

## Frontmatter requerido

### `SKILL.md`

```yaml
---
name: <nombre-skill>          # identificador único, kebab-case
description: >-
  Una o dos frases. Explica qué hace la skill y cuándo usarla. El
  modelo leerá esto para decidir si activarla.
---
```

### `agents/*.md`

```yaml
---
name: <nombre-agente>         # kebab-case
description: >-
  Qué hace este subagente y en qué fase del flujo se usa.
tools: Read, Bash, Edit       # lista separada por comas
model: sonnet                 # o haiku, opus, etc.
---
```

El CI valida que estos campos existan. Un PR con frontmatter incompleto no
pasará la comprobación.

---

## Anadir una skill nueva

1. **Copia la plantilla:**

   ```bash
   cp -r _template/ <nombre-skill>/
   ```

2. **Rellena `SKILL.md`** — pon el `name`, `description` y el contenido del
   flujo en el cuerpo.

3. **Escribe los subagentes** en `agents/`. Cada archivo es un `.md` con
   frontmatter válido y las instrucciones del subagente en el cuerpo.

4. **Escribe los comandos** en `commands/` si la skill necesita comandos slash.

5. **Rellena `INSTALL.md`** con los pasos específicos de tu skill (qué copiar,
   en qué orden, requisitos).

6. **Elimina las carpetas vacías** que no necesites (o déjalas con su
   `.gitkeep` si las vas a necesitar después).

7. **Actualiza `README.md`** en la raíz añadiendo tu skill a la tabla de
   disponibles.

---

## Cómo instalar y probar

Consulta el `INSTALL.md` de cada skill para los pasos exactos. El patrón
general es:

```bash
# instalar la skill
cp -r <nombre-skill>/ ~/.claude/skills/

# instalar subagentes
cp <nombre-skill>/agents/*.md ~/.claude/agents/

# instalar comandos (si los hay)
cp <nombre-skill>/commands/*.md ~/.claude/commands/
```

Próximamente cada bundle incluirá un `install.sh` que automatiza estos pasos.
Hasta entonces, sigue el `INSTALL.md` de la skill correspondiente.

---

## Estilo y convenciones de escritura

- Los docs van en **español** (este repo, sus README e INSTALL.md).
- Los archivos de agentes y comandos pueden ir en el idioma que mejor sirva al
  modelo, pero el frontmatter (`name`, `description`) va siempre en español si
  describe comportamiento orientado al usuario.
- Nombres de carpetas y de skills en **kebab-case**.
- No rompas la convención de bundle autocontenido: si tu skill necesita algo de
  otra skill, documenta esa dependencia explícitamente en su `INSTALL.md`.
