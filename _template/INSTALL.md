# Instalación — <nombre-skill>

<!-- Descripción breve de qué instala este bundle. -->

## 1. Instalar la skill

A nivel de proyecto (se comparte con el equipo vía git):

```bash
mkdir -p .claude/skills
cp -r <nombre-skill> .claude/skills/
```

O a nivel de usuario (todas tus sesiones):

```bash
mkdir -p ~/.claude/skills
cp -r <nombre-skill> ~/.claude/skills/
```

## 2. Instalar los subagentes

```bash
# proyecto
cp <nombre-skill>/agents/*.md .claude/agents/

# o usuario
cp <nombre-skill>/agents/*.md ~/.claude/agents/
```

<!-- Si no hay subagentes, elimina esta sección. -->

## 3. Instalar los comandos (si los hay)

```bash
mkdir -p .claude/commands
cp <nombre-skill>/commands/*.md .claude/commands/
```

<!-- Si no hay comandos, elimina esta sección. -->

## 4. Instalar los hooks (si los hay)

```bash
chmod +x .claude/skills/<nombre-skill>/hooks/*.sh
# Fusiona hooks/settings.snippet.json en .claude/settings.json
```

<!-- Si no hay hooks, elimina esta sección. -->

## 5. Requisitos

<!-- Lista las dependencias externas (CLI, herramientas, etc.). -->

- ...

## 6. Uso

<!-- Cómo invocar la skill dentro de Claude Code. -->

```
<Ejemplo de prompt o comando slash>
```
