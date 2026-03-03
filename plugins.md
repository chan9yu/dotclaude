# 플러그인 목록

`claude plugin add`로 설치된 플러그인 구성. 자동 업데이트되며 별도 MCP 설정이 필요 없다.

## 마켓플레이스

| 마켓플레이스             | 소스                                 |
| ------------------------ | ------------------------------------ |
| claude-plugins-official  | anthropics/claude-plugins-official    |
| superpowers-marketplace  | obra/superpowers-marketplace         |
| claude-context-mode      | mksglu/claude-context-mode           |

## MCP 서버 플러그인

외부 서비스 연동용 플러그인.

| 플러그인   | 제공      | 설명                                        |
| ---------- | --------- | ------------------------------------------- |
| context7   | Upstash   | 라이브러리 문서 실시간 조회                  |
| serena     | Oraios    | 시맨틱 코드 분석 (LSP 기반)                  |
| playwright | Microsoft | 브라우저 자동화 (스크린샷, 클릭, 폼 입력 등) |

## 개발 워크플로우 플러그인

| 플러그인        | 설명                                                                |
| --------------- | ------------------------------------------------------------------- |
| feature-dev     | 기능 개발 워크플로우 (코드 탐색, 아키텍처 설계, 리뷰)               |
| code-review     | PR 코드 리뷰 자동화                                                 |
| code-simplifier | 코드 단순화 및 리팩토링                                             |
| frontend-design | UI/UX 구현 스킬                                                     |
| typescript-lsp  | TypeScript/JavaScript 코드 인텔리전스 (go-to-definition, 참조 검색) |
| superpowers     | 구조화된 개발 워크플로우 스킬 모음 (TDD, 디버깅, 플래닝 등)         |
| context-mode    | 컨텍스트 윈도우 절약 (대량 출력을 샌드박스에서 처리)                 |
