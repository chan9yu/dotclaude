# dotclaude

여러 디바이스에서 동일한 Claude Code 환경을 설정하기 위한 개인 설정 저장소

## 구조

```
.claude/
├── CLAUDE.md            # 전역 지침 (언어/문제 해결)
├── settings.json        # Claude Code 설정 (권한, 플러그인, 상태바)
├── statusline.sh        # 상태바 스크립트 (계정, 모델, Git, 사용량)
├── output-styles/       # 응답 스타일 프리셋
├── skills/
│   └── frontend-fundamentals/   # 저장소가 직접 관리하는 스킬
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

**statusline.sh** — 터미널 상태바 스크립트.

- 계정·구독 플랜, 모델, 작업 디렉토리, Git 브랜치·변경 여부, 세션 비용
- 컨텍스트 점유율, 5시간·주간 사용량 게이지 (50% 이상 앰버, 80% 이상 코랄로 전환)
- 사용량은 Claude Code가 넘겨주는 stdin JSON에서, 계정은 `~/.claude.json`에서 읽는다. 외부 통신은 없다.

## 사용법

### 1. 저장소 클론

이 저장소를 `~/.claude/`에 클론한다.

```bash
git clone https://github.com/<username>/dotclaude.git ~/.claude
```

### 2. 심볼릭 링크 재생성

`skills/`의 스킬 대부분과 `rules`는 별도 저장소인 `~/.agents`를 가리키는 심볼릭 링크라 `.gitignore`로 제외되어 있다. 새 디바이스에서는 `~/.agents`를 준비한 뒤 링크를 다시 만든다.

```bash
ln -sfn ../../.agents/skills/<name> ~/.claude/skills/<name>
ln -sfn ../.agents/rules ~/.claude/rules
```

저장소가 직접 관리하는 스킬은 `skills/frontend-fundamentals/`뿐이다.

### 3. 기타

`ide/`, `plugins/`, `image-cache/`도 `.gitignore`로 제외되어 있으므로 디바이스별로 관리한다.

## 요구 사항

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [jq](https://jqlang.github.io/jq/) (statusline.sh에서 JSON 파싱에 사용)
