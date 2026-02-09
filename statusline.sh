#!/usr/bin/env bash
# Unified Claude Code statusline script
# Combines: inline (dirty/clean), colorful.py (timeout/colors), command.sh (stdin safety)
set -euo pipefail

# ── ANSI Colors ──────────────────────────────────────────────
readonly C_RESET='\033[0m'
readonly C_BOLD='\033[1m'
readonly C_DIM='\033[2m'
readonly C_CYAN='\033[96m'
readonly C_BLUE='\033[94m'
readonly C_YELLOW='\033[93m'
readonly C_MAGENTA='\033[95m'
readonly C_GREEN='\033[92m'
readonly C_RED='\033[91m'

# ── Read stdin ───────────────────────────────────────────────
# Pipe from Claude Code closes immediately after writing, so cat returns at once.
input=""
if [ ! -t 0 ]; then
  input=$(cat 2>/dev/null) || true
fi

if [ -z "$input" ]; then
  printf "statusline: no input\n"
  exit 0
fi

# ── Parse JSON — single jq call ─────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  printf "statusline: jq not found\n"
  exit 0
fi

IFS=$'\t' read -r model cwd < <(
  printf '%s' "$input" | jq -r '
    [
      (if .model then
        (if .model | type == "object" then .model.display_name // .model.id
         else .model end)
       else "sonnet" end),
      (.workspace.current_dir // "")
    ] | @tsv
  ' 2>/dev/null
) || { printf "statusline: json parse error\n"; exit 0; }

# Shorten model name: "Claude Opus 4" → "opus-4", "Claude 3.5 Sonnet" → "sonnet-3.5"
# macOS sed doesn't support \L, so use tr for lowercasing
model=$(printf '%s' "$model" \
  | sed -E 's/^Claude //' \
  | sed -E 's/^([A-Za-z]+) ([0-9.]+)/\1-\2/' \
  | sed -E 's/^([0-9.]+) ([A-Za-z]+)/\2-\1/' \
  | tr '[:upper:]' '[:lower:]')

dir=$(basename "$cwd" 2>/dev/null || echo "unknown")
timestamp=$(date "+%H:%M")

# ── Git info (all with -C and --no-optional-locks) ──────────
branch="" dirty="" ahead="" behind="" stash_count=""

if command -v git >/dev/null 2>&1 && \
   git -C "$cwd" rev-parse --git-dir &>/dev/null 2>&1; then

  # Branch name (or short SHA for detached HEAD)
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null) || \
  branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null) || \
  branch=""

  # Dirty check
  if [ -n "$branch" ]; then
    if git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | grep -q .; then
      dirty="dirty"
    else
      dirty="clean"
    fi
  fi

  # Ahead / behind upstream
  if [ -n "$branch" ]; then
    local_ref=$(git -C "$cwd" --no-optional-locks rev-parse HEAD 2>/dev/null) || true
    upstream=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || true
    if [ -n "$upstream" ] && [ -n "$local_ref" ]; then
      counts=$(git -C "$cwd" --no-optional-locks rev-list --left-right --count HEAD..."@{upstream}" 2>/dev/null) || true
      if [ -n "$counts" ]; then
        ahead=$(printf '%s' "$counts" | cut -f1)
        behind=$(printf '%s' "$counts" | cut -f2)
        [ "$ahead" = "0" ] && ahead=""
        [ "$behind" = "0" ] && behind=""
      fi
    fi
  fi

  # Stash count
  stash_count=$(git -C "$cwd" --no-optional-locks stash list 2>/dev/null | wc -l | tr -d ' ') || true
  [ "$stash_count" = "0" ] && stash_count=""
fi

# ── Build output ─────────────────────────────────────────────
parts=""

# Time
parts="${C_BOLD}${C_CYAN}🕐 ${timestamp}${C_RESET}"

# Model
parts="${parts}  ${C_BOLD}${C_BLUE}🤖 ${model}${C_RESET}"

# Directory
parts="${parts}  ${C_BOLD}${C_YELLOW}📁 ${dir}${C_RESET}"

# Git branch + status
if [ -n "$branch" ]; then
  parts="${parts}  ${C_BOLD}${C_MAGENTA}🌿 ${branch}"
  if [ "$dirty" = "dirty" ]; then
    parts="${parts} ${C_RED}●${C_RESET}"
  elif [ "$dirty" = "clean" ]; then
    parts="${parts} ${C_GREEN}✓${C_RESET}"
  else
    parts="${parts}${C_RESET}"
  fi

  # Ahead/behind
  ab=""
  [ -n "$ahead" ]  && ab="${ab} ↑${ahead}"
  [ -n "$behind" ] && ab="${ab} ↓${behind}"
  [ -n "$ab" ] && parts="${parts} ${C_DIM}${ab}${C_RESET}"

  # Stash
  if [ -n "$stash_count" ]; then
    parts="${parts} ${C_DIM}📦${stash_count}${C_RESET}"
  fi
fi

printf '%b\n' "$parts"
