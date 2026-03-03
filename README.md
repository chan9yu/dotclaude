# dotclaude

여러 디바이스에서 동일한 Claude Code 환경을 설정하기 위한 개인 설정 저장소

## 구조

```
.claude/
├── CLAUDE.md            # 전역 지침 (언어, 문제 해결)
├── settings.json        # Claude Code 설정 (권한, 플러그인, 훅)
├── hooks/               # 이벤트 훅 스크립트
│   ├── discord-notify.sh  # Discord Webhook 알림
│   ├── .env.example       # 환경 변수 템플릿
│   └── .env               # 환경 변수 (gitignore)
├── output-styles/       # 응답 스타일 프리셋
├── statusline.sh        # 상태바 스크립트 (시각, 모델, Git 상태, 세션 비용)
├── hooks.md             # 훅 설정 문서
├── mcp-servers.md       # MCP 서버 설정 문서
└── plugins.md           # 플러그인 목록 문서
```

## 설정 요약

**CLAUDE.md** — 모든 프로젝트에 적용되는 전역 지침.

- 텍스트 출력: 한국어 / 코드 식별자: 영어
- 문제 해결: 근본 원인 분석 (임시 우회 금지)

**settings.json** — 권한, 환경 변수, 플러그인 설정.

- 위험 명령어 차단 (`sudo`, `rm -rf`, pipe-to-shell 등)
- 민감 파일 읽기 차단 (`.env`, `credentials.json`)
- 활성 플러그인: frontend-design, typescript-lsp, code-review, code-simplifier, feature-dev, context7, serena, playwright, superpowers, context-mode
- 훅: Stop, Notification → Discord Webhook 알림

**hooks/discord-notify.sh** — 작업 종료/알림 시 Discord 채널에 Embed 카드 전송. 상세 설정은 [`hooks.md`](./hooks.md) 참조.

**statusline.sh** — 터미널 상태바에 현재 시각, 모델명, 디렉토리, Git 브랜치/상태, 세션 비용을 표시한다.

## 사용법

### 1. 저장소 클론

이 저장소를 `~/.claude/`에 클론한다.

```bash
git clone https://github.com/<username>/dotclaude.git ~/.claude
```

### 2. Discord 알림 설정 (선택)

```bash
cp ~/.claude/hooks/.env.example ~/.claude/hooks/.env
# .env 파일에 Discord Webhook URL 입력
```

상세 설정은 [`hooks.md`](./hooks.md)를 참조한다.

### 3. MCP 서버 설정

선호하는 MCP 서버 목록과 설정 방법은 [`mcp-servers.md`](./mcp-servers.md)를 참조한다.

### 4. 기타

`ide/`, `plugins/`, `skills/`, `image-cache/`는 `.gitignore`로 제외되어 있으므로 디바이스별로 별도 관리한다.

## 요구 사항

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [jq](https://jqlang.github.io/jq/) (statusline.sh에서 JSON 파싱에 사용)
