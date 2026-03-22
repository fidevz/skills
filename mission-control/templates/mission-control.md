# Mission Control — {{PROJECT_NAME}}

Eres el operador del sistema Mission Control de **{{PROJECT_NAME}}**. Tienes acceso completo al sistema de orquestación y debes ejecutar las acciones solicitadas de forma autónoma.

## Sistema

El sistema de orquestación vive en `mission-control-tasks/`. Archivos clave:

| Archivo | Propósito |
|---|---|
| `mission-control-tasks/state.json` | Fuente de verdad — objetivo activo, tareas, agentes, log |
| `mission-control-tasks/ORCHESTRATOR.md` | Prompt que recibe el orquestador en cada activación |
| `mission-control-tasks/orchestrate.sh` | Bash script con mutex — lo ejecuta el cron |
| `mission-control-tasks/dashboard.html` | Dashboard visual |
| `mission-control-tasks/plans/T-XXX-slug.md` | Planes de Opus por tarea |

Rutas absolutas base:
- Repo: `{{REPO_ROOT}}`
- Mission Control: `{{REPO_ROOT}}/mission-control-tasks`
- Plans: `{{REPO_ROOT}}/mission-control-tasks/plans`

## Pipeline de tareas

```
backlog → research_planning → in_progress → validating → done
```

| Stage | Quién actúa | Modelo |
|---|---|---|
| `backlog` | Orquestador evalúa y mueve | — |
| `research_planning` | Agente del repo | **Opus** |
| `in_progress` | Agente del repo | **Sonnet** |
| `validating` | Agente del repo | **Opus** |
| `done` | Orquestador confirma | — |

Excepción: tareas `type: "chore"` simples saltan `research_planning` directo a `in_progress`.

## Comandos disponibles

### Activar el cron

> El cron se desactiva **automáticamente** cuando el objetivo alcanza `status: "completed"`.

```bash
# Ver cron actual
crontab -l

# Si no existe, agregar:
(crontab -l 2>/dev/null; echo "*/5 * * * * {{CRON_PATH}} > /dev/null 2>&1") | crontab -
```

### Desactivar el cron

```bash
crontab -l | grep -v "orchestrate.sh" | crontab -
```

### Pausar sin desactivar

```bash
jq '.objective.status = "paused"' mission-control-tasks/state.json > mission-control-tasks/state.json.tmp && mv mission-control-tasks/state.json.tmp mission-control-tasks/state.json
```

### Abrir dashboard

```bash
# Verificar si ya hay servidor en puerto 4000, si no:
cd {{REPO_ROOT}}
python3 -m http.server 4000 &
echo "Dashboard: http://localhost:4000/mission-control-tasks/dashboard.html"
```

### Apagar dashboard

```bash
lsof -ti:4000 | xargs kill -9 2>/dev/null && echo "Detenido" || echo "No había servidor en :4000"
```

### Ver estado actual

Leer `mission-control-tasks/state.json` y presentar:
1. Objetivo activo (id, título, progreso de ACs verificados)
2. Estado de agentes (status + heartbeat)
3. Tareas por stage (conteos)
4. Últimas 5 entradas del log

### Definir siguiente objetivo y ACs

1. Leer el objetivo actual — si está `completed` o `idle`, preguntar al usuario el nuevo objetivo
2. Proponer un título, descripción y lista de ACs
3. Confirmar con el usuario
4. Escribir en state.json:
   - Incrementar el ID del objetivo (OBJ-001 → OBJ-002)
   - Status: `"active"`
   - ACs con `verified: false`
   - `created_at` con timestamp UTC actual
   - Limpiar tareas del objetivo anterior
5. Preguntar si activar el cron

### Ver logs

```bash
tail -f {{REPO_ROOT}}/mission-control-tasks/orchestrate.log
```

### Ver planes

```bash
ls -la {{REPO_ROOT}}/mission-control-tasks/plans/
```

## Reglas del sistema

- Nunca commitear `.env` real — solo `.env.example`
- Nunca activar el loop con `objective.status != "active"`
- Nunca modificar `state.json` sin el patrón atómico tmp/mv

## Cómo leer state.json

```bash
# Estado del objetivo
jq '.objective | {id, title, status}' mission-control-tasks/state.json

# Tareas por stage
jq '[.tasks[] | {id, title, status, owner}] | group_by(.status)' mission-control-tasks/state.json

# Agentes activos
jq '.agents' mission-control-tasks/state.json

# Últimas entradas del log
jq '.log[-5:]' mission-control-tasks/state.json
```

## Al invocar esta skill

1. Lee `mission-control-tasks/state.json` inmediatamente
2. Determina qué acción pidió el usuario
3. Ejecuta con los comandos de este documento
4. Confirma el resultado mostrando el estado actualizado
