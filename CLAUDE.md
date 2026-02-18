## 언어 규칙

- 응답/주석/커밋/문서: 한국어, 변수명/함수명: 영어

## 기술 스택

- React 19 + TypeScript 5.9 (strict mode)
- Next.js 16 (App Router) / Vite 7.x
- Tailwind CSS 4, pnpm

## TypeScript

- strict mode, 상대 경로 import (path aliases 지양)
- 리턴 타입 자동 추론, 불필요한 주석 금지
- `React.MouseEvent` 등 `React.*` 네임스페이스 접근 금지 → `import type { MouseEvent } from "react"` 직접 import

## React 19

- `use(Context)`, `<Context value={...}>`, ref는 일반 prop (`forwardRef` 금지)
- 내장 유틸리티 타입(`PropsWithChildren` 등) 활용 (커스텀 재정의 금지)
- JSX 인라인 함수 지양 → named 함수로 추출
- 컴포넌트 내부 함수는 화살표 함수 사용 (`function handleX()` ❌ → `const handleX = () =>` ✅)
- `useCallback`/`useMemo`: Context Provider value 안정성 용도로만

## Import/Export

- Named exports 우선 (프레임워크 요구사항 예외)
- 순서: external → internal → relative
- 배럴 파일(index.ts)로 모듈 간 접근 (직접 파일 경로 import 금지)
- 새 모듈 추가 시 배럴 파일에 re-export 추가

## 프로젝트 구조

- **Feature-based**: `src/features/[feature]/components|types|services`
- **Shared**: `src/shared/ui|layouts|hooks|utils`
- 파일명: 컴포넌트 PascalCase, utils/hooks camelCase
- `_components` 디렉토리 사용 금지

## 접근성 (a11y)

- 모달: `aria-labelledby` (`useId()` + Context)
- 트리거: `aria-expanded`, 로딩 버튼: `aria-busy`
- 아이콘 버튼: `aria-label`, 장식 아이콘: `aria-hidden="true"`

## 개발 워크플로우

- Pre-commit: lefthook + Lint-staged
- 커밋: 명시적 요청 시에만, 작은 단위로

## 문제 해결

- 근본 원인 분석 후 해결
- 의미 없는 타이머(setTimeout/setInterval), 임시 플래그 금지
