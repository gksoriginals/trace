#!/usr/bin/env bash
# Install Trace skills into host skill folders (whole-agent default).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT=""
DRY=0

usage() {
  cat <<EOF
Usage: ./skills/install.sh [--project DIR] [--dry-run]

Copies Trace skills into:
  ~/.agents/skills/   (Cursor + Codex)
  ~/.cursor/skills/   (Cursor)

With --project, appends one instruction line to that project's AGENTS.md
(creates the file if needed). Skip --project for opted-out projects.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

SKILLS=(memory-writer decide-later session-end-cleanup hygienic-setup)
DESTS=("$HOME/.agents/skills" "$HOME/.cursor/skills")
LINE='Use Trace skills when creating storage (trace-hygienic-setup), when finishing a session that left leftovers (trace-session-end), when a cleanup is doubtful (trace-decide-later), and when recording what the session created (trace-memory-writer).'

copy_skill() {
  local name="$1" dest_root="$2"
  local src="$ROOT/$name"
  local dest="$dest_root/$name"
  if [[ ! -d "$src" ]]; then
    echo "missing skill: $src" >&2
    exit 1
  fi
  if [[ "$DRY" -eq 1 ]]; then
    echo "would copy $src -> $dest"
    return
  fi
  mkdir -p "$dest_root"
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -R "$src/." "$dest/"
  # Shared core next to each install root once
  mkdir -p "$dest_root/trace-shared"
  rm -rf "$dest_root/trace-shared"
  cp -R "$ROOT/shared" "$dest_root/trace-shared"
  echo "installed $name -> $dest"
}

for dest in "${DESTS[@]}"; do
  for skill in "${SKILLS[@]}"; do
    copy_skill "$skill" "$dest"
  done
done

# Point record scripts at shared package via TRACE_SKILLS
if [[ "$DRY" -eq 0 ]]; then
  mkdir -p "$HOME/.trace"
  echo "$ROOT" > "$HOME/.trace/skills_source.txt"
fi

if [[ -n "$PROJECT" ]]; then
  agents="$PROJECT/AGENTS.md"
  if [[ "$DRY" -eq 1 ]]; then
    echo "would ensure line in $agents"
  else
    mkdir -p "$PROJECT"
    touch "$agents"
    if ! grep -Fq "trace-memory-writer" "$agents" 2>/dev/null; then
      printf '\n## Trace\n\n%s\n' "$LINE" >> "$agents"
      echo "added Trace instruction line to $agents"
    else
      echo "Trace instruction already present in $agents"
    fi
  fi
fi

echo "Done. Open the native app via app/README.md (Xcode). Skills work with the app closed."
