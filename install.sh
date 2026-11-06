#!/usr/bin/env bash
# Install committed agent-kit skills. Also works as: bash -s -- --global
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash install.sh --global [--pull]
       bash install.sh --target /existing/project [--pull]

Install all skills from the cached checkout's HEAD commit.
Create crew-manager.yaml in that checkout if missing; preserve personal settings.
  --global       Install to ~/.agents/skills
  --target DIR   Install to DIR/.agents/skills (DIR must exist)
  --pull         Pull the checkout's upstream first (fast-forward only)
  -h, --help     Show this help

GEMYAGO_AGENT_KIT_HOME overrides the checkout at ~/.gemyago-agent-kit.
GEMYAGO_AGENT_KIT_GLOBAL_SKILLS_DIR overrides only the global skills directory.
EOF
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
argument_error() { printf 'error: %s\n' "$*" >&2; usage >&2; exit 2; }

scope=''
target=''
pull=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)
      [[ -z "$scope" ]] || argument_error 'choose exactly one of --global or --target'
      scope=global
      shift
      ;;
    --target|--target=*)
      [[ -z "$scope" ]] || argument_error 'choose exactly one of --global or --target'
      scope=project
      if [[ "$1" == --target ]]; then
        [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || argument_error '--target requires a directory'
        target="$2"
        shift 2
      else
        target="${1#--target=}"
        [[ -n "$target" ]] || argument_error '--target requires a directory'
        shift
      fi
      ;;
    --pull) pull=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) argument_error "unexpected argument: $1" ;;
  esac
done
[[ -n "$scope" ]] || argument_error 'choose --global or --target'
command -v git >/dev/null 2>&1 || die 'Git is required'
if [[ "$scope" == project ]]; then
  [[ -d "$target" ]] || die "target is not an existing directory: $target"
  target="$(cd "$target" && pwd -P)"
  destination="$target/.agents/skills"
else
  destination="${GEMYAGO_AGENT_KIT_GLOBAL_SKILLS_DIR:-$HOME/.agents/skills}"
fi

# Check every component before creating directories or copying over files.
# Resolving the project itself above still permits a symlink passed as --target.
check_directory_path() {
  local path="$1" parent
  while [[ "$path" != / && "$path" != . ]]; do
    [[ ! -L "$path" ]] || die "directory path contains a symlink: $path"
    [[ ! -e "$path" || -d "$path" ]] || die "not a directory: $path"
    parent="$(dirname "$path")"
    [[ "$parent" != "$path" ]] || break
    path="$parent"
  done
}

# Remove lexical . and .. components before comparing source/destination paths.
normalize_absolute_path() {
  local rest="${1#/}/" component result=''
  while [[ "$rest" == */* ]]; do
    component="${rest%%/*}"
    rest="${rest#*/}"
    case "$component" in
      ''|.) ;;
      ..) result="${result%/*}" ;;
      *) result="$result/$component" ;;
    esac
  done
  printf '%s\n' "${result:-/}"
}

[[ "$destination" == /* ]] || destination="$PWD/$destination"
check_directory_path "$destination"
destination="$(normalize_absolute_path "$destination")"
checkout="${GEMYAGO_AGENT_KIT_HOME:-$HOME/.gemyago-agent-kit}"
[[ "$checkout" == /* ]] || checkout="$PWD/$checkout"
check_directory_path "$checkout"
checkout="$(normalize_absolute_path "$checkout")"
cloned=false
if [[ ! -e "$checkout" ]]; then
  printf 'Cloning agent-kit into %s\n' "$checkout"
  mkdir -p "$(dirname "$checkout")"
  git clone -- https://github.com/gemyago/agent-kit.git "$checkout"
  cloned=true
fi
[[ -d "$checkout/.git" || -f "$checkout/.git" ]] || die "checkout is not a Git working tree: $checkout"
checkout="$(cd "$checkout" && pwd -P)"
[[ "$(git -C "$checkout" rev-parse --show-toplevel)" == "$checkout" ]] || die "checkout must be a Git repository root: $checkout"
case "$destination/" in
  "$checkout/skills/"*) die 'destination must not overwrite checkout skill sources' ;;
esac
if [[ "$pull" == true && "$cloned" == false ]]; then
  printf 'Pulling agent-kit in %s\n' "$checkout"
  git -C "$checkout" pull --ff-only --no-rebase --no-autostash || die 'pull failed; installation stopped'
fi
commit="$(git -C "$checkout" rev-parse --verify 'HEAD^{commit}')"

# All scratch and the shared registry stay inside the cached repository.
check_directory_path "$checkout/tmp"
mkdir -p "$checkout/tmp"
scratch="$(mktemp -d "$checkout/tmp/install.XXXXXX")"
locked=false
lock="$checkout/tmp/install.lock"
trap 'rm -rf -- "$scratch"; if [[ "$locked" == true ]]; then rmdir "$lock"; fi' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$lock" 2>/dev/null || die "another installation holds $lock; remove it if a previous install was interrupted"
locked=true

# The registry is tab-separated data, never shell code. Reject separators in
# destination paths so each installation has exactly one unambiguous record.
case "$destination" in
  *$'\t'*|*$'\n'*) die 'destination must not contain tabs or newlines' ;;
esac
state="$checkout/.install-state"
[[ ! -L "$state" ]] || die "install state must not be a symlink: $state"
[[ ! -e "$state" || -f "$state" ]] || die "install state is not a regular file: $state"
previous=''
: > "$scratch/state"
if [[ -f "$state" ]]; then
  while IFS= read -r record || [[ -n "$record" ]]; do
    [[ "$record" == *$'\t'* ]] || die "invalid install state: $state"
    location="${record%%$'\t'*}"
    sha="${record#*$'\t'}"
    [[ "$location" == /* && "$sha" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] || die "invalid install state: $state"
    if [[ "$location" == "$destination" ]]; then
      [[ -z "$previous" ]] || die "duplicate destination in install state: $destination"
      previous="$sha"
    else
      printf '%s\n' "$record" >> "$scratch/state"
    fi
  done < "$state"
fi
if [[ -n "$previous" ]]; then
  git -C "$checkout" cat-file -e "$previous^{commit}" 2>/dev/null || die "installed commit $previous is unavailable; cannot update $destination"
fi

# Only directories with a root SKILL.md are installed. Use NUL-delimited Git
# output throughout so supporting filenames can contain spaces or newlines.
skill_tree() {
  local revision="$1" output="$2" entry path relative name
  git -C "$checkout" ls-tree -r -z "$revision" -- skills/ > "$scratch/tree"
  : > "$output"
  while IFS= read -r -d '' entry; do
    path="${entry#*$'\t'}"
    relative="${path#skills/}"
    name="${relative%%/*}"
    [[ "$relative" == "$name/SKILL.md" ]] || continue
    [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || die "unsupported skill directory name: $name"
    git -C "$checkout" ls-tree -r -z "$revision" -- "skills/$name/" >> "$output"
  done < "$scratch/tree"
}
skill_tree "$commit" "$scratch/new-tree"
: > "$scratch/old-tree"
if [[ -n "$previous" ]]; then
  skill_tree "$previous" "$scratch/old-tree"
fi
mkdir "$scratch/source" "$scratch/previous"
while IFS= read -r -d '' entry; do
  path="${entry#*$'\t'}"
  relative="${path#skills/}"
  mkdir -p "$scratch/previous/${relative%/*}"
  : > "$scratch/previous/$relative"
done < "$scratch/old-tree"

# Read blob objects, not working-tree files or git archive (which can apply
# export-ignore/export-subst). Resolve HEAD only once for a consistent snapshot.
while IFS= read -r -d '' entry; do
  header="${entry%%$'\t'*}"
  relative="${entry#*$'\t'}"
  relative="${relative#skills/}"
  mode="${header%% *}"
  object="${header##* }"
  case "$mode" in
    100644|100755) ;;
    *) die "unsupported tracked file mode $mode: skills/$relative (regular files required)" ;;
  esac
  mkdir -p "$scratch/source/${relative%/*}"
  git -C "$checkout" cat-file blob "$object" > "$scratch/source/$relative"
  if [[ "$mode" == 100755 ]]; then
    chmod 755 "$scratch/source/$relative"
  else
    chmod 644 "$scratch/source/$relative"
  fi
done < "$scratch/new-tree"
# An empty new skill tree is valid when an update removes the final skill.
[[ -s "$scratch/new-tree" || -n "$previous" ]] || die "no skills/<name>/SKILL.md files in commit $commit"
git -C "$checkout" cat-file blob "$commit:crew-manager.yaml.template" > "$scratch/crew-manager.yaml.template"
config_path="$checkout/crew-manager.yaml"
[[ ! -L "$config_path" ]] || die "personal configuration must not be a symlink: $config_path"
[[ ! -e "$config_path" || -f "$config_path" ]] || die "personal configuration is not a regular file: $config_path"
checkout_config="$checkout/skills/crew-manager/config.yaml"
legacy_config="$destination/crew-manager/config.yaml"
if [[ ! -e "$config_path" ]]; then
  for candidate in "$checkout_config" "$legacy_config"; do
    [[ -e "$candidate" || -L "$candidate" ]] || continue
    check_directory_path "$(dirname "$candidate")"
    [[ -f "$candidate" && ! -L "$candidate" ]] || die "legacy configuration is not a regular file: $candidate"
  done
fi

# Validate every affected skill before changing the destination. Existing files
# at tracked paths are replaced without content or frontmatter ownership checks.
for source in "$scratch/source/"* "$scratch/previous/"*; do
  [[ -d "$source" ]] || continue
  name="${source##*/}"
  skill_destination="$destination/$name"
  [[ ! -L "$skill_destination" ]] || die "destination skill is a symlink: $skill_destination"
  if [[ -d "$skill_destination" ]]; then
    find "$skill_destination" ! -type d ! -type f -print > "$scratch/conflicts"
    [[ ! -s "$scratch/conflicts" ]] || die "destination skill contains a symlink or special file: $skill_destination"
  else
    [[ ! -e "$skill_destination" ]] || die "destination skill is not a directory: $skill_destination"
  fi
done

# A tracked file may become a directory. Its old file will be removed first;
# other files blocking a new directory are a structural conflict.
while IFS= read -r -d '' entry; do
  relative="${entry#*$'\t'}"
  relative="${relative#skills/}"
  parent="$relative"
  while [[ "$parent" == */* ]]; do
    parent="${parent%/*}"
    if [[ -e "$destination/$parent" && ! -d "$destination/$parent" ]]; then
      [[ -f "$scratch/previous/$parent" && ! -f "$scratch/source/$parent" ]] || die "destination file conflicts with a directory: $destination/$parent"
    fi
  done
done < "$scratch/new-tree"

if [[ ! -f "$config_path" ]]; then
  if [[ -f "$checkout_config" ]]; then
    cp -p "$checkout_config" "$config_path"
  elif [[ -f "$legacy_config" ]]; then
    cp -p "$legacy_config" "$config_path"
  else
    cp "$scratch/crew-manager.yaml.template" "$config_path"
  fi
  printf 'Created personal configuration: %s\n' "$config_path"
fi

# Remove obsolete paths even if they were edited locally. Renamed or deleted
# skills lose their old directory, and empty supporting directories are pruned.
for source in "$scratch/previous/"*; do
  [[ -d "$source" ]] || continue
  name="${source##*/}"
  if [[ ! -d "$scratch/source/$name" ]]; then
    rm -rf -- "$destination/$name"
  fi
done
while IFS= read -r -d '' entry; do
  relative="${entry#*$'\t'}"
  relative="${relative#skills/}"
  [[ ! -f "$scratch/source/$relative" ]] || continue
  rm -rf -- "$destination/$relative"
  parent="$relative"
  while [[ "$parent" == */* ]]; do
    parent="${parent%/*}"
    rmdir "$destination/$parent" 2>/dev/null || break
  done
done < "$scratch/old-tree"

mkdir -p "$destination"
while IFS= read -r -d '' entry; do
  relative="${entry#*$'\t'}"
  relative="${relative#skills/}"
  mkdir -p "$destination/${relative%/*}"
  # Replace directories and hard-linked files at incoming file paths as well.
  if [[ -d "$destination/$relative" ]]; then
    rm -rf -- "$destination/$relative"
  fi
  mv -f "$scratch/source/$relative" "$destination/$relative"
done < "$scratch/new-tree"
printf '%s\t%s\n' "$destination" "$commit" >> "$scratch/state"
mv -f "$scratch/state" "$state"
printf 'Installed skills into %s\nSource commit: %s\n' "$destination" "$commit"
