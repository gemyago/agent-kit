# agent-kit

Gemyago's skills for AI and agentic workflows.

## Available skills

- [gak-crew-manager](skills/gak-crew-manager/SKILL.md): Coordinate workers through assignments, handoffs, and verification.
- [gak-crew-explore](skills/gak-crew-explore/SKILL.md): Explore a task and prepare a brief for the crew manager.
- [gak-checkpoint](skills/gak-checkpoint/SKILL.md): Preserve useful conversation context through checkpoints and forks.

## Installation

Use the skills CLI from your project, or add `--global` for a personal install:

```bash
npx skills add gemyago/agent-kit
npx skills add gemyago/agent-kit --global
```

Alternatively, use the Bash installer:

```bash
# Project install
curl -fsSL https://raw.githubusercontent.com/gemyago/agent-kit/main/install.sh | bash -s -- --target "$PWD"

# Global install
curl -fsSL https://raw.githubusercontent.com/gemyago/agent-kit/main/install.sh | bash -s -- --global
```

The Bash installer uses the cached checkout's HEAD. Add `--pull` to update it
from its upstream before installing (fast-forward only):

```bash
bash ~/.gemyago-agent-kit/install.sh --global --pull
```

Crew settings live in `~/.gemyago-agent-kit/crew-manager.yaml`. The Bash installer
initializes this file without overwriting existing settings. For a CLI-only
install, create it from [crew-manager.yaml.template](crew-manager.yaml.template).
