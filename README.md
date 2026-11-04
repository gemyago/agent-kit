# agent-kit

Gemyago's kit of tools, prompts, and other stuff for AI and agentic workflows.

## Install

Choose either the skills CLI or the Bash installer.

### Skills CLI

Requires Node.js 22.20 or later and npm/npx. Run the first command inside your project for a project install, or use `--global` for a global install:

```bash
npx skills add gemyago/agent-kit
npx skills add gemyago/agent-kit --global
```

The CLI can prompt you to choose skills and supported agents. To select these skills directly:

```bash
npx skills add gemyago/agent-kit --skill crew-manager --skill crew-explore
```

### Bash installer

Requires Bash 3.2 or later and Git. curl downloads and runs the installer. After it is published on `main`, run the project command from the destination project; the global command works from any directory. The installer clones the repository into `~/.gemyago-agent-kit` if needed.

```bash
# Project install, from the destination project
curl -fsSL https://raw.githubusercontent.com/gemyago/agent-kit/main/install.sh | bash -s -- --target "$PWD"

# Global install
curl -fsSL https://raw.githubusercontent.com/gemyago/agent-kit/main/install.sh | bash -s -- --global
```

If you already have a checkout at `~/.gemyago-agent-kit`, run:

```bash
# Project install, from the destination project
bash ~/.gemyago-agent-kit/install.sh --target "$PWD"

# Global install
bash ~/.gemyago-agent-kit/install.sh --global
```

## Use the skills

- [crew-manager](skills/crew-manager/SKILL.md) helps coordinate a small crew of workers.
- [crew-explore](skills/crew-explore/SKILL.md) helps explore a task and prepare a brief for the crew manager.

After installing, select the skill in your AI coding tool and follow its instructions. Before using `crew-manager` or the OpenCode setup, copy its `config.yaml.template` to `config.yaml` in the same directory and edit it for your environment.

Optional: to copy both skills into an existing workspace and configure OpenCode, run `./skills/crew-manager/setup.sh --target /path/to/workspace` from a checkout. It requires Python 3.
