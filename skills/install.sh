#!/usr/bin/env bash
# Install Trace skills into host skill folders (whole-agent default).
# Product skills only (ADR-0004): hygienic-setup, session-end-cleanup, memory-writer.
# Opt-in is per agent: --host cursor|codex|all and optional --skills list.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT=""
DRY=0
HOST="all"
SKILLS_CSV=""

usage() {
  cat <<EOF
Usage: ./skills/install.sh [--project DIR] [--host cursor|codex|all] [--skills a,b,c] [--dry-run]

Copies Trace Agent Skills into host folders:
  cursor → ~/.cursor/skills
  codex  → ~/.agents/skills
  all    → both (default)

With --project, appends one instruction line to that project's AGENTS.md
(creates the file if needed). Skip --project for opted-out projects.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:-}"; shift 2 ;;
    --host) HOST="${2:-}"; shift 2 ;;
    --skills) SKILLS_CSV="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

# Product skills + prepare-home (Home cards). Decide-later is shared queue, not marketed separately.
DEFAULT_SKILLS=(hygienic-setup session-end-cleanup memory-writer prepare-home)
if [[ -n "$SKILLS_CSV" ]]; then
  IFS=',' read -r -a SKILLS <<< "$SKILLS_CSV"
else
  SKILLS=("${DEFAULT_SKILLS[@]}")
fi

case "$HOST" in
  cursor) DESTS=("$HOME/.cursor/skills") ;;
  codex)  DESTS=("$HOME/.agents/skills") ;;
  all)    DESTS=("$HOME/.agents/skills" "$HOME/.cursor/skills") ;;
  *) echo "Unknown --host: $HOST (use cursor|codex|all)" >&2; exit 2 ;;
esac

LINE='Use Trace skills before an install or environment setup (trace-hygienic-setup), when finishing a session that left leftovers (trace-session-end), when recording what the session created (trace-memory-writer), and when preparing Home insight cards (trace-prepare-home). Doubtful storage decisions go to the Decide-later queue via those skills — do not guess.'

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
  # Shared core once per install root
  mkdir -p "$dest_root/trace-shared"
  rm -rf "$dest_root/trace-shared"
  cp -R "$ROOT/shared" "$dest_root/trace-shared"
  echo "installed $name -> $dest"
}

for dest in "${DESTS[@]}"; do
  for skill in "${SKILLS[@]}"; do
    skill="$(echo "$skill" | tr -d '[:space:]')"
    [[ -z "$skill" ]] && continue
    copy_skill "$skill" "$dest"
  done
done

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
