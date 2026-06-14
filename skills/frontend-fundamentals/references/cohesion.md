# 응집도 (Cohesion)

> 함께 수정되어야 할 코드가 **항상 함께 수정되는가**. 응집도가 높으면 한 부분을 고쳐도 다른 곳에서 의도치 않은 오류가 나지 않는다 — 함께 바뀔 것이 구조적으로 묶여 있기 때문.
>
> ⚠️ **가독성과 상충**: 응집도를 높이려면 보통 추상화·공통화가 필요해 가독성이 떨어진다. 함께 안 고치면 **버그가 나는** 경우엔 응집도를 우선(공통화·추상화)하고, 위험이 낮으면 가독성을 우선(중복 허용)하라.

## 목차
1. [함께 수정되는 파일을 같은 디렉토리에 두기](#1-함께-수정되는-파일을-같은-디렉토리에-두기)
2. [매직 넘버 없애기](#2-매직-넘버-없애기)
3. [폼의 응집도 생각하기](#3-폼의-응집도-생각하기)

---

## 1. 함께 수정되는 파일을 같은 디렉토리에 두기

**냄새**: 파일을 **모듈 종류별**(components/constants/containers/hooks/utils...)로만 나누면, 어떤 코드가 어떤 코드를 참조하는지 한눈에 안 보인다. 더 이상 안 쓰는 코드를 지울 때 연관 파일이 함께 안 지워져 죽은 코드가 남는다. 프로젝트가 커지면 한 디렉토리에 100개 넘는 파일이 쌓인다.

```text
└─ src
   ├─ components
   ├─ constants
   ├─ containers
   ├─ contexts
   ├─ remotes
   ├─ hooks
   ├─ utils
   └─ ...
```

**개선**: **함께 수정되는 파일끼리** 같은(도메인) 디렉토리로 묶는다. 전역 공용 코드만 최상위에 두고, 특정 도메인에서만 쓰는 코드는 그 도메인 폴더 안에 components/hooks/utils를 둔다.

```text
└─ src
   │  // 전체 프로젝트 공용
   ├─ components
   ├─ hooks
   ├─ utils
   └─ domains
      ├─ Domain1
      │     ├─ components
      │     ├─ hooks
      │     └─ utils
      └─ Domain2
            ├─ components
            ├─ hooks
            └─ utils
```

이점:
- 의존 관계가 드러난다. `import { useFoo } from "../../../Domain2/hooks/useFoo"` 같은 import를 보면 **잘못된 참조**(도메인 경계 침범)임을 즉시 안다.
- 기능을 지울 때 **디렉토리 하나를 통째로** 삭제하면 깔끔하게 사라져 죽은 코드가 안 남는다.

---

## 2. 매직 넘버 없애기

**매직 넘버**: 뜻을 밝히지 않고 코드에 직접 박은 숫자(`404`, `86400`초 등).

**냄새 (응집도 관점)**: `delay(300)`의 `300`을 "애니메이션 완료 대기"로 썼다면, 애니메이션 길이를 바꿀 때 이 숫자도 함께 바뀌어야 한다. 이름이 없으면 한쪽만 바뀌어 — 애니메이션이 끝나기도 전에 다음 로직이 실행되는 식으로 — **조용히 서비스가 깨진다**. 함께 수정될 코드 중 한쪽만 수정되는, 응집도가 낮은 코드다.

```typescript
// before
async function onLikeClick() {
  await postLike(url);
  await delay(300);
  await refetchPostLike();
}
```

**개선**: 맥락을 담은 상수로 묶어 함께 바뀌도록 한다.

```typescript
const ANIMATION_DELAY_MS = 300;

async function onLikeClick() {
  await postLike(url);
  await delay(ANIMATION_DELAY_MS);
  await refetchPostLike();
}
```

> [가독성 — 매직 넘버에 이름 붙이기](./readability.md#5-매직-넘버에-이름-붙이기)와 같은 코드의 다른 관점.

---

## 3. 폼의 응집도 생각하기

폼 관리에는 두 가지 응집 방식이 있고, **변경의 단위**에 맞춰 선택해야 한다.

### 필드 단위 응집도

개별 입력 요소를 독립적으로 관리. 각 필드가 고유 검증 로직을 가져 변경 범위가 좁고, 다른 필드에 영향을 주지 않는다.

```tsx
// react-hook-form, 필드별 validate
<input
  {...register("email", {
    validate: (value) => {
      if (isEmptyStringOrNil(value)) return "이메일을 입력해주세요.";
      if (!/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i.test(value)) return "유효한 이메일 주소를 입력해주세요.";
      return "";
    }
  })}
  placeholder="이메일"
/>
```

### 폼 전체 단위 응집도

모든 필드의 검증을 폼에 종속시켜 한 곳(스키마)에서 관리. 흐름을 이해하기 쉽지만 필드 간 결합도가 올라 재사용성은 떨어진다.

```tsx
import * as z from "zod";
import { zodResolver } from "@hookform/resolvers/zod";

const schema = z.object({
  name: z.string().min(1, "이름을 입력해주세요."),
  email: z.string().min(1, "이메일을 입력해주세요.").email("유효한 이메일 주소를 입력해주세요.")
});

const { register, formState: { errors }, handleSubmit } = useForm({
  defaultValues: { name: "", email: "" },
  resolver: zodResolver(schema)
});
```

### 무엇을 선택할까 (판단 기준)

| 필드 단위가 좋을 때 | 폼 전체 단위가 좋을 때 |
|---|---|
| 독립적·비동기 검증 (이메일 형식, 아이디 중복, 추천 코드 등) | 모든 필드가 하나의 완결된 기능 (결제·배송 정보) |
| 필드+검증을 다른 폼에서 재사용 | 단계별 입력 (Wizard, 회원가입, 설문) |
| | 필드 간 의존성 (비밀번호 확인, 총액 계산) |

핵심 질문: **"변경이 필드 단위로 일어나는가, 폼 전체 단위로 일어나는가?"** 그에 맞춰 구조를 정한다.
