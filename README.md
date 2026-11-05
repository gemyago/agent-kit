# agent-kit

Gemyago's kit of tools, prompts, and other stuff for AI and agentic workflows.
Skills use the `gak-` prefix (Gemyago Agent Kit) to distinguish them from other
installed skills.

## Install

Choose either the skills CLI or the Bash installer.

### Skills CLI

Requires Node.js 22.20 or later and npm/npx. Run the first command inside your project for a project install, or use `--global` for a global install:

```bash
npx skills add gemyago/agent-kit
npx skills add gemyago/agent-kit --global
```

The CLI can prompt you to choose skills and supported agents. To select the crew skills directly:

```bash
npx skills add gemyago/agent-kit --skill gak-crew-manager --skill gak-crew-explore
```

The skills CLI installs the skill folders. For the personal configuration,
keep a checkout at `~/.gemyago-agent-kit` and copy the template as described
below. Alternatively, use the Bash installer for both installation and config
initialization. Use one installer per destination: the Bash installer requires
its source metadata before updating an existing skill.

### Bash installer

Requires Bash 3.2 or later and Git. Run the project command from the destination
project; the global command works from any directory. The installer clones the
repository into `~/.gemyago-agent-kit` if needed and installs its HEAD commit.

```bash
# Project install, from the destination project
curl -fsSL https://raw.githubusercontent.com/gemyago/agent-kit/main/install.sh | bash -s -- --target "$PWD"

# Global install
curl -fsSL https://raw.githubusercontent.com/gemyago/agent-kit/main/install.sh | bash -s -- --global
```

With an existing checkout:

```bash
bash ~/.gemyago-agent-kit/install.sh --target "$PWD"
bash ~/.gemyago-agent-kit/install.sh --global
```

`GEMYAGO_AGENT_KIT_HOME` overrides the checkout location.
`GEMYAGO_AGENT_KIT_GLOBAL_SKILLS_DIR` overrides the global skill destination.
The installer refuses to overwrite an existing skill unless its source metadata
identifies it as an agent-kit installation.

## Personal crew configuration

One YAML file configures the crew across projects:

```text
~/.gemyago-agent-kit/
  crew-manager.yaml.template   # Tracked template
  crew-manager.yaml            # Personal configuration, ignored by Git
```

The Bash installer creates `crew-manager.yaml` only when it is missing. It
preserves existing settings on every subsequent install. Edit this file to tune
the models, reasoning efforts, agent names, and delegation policy.

To initialize it manually from a checkout, copy `crew-manager.yaml.template` to
`crew-manager.yaml` at that checkout's root. Keep the personal file out of commits.
The skill reports a missing configuration and offers to initialize it; it does
not silently invent a configured roster.

With a custom `GEMYAGO_AGENT_KIT_HOME`, the config lives in that directory.
Provide its absolute config path when invoking a skill if your harness does not
expose the environment variable. Generated OpenCode entrypoints include the
absolute path automatically. The host must permit reading the config; its
location does not grant filesystem access.

## Use the skills

- [gak-crew-manager](skills/gak-crew-manager/SKILL.md) coordinates a crew of workers.
- [gak-crew-explore](skills/gak-crew-explore/SKILL.md) explores a task and prepares a brief for the manager.
- [gak-checkpoint](skills/gak-checkpoint/SKILL.md) preserves conversation context through numbered checkpoints and forks.

Select the skill in your AI coding tool and follow its instructions. In Codex,
invoke `$gak-crew-manager`, `$gak-crew-explore`, or `$gak-checkpoint`.

Crew manager keeps its supporting instructions under `references/` and its
executable helpers under `scripts/`.

## OpenCode setup

To install the skills into an existing workspace and generate OpenCode agents:

```bash
bash ~/.gemyago-agent-kit/skills/gak-crew-manager/scripts/setup.sh --target /path/to/workspace
```

Setup uses the Bash installer, then reads the personal YAML configuration. The
generator requires Python 3 and PyYAML; it installs PyYAML in a private cache
virtual environment if needed. It grants the manager read access to the personal
configuration and delegation access to the configured workers.

After editing model settings or agent names, regenerate the workspace's agent
definitions:

```bash
bash ~/.gemyago-agent-kit/skills/gak-crew-manager/scripts/sync-opencode-agents.sh --target /path/to/workspace
```

Changes to YAML do not automatically update previously generated definitions.
The generator refuses to overwrite unrelated agent files and removes stale
agents that carry its generation marker.

## Updating older installations

The Bash installer renames legacy `crew-manager`, `crew-explore`, and `checkpoint`
folders only when their source metadata identifies them as agent-kit skills.
It preserves extra files. When the personal config is missing, the checkout's
old `skills/crew-manager/config.yaml` seeds it first, or a recognized legacy
installation's `config.yaml` if the checkout has none. Those settings take
precedence over the template. An existing personal config always wins. The old
checkout config remains ignored by Git.

Unmarked copies and installations managed by another installer are left alone.
After installing the namespaced skills, inspect those older copies and remove
them yourself if they are no longer needed, so both names do not appear in the
skill list. If both a recognized legacy folder and its namespaced replacement
exist, move the legacy folder outside the skill search path before rerunning.
