#!/usr/bin/env bash
# =============================================================================
# setup.sh — Mission Control installer
# =============================================================================
# Run this from the root of any project to set up Mission Control.
# Creates mission-control-tasks/ with all required files.
#
# Usage:
#   bash ~/.claude/skills/mission-control/setup.sh
#   bash /path/to/skills/mission-control/setup.sh
# =============================================================================

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SKILL_DIR/templates"
TARGET_DIR="$(pwd)/mission-control-tasks"
COMMANDS_DIR="$(pwd)/.claude/commands"

# ── Colors ────────────────────────────────────────────────────────────────────
BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
GOLD="\033[33m"
RESET="\033[0m"

header() { echo -e "\n${GOLD}${BOLD}$1${RESET}"; }
ok()     { echo -e "  ${GREEN}✓${RESET} $1"; }
ask()    { echo -e "  ${BOLD}$1${RESET}"; }

# ── Guard ─────────────────────────────────────────────────────────────────────
if [[ -d "$TARGET_DIR" ]]; then
  echo -e "${BOLD}mission-control-tasks/ already exists.${RESET}"
  read -rp "  Overwrite? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

# =============================================================================
# 1. Project name
# =============================================================================
header "Mission Control Setup"
echo -e "${DIM}  Answer a few questions to configure the orchestrator for this project.${RESET}\n"

ask "Project name (e.g. myapp, gremio-ink):"
read -rp "  > " PROJECT_NAME
PROJECT_NAME="${PROJECT_NAME:-myproject}"

# =============================================================================
# 2. Agents
# =============================================================================
header "Agents"
echo -e "${DIM}  Define the repos/agents this orchestrator will delegate work to.${RESET}"
echo -e "${DIM}  Each agent = a directory in this repo + a Claude sub-agent.${RESET}\n"

AGENTS=()
AGENT_TABLE_MD=""
AGENT_TABLE_ORCHESTRATOR=""
STATE_AGENTS_JSON='  "orchestrator": { "status": "idle", "heartbeat": null, "current_task": null }'

while true; do
  ask "Agent name (e.g. backend, frontend, mobile) — or press Enter to finish:"
  read -rp "  > " AGENT_NAME
  [[ -z "$AGENT_NAME" ]] && break

  ask "  Subdir path for $AGENT_NAME (e.g. backend/, src/api/):"
  read -rp "  > " AGENT_PATH
  AGENT_PATH="${AGENT_PATH:-${AGENT_NAME}/}"

  ask "  Stack description for $AGENT_NAME (e.g. Django · PostgreSQL · Redis):"
  read -rp "  > " AGENT_STACK

  ask "  Role description for $AGENT_NAME (e.g. REST API + Celery workers):"
  read -rp "  > " AGENT_ROLE

  AGENTS+=("$AGENT_NAME")
  AGENT_TABLE_MD+="| \`${AGENT_NAME}\` | \`${AGENT_PATH}\` | ${AGENT_STACK} | ${AGENT_ROLE} |\n"
  AGENT_TABLE_ORCHESTRATOR+="| \`${AGENT_NAME}\` | ${AGENT_NAME} | \`${AGENT_PATH}\` | ${AGENT_STACK} — ${AGENT_ROLE} |\n"
  STATE_AGENTS_JSON+=",\n  \"${AGENT_NAME}\": { \"status\": \"idle\", \"heartbeat\": null, \"current_task\": null }"

  ok "Added agent: $AGENT_NAME"
done

# =============================================================================
# 3. ntfy topic (optional)
# =============================================================================
header "Push Notifications (ntfy.sh)"
echo -e "${DIM}  Optional — receive push notifications on your phone for each orchestrator cycle.${RESET}"
echo -e "${DIM}  Leave empty to skip.${RESET}\n"

ask "ntfy.sh topic (e.g. myproject-orch):"
read -rp "  > " NTFY_TOPIC
NTFY_TOPIC="${NTFY_TOPIC:-}"

# =============================================================================
# 4. Project context for the orchestrator
# =============================================================================
header "Project Context"
echo -e "${DIM}  A short description the orchestrator will use when delegating tasks.${RESET}\n"

ask "One-line description of what this project does:"
read -rp "  > " PROJECT_DESC
PROJECT_DESC="${PROJECT_DESC:-Software project}"

ask "API base URL for development (e.g. http://localhost:8000):"
read -rp "  > " API_BASE_URL
API_BASE_URL="${API_BASE_URL:-http://localhost:8000}"

# =============================================================================
# Build files
# =============================================================================
header "Installing Mission Control..."
mkdir -p "$TARGET_DIR" "$TARGET_DIR/plans" "$COMMANDS_DIR"

REPO_ROOT="$(pwd)"
CRON_PATH="$TARGET_DIR/orchestrate.sh"

# ── orchestrate.sh ─────────────────────────────────────────────────────────
NTFY_DEFAULT="${NTFY_TOPIC:-${PROJECT_NAME}-orch}"
sed \
  -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
  -e "s|{{NTFY_TOPIC_DEFAULT}}|${NTFY_DEFAULT}|g" \
  "$TEMPLATES_DIR/orchestrate.sh" > "$TARGET_DIR/orchestrate.sh"
chmod +x "$TARGET_DIR/orchestrate.sh"
ok "orchestrate.sh"

# ── ORCHESTRATOR.md ────────────────────────────────────────────────────────
# Build the agent routing table rows
AGENT_ROWS=""
for agent in "${AGENTS[@]}"; do
  # Extract path and stack from what we stored (re-parse from AGENT_TABLE_ORCHESTRATOR)
  AGENT_ROWS+="| \`${agent}\` | ${agent} | see state.json |\n"
done

sed \
  -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
  -e "s|{{PROJECT_DESC}}|${PROJECT_DESC}|g" \
  -e "s|{{API_BASE_URL}}|${API_BASE_URL}|g" \
  -e "s|{{REPO_ROOT}}|${REPO_ROOT}|g" \
  "$TEMPLATES_DIR/ORCHESTRATOR.md" > "$TARGET_DIR/ORCHESTRATOR.md"

# Append agent table dynamically
printf "\n## Agent Routing\n\n| task.owner | Team Agent | Submodule | Stack |\n|---|---|---|---|\n" >> "$TARGET_DIR/ORCHESTRATOR.md"
printf "${AGENT_TABLE_ORCHESTRATOR}" >> "$TARGET_DIR/ORCHESTRATOR.md"
printf "\n" >> "$TARGET_DIR/ORCHESTRATOR.md"
ok "ORCHESTRATOR.md"

# ── state.json ─────────────────────────────────────────────────────────────
cat > "$TARGET_DIR/state.json" <<STATE
{
  "objective": {
    "id": "OBJ-001",
    "title": "",
    "description": "",
    "status": "idle",
    "created_at": null,
    "acceptance_criteria": []
  },
  "agents": {
$(printf "${STATE_AGENTS_JSON}")
  },
  "tasks": [],
  "log": []
}
STATE
ok "state.json"

# ── dashboard.html ─────────────────────────────────────────────────────────
sed \
  -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
  "$TEMPLATES_DIR/dashboard.html" > "$TARGET_DIR/dashboard.html"
ok "dashboard.html"

# ── .claude/commands/mission-control.md ────────────────────────────────────
sed \
  -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
  -e "s|{{REPO_ROOT}}|${REPO_ROOT}|g" \
  -e "s|{{CRON_PATH}}|${CRON_PATH}|g" \
  "$TEMPLATES_DIR/mission-control.md" > "$COMMANDS_DIR/mission-control.md"
ok ".claude/commands/mission-control.md"

# =============================================================================
# Done
# =============================================================================
header "Done!"
echo -e "  ${BOLD}mission-control-tasks/${RESET} is ready.\n"
echo -e "  ${DIM}Next steps:${RESET}"
echo -e "  1. Open a Claude Code session in this project"
echo -e "  2. Type ${BOLD}/mission-control${RESET} to define your first objective"
echo -e "  3. The orchestrator will activate the cron when you're ready\n"

if [[ -n "$NTFY_TOPIC" ]]; then
  echo -e "  ${DIM}Push notifications configured for topic:${RESET} ${BOLD}${NTFY_TOPIC}${RESET}"
  echo -e "  ${DIM}Subscribe in the ntfy app on your phone.${RESET}\n"
fi
