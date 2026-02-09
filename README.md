# dotclaude

여러 디바이스에서 동일한 Claude Code 환경을 설정하기 위한 개인 설정 저장소

## 구조

```
.claude/
├── CLAUDE.md            # 프로젝트 지침 (언어, 기술 스택, 코드 컨벤션)
├── settings.json        # Claude Code 설정 (권한, 플러그인, MCP 서버)
├── output-styles/       # 응답 스타일 프리셋
└── statusline.sh        # 상태바 스크립트 (시각, 모델, Git 상태, 세션 비용)
```

## 설정 요약

**CLAUDE.md** — 모든 프로젝트에 적용되는 글로벌 지침.

- 응답 언어: 한국어 / 변수명: 영어
- 기술 스택: React 19 + TypeScript (strict), Next.js 16 / Vite 7, Tailwind CSS 4
- 컨벤션: named exports 우선, feature-based 구조, 불필요한 주석 금지

**settings.json** — 권한, 환경 변수, 플러그인 설정.

- 위험 명령어 차단 (`sudo`, `rm -rf`, pipe-to-shell 등)
- 민감 파일 읽기 차단 (`.env`, `credentials.json`)
- 활성 플러그인: frontend-design, typescript-lsp, code-review, code-simplifier, feature-dev, context7

**statusline.sh** — 터미널 상태바에 현재 시각, 모델명, 디렉토리, Git 브랜치/상태, 세션 비용을 표시한다.

## 사용법

이 저장소를 `~/.claude/`에 클론한다.

```bash
git clone https://github.com/<username>/dotclaude.git ~/.claude
```

`settings.json`의 `mcpServers` 경로는 로컬 환경에 맞게 수정한다. `ide/`, `plugins/`, `skills/`, `image-cache/`는 `.gitignore`로 제외되어 있으므로 디바이스별로 별도 관리한다.

## 요구 사항

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [jq](https://jqlang.github.io/jq/) (statusline.sh에서 JSON 파싱에 사용)
