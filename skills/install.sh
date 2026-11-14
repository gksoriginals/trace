#!/usr/bin/env bash
# Install Trace skills into host skill folders (whole-agent default).
# Product skills: hygienic-setup, session-end-cleanup, memory-writer.
# prepare-home stays an operational helper for the app (ADR-0007).
# With --project, also write the rule line and the default hooks (ADR-0014).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT=""
DRY=0
HOST="all"
SKILLS_CSV=""
UNINSTALL=0
OPT_OUT=0

usage() {
  cat <<EOF
Usage: ./skills/install.sh [--project DIR] [--host cursor|codex|claude|all] [--skills a,b,c] [--dry-run]
       ./skills/install.sh --uninstall [--project DIR] [--host ...]
       ./skills/install.sh --opt-out --project DIR

Copies Trace Agent Skills into host folders:
  cursor → ~/.cursor/skills
  codex  → ~/.agents/skills
  claude → ~/.claude/skills
  all    → cursor and codex (default; matches the app)

With --project, writes one idempotent rule into AGENTS.md, .cursor/rules/trace.mdc,
and CLAUDE.md, and installs stop/session-end hooks that only enqueue work.
--opt-out removes that project's rule and hooks and records .trace/opt-out.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:-}"; shift 2 ;;
    --host) HOST="${2:-}"; shift 2 ;;
    --skills) SKILLS_CSV="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --opt-out) OPT_OUT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

DEFAULT_SKILLS=(hygienic-setup session-end-cleanup memory-writer prepare-home)
if [[ -n "$SKILLS_CSV" ]]; then
  IFS=',' read -r -a SKILLS <<< "$SKILLS_CSV"
else
  SKILLS=("${DEFAULT_SKILLS[@]}")
fi

case "$HOST" in
  cursor) DESTS=("$HOME/.cursor/skills") ;;
  codex)  DESTS=("$HOME/.agents/skills") ;;
  claude) DESTS=("$HOME/.claude/skills") ;;
  all)    DESTS=("$HOME/.agents/skills" "$HOME/.cursor/skills") ;;
  *) echo "Unknown --host: $HOST (use cursor|codex|claude|all)" >&2; exit 2 ;;
esac

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
  rm -rf "$dest_root/trace-shared"
  cp -R "$ROOT/shared" "$dest_root/trace-shared"
  echo "installed $name -> $dest"
}

remove_skill() {
  local name="$1" dest_root="$2"
  local dest="$dest_root/$name"
  if [[ "$DRY" -eq 1 ]]; then
    echo "would remove $dest"
    return
  fi
  rm -rf "$dest"
  echo "removed $dest"
}

if [[ "$OPT_OUT" -eq 1 ]]; then
  if [[ -z "$PROJECT" ]]; then
    echo "--opt-out needs --project" >&2
    exit 2
  fi
  python3 "$ROOT/install_project.py" --project "$PROJECT" --opt-out
  echo "Done. This project is opted out. Host skill folders were left in place."
  exit 0
fi

if [[ "$UNINSTALL" -eq 1 ]]; then
  for dest in "${DESTS[@]}"; do
    for skill in "${SKILLS[@]}"; do
      skill="$(echo "$skill" | tr -d '[:space:]')"
      [[ -z "$skill" ]] && continue
      remove_skill "$skill" "$dest"
    done
  done
else
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
fi

if [[ -n "$PROJECT" ]]; then
  args=(python3 "$ROOT/install_project.py" --project "$PROJECT")
  if [[ "$UNINSTALL" -eq 1 ]]; then
    args+=(--uninstall)
  fi
  if [[ "$DRY" -eq 1 ]]; then
    args+=(--dry-run)
  fi
  "${args[@]}"
fi

echo "Done. Skills work with the app closed. The native app is unchanged: app/README.md."
