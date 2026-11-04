# agent-kit

Gemyago's kit of tools, prompts, and other stuff for AI and agentic workflows.

A collection of things I use, build, and experiment with. Some are general-purpose; others are tailored to specific tools or projects.

## What's here

- [crew-manager](skills/crew-manager/SKILL.md): coordinate a small crew of workers, with configuration, shared rules, and OpenCode setup scripts.
- [crew-explore](skills/crew-explore/SKILL.md): explore and plan a task, then write a brief for the crew manager.

## Install with the skills CLI

These are independent installation routes. The [skills CLI](https://github.com/vercel-labs/skills/blob/main/docs/commands.md#skills-add)
reads this repository's `skills/<name>/SKILL.md` layout directly; agent-kit does
not need an npm package. This route requires Node.js 22.20 or later and npm/npx
(see the [CLI prerequisites](https://github.com/vercel-labs/skills#install-a-skill)).

```bash
# Project install: run inside your project and choose skills and agents
npx skills add gemyago/agent-kit

# Global install
npx skills add gemyago/agent-kit --global

# From a local checkout, run inside the destination project
npx skills add /path/to/agent-kit
```

Use `--skill crew-manager --skill crew-explore` to select these skills explicitly.
The CLI manages its own destinations and installation behavior; the custom
metadata and overrides below belong to the Bash route.

## Install with Bash

Requires Bash 3.2 or later, Git, and standard filesystem/text tools such as awk,
find, and mktemp. No Node.js, Python, YAML tools, or package installs are needed.
Both commands install all skills and their tracked support files:

```bash
# From this checkout, into an existing project
bash install.sh --target /path/to/project

# Global install
bash install.sh --global
```

The installer clones `https://github.com/gemyago/agent-kit.git` into
`~/.gemyago-agent-kit` when that checkout is absent, then reads its current HEAD
commit. An existing checkout is reused without fetching or changing branches.
Even when invoked from another checkout, files come from this cache, not the
directory containing the running script.

The following bootstrap commands are for after `install.sh` is published on
`main`. That file is not published there yet; local fixture checks do not verify
live remote bootstrap. Bootstrap also requires curl:

```bash
curl -fsSL https://raw.githubusercontent.com/gemyago/agent-kit/main/install.sh | bash -s -- --global

# Run inside the existing destination project
curl -fsSL https://raw.githubusercontent.com/gemyago/agent-kit/main/install.sh | bash -s -- --target "$PWD"
```

After bootstrap, rerun the cached installer with the same scope:

```bash
bash ~/.gemyago-agent-kit/install.sh --global
bash ~/.gemyago-agent-kit/install.sh --target /path/to/project
```

Global skills go into `~/.agents/skills/`; project skills go into
`<target>/.agents/skills/`. `GEMYAGO_AGENT_KIT_HOME` overrides the cached checkout
location. Its `tmp/` directory holds temporary staging files, removed on exit.
`GEMYAGO_AGENT_KIT_GLOBAL_SKILLS_DIR` overrides only the global destination, for
example for an isolated local check without changing HOME:

```bash
GEMYAGO_AGENT_KIT_HOME="$PWD/tmp/installer-cache" \
GEMYAGO_AGENT_KIT_GLOBAL_SKILLS_DIR="$PWD/tmp/global-skills" \
  bash install.sh --global
```

To install an unpublished local source, point `GEMYAGO_AGENT_KIT_HOME` at an
existing Git checkout. Installation uses committed files from that checkout's
HEAD, excluding ignored, untracked, and uncommitted working-tree changes.
Support files keep their Git executable bit. V1 accepts regular tracked files;
it refuses symlinks, submodules, and destination paths containing symlinks.

Only the installed `SKILL.md` is stamped, under its standard YAML `metadata`:

```yaml
metadata:
  gemyago-source-commit: "<full source commit SHA>"
  gemyago-source-path: "skills/crew-manager"
```

These string fields identify the source for future ownership/version checks.
The source `SKILL.md`, other frontmatter, existing metadata, and body are
preserved. The frontmatter writer supports an unquoted `metadata` key with a
block mapping or `{}`; unsupported shapes fail before copying. It never executes
metadata or user configuration. No destination manifests or bookkeeping files
are created. Tracked support files, including a skill's existing `.gitignore`,
are copied as supplied; no Git exclusions are added automatically.

V1 covers bootstrap, copying, and commit metadata. Rerunning overwrites matching
files, including local edits, and retains extra or obsolete destination files.
There is no supported upgrade workflow, version comparison, ownership-based
deletion, or rollback; an interrupted copy can leave a partial installation.

## Crew configuration and optional OpenCode setup

Installing files does not configure the crew. Before using crew-manager, create
its required `config.yaml` from the installed `config.yaml.template` and review
it for your environment. The Bash installer does not initialize or resolve
configuration or generate OpenCode agents.

The existing, separate setup script copies both skills into a workspace and
generates OpenCode agents:

```bash
./skills/crew-manager/setup.sh --target /path/to/workspace
```

Configure `skills/crew-manager/config.yaml` in the checkout before using this
optional setup. The target workspace must already exist. Setup overwrites
existing crew skill copies, adds local Git ignores for generated files, and
requires Python 3. If PyYAML is missing, it installs it in a user cache virtual
environment. These are behaviors of the existing setup, not the Bash installer.

## Contributing

Suggestions, fixes, and improvements are welcome. Open an issue or a pull request.
