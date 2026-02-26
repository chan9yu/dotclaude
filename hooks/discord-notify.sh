#!/usr/bin/env bash
# Discord notification hook for Claude Code
# Sends Discord Webhook notifications on Stop, Notification, and TaskCompleted events
set -euo pipefail

# ── .env 로딩 ────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

if [ -z "${DISCORD_WEBHOOK_URL:-}" ] || [ "$DISCORD_WEBHOOK_URL" = "https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN" ]; then
  echo "discord-notify: DISCORD_WEBHOOK_URL이 설정되지 않았습니다. ~/.claude/hooks/.env를 확인하세요." >&2
  exit 0
fi

# ── jq 확인 ──────────────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  echo "discord-notify: jq가 설치되어 있지 않습니다." >&2
  exit 0
fi

# ── stdin 읽기 ───────────────────────────────────────────────
input=""
if [ ! -t 0 ]; then
  input=$(cat 2>/dev/null) || true
fi

if [ -z "$input" ]; then
  echo "discord-notify: stdin 입력 없음" >&2
  exit 0
fi

# ── JSON 파싱 (단일 jq, 줄 단위 — bash 3.2 호환) ────────────
# NOTE: @tsv + IFS read는 연속 구분자를 합쳐 빈 필드를 잃는다.
#       대신 필드별 한 줄씩 출력하고 인덱스로 접근한다.
_parsed=$(printf '%s' "$input" | jq -r '
  [
    (.hook_event_name // ""),
    (.stop_hook_active // false | tostring),
    (.session_id // ""),
    (.cwd // ""),
    (.last_assistant_message // ""),
    (.title // ""),
    (.message // ""),
    (.task_id // ""),
    (.task_subject // ""),
    (.task_description // "")
  ] | .[]
' 2>/dev/null) || { echo "discord-notify: JSON 파싱 실패" >&2; exit 0; }

# 줄 단위로 배열에 담기 (bash 3.2 호환)
_i=0
while IFS= read -r _line; do
  _fields[_i]="$_line"
  _i=$((_i + 1))
done <<< "$_parsed"

event_name="${_fields[0]:-}"
stop_hook_active="${_fields[1]:-false}"
session_id="${_fields[2]:-}"
cwd="${_fields[3]:-}"
last_message="${_fields[4]:-}"
notif_title="${_fields[5]:-}"
notif_message="${_fields[6]:-}"
task_id="${_fields[7]:-}"
task_subject="${_fields[8]:-}"
task_description="${_fields[9]:-}"

# ── stop_hook_active 체크 (무한 루프 방지) ───────────────────
if [ "$stop_hook_active" = "true" ]; then
  exit 0
fi

# ── 텍스트 truncate 함수 ────────────────────────────────────
truncate() {
  local text="$1"
  local max_len="$2"
  if [ "${#text}" -gt "$max_len" ]; then
    echo "${text:0:$((max_len - 3))}..."
  else
    echo "$text"
  fi
}

# ── 프로젝트명 추출 ─────────────────────────────────────────
project_name=$(basename "$cwd" 2>/dev/null || echo "unknown")
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── 이벤트별 메시지 구성 ──────────────────────────────────────
embed_title=""
embed_desc=""
color=""
fields="[]"
session_short="${session_id:0:8}"

case "$event_name" in
  Stop)
    color=5763719  # 녹색
    embed_title="✅  Claude 작업 종료"
    embed_desc=$(truncate "${last_message:-작업이 완료되었습니다.}" 1024)
    fields=$(jq -n \
      --arg proj "$project_name" \
      --arg path "$cwd" \
      --arg sess "$session_short" \
      '[
        {"name": "📁 프로젝트", "value": $proj, "inline": true},
        {"name": "🔑 세션", "value": ("`" + $sess + "`"), "inline": true},
        {"name": "📂 경로", "value": ("`" + $path + "`"), "inline": false}
      ]')
    ;;
  Notification)
    color=5793266  # 파란색
    embed_title="🔔  ${notif_title:-알림}"
    embed_desc=$(truncate "${notif_message:-알림이 도착했습니다.}" 1024)
    fields=$(jq -n \
      --arg proj "$project_name" \
      --arg path "$cwd" \
      '[
        {"name": "📁 프로젝트", "value": $proj, "inline": true},
        {"name": "📂 경로", "value": ("`" + $path + "`"), "inline": false}
      ]')
    ;;
  TaskCompleted)
    color=10181046  # 보라색
    embed_title="🟣  작업 완료: ${task_subject:-작업}"
    embed_desc=$(truncate "${task_description:-작업이 완료되었습니다.}" 1024)
    fields=$(jq -n \
      --arg proj "$project_name" \
      --arg path "$cwd" \
      --arg tid "$task_id" \
      '[
        {"name": "📁 프로젝트", "value": $proj, "inline": true},
        {"name": "🏷️ 작업 ID", "value": ("`" + $tid + "`"), "inline": true},
        {"name": "📂 경로", "value": ("`" + $path + "`"), "inline": false}
      ]')
    ;;
  *)
    exit 0
    ;;
esac

# ── Discord JSON 조립 ────────────────────────────────────────
# content에 빈 줄(\n)을 넣어 메시지 간 시각적 간격 확보
payload=$(jq -n \
  --arg content $'\n' \
  --arg title "$embed_title" \
  --arg desc "$embed_desc" \
  --argjson color "$color" \
  --arg ts "$timestamp" \
  --argjson fields "$fields" \
  '{
    content: $content,
    embeds: [{
      title: $title,
      description: $desc,
      color: $color,
      fields: $fields,
      footer: { text: "Claude Code Hook" },
      timestamp: $ts
    }]
  }')

# ── curl 전송 ───────────────────────────────────────────────
http_code=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time 8 \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "$DISCORD_WEBHOOK_URL" 2>/dev/null) || { echo "discord-notify: curl 실행 실패" >&2; exit 0; }

if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
  echo "discord-notify: Discord API 응답 코드 ${http_code}" >&2
fi

exit 0
