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

# All scratch stays inside the cached repository, never the system temp folder.
check_directory_path "$checkout/tmp"
mkdir -p "$checkout/tmp"
scratch="$(mktemp -d "$checkout/tmp/install.XXXXXX")"
trap 'rm -rf -- "$scratch"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$scratch/source"

# Read blob objects, not working-tree files or git archive (which can apply
# export-ignore/export-subst). Resolve HEAD only once for a consistent snapshot.
git -C "$checkout" ls-tree -r -z "$commit" -- skills/ > "$scratch/tree"
while IFS= read -r -d '' entry; do
  header="${entry%%$'\t'*}"
  path="${entry#*$'\t'}"
  mode="${header%% *}"
  object="${header##* }"
  case "$mode" in
    100644|100755) ;;
    *) die "unsupported tracked file mode $mode: $path (regular files required)" ;;
  esac
  mkdir -p "$scratch/source/$(dirname "$path")"
  git -C "$checkout" cat-file blob "$object" > "$scratch/source/$path"
  if [[ "$mode" == 100755 ]]; then
    chmod 755 "$scratch/source/$path"
  else
    chmod 644 "$scratch/source/$path"
  fi
done < "$scratch/tree"
git -C "$checkout" cat-file blob "$commit:crew-manager.yaml.template" > "$scratch/crew-manager.yaml.template"
config_path="$checkout/crew-manager.yaml"
[[ ! -L "$config_path" ]] || die "personal configuration must not be a symlink: $config_path"
[[ ! -e "$config_path" || -f "$config_path" ]] || die "personal configuration is not a regular file: $config_path"

owned_skill() {
  local directory="$1" source_path="$2"
  [[ -f "$directory/SKILL.md" ]] || return 1
  awk -v expected="$source_path" '
    NR == 1 { if ($0 != "---") exit; next }
    /^---$|^\.\.\.$/ { exit }
    $1 == "gemyago-source-path:" {
      value=$2; gsub(/"/, "", value)
      if (value == expected) owned=1
    }
    END { exit !owned }
  ' "$directory/SKILL.md"
}

check_skill_files() {
  local directory="$1"
  find "$directory" ! -type d ! -type f -print > "$scratch/conflicts"
  [[ ! -s "$scratch/conflicts" ]] || die "destination skill contains a symlink or special file: $directory"
}

# This is deliberately a parser for our block-style frontmatter, not a YAML
# interpreter. Unsupported metadata shapes fail before any destination writes.
stamp_skill() {
  local file="$1" source_path="$2" body_start
  awk -v sha="$commit" -v source_path="$source_path" -v offset_file="$scratch/body-start" '
    function fail(message) { print "error: " source_path "/SKILL.md: " message > "/dev/stderr"; failed=1; exit 1 }
    function clean(line) { sub(/\r$/, "", line); return line }
    function indentation(line, prefix) { prefix=line; sub(/[^ ].*$/, "", prefix); return length(prefix) }
    NR == 1 { if (clean($0) != "---") fail("expected YAML frontmatter starting with ---") }
    {
      lines[NR]=$0
      if (NR > 1 && (clean($0) == "---" || clean($0) == "...")) { last=NR; exit }
    }
    END {
      if (failed) exit 1
      if (!last) fail("missing closing frontmatter delimiter")
      for (i=2; i<last; i++) {
        line=clean(lines[i])
        if (line ~ /^metadata[ ]*:/) {
          if (meta) fail("duplicate metadata key")
          if (line !~ /^metadata[ ]*:[ ]*(#.*)?$/ && line !~ /^metadata[ ]*:[ ]*\{[ ]*\}[ ]*(#.*)?$/)
            fail("metadata must use a block mapping or {}")
          meta=i
        }
        if (line ~ /^["\047]metadata["\047][ ]*:/)
          fail("metadata must use an unquoted block mapping key")
      }
      stop=last
      indent=0
      if (meta) {
        for (i=meta+1; i<last; i++) {
          line=clean(lines[i])
          if (line ~ /^[ ]*(#.*)?$/) continue
          if (line ~ /^\t/ || line ~ /^[ ]+\t/) fail("metadata indentation must use spaces")
          # The first entry establishes the metadata shape. A sequence can be
          # indented or indentless, and its mapping items can contain colons.
          if (!indent && line ~ /^[ ]*-([ \t]|$)/)
            fail("metadata must use a block mapping, not a sequence")
          if (!indent && (line ~ /^[ ]*\[/ || line ~ /^[ ]*\{/))
            fail("metadata must use a block mapping, not a flow collection")
          width=indentation(line)
          if (!width) { stop=i; break }
          if (!indent || width<indent) indent=width
        }
        if (!indent) indent=2
        for (i=meta+1; i<stop; i++) {
          line=clean(lines[i])
          if (line ~ /^[ ]*(#.*)?$/) continue
          if (indentation(line)==indent && line !~ /^[ ]*[^ #][^:]*:/)
            fail("metadata must contain mapping entries")
          if (indentation(line)==indent && line ~ /^[ ]*["\047]gemyago-source-(commit|path)["\047][ ]*:/)
            fail("source marker keys must be unquoted")
        }
      } else indent=2
      padding=sprintf("%" indent "s", "")
      skipping=0
      for (i=1; i<=last; i++) {
        line=clean(lines[i])
        if (meta && i>meta && i<stop) {
          if (line !~ /^[ ]*(#.*)?$/ && indentation(line)<=indent) skipping=0
          if (indentation(line)==indent && line ~ /^[ ]*gemyago-source-(commit|path)[ ]*:/) skipping=1
          if (skipping && line !~ /^[ ]*(#.*)?$/) continue
        }
        if ((!meta && i==last) || i==meta) {
          if (meta) {
            # Normalize an empty flow mapping, keeping its trailing comment.
            sub(/\{[ ]*\}/, "", lines[i])
            print lines[i]
          } else print "metadata:"
          print padding "gemyago-source-commit: \"" sha "\""
          print padding "gemyago-source-path: \"" source_path "\""
          if (meta) continue
        }
        print lines[i]
      }
      print last+1 > offset_file
    }
  ' "$file" > "$scratch/stamped"
  body_start="$(cat "$scratch/body-start")"
  tail -n "+$body_start" "$file" >> "$scratch/stamped"
  cat "$scratch/stamped" > "$file"
}

count=0
for source in "$scratch/source/skills/"*/SKILL.md; do
  [[ -f "$source" ]] || continue
  name="${source%/SKILL.md}"
  name="${name##*/}"
  [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || die "unsupported skill directory name: $name"
  stamp_skill "$source" "skills/$name"
  skill_destination="$destination/$name"
  check_directory_path "$skill_destination"
  if [[ -d "$skill_destination" ]]; then
    check_skill_files "$skill_destination"
    owned_skill "$skill_destination" "skills/$name" || die "refusing to overwrite a skill not owned by agent-kit: $skill_destination"
  fi
  legacy_name="${name#gak-}"
  legacy_destination="$destination/$legacy_name"
  validation_destination="$skill_destination"
  if [[ "$legacy_name" != "$name" && -d "$legacy_destination" && ! -L "$legacy_destination" ]] && owned_skill "$legacy_destination" "skills/$legacy_name"; then
    check_directory_path "$legacy_destination"
    check_skill_files "$legacy_destination"
    [[ ! -e "$skill_destination" ]] || die "both legacy and namespaced skills exist; move the legacy installation aside: $legacy_destination"
    validation_destination="$legacy_destination"
    printf '%s\n' "$name" >> "$scratch/migrations"
  fi
  find "${source%/SKILL.md}" -type f -print0 > "$scratch/files"
  while IFS= read -r -d '' file; do
    relative="${file#"${source%/SKILL.md}/"}"
    check_directory_path "$(dirname "$validation_destination/$relative")"
    [[ ! -e "$validation_destination/$relative" || -f "$validation_destination/$relative" ]] || die "destination file conflicts with a directory: $validation_destination/$relative"
  done < "$scratch/files"
  count=$((count + 1))
done
[[ "$count" -gt 0 ]] || die "no skills/<name>/SKILL.md files in commit $commit"

# Staging and metadata validation finish before installation begins. Copying
# merges directories: reruns overwrite matching files and retain extra files.
if [[ ! -f "$config_path" ]]; then
  checkout_config="$checkout/skills/crew-manager/config.yaml"
  legacy_config="$destination/crew-manager/config.yaml"
  if [[ -e "$checkout_config" || -L "$checkout_config" ]]; then
    check_directory_path "$(dirname "$checkout_config")"
    [[ -f "$checkout_config" && ! -L "$checkout_config" ]] || die "legacy configuration is not a regular file: $checkout_config"
    cp -p "$checkout_config" "$config_path"
    printf 'Preserved checkout crew configuration in %s\n' "$config_path"
  elif owned_skill "$destination/crew-manager" "skills/crew-manager" && [[ -f "$legacy_config" ]]; then
    cp -p "$legacy_config" "$config_path"
    printf 'Preserved legacy crew configuration in %s\n' "$config_path"
  else
    cp "$scratch/crew-manager.yaml.template" "$config_path"
    printf 'Created personal configuration: %s\n' "$config_path"
  fi
fi
if [[ -f "$scratch/migrations" ]]; then
  while IFS= read -r name; do
    mv "$destination/${name#gak-}" "$destination/$name"
    printf 'Migrated %s to %s\n' "${name#gak-}" "$name"
  done < "$scratch/migrations"
fi
mkdir -p "$destination"
for source in "$scratch/source/skills/"*/SKILL.md; do
  [[ -f "$source" ]] || continue
  source="${source%/SKILL.md}"
  name="${source##*/}"
  mkdir -p "$destination/$name"
  find "$source" -type f -print0 > "$scratch/files"
  while IFS= read -r -d '' file; do
    relative="${file#"$source/"}"
    mkdir -p "$(dirname "$destination/$name/$relative")"
    # Replace files rather than writing through preexisting hard links.
    mv -f "$file" "$destination/$name/$relative"
  done < "$scratch/files"
  printf 'Installed %s into %s\n' "$name" "$destination/$name"
done
printf 'Source commit: %s\n' "$commit"
