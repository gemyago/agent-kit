#!/usr/bin/env bash
# Install the GAK skills and generate OpenCode agents for a workspace.
# Usage: ./setup.sh --target <workspace-dir>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
KIT_HOME="${GEMYAGO_AGENT_KIT_HOME:-$HOME/.gemyago-agent-kit}"
TARGET=""
usage() {
  echo "usage: $0 --target <workspace-dir>" >&2
  exit 2
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || usage
      TARGET="$2"; shift 2 ;;
    --target=*) TARGET="${1#--target=}"; shift ;;
    -h|--help) usage ;;
    *) echo "error: unexpected argument: $1" >&2; usage ;;
  esac
done
[[ -n "$TARGET" && -d "$TARGET" ]] || usage
TARGET="$(cd "$TARGET" && pwd -P)"
INSTALLER="$KIT_HOME/install.sh"
if [[ ! -f "$INSTALLER" ]]; then
  INSTALLER="$SCRIPT_DIR/../../../install.sh"
fi
if [[ ! -f "$INSTALLER" ]]; then
  echo "error: agent-kit checkout not found at $KIT_HOME; run the Bash installer first (see the agent-kit README)" >&2
  exit 1
fi
bash "$INSTALLER" --target "$TARGET"
mkdir -p "$TARGET/tmp/crew-manager"
printf '*\n' > "$TARGET/tmp/crew-manager/.gitignore"
bash "$TARGET/.agents/skills/gak-crew-manager/scripts/sync-opencode-agents.sh" --target "$TARGET"
