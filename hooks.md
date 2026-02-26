# Hooks

Claude Code 이벤트에 반응하여 자동 실행되는 쉘 스크립트 모음.

## Discord 알림 (`hooks/discord-notify.sh`)

작업 종료/알림 이벤트 발생 시 Discord 채널에 Embed 카드로 알림을 전송한다.

### 등록된 이벤트

| 이벤트 | 설명 | Embed 색상 |
|--------|------|-----------|
| **Stop** | Claude 작업 종료 시 | 🟢 녹색 |
| **Notification** | Claude가 알림을 보낼 때 | 🔵 파란색 |

> `TaskCompleted`는 알림이 과도하여 비활성화함.

### Embed 구성

- **title**: 이벤트 아이콘 + 상태
- **description**: 작업 요약 또는 알림 메시지 (최대 1024자)
- **fields**: 프로젝트명, 세션 ID, 경로 등 메타 정보
- **footer**: `Claude Code Hook` + 타임스탬프

### 설정 방법

1. `hooks/.env.example`을 복사하여 `hooks/.env` 생성:
   ```bash
   cp ~/.claude/hooks/.env.example ~/.claude/hooks/.env
   ```
2. `.env`에 Discord Webhook URL 입력:
   ```
   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN
   ```
3. `settings.json`의 `hooks` 섹션에 이벤트가 등록되어 있는지 확인

### Discord 서버 요구 사항

- **Embed Links 권한** 필수 — 서버 설정 > 역할 > `@everyone` > "링크 첨부" 활성화
- 채널 권한만으로는 부족할 수 있으므로 **서버 레벨**에서 설정

### 의존성

- `jq` (JSON 파싱)
- `curl` (HTTP 전송)

### 기술 참고

- **bash 3.2 호환** (macOS 기본 쉘)
- `jq .[]` + `while IFS= read -r` 루프로 빈 필드 보존 (`@tsv` + `IFS read`는 연속 구분자를 합쳐 빈 필드를 잃음)
- `set -u` 환경에서 `${arr[N]:-}` 기본값 패턴으로 unbound variable 방지
- `stop_hook_active` 가드로 Stop 훅의 무한 재귀 방지
- 모든 에러는 `exit 0`으로 종료하여 Claude Code 워크플로우를 중단시키지 않음
