## 언어 및 커뮤니케이션 규칙

- 기본 응답 언어: 한국어
- 코드 주석: 한국어로 작성
- 커밋 메시지: 한국어로 작성
- 문서화: 한국어로 작성
- 변수명/함수명: 영어 (코드 표준 준수)

## 기술 스택

- **React**: 19.x + TypeScript 5.9.x (strict mode)
- **빌드 도구**: Next.js 16.x (App Router) / Vite 7.x
- **스타일링**: Tailwind CSS 4.x
- **패키지 매니저**: pnpm 10.x
- **런타임**: Node.js 22+

## 코드 스타일 및 컨벤션

### TypeScript

- strict mode 필수
- 상대 경로 import 사용 (path aliases 지양)
- 자동 추론 가능한 리턴 타입은 명시하지 않기
- 불필요한 주석 금지 (자명한 코드는 주석 없이 작성)

### Import/Export

- Named exports 우선 (default export 지양)
- Import 순서: external → internal → relative
- 배럴 파일(index.ts) 사용으로 import 구문 최적화

## 프로젝트 구조

- **Feature-based**: `src/features/[feature]/components|types|services`
- **Shared**: `src/shared/components|utils|types`
- **Next.js**: `app/` (App Router), Server/Client Component 명확히 구분
- **파일명**: 컴포넌트 PascalCase, utils/hooks camelCase

## 개발 워크플로우

- **Pre-commit**: lefthook + Lint-staged (자동 린팅/포매팅)
- **모노레포**: pnpm workspace
- **커밋**: 사용자가 명시적으로 요청하지 않는 한 자동 커밋 금지

## 문제 해결 원칙

- 이슈는 근본 원인 분석 후 해결
- setTimeout/setInterval을 이용한 의미 없는 타이머로 이슈 우회 금지
- 임시 플래그 변수 선언으로 이슈 우회 금지
- **다시 한 번 강조: 의미 없는 타이머는 절대 금지**