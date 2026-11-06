# Repository instructions

## Documentation

- Keep `README.md` short and limited to the minimum needed to discover and install the skills.
- Its first section must list available skills with a brief description and link for each. Its second section must cover installation.
- Do not add sections for implementation details, contributor guidance, validation, migration internals, or agent rules to the README. Keep repository guidance for agents in this file.
- Keep skill-specific workflow instructions in the relevant skill and its supporting references. Do not duplicate them here.
- Use simple language and straight punctuation in text intended for sharing.

## Files and configuration

- Skill folders and their frontmatter names must match and use the `gak-` prefix.
- Keep `SKILL.md` at each skill's root, supporting instructions in `references/`, and executable helpers in `scripts/`. Update callers and links when moving files.
- The tracked crew template is `crew-manager.yaml.template` at the repository root.
- Personal settings live at `${GEMYAGO_AGENT_KIT_HOME:-$HOME/.gemyago-agent-kit}/crew-manager.yaml`. Never commit that file or overwrite it during installation or updates.
- Preserve legacy personal settings during migration, including `skills/crew-manager/config.yaml` in older checkouts. Keep that legacy path ignored by Git.
- Store all temporary files and test fixtures under the workspace's `tmp/` directory, never a system temporary directory or `.tmp/`. Never commit temporary files.

## Installation and OpenCode

- Keep the Bash installer compatible with Bash 3.2 and Git alone. Python and PyYAML are used by OpenCode generation and its tests.
- The Bash installer installs committed files from the checkout's HEAD without changing frontmatter. Keep its destination-to-commit registry in the checkout's ignored `.install-state` file; never add installer metadata to destination directories.
- Updates remove obsolete installed paths using the recorded commit, without checking for local edits. Keep unrelated skill names untouched, preserve personal crew settings, and stop before installation if the recorded commit is unavailable.
- The skills CLI does not maintain this registry. Do not recommend mixing the Bash installer and CLI in the same destination.
- OpenCode setup and regeneration helpers live in `skills/gak-crew-manager/scripts/`. Generate agents from the shared personal YAML, using configured names and settings rather than a fixed roster.
- Model or agent-name changes require regenerating OpenCode definitions. Keep generated prompts and permissions aligned with the actual configuration path and worker names.

## Validation

Install the test dependency and run the integration suite:

```bash
python3 -m pip install 'PyYAML>=6,<7'
python3 -m unittest discover -s tests -v
```

After changing shell scripts, also run:

```bash
bash -n install.sh skills/gak-crew-manager/scripts/setup.sh skills/gak-crew-manager/scripts/sync-opencode-agents.sh
```

Keep the pull request workflow running the integration suite. Before reporting CI
as successful, check the workflow result for the current PR head commit.
