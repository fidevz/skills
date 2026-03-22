# mission-control skill

Autonomous project orchestration system for Claude Code.

## What it does

- Reads `mission-control-tasks/state.json` as the source of truth
- Routes tasks through 5 stages: `backlog → research_planning → in_progress → validating → done`
- Delegates work to your team agents (Claude sub-agents, one per repo/service)
- Runs on a 5-minute cron with mutex to prevent overlapping runs
- Sends push notifications via ntfy.sh (optional)
- Includes a live dashboard (HTML, served by python3)

## Setup in a new project

```bash
bash /path/to/skills/mission-control/setup.sh
```

The script will ask you:
1. Project name
2. Agents (name, path, stack, role) — repeat for as many as you need
3. ntfy.sh topic (optional — for push notifications)
4. API base URL + one-line project description

It generates `mission-control-tasks/` and `.claude/commands/mission-control.md` in your project.

## Generated files

```
mission-control-tasks/
├── orchestrate.sh      ← run by cron every 5 min
├── ORCHESTRATOR.md     ← prompt given to Claude each cycle
├── state.json          ← source of truth (objective + tasks + agents + log)
├── dashboard.html      ← live dashboard (open with python3 -m http.server 4000)
└── plans/              ← Opus-generated plan files per task

.claude/commands/
└── mission-control.md  ← /mission-control slash command for this project
```

## Workflow

1. `/mission-control` → define objective + acceptance criteria
2. `/mission-control` → write tasks to state.json with owners and dependencies
3. `/mission-control` → activate cron
4. Watch the dashboard: `python3 -m http.server 4000`
5. Cron deactivates automatically when all ACs are verified

## Test results

Place a Playwright JSON report at `mission-control-tasks/e2e-results.json` and the dashboard will display it automatically.

```bash
# Example: configure Playwright to output here
npx playwright test --reporter=json > mission-control-tasks/e2e-results.json
```
