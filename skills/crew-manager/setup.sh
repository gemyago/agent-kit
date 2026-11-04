#!/usr/bin/env bash
# Install crew-manager and its crew-explore companion into a target workspace.
#
# Usage: ./setup.sh --target <workspace-dir>
#
# Creates the following inside <workspace-dir>, each folder carrying its own
# .gitignore so the workspace's git status stays clean:
#   .agents/skills/crew-manager/  copy of SKILL.md, shared-rules.md, config.yaml,
#                                 chat-mode.md, commit.md, create-pull-request.md
#   .agents/skills/crew-explore/  copy of SKILL.md
#   .opencode/agents/             generated OpenCode agents
#   tmp/crew-manager/             manager/worker handoff notes and briefs
#
# Existing copies are overwritten. The target directory must already exist.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")"
MANAGER_FILES=(SKILL.md shared-rules.md config.yaml chat-mode.md commit.md create-pull-request.md)
EXPLORE_FILES=(SKILL.md)

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

# install_skill <skill-name> <file>...
install_skill() {
  local name="$1"
  shift
  local src="$SKILLS_DIR/$name"
  local dest="$TARGET/.agents/skills/$name"
  local file

  for file in "$@"; do
    if [[ ! -f "$src/$file" ]]; then
      echo "error: missing skill file: $src/$file" >&2
      exit 1
    fi
  done

  # When the target already is the checkout this skill lives in, the skill
  # files are in place: copying a file onto itself fails, and ignoring the
  # folder would hide the skill's own sources from git.
  if [[ -d "$dest" && "$(cd "$dest" && pwd -P)" == "$src" ]]; then
    echo "Skill files already in place: $dest"
    return
  fi

  mkdir -p "$dest"
  for file in "$@"; do
    cp -f "$src/$file" "$dest/$file"
  done
  printf '*\n' > "$dest/.gitignore"
  echo "Installed skill files into $dest"
}

install_skill crew-manager "${MANAGER_FILES[@]}"
install_skill crew-explore "${EXPLORE_FILES[@]}"

TMP_DEST="$TARGET/tmp/crew-manager"
mkdir -p "$TMP_DEST"
printf '*\n' > "$TMP_DEST/.gitignore"

"$SCRIPT_DIR/sync-opencode-agents.sh" --target "$TARGET"
