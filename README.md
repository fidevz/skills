# fidevz/skills

Personal Claude Code skills collection.

## Skills

| Skill | Description |
|---|---|
| [mission-control](mission-control/) | Autonomous project orchestrator — 5-stage pipeline, multi-agent delegation, cron + ntfy.sh push notifications |

## Install

```bash
# Clone to ~/.claude/skills so skills are globally available in Claude Code
git clone git@github.com:fidevz/skills.git ~/.claude/skills
```

Or clone anywhere and symlink:
```bash
git clone git@github.com:fidevz/skills.git ~/skills
ln -s ~/skills/mission-control ~/.claude/skills/mission-control
```

## Usage

After installing, type `/mission-control` in any Claude Code session.

On first use in a new project, it will detect there's no setup and walk you through `setup.sh`.
