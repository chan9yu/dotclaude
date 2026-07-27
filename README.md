# dotclaude

여러 디바이스에서 동일한 Claude Code 환경을 설정하기 위한 개인 설정 저장소

## 구조

```
.claude/
├── CLAUDE.md            # 전역 지침 (언어/문제 해결)
├── settings.json        # Claude Code 설정 (권한, 플러그인, 상태바)
├── statusline.sh        # 상태바 스크립트 (시각, 모델, 디렉토리, Git)
├── output-styles/       # 응답 스타일 프리셋
└── .gitignore           # Git 제외 설정
```

## 설정 요약

**CLAUDE.md** — 모든 프로젝트에 적용되는 전역 지침.

- 텍스트 출력: 한국어 / 코드 식별자: 영어
- 문제 해결: 근본 원인 분석 (임시 우회 금지)

**settings.json** — 권한, 환경 변수, 플러그인 설정.

- 위험 명령어 차단 (`sudo`, `rm -rf`, `killall`, `pkill -9`, `npm publish`, pipe-to-shell 등)
- 민감 파일 읽기 차단 (`.env`, `credentials.json`)
- 활성 플러그인: typescript-lsp, harness, humanize-korean
- 세션 보존 기간: 90일

**statusline.sh** — 터미널 상태바 스크립트. 현재 시각, 모델, 작업 디렉토리, Git 브랜치·변경 여부를 표시한다.

## 사용법

### 1. 저장소 클론

이 저장소를 `~/.claude/`에 클론한다.

```bash
git clone https://github.com/<username>/dotclaude.git ~/.claude
```

### 2. 기타

`ide/`, `plugins/`, `skills/`, `image-cache/`는 `.gitignore`로 제외되어 있으므로 디바이스별로 별도 관리한다.

## 요구 사항

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [jq](https://jqlang.github.io/jq/) (statusline.sh에서 JSON 파싱에 사용)
