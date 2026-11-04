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

Requires Bash 3.2 or later, Git, and standard command-line tools. Run from a checkout containing `install.sh`; `--target` must point to an existing project directory.

```bash
# Project install
bash install.sh --target /path/to/project

# Global install
bash install.sh --global
```

## Use the skills

- [crew-manager](skills/crew-manager/SKILL.md) helps coordinate a small crew of workers.
- [crew-explore](skills/crew-explore/SKILL.md) helps explore a task and prepare a brief for the crew manager.

After installing, select the skill in your AI coding tool and follow its instructions. Before using `crew-manager` or the OpenCode setup, copy its `config.yaml.template` to `config.yaml` in the same directory and edit it for your environment.

Optional: to copy both skills into an existing workspace and configure OpenCode, run `./skills/crew-manager/setup.sh --target /path/to/workspace` from a checkout. It requires Python 3.
