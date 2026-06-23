#!/usr/bin/env bash
# Instalador del bundle task-orchestrator en un destino .claude/.
# Automatiza los pasos manuales documentados en INSTALL.md:
#   1. Instala la skill en  <target>/skills/task-orchestrator
#   2. Instala los agentes en <target>/agents/
#   3. Instala el comando de relevo en <target>/commands/
#   4. Da chmod +x a los hooks instalados
#   5. Fusiona hooks/settings.snippet.json en <target>/settings.json (con jq),
#      sin pisar las claves/hooks existentes del usuario.
#
# Idempotente: re-ejecutar deja el mismo estado final, sin duplicar hooks.
set -euo pipefail

# --- Resolver la ruta del propio script (fuente del bundle) ---------------
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)
SNIPPET="$SCRIPT_DIR/hooks/settings.snippet.json"

# --- Defaults de flags ----------------------------------------------------
MODE="user"          # user | project
PROJECT_DIR=""       # destino para --project (default: cwd)
USE_LINK=0           # 0 copia, 1 symlink
DRY_RUN=0

usage() {
  cat <<'EOF'
Uso: install.sh [opciones]

Instala el bundle task-orchestrator (skill, agentes, comando y hooks) en un
destino .claude/.

Opciones:
  --user            Instala en ~/.claude (por defecto).
  --project [DIR]   Instala en DIR/.claude (DIR por defecto: directorio actual).
  --link            Usa symlinks en vez de copia para skill/agentes/comando,
                    de modo que un 'git pull' del repo actualice la instalación.
  --dry-run         Muestra lo que haría sin tocar nada.
  -h, --help        Muestra esta ayuda.
EOF
}

# --- Parseo de flags ------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --user)
      MODE="user"
      shift
      ;;
    --project)
      MODE="project"
      shift
      # DIR opcional: solo lo consumimos si no es otra flag.
      if [ "$#" -gt 0 ] && [ "${1#-}" = "$1" ]; then
        PROJECT_DIR="$1"
        shift
      fi
      ;;
    --link)
      USE_LINK=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: opción desconocida '$1'." >&2
      usage >&2
      exit 1
      ;;
  esac
done

# --- Calcular el destino --------------------------------------------------
if [ "$MODE" = "project" ]; then
  base_dir="${PROJECT_DIR:-$PWD}"
  TARGET="$base_dir/.claude"
else
  TARGET="$HOME/.claude"
fi

# --- Helpers --------------------------------------------------------------
log() { printf '%s\n' "$*"; }

# Ejecuta un comando, o lo imprime si estamos en dry-run.
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# Instala (copia o symlink) un origen en un destino, idempotente.
install_path() {
  local src="$1" dest="$2"
  if [ "$USE_LINK" -eq 1 ]; then
    # symlink: borra el destino previo (archivo, dir o link) y re-enlaza.
    run rm -rf -- "$dest"
    run ln -s -- "$src" "$dest"
  else
    # copia: para directorios, limpia primero para no dejar restos huérfanos.
    if [ -d "$src" ]; then
      run rm -rf -- "$dest"
    fi
    run cp -R -- "$src" "$dest"
  fi
}

log "task-orchestrator :: instalación"
log "  origen:  $SCRIPT_DIR"
log "  destino: $TARGET"
if [ "$USE_LINK" -eq 1 ]; then
  log "  modo:    symlink"
else
  log "  modo:    copia"
fi
if [ "$DRY_RUN" -eq 1 ]; then
  log "  (dry-run: no se modificará nada)"
fi
log ""

# --- 1. Skill -------------------------------------------------------------
log "1. Instalando skill en $TARGET/skills/task-orchestrator"
run mkdir -p -- "$TARGET/skills"
install_path "$SCRIPT_DIR" "$TARGET/skills/task-orchestrator"

# --- 2. Agentes -----------------------------------------------------------
log "2. Instalando agentes en $TARGET/agents/"
run mkdir -p -- "$TARGET/agents"
for agent in "$SCRIPT_DIR"/agents/*.md; do
  [ -e "$agent" ] || continue
  install_path "$agent" "$TARGET/agents/$(basename -- "$agent")"
done

# --- 3. Comando de relevo -------------------------------------------------
log "3. Instalando comando en $TARGET/commands/task-execute.md"
run mkdir -p -- "$TARGET/commands"
install_path "$SCRIPT_DIR/commands/task-execute.md" "$TARGET/commands/task-execute.md"

# --- 4. chmod +x a los hooks instalados -----------------------------------
log "4. Asegurando permisos de ejecución de los hooks"
# Con symlink, los hooks apuntan al repo; con copia, viven bajo el destino.
# En ambos casos chmod sobre la ruta instalada resuelve el archivo real.
for hook in "$TARGET"/skills/task-orchestrator/hooks/*.sh; do
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] chmod +x %s\n' "$hook"
  else
    [ -e "$hook" ] || continue
    # Nota: BSD chmod (macOS) no soporta el separador '--'; las rutas son
    # absolutas, así que omitirlo es seguro.
    chmod +x "$hook"
  fi
done

# --- 5. Merge de settings.json --------------------------------------------
log "5. Fusionando hooks en $TARGET/settings.json"
SETTINGS="$TARGET/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  log "  AVISO: 'jq' no está disponible; se omite la fusión de settings.json."
  log "  Paso manual: pega el contenido de"
  log "    $SNIPPET"
  log "  en $SETTINGS (fusionándolo con tus hooks existentes)."
else
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] fusionaría $SNIPPET en $SETTINGS (sin duplicar hooks)."
  else
    # Limpiamos las claves de comentario '//' del snippet antes de fusionar.
    snippet_clean=$(jq 'del(.["//"], .["//paths"])' "$SNIPPET")

    if [ -f "$SETTINGS" ]; then
      current=$(cat "$SETTINGS")
    else
      current='{}'
    fi

    # Merge idempotente:
    #  - Las claves de nivel superior del usuario se preservan ('* + snippet'
    #    deja ganar al snippet solo en .hooks, que reconstruimos abajo).
    #  - Para cada evento de hook (PreToolUse, PostToolUse, ...) y cada matcher,
    #    unimos las listas de comandos y deduplicamos por .command, de modo que
    #    re-ejecutar no acumula entradas repetidas.
    merged=$(jq -n \
      --argjson cur "$current" \
      --argjson snip "$snippet_clean" '
      # Funde dos arrays de bloques {matcher, hooks:[...]} agrupando por matcher
      # y deduplicando los hooks por su .command.
      def merge_event(a; b):
        ((a // []) + (b // []))
        | group_by(.matcher)
        | map({
            matcher: .[0].matcher,
            hooks: (map(.hooks // []) | add
                    | unique_by(.command // (. | tojson)))
          });

      # Funde el objeto .hooks evento por evento.
      def merge_hooks(a; b):
        reduce ((a // {}) * (b // {}) | keys_unsorted[]) as $k
          ({}; .[$k] = merge_event(a[$k]; b[$k]));

      $cur
      | .hooks = merge_hooks(($cur.hooks // {}); ($snip.hooks // {}))
      ' )

    printf '%s\n' "$merged" > "$SETTINGS"
    log "  settings.json actualizado (hooks deduplicados)."
  fi
fi

# --- Resumen --------------------------------------------------------------
log ""
log "Instalación completada."
log "  skill:    $TARGET/skills/task-orchestrator"
log "  agentes:  $TARGET/agents/ (task-analyzer, task-implementer, task-verifier, task-dreamer)"
log "  comando:  $TARGET/commands/task-execute.md"
log "  settings: $TARGET/settings.json"
log ""
log "Nota: verifica con /agents dentro de Claude Code que aparezcan los subagentes."
