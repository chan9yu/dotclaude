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

# 사용량 항목별 고유색 (256색). 평상시엔 항목마다 다른 색으로 구분되고,
# 임계값을 넘으면 아래 경고색이 베이스색을 덮어써 위험 신호가 살아난다.
readonly C_LAVENDER='\033[38;5;147m'  # 🧠 컨텍스트
readonly C_ORANGE='\033[38;5;214m'    # ⏳ 5시간 한도
readonly C_MINT='\033[38;5;79m'       # 📅 주간 한도
readonly C_WARN='\033[38;5;220m'      # 50% 이상
readonly C_DANGER='\033[38;5;203m'    # 80% 이상
readonly C_ACCOUNT='\033[38;5;117m'   # 👤 계정
readonly C_PLAN='\033[38;5;211m'      # 💳 구독 플랜

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

model="" cwd="" cost="" ctx_pct="" five_pct="" five_reset="" week_pct="" week_reset=""

# 한 줄에 한 필드씩 읽는다.
# `@tsv` + `IFS=$'\t' read`는 탭이 IFS 공백류로 취급되어 연속 구분자를 합치므로
# 빈 필드가 통째로 사라진다. 줄 단위로 읽으면 빈 값도 빈 줄로 보존된다.
{
  read -r model      || true
  read -r cwd        || true
  read -r cost       || true
  read -r ctx_pct    || true
  read -r five_pct   || true
  read -r five_reset || true
  read -r week_pct   || true
  read -r week_reset || true
} < <(
  printf '%s' "$input" | jq -r '
    (if .model then
      (if .model | type == "object" then .model.display_name // .model.id
       else .model end)
     else "sonnet" end),
    (.workspace.current_dir // ""),
    (.cost.total_cost_usd // ""),
    (.context_window.used_percentage // ""),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // "")
  ' 2>/dev/null
)

if [ -z "$model" ]; then
  printf "statusline: json parse error\n"
  exit 0
fi

# Shorten model name: "Claude Opus 4" → "opus-4", "Claude 3.5 Sonnet" → "sonnet-3.5"
# macOS sed doesn't support \L, so use tr for lowercasing
model=$(printf '%s' "$model" \
  | sed -E 's/^Claude //' \
  | sed -E 's/^([A-Za-z]+) ([0-9.]+)/\1-\2/' \
  | sed -E 's/^([0-9.]+) ([A-Za-z]+)/\2-\1/' \
  | tr '[:upper:]' '[:lower:]')

dir=$(basename "$cwd" 2>/dev/null || echo "unknown")

# ── Account (~/.claude.json) ─────────────────────────────────
# statusline stdin에는 계정 정보가 없어 Claude Code 설정 파일에서 직접 읽는다.
# Keychain 접근이나 네트워크 호출 없이 로컬 파일 한 번이면 된다 (160KB, 10ms 미만).
acct_user="" acct_plan=""
claude_json="${HOME}/.claude.json"
if [ -r "$claude_json" ]; then
  {
    read -r acct_user || true
    read -r acct_plan || true
  } < <(
    jq -r '
      (.oauthAccount.emailAddress // "" | split("@")[0]),
      (.oauthAccount.userRateLimitTier // .oauthAccount.organizationRateLimitTier // "")
    ' "$claude_json" 2>/dev/null
  )

  # "default_claude_max_5x" → "Max 5x"
  case "$acct_plan" in
    ""|null) acct_plan="" ;;
    *)
      acct_plan=$(printf '%s' "$acct_plan" | sed -E 's/^default_//; s/^claude_//; s/_/ /g')
      acct_plan="$(printf '%s' "${acct_plan:0:1}" | tr '[:lower:]' '[:upper:]')${acct_plan:1}"
      ;;
  esac

  case "$acct_user" in
    ""|null) acct_user="" ;;
  esac
fi

# ── Format cost ──────────────────────────────────────────────
cost_fmt=""
if [ -n "$cost" ] && [ "$cost" != "null" ]; then
  cost_fmt=$(printf '$%.2f' "$cost")
fi

# ── Usage helpers ────────────────────────────────────────────
# 사용률 색상: 50% 미만은 항목 고유색, 그 위로는 경고색이 덮어쓴다.
pct_color() {
  local p=$1 base=$2
  if   [ "$p" -ge 80 ]; then printf '%s' "$C_DANGER"
  elif [ "$p" -ge 50 ]; then printf '%s' "$C_WARN"
  else                       printf '%s' "$base"
  fi
}

# 5칸 게이지 바. 반올림하므로 1%는 빈 바, 14%는 한 칸이 찬다.
gauge() {
  local p=$1 width=5 filled i out=""
  filled=$(( (p * width + 50) / 100 ))
  [ "$filled" -gt "$width" ] && filled=$width
  [ "$filled" -lt 0 ] && filled=0
  i=0
  while [ "$i" -lt "$width" ]; do
    if [ "$i" -lt "$filled" ]; then out="${out}▓"; else out="${out}░"; fi
    i=$(( i + 1 ))
  done
  printf '%s' "$out"
}

# 유닉스 타임스탬프 → 리셋까지 남은 시간.
# 상위 단위만 쓰면 "4h"가 4시간 1분부터 4시간 59분까지를 뭉뚱그리므로 하위 단위까지 붙인다.
time_until() {
  local target=$1 now diff
  now=$(date +%s)
  diff=$(( target - now ))
  if   [ "$diff" -le 0 ];     then printf 'now'
  elif [ "$diff" -lt 3600 ];  then printf '%dm' $(( diff / 60 ))
  elif [ "$diff" -lt 86400 ]; then printf '%dh %dm' $(( diff / 3600 )) $(( (diff % 3600) / 60 ))
  else                             printf '%dd %dh' $(( diff / 86400 )) $(( (diff % 86400) / 3600 ))
  fi
}

# "아이콘 게이지 퍼센트 (리셋)" 한 덩어리. 데이터가 없으면 아무것도 내지 않는다.
usage_part() {
  local icon=$1 pct_raw=$2 resets=${3:-} base=${4:-$C_GREEN} p color bar rest=""
  case "$pct_raw" in ""|null) return 0 ;; esac
  p=$(printf '%.0f' "$pct_raw" 2>/dev/null) || return 0
  color=$(pct_color "$p" "$base")
  bar=$(gauge "$p")
  case "$resets" in
    ""|null) ;;
    *) rest=" ${C_DIM}($(time_until "$resets"))${C_RESET}" ;;
  esac
  printf '  %s%s %s %d%%%s%s' "$color" "$icon" "$bar" "$p" "$C_RESET" "$rest"
}

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
# 모든 조각을 구분 공백 2칸으로 시작해 붙이고, 맨 앞 공백만 마지막에 걷어낸다.
# 어떤 항목이 첫 자리에 오든(계정이 없으면 모델이 첫 항목) 정렬이 흔들리지 않는다.
parts=""

# Account
if [ -n "$acct_user" ]; then
  parts="${parts}  ${C_ACCOUNT}👤 ${acct_user}${C_RESET}"
fi

# Plan
if [ -n "$acct_plan" ]; then
  parts="${parts}  ${C_PLAN}💳 ${acct_plan}${C_RESET}"
fi

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
    parts="${parts} ${C_DIM}📦 ${stash_count}${C_RESET}"
  fi
fi

# Cost
if [ -n "$cost_fmt" ]; then
  parts="${parts}  ${C_CYAN}💲 ${cost_fmt}${C_RESET}"
fi

# Context window — 게이지 없이 퍼센트만
if [ -n "$ctx_pct" ] && [ "$ctx_pct" != "null" ]; then
  ctx_int=$(printf '%.0f' "$ctx_pct" 2>/dev/null || printf '0')
  parts="${parts}  $(pct_color "$ctx_int" "$C_LAVENDER")🧠 ${ctx_int}%${C_RESET}"
fi

# 5시간 한도 / 주간(7일) 한도
parts="${parts}$(usage_part '⏳' "$five_pct" "$five_reset" "$C_ORANGE")"
parts="${parts}$(usage_part '📅' "$week_pct" "$week_reset" "$C_MINT")"

printf '%b\n' "${parts#  }"
