#!/usr/bin/env bash
# Generate OpenCode crew-manager agents in a target workspace from the
# personal configuration shared across workspaces (see setup.sh).
#
# Usage: ./sync-opencode-agents.sh --target <workspace-dir>
#
# Reads  ${GEMYAGO_AGENT_KIT_HOME:-$HOME/.gemyago-agent-kit}/crew-manager.yaml
# Writes <workspace-dir>/.opencode/agents/*.md plus a .gitignore beside them
# that lists exactly the generated files, so unrelated agents stay visible to git.
# Needs python3 with PyYAML; if PyYAML is missing it is installed automatically
# into $XDG_CACHE_HOME/crew-manager/venv (default ~/.cache/crew-manager/venv).

set -euo pipefail

usage() {
  echo "usage: $0 --target <workspace-dir>" >&2
  exit 2
}

TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || usage
      TARGET="$2"
      shift 2
      ;;
    --target=*)
      TARGET="${1#--target=}"
      shift
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "error: unexpected argument: $1" >&2
      usage
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "error: --target is required" >&2
  usage
fi
if [[ ! -d "$TARGET" ]]; then
  echo "error: target is not an existing directory: $TARGET" >&2
  exit 1
fi
TARGET="$(cd "$TARGET" && pwd -P)"

SKILL_REL=".agents/skills/gak-crew-manager"
EXPLORE_SKILL_REL=".agents/skills/gak-crew-explore"
KIT_HOME="${GEMYAGO_AGENT_KIT_HOME:-$HOME/.gemyago-agent-kit}"
CONFIG="$KIT_HOME/crew-manager.yaml"
AGENTS_DIR="$TARGET/.opencode/agents"

if [[ ! -f "$CONFIG" ]]; then
  echo "error: config not found: $CONFIG (run setup.sh first)" >&2
  exit 1
fi

if ! command -v python3 > /dev/null 2>&1; then
  echo "error: python3 is required but was not found on PATH" >&2
  exit 1
fi

# PyYAML is needed to read the config. If the system python3 lacks it, install
# it into a private venv under the user cache instead of the system site-packages
# (which may be externally managed) or the target workspace.
PYTHON="python3"
if ! "$PYTHON" -c 'import yaml' > /dev/null 2>&1; then
  VENV_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/crew-manager/venv"
  if [[ ! -x "$VENV_DIR/bin/python" ]] || ! "$VENV_DIR/bin/python" -c 'import yaml' > /dev/null 2>&1; then
    echo "PyYAML not found; installing it into $VENV_DIR" >&2
    if ! python3 -m venv "$VENV_DIR" || ! "$VENV_DIR/bin/python" -m pip install --quiet --disable-pip-version-check pyyaml; then
      echo "error: could not install PyYAML automatically; install it manually (pip install pyyaml)" >&2
      exit 1
    fi
  fi
  PYTHON="$VENV_DIR/bin/python"
fi

# Python writes the generated paths to a file rather than through a pipe or
# command substitution, so its failure stops this script under `set -e`.
mkdir -p "$TARGET/tmp/crew-manager/sync-opencode-agents"
WRITTEN_LIST="$(mktemp "$TARGET/tmp/crew-manager/sync-opencode-agents/written.XXXXXX")"
trap 'rm -f "$WRITTEN_LIST"' EXIT

"$PYTHON" - "$CONFIG" "$AGENTS_DIR" "$SKILL_REL" "$EXPLORE_SKILL_REL" > "$WRITTEN_LIST" <<'PY'
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError as error:
    sys.exit(f"error: PyYAML is required (pip install pyyaml): {error}")

config_path = Path(sys.argv[1])
agents_dir = Path(sys.argv[2])
skill_rel = sys.argv[3]
explore_skill_rel = sys.argv[4]

manager_prompt_prefix = f"./{skill_rel}"
config_path = config_path.resolve()
config_prompt_path = str(config_path)

with config_path.open(encoding="utf-8") as f:
    config = yaml.safe_load(f) or {}

manager = config.get("manager")
if not isinstance(manager, dict):
    sys.exit(f"error: manager block is required in {config_path}")

manager_name = manager.get("agent_name")
manager_description = manager.get("description")
manager_model = manager.get("model")
manager_opencode_model = manager.get("opencode_model") or manager.get("opencodeModel")
manager_reasoning = manager.get("reasoning_effort") or manager.get("reasoningEffort")
if not manager_name:
    sys.exit("error: manager.agent_name is required")
if not manager_description:
    sys.exit("error: manager.description is required")
if not manager_model:
    sys.exit("error: manager.model is required")
if not manager_opencode_model:
    sys.exit("error: manager.opencode_model is required")
if not manager_reasoning:
    sys.exit("error: manager.reasoning_effort is required")

explorer = config.get("explorer")
if not isinstance(explorer, dict):
    sys.exit(f"error: explorer block is required in {config_path}")

explorer_name = explorer.get("agent_name")
explorer_description = explorer.get("description")
explorer_model = explorer.get("model")
explorer_opencode_model = explorer.get("opencode_model") or explorer.get("opencodeModel")
explorer_reasoning = explorer.get("reasoning_effort") or explorer.get("reasoningEffort")
if not explorer_name:
    sys.exit("error: explorer.agent_name is required")
if not explorer_description:
    sys.exit("error: explorer.description is required")
if not explorer_model:
    sys.exit("error: explorer.model is required")
if not explorer_opencode_model:
    sys.exit("error: explorer.opencode_model is required")
if not explorer_reasoning:
    sys.exit("error: explorer.reasoning_effort is required")

workers = config.get("workers") or config.get("sub-agents") or config.get("sub_agents")
if not isinstance(workers, dict) or not workers:
    sys.exit(f"error: no workers found in {config_path}")

definitions = []

def write_agent(path: Path, frontmatter: dict, extra_lines: list[str]) -> None:
    definitions.append((path, frontmatter, extra_lines))

agents_dir.mkdir(parents=True, exist_ok=True)

written = []
generated_marker = (
    "Generated by gak-crew-manager sync; edit crew-manager.yaml and re-run."
)

manager_frontmatter = {
    "name": manager_name,
    "description": manager_description,
    "mode": "primary",
    "model": manager_opencode_model,
    "reasoningEffort": manager_reasoning,
    "permission": {
        "*": "deny",
        "glob": "allow",
        "grep": "allow",
        "list": "allow",
        "todowrite": "allow",
        "question": "allow",
        "skill": {
            "*": "deny",
            "notion-user": "allow",
        },
        "read": {
            "*": "deny",
            "*.md": "allow",
            config_prompt_path: "allow",
        },
        "edit": {
            "*": "deny",
            "tmp/crew-manager/**": "allow",
        },
        "bash": {
            "*": "deny",
        },
        "task": {
            "*": "deny",
            **{
                value.get("agent_name") or value.get("sub_agent_name"): "allow"
                for value in workers.values() if isinstance(value, dict)
            },
        },
        "webfetch": "deny",
        "lsp": "deny",
        "external_directory": {
            "*": "deny",
            str(config_path.parent / "**"): "allow",
        },
    },
}
manager_extra = [
    f"<!-- {generated_marker} -->",
    "",
    f"Read `@{manager_prompt_prefix}/SKILL.md` first and follow it as the workflow contract.",
    f"Use the crew configuration at `{config_prompt_path}`; read it before delegating.",
]
manager_path = agents_dir / f"{manager_name}.md"
write_agent(manager_path, manager_frontmatter, manager_extra)
written.append(manager_path)

# The explorer runs in a session forked from the manager's, so its prompt has to
# override the manager role that the inherited history establishes.
explorer_frontmatter = {
    "name": explorer_name,
    "description": explorer_description,
    "mode": "primary",
    "model": explorer_opencode_model,
    "reasoningEffort": explorer_reasoning,
    "permission": {
        "*": "allow",
    },
}
explorer_extra = [
    f"<!-- {generated_marker} -->",
    "",
    f"Read `@./{explore_skill_rel}/SKILL.md` first and follow it as the workflow contract.",
    f"Earlier messages in this session may come from {manager_name}; its role, delegation rules and permission limits do not apply to you.",
]
explorer_path = agents_dir / f"{explorer_name}.md"
write_agent(explorer_path, explorer_frontmatter, explorer_extra)
written.append(explorer_path)

for role, settings in workers.items():
    if not isinstance(settings, dict):
        sys.exit(f"error: workers.{role} must be a mapping")

    agent_id = settings.get("agent_name") or settings.get("sub_agent_name")
    description = settings.get("description")
    model = settings.get("model")
    opencode_model = settings.get("opencode_model") or settings.get("opencodeModel")
    reasoning = settings.get("reasoning_effort") or settings.get("reasoningEffort")
    if not agent_id:
        sys.exit(f"error: workers.{role}.agent_name is required")
    if not description:
        sys.exit(f"error: workers.{role}.description is required")
    if not model:
        sys.exit(f"error: workers.{role}.model is required")
    if not opencode_model:
        sys.exit(f"error: workers.{role}.opencode_model is required")
    if not reasoning:
        sys.exit(f"error: workers.{role}.reasoning_effort is required")

    frontmatter = {
        "name": agent_id,
        "description": description,
        "mode": "subagent",
        "model": opencode_model,
        "reasoningEffort": reasoning,
        "permission": {
            "*": "allow",
        },
    }
    extra = [
        f"<!-- crew-role: {role}; crew-agent: {agent_id} -->",
        f"<!-- {generated_marker} -->",
        "",
        f"Read `@{manager_prompt_prefix}/references/shared-rules.md` first and follow it.",
    ]

    out_path = agents_dir / f"{agent_id}.md"
    write_agent(out_path, frontmatter, extra)
    written.append(out_path)

markers = (generated_marker, "Generated by crew-manager sync; edit its config.yaml and re-run.")
seen = set()
for path, frontmatter, extra_lines in definitions:
    name = frontmatter["name"]
    if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", name):
        sys.exit(f"error: invalid agent name: {name!r}")
    if name in seen:
        sys.exit(f"error: duplicate agent name: {name}")
    seen.add(name)
    if path.is_symlink() or (path.exists() and not path.is_file()):
        sys.exit(f"error: agent path is not a regular file: {path}")
    if path.exists() and not any(marker in path.read_text(encoding="utf-8") for marker in markers):
        sys.exit(f"error: refusing to overwrite an unrelated OpenCode agent: {path}")

for path, frontmatter, extra_lines in definitions:
    body = yaml.safe_dump(frontmatter, sort_keys=False).strip()
    path.write_text("\n".join(["---", body, "---", "", *extra_lines]) + "\n", encoding="utf-8")

written_set = set(written)
for path in agents_dir.glob("*.md"):
    if path in written_set or path.is_symlink() or not path.is_file():
        continue
    content = path.read_text(encoding="utf-8")
    if any(marker in content for marker in markers):
        path.unlink()

# Ignore only what this sync generates; other agents in the folder stay visible.
ignore_lines = [".gitignore"] + sorted(p.name for p in written)
(agents_dir / ".gitignore").write_text("\n".join(ignore_lines) + "\n", encoding="utf-8")

for path in sorted(written):
    print(path)
PY

count=0
while IFS= read -r path; do
  [[ -n "$path" ]] && count=$((count + 1))
done < "$WRITTEN_LIST"

echo "Synced $count OpenCode agents into $AGENTS_DIR"
while IFS= read -r path; do
  [[ -n "$path" ]] && echo "  $path"
done < "$WRITTEN_LIST"
