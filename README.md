# dotclaude

여러 디바이스에서 동일한 Claude Code 환경을 설정하기 위한 개인 설정 저장소

## 구조

```
.claude/
├── CLAUDE.md            # 전역 지침 (언어, 문제 해결, 한국어 작성 규칙)
├── settings.json        # Claude Code 설정 (권한, 모델, 플러그인, 상태바)
├── statusline.sh        # 상태바 스크립트 (계정, 모델, Git, 사용량)
├── output-styles/       # 응답 스타일 프리셋
└── .gitignore           # Git 제외 설정
```

`skills/`와 `rules/`는 별도 저장소인 `~/.agents`를 가리키는 심볼릭 링크만 있어 추적하지 않는다. 실제 파일은 그쪽에 한 벌만 둔다.

## 설정 요약

**CLAUDE.md**는 모든 프로젝트에 적용되는 전역 지침이다.

- 텍스트 출력은 한국어, 코드 식별자는 영어
- 문제 해결은 근본 원인 분석 (임시 우회 금지)
- 한국어 작성 규칙 (기호와 한자 사용 금지, 번역투 제거, 문장 다듬기 기준)

**settings.json**은 권한과 모델, 환경 변수, 플러그인을 설정한다.

- 셸 명령은 auto 분류기가 검증한다. `allow`에 `Bash`를 두지 않아 파괴적인 명령이 걸러진다
- 위험 명령 차단 (`sudo`, `rm -rf`, `killall`, `pkill -9`, `npm publish`, 파이프로 셸에 넘기는 형태)
- 민감 파일 읽기 차단 (`.env`, `credentials.json`, OAuth 토큰이 담긴 `.credentials.json`)
- 확인을 거치는 명령 (`git push`, `git merge`, `git rebase`, 패키지 설치)
- 주 모델은 fable, 과부하 시 `fallbackModel`로 opus가 이어받는다
- 사용 한도에 걸리면 리셋 후 자동으로 이어서 진행한다
- 활성 플러그인은 typescript-lsp와 harness, humanize-korean
- 세션 보존 기간은 90일

권한 규칙은 `Bash(sudo *)` 형식으로 적는다. `Bash(sudo :*)`는 같은 뜻이지만 공식 권장 형식이 아니다.

**statusline.sh**는 터미널 상태바를 그린다.

- 계정과 구독 플랜, 모델, 작업 디렉토리, Git 브랜치와 변경 여부, 세션 비용
- 컨텍스트 점유율과 5시간, 주간 사용량 게이지 (50% 이상 앰버, 80% 이상 코랄로 전환)
- 사용량은 Claude Code가 넘겨주는 stdin JSON에서, 계정은 `~/.claude.json`에서 읽는다. 외부 통신은 없다.

## 사용법

### 1. 두 저장소 클론

설정과 공유 자산이 나뉘어 있다. 둘 다 홈 디렉토리에 둔다.

```bash
git clone https://github.com/chan9yu/dotclaude.git ~/.claude
git clone https://github.com/chan9yu/docagents.git ~/.agents
```

### 2. 심볼릭 링크 생성

`~/.agents`의 스크립트가 스킬과 룰 링크를 만든다. 여러 번 실행해도 안전하고, 없어진 항목의 링크는 지운다.

```bash
bash ~/.agents/scripts/link-agents.sh --dry-run   # 무엇이 바뀔지 먼저 본다
bash ~/.agents/scripts/link-agents.sh
```

`~/.agents`에 스킬이나 룰을 추가한 뒤에도 다시 실행한다.

### 3. 기타

`ide/`와 `plugins/`, 캐시 디렉토리도 `.gitignore`로 제외되어 있으므로 디바이스별로 관리한다.

## 요구 사항

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [jq](https://jqlang.github.io/jq/) (statusline.sh에서 JSON 파싱에 사용)
- 심볼릭 링크를 지원하는 파일 시스템
