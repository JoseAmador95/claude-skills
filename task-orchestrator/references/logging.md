# Logging de la tarea

El log es la fuente de verdad del progreso, persistente fuera de tu ventana de
contexto. Si la sesión se alarga o pierdes el hilo, lo reconstruyes leyendo el log.

## Ubicación

`.task-logs/<slug>-<YYYY-MM-DD>.md`, donde `<slug>` es un nombre corto derivado
de la tarea (p. ej. `google-oauth`). Antes de crearlo, asegura que `.task-logs/`
está en `.gitignore`:

```bash
grep -qxF '.task-logs/' .gitignore || echo '.task-logs/' >> .gitignore
```

Alternativa: si prefieres no dejar archivos, puedes usar la tool de memoria de
Claude Code para el mismo contenido. El archivo gitignored es la opción por
defecto porque es inspeccionable y portable entre sesiones.

## Cuándo escribir (por evento, no solo por fase)

El log se escribe **a lo largo de todas las fases, cada vez que pasa algo
relevante**, no únicamente al cerrar cada fase. Dispara una entrada nueva cuando
ocurra cualquiera de estos:

- Información clave aprendida (del análisis, de la implementación, del CI).
- Un **error o bug**, ya afecte directamente a la tarea o lo hayas encontrado de
  casualidad mientras hacías otra cosa. Anótalo aunque no lo vayas a arreglar
  ahora: un bug colateral sin registrar es un bug perdido.
- Una **decisión** (tuya o del usuario) y su porqué.
- Una **desviación** respecto al plan aprobado.
- El cierre de cada fase (entrada de resumen).

La regla mental: si dentro de una semana quisieras saber "¿por qué se hizo esto
así?" o "¿de dónde salió este bug?", debe estar en el log en el momento en que
ocurrió.

## Estructura de cada entrada

Cada entrada (de cierre de fase o de evento puntual) usa
`assets/task-log.template.md`. Campos por entrada:

- **Timestamp**: fecha y hora.
- **Fase**: número y nombre de la fase del workflow.
- **Qué aprendió el agente**: hallazgos relevantes (del análisis, de la
  implementación, del CI…).
- **Qué se debe hacer**: acciones derivadas, pendientes.
- **Cómo afecta al repo**: archivos/módulos impactados, efectos colaterales.
- **Desviaciones del plan inicial**: cualquier cambio respecto a lo previsto y por
  qué (esto es de lo más valioso del log).
- **Conclusión**: estado al cerrar la fase.

## Mirroring a GitHub (opt-in)

Si la tarea viene de un issue, puedes reflejar cada entrada como comentario del
issue para dejar traza pública del progreso. **Es opt-in**: pregunta primero al
usuario, porque escribe en el issue y eso es un efecto externo visible.

Si lo acepta:

```bash
gh issue comment <n> --body-file <ruta-a-la-entrada.md>
```

Mantén el archivo local como registro completo y publica cada entrada nueva como
comentario. No publiques secretos ni rutas internas sensibles en comentarios públicos.
