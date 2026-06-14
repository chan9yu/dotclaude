# 가독성 (Readability)

> 코드가 읽기 쉬운 정도. 변경하려면 먼저 동작을 이해할 수 있어야 한다. 읽기 좋은 코드는 **읽는 사람이 한 번에 떠올리는 맥락이 적고**, 위에서 아래로 자연스럽게 이어진다. 사람이 한 번에 다루는 맥락은 6~7개로 제한된다(『프로그래머의 뇌』).

가독성을 높이는 3대 전략: **맥락 줄이기 · 이름 붙이기 · 위에서 아래로 읽히게 하기**.

## 목차
1. [같이 실행되지 않는 코드 분리하기](#1-같이-실행되지-않는-코드-분리하기) — 맥락 줄이기
2. [구현 상세 추상화하기](#2-구현-상세-추상화하기) — 맥락 줄이기
3. [로직 종류에 따라 합쳐진 함수 쪼개기](#3-로직-종류에-따라-합쳐진-함수-쪼개기) — 맥락 줄이기
4. [복잡한 조건에 이름 붙이기](#4-복잡한-조건에-이름-붙이기) — 이름 붙이기
5. [매직 넘버에 이름 붙이기](#5-매직-넘버에-이름-붙이기) — 이름 붙이기
6. [시점 이동 줄이기](#6-시점-이동-줄이기) — 위에서 아래로
7. [삼항 연산자 단순하게 하기](#7-삼항-연산자-단순하게-하기) — 위에서 아래로
8. [왼쪽에서 오른쪽으로 읽히게 하기](#8-왼쪽에서-오른쪽으로-읽히게-하기) — 위에서 아래로

---

## 1. 같이 실행되지 않는 코드 분리하기

**냄새**: 동시에 실행되지 않는 코드(예: `viewer`일 때와 일반 사용자일 때)가 한 컴포넌트/함수에 뒤섞여, 분기가 곳곳에 흩어지고 읽는 사람이 두 경우를 동시에 머리에 담아야 한다.

```tsx
// before — 두 권한 상태가 한 컴포넌트에 교차
function SubmitButton() {
  const isViewer = useRole() === "viewer";

  useEffect(() => {
    if (isViewer) {
      return;
    }
    showButtonAnimation();
  }, [isViewer]);

  return isViewer ? (
    <TextButton disabled>Submit</TextButton>
  ) : (
    <Button type="submit">Submit</Button>
  );
}
```

**개선**: 분기를 단 하나로 모으고, 각 경우를 별도 컴포넌트로 완전히 분리한다. 각 컴포넌트는 분기 하나만 다루므로 맥락이 적다.

```tsx
function SubmitButton() {
  const isViewer = useRole() === "viewer";
  return isViewer ? <ViewerSubmitButton /> : <AdminSubmitButton />;
}

function ViewerSubmitButton() {
  return <TextButton disabled>Submit</TextButton>;
}

function AdminSubmitButton() {
  useEffect(() => {
    showButtonAnimation();
  }, []);
  return <Button type="submit">Submit</Button>;
}
```

---

## 2. 구현 상세 추상화하기

**냄새**: 한 컴포넌트가 본연의 역할 외에 부수적인 구현 상세(로그인 확인 후 리다이렉트, 동의 다이얼로그 로직 등)까지 본문에 그대로 노출해, 한 번에 따라가야 할 맥락이 많다.

### 예시 A — 로그인 가드

```tsx
// before — 로그인 확인/이동 로직이 본문에 노출
function LoginStartPage() {
  useCheckLogin({
    onChecked: (status) => {
      if (status === "LOGGED_IN") {
        location.href = "/home";
      }
    }
  });
  /* ... 로그인 관련 로직 ... */
  return <>{/* ... */}</>;
}
```

개선: 인증 확인/이동 책임을 **Wrapper 컴포넌트**나 **HOC**로 분리한다. 분리된 컴포넌트끼리 참조를 막아 불필요한 의존도 끊는다.

```tsx
// 옵션 A: Wrapper 컴포넌트
function App() {
  return (
    <AuthGuard>
      <LoginStartPage />
    </AuthGuard>
  );
}

function AuthGuard({ children }) {
  const status = useCheckLoginStatus();
  useEffect(() => {
    if (status === "LOGGED_IN") {
      location.href = "/home";
    }
  }, [status]);
  return status !== "LOGGED_IN" ? children : null;
}

// 옵션 B: HOC
export default withAuthGuard(LoginStartPage);

function withAuthGuard(WrappedComponent) {
  return function AuthGuard(props) {
    const status = useCheckLoginStatus();
    useEffect(() => {
      if (status === "LOGGED_IN") {
        location.href = "/home";
      }
    }, [status]);
    return status !== "LOGGED_IN" ? <WrappedComponent {...props} /> : null;
  };
}
```

### 예시 B — 동의 다이얼로그를 가진 버튼

`<FriendInvitation />`이 초대 버튼과 함께, 동의를 받는 상세 다이얼로그 로직까지 전부 들고 있어 맥락이 과하다. 또한 동의 로직과 그것을 실행하는 `<Button>`이 멀리 떨어져 **응집도**도 낮다(함께 수정될 코드가 떨어져 있음).

개선: 동의 로직 + 버튼을 `<InviteButton />`으로 추상화해 한 곳에 모은다. 버튼과 클릭 핸들러가 가까워지고, 부모 컴포넌트의 맥락이 줄어든다.

```tsx
export function FriendInvitation() {
  const { data } = useQuery(/* ... */);
  return (
    <>
      <InviteButton name={data.name} />
      {/* ... */}
    </>
  );
}

function InviteButton({ name }) {
  return (
    <Button onClick={async () => {
      const canInvite = await overlay.openAsync(({ isOpen, close }) => (
        <ConfirmDialog title={`${name}님에게 공유해요`} /* ... */ />
      ));
      if (canInvite) {
        await sendPush();
      }
    }}>
      초대하기
    </Button>
  );
}
```

> 추상화의 본질: "왼쪽으로 10걸음 걸어라"를 구현 상세까지 풀어 쓰면("북쪽 기준 90도 회전한 방향으로...") 오히려 이해 불가능해진다. 코드도 6~7개 맥락 단위로 적절히 추상화해야 읽힌다.

---

## 3. 로직 종류에 따라 합쳐진 함수 쪼개기

**냄새**: 쿼리 파라미터·상태·API 호출 등을 **종류별로 한 덩어리**로 묶은 Hook(`usePageState`류). 책임이 "페이지의 모든 쿼리 파라미터 관리"처럼 무제한 확장되어 구현이 길어지고 역할 파악이 어렵다. 성능도 나쁘다 — 어떤 파라미터 하나만 바뀌어도 이 Hook을 쓰는 모든 컴포넌트가 리렌더링된다.

```typescript
// before — 페이지의 모든 쿼리 파라미터를 한 Hook이 관리
export function usePageState() {
  const [query, setQuery] = useQueryParams({
    cardId: NumberParam,
    statementId: NumberParam,
    dateFrom: DateParam,
    dateTo: DateParam,
    statusList: ArrayParam
  });
  return useMemo(() => ({ values: { /* ...5개... */ }, controls: { /* ...5개... */ } }), [query, setQuery]);
}
```

**개선**: 쿼리 파라미터별로 별도 Hook으로 분리한다. 이름이 명확해지고 수정의 영향 범위가 좁아진다(결합도도 함께 개선).

```typescript
export function useCardIdQueryParam() {
  const [cardId, _setCardId] = useQueryParam("cardId", NumberParam);
  const setCardId = useCallback((cardId: number) => {
    _setCardId({ cardId }, "replaceIn");
  }, []);
  return [cardId ?? undefined, setCardId] as const;
}
```

> 이 코드는 [결합도 — 책임을 하나씩 관리하기](./coupling.md#1-책임을-하나씩-관리하기)와 동일한 코드의 다른 관점이다.

---

## 4. 복잡한 조건에 이름 붙이기

**냄새**: 익명 함수와 `filter`/`some`/`&&`가 여러 겹 중첩되어 정확한 조건을 한눈에 못 읽는다.

```typescript
// before
const result = products.filter((product) =>
  product.categories.some(
    (category) =>
      category.id === targetCategory.id &&
      product.prices.some((price) => price >= minPrice && price <= maxPrice)
  )
);
```

**개선**: 의미 있는 조건에 이름을 붙여 맥락을 줄인다.

```typescript
const matchedProducts = products.filter((product) => {
  return product.categories.some((category) => {
    const isSameCategory = category.id === targetCategory.id;
    const isPriceInRange = product.prices.some(
      (price) => price >= minPrice && price <= maxPrice
    );
    return isSameCategory && isPriceInRange;
  });
});
```

**언제 이름을 붙이나 (판단 기준)**
- 붙이는 게 좋을 때: 복잡한 로직이 여러 줄에 걸칠 때 · 같은 로직을 여러 곳에서 재사용할 때 · 독립적인 단위 테스트가 필요할 때.
- 굳이 안 붙여도 될 때: 로직이 매우 단순할 때(`arr.map(x => x * 2)`) · 한 번만 쓰이고 복잡하지 않을 때. 과도한 이름 붙이기는 오히려 시점 이동을 늘린다.

---

## 5. 매직 넘버에 이름 붙이기

**매직 넘버**: 뜻을 밝히지 않고 코드에 직접 박은 숫자(`404`, 하루 `86400`초 등).

**냄새**: `delay(300)`의 `300`이 무엇을 위한 대기인지(애니메이션? 반영 지연? 지우다 만 테스트?) 작성자 외엔 알 수 없다. 여러 명이 수정하다 의도와 다르게 바뀔 수 있다.

```typescript
// before
async function onLikeClick() {
  await postLike(url);
  await delay(300);
  await refetchPostLike();
}
```

**개선**: 맥락을 담은 상수로 선언한다.

```typescript
const ANIMATION_DELAY_MS = 300;

async function onLikeClick() {
  await postLike(url);
  await delay(ANIMATION_DELAY_MS);
  await refetchPostLike();
}
```

> 이 값은 [응집도 — 매직 넘버 없애기](./cohesion.md#2-매직-넘버-없애기) 관점에서도 중요하다: 애니메이션이 바뀌면 이 숫자도 함께 바뀌어야 하는데, 이름이 없으면 한쪽만 바뀌어 조용히 깨진다.

---

## 6. 시점 이동 줄이기

**시점 이동**: 코드를 읽다 위아래로, 여러 파일·함수·변수를 오가는 것. 시점이 많이 이동할수록 맥락 유지가 어렵다. 위에서 아래로, 한 함수/파일에서 읽히게 하라.

**냄새**: `Invite` 버튼이 왜 비활성화되는지 알려면 `policy.canInvite` → `getPolicyByRole(user.role)` → `POLICY_SET`까지 3번 시점을 옮겨야 한다. 권한 체계가 간단한데도 `POLICY_SET` 같은 추상화를 쓰면 오히려 읽기 어렵다.

```tsx
// before
function Page() {
  const user = useUser();
  const policy = getPolicyByRole(user.role);
  return (
    <div>
      <Button disabled={!policy.canInvite}>Invite</Button>
      <Button disabled={!policy.canView}>View</Button>
    </div>
  );
}
function getPolicyByRole(role) {
  const policy = POLICY_SET[role];
  return { canInvite: policy.includes("invite"), canView: policy.includes("view") };
}
const POLICY_SET = { admin: ["invite", "view"], viewer: ["view"] };
```

**개선 A — 조건을 펼쳐 그대로 드러내기**: 권한별 요구사항을 코드에 직접 노출. 위에서 아래로만 읽어도 파악된다.

```tsx
function Page() {
  const user = useUser();
  switch (user.role) {
    case "admin":
      return (<div><Button disabled={false}>Invite</Button><Button disabled={false}>View</Button></div>);
    case "viewer":
      return (<div><Button disabled={true}>Invite</Button><Button disabled={false}>View</Button></div>);
    default:
      return null;
  }
}
```

**개선 B — 한눈에 보이는 객체로**: 권한 로직을 컴포넌트 안 객체로 모아 시점 이동 없이 본다.

```tsx
function Page() {
  const user = useUser();
  const policy = {
    admin: { canInvite: true, canView: true },
    viewer: { canInvite: false, canView: true }
  }[user.role];
  return (
    <div>
      <Button disabled={!policy.canInvite}>Invite</Button>
      <Button disabled={!policy.canView}>View</Button>
    </div>
  );
}
```

> 주의: 추상화(`POLICY_SET`) 자체가 나쁜 게 아니다. **권한 체계가 복잡하면** 유용하다. 지금처럼 간단할 때 과한 추상화가 문제다 — 트레이드오프 판단이 필요하다.

---

## 7. 삼항 연산자 단순하게 하기

**냄새**: 삼항 연산자를 중첩하면 조건 구조가 안 보인다.

```typescript
// before
const status =
  A조건 && B조건 ? "BOTH" : A조건 || B조건 ? (A조건 ? "A" : "B") : "NONE";
```

**개선**: `if`로 풀어 조건을 명확히 드러낸다(즉시 실행 함수로 값 반환).

```typescript
const status = (() => {
  if (A조건 && B조건) return "BOTH";
  if (A조건) return "A";
  if (B조건) return "B";
  return "NONE";
})();
```

---

## 8. 왼쪽에서 오른쪽으로 읽히게 하기

**냄새**: 범위 비교 `a >= b && a <= c`는 중간값 `a`를 두 번 확인하게 만들어 인지 부담을 준다.

```typescript
// before
if (a >= b && a <= c) { ... }
if (score >= 80 && score <= 100) { console.log("우수"); }
```

**개선**: 수학의 부등식(`b ≤ a ≤ c`)처럼 시작점→끝점이 왼쪽에서 오른쪽으로 읽히게 쓴다.

```typescript
if (b <= a && a <= c) { ... }
if (80 <= score && score <= 100) { console.log("우수"); }
if (minPrice <= price && price <= maxPrice) { console.log("적정 가격"); }
```
