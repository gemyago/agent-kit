# agent-kit

Gemyago's kit of tools, prompts, and other stuff for AI and agentic workflows.

A collection of things I use, build, and experiment with. Some are general-purpose; others are tailored to specific tools or projects.

## What's here

- [crew-manager](skills/crew-manager/SKILL.md): coordinate a small crew of workers, with configuration, shared rules, and OpenCode setup scripts.
- [crew-explore](skills/crew-explore/SKILL.md): explore and plan a task, then write a brief for the crew manager.

## Usage

The crew skills include configuration and helper scripts. A sharing mechanism is still to be decided.

The existing setup script copies both skills into a workspace and generates OpenCode agents:

```bash
./skills/crew-manager/setup.sh --target /path/to/workspace
```

The target workspace must already exist. Setup overwrites existing crew skill copies, adds local Git ignores for generated files, and requires Python 3. If PyYAML is missing, it installs it in a user cache virtual environment.

## Contributing

Suggestions, fixes, and improvements are welcome. Open an issue or a pull request.
