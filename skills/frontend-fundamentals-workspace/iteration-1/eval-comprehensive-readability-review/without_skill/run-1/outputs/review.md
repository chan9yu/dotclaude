# `OrderStatusCard` 코드 리뷰

코드를 살펴봤습니다. 작은 컴포넌트지만 "자꾸 손이 가고 읽기 힘든" 이유가 꽤 명확합니다. 핵심은 **(1) JSX 분기가 거의 통째로 중복**되어 있고, **(2) 비즈니스 규칙이 매직 넘버와 인라인 조건으로 흩어져 있으며**, **(3) 게스트/회원 분기가 여러 곳(useEffect, JSX)에 퍼져 있어** 한눈에 의도가 안 들어온다는 점입니다.

아래에서 문제별로 짚고, 마지막에 개선된 전체 코드를 제시하겠습니다.

---

## 1. JSX가 게스트/회원 두 갈래로 통째로 중복됨 (가장 큰 문제)

```tsx
return isGuest ? (
  <div className="card">
    <span>{order.title}</span>
    <Button disabled>재주문</Button>
  </div>
) : (
  <div className="card">
    <span>{order.title}</span>
    <Button disabled={!canReorder} onClick={() => reorder(order.id)}>
      재주문
    </Button>
  </div>
);
```

두 분기에서 실제로 **다른 건 `<Button>` 하나뿐**인데, `div.card`와 `<span>{order.title}</span>` 껍데기를 통째로 복붙해 놨습니다.

- **읽기 힘든 이유**: 두 블록을 줄 단위로 눈으로 대조(diff)해야 "아, 버튼만 다르구나"를 깨닫게 됩니다. 의도가 코드 구조에 드러나지 않습니다.
- **유지보수 위험("손이 가는" 직접적 원인)**: 카드 레이아웃에 클래스 하나만 추가해도 **두 군데**를 똑같이 고쳐야 합니다. 한쪽만 고치면 게스트/회원 화면이 미묘하게 어긋나는 버그가 생깁니다.

**개선 방향**: 공통 껍데기는 한 번만 쓰고, 달라지는 버튼만 분기합니다.

```tsx
return (
  <div className="card">
    <span>{order.title}</span>
    {isGuest ? (
      <Button disabled>재주문</Button>
    ) : (
      <Button disabled={!canReorder} onClick={() => reorder(order.id)}>
        재주문
      </Button>
    )}
  </div>
);
```

> 참고: 게스트 버튼은 `disabled={true}`로 항상 비활성, 회원 버튼은 `disabled={!canReorder}`입니다. 게스트는 `canReorder`를 계산할 필요조차 없으므로, 분기 위치를 버튼 단위로 좁히면 자연스럽게 정리됩니다.

---

## 2. 재주문 가능 여부 계산이 "무슨 의미인지" 안 보임

```tsx
const canReorder =
  order.items.filter(
    (item) =>
      item.status === "delivered" &&
      item.refundedAt == null &&
      Date.now() - item.deliveredAt < 2592000000
  ).length > 0;
```

여기에 여러 냄새가 겹쳐 있습니다.

### 2-1. 매직 넘버 `2592000000`
이게 30일(밀리초)이라는 걸 코드만 봐서는 알 수 없습니다. 읽는 사람이 `2592000000 / 1000 / 60 / 60 / 24`를 암산해야 합니다.

```tsx
const REORDER_WINDOW_MS = 30 * 24 * 60 * 60 * 1000; // 배송 후 30일 이내 재주문 가능
```

이렇게 **이름 있는 상수**로 빼면 "30일"이라는 정책이 코드에 그대로 드러나고, 정책이 바뀔 때 한 곳만 고치면 됩니다.

### 2-2. `filter(...).length > 0` → `some(...)`
"조건을 만족하는 아이템이 하나라도 있는가?"가 의도인데, `filter`는 매칭되는 **전체 배열을 새로 만든 뒤** 길이를 셉니다. 의도는 `some`이 정확히 표현합니다(조기 종료라 약간 더 효율적이기도 합니다).

### 2-3. 조건의 "의미"가 인라인에 묻혀 있음
`item.status === "delivered" && item.refundedAt == null && ...`가 한 덩어리로 붙어 있어, 각 조건이 어떤 비즈니스 규칙인지 즉시 안 읽힙니다. **재주문 가능한 아이템의 판별 규칙**을 이름 있는 함수로 빼면 본문이 선언적으로 읽힙니다.

```tsx
function isReorderable(item: OrderItem): boolean {
  return (
    item.status === "delivered" &&
    item.refundedAt == null &&
    Date.now() - item.deliveredAt < REORDER_WINDOW_MS
  );
}

// ...
const canReorder = order.items.some(isReorderable);
```

이제 본문은 "배송 후 30일 안 지났고, 환불 안 됐고, 배송 완료된 아이템이 하나라도 있으면 재주문 가능"이라고 거의 자연어처럼 읽힙니다.

> 작은 주의: `Date.now()`를 렌더 중에 직접 호출하므로 매 렌더마다 값이 달라집니다. 이 컴포넌트 규모에서는 보통 문제없지만, "30일 경계"가 정확해야 하거나 테스트로 시점을 고정하고 싶다면 시각을 인자로 받도록(`isReorderable(item, now)`) 만드는 편이 안전합니다.

---

## 3. 게스트/회원 판단 로직이 흩어져 있음

```tsx
const isGuest = useAuth().type === "guest";

useEffect(() => {
  if (isGuest) {
    return;
  }
  trackImpression(order.id);
}, [isGuest, order.id]);
```

`isGuest`라는 파생값을 잘 뽑아둔 건 좋습니다. 다만 두 가지를 짚고 싶습니다.

- `useEffect`의 `if (isGuest) return;`는 "게스트가 아닐 때만 노출 추적"이라는 의도입니다. 조기 반환 자체는 괜찮지만, **주석으로 "회원에게만 노출 임프레션을 집계한다"**는 한 줄을 달아주면 *왜* 게스트를 제외하는지(=비즈니스 의도)가 분명해집니다. 코드는 *무엇을* 하는지는 보여주지만 *왜*는 안 보여줍니다.
- `useAuth()` 호출 결과에서 `type`만 꺼내 쓰는데, 향후 회원 등급/권한 등 분기가 늘어나면 이 한 줄이 여러 곳으로 번질 수 있습니다. 지금 당장 바꿀 필요는 없지만, 재주문 권한 판단이 늘어나면 `useCanReorder(order)` 같은 커스텀 훅으로 캡슐화하는 걸 염두에 두세요. (지금은 과한 추상화이니 **보류** 권장.)

---

## 4. 타입 import / 정의가 안 보임

`Order`, `OrderItem`, `Button`, `useAuth`, `trackImpression`, `reorder`가 어디서 오는지 파일에 import가 없습니다. 실제 코드엔 있겠지만, 리뷰 관점에서 한 가지만:

- `order: Order` 타입에서 `items`, `title`, `id`가 보장되는지 확인하세요. `item.deliveredAt`이 `delivered` 상태일 때만 존재하는 옵셔널 필드라면, `Date.now() - item.deliveredAt` 계산 전에 타입 가드가 필요할 수 있습니다(현재 `status === "delivered"` 체크가 그 역할을 하지만, 타입상 `deliveredAt`이 `number | undefined`라면 TS가 잡아줄 겁니다).

---

## 개선된 전체 코드

```tsx
import { useEffect } from "react";

// 배송 후 30일 이내에만 재주문 가능
const REORDER_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;

// 환불되지 않고 배송 완료되었으며, 배송 후 재주문 가능 기간이 지나지 않은 아이템인가?
function isReorderable(item: OrderItem): boolean {
  return (
    item.status === "delivered" &&
    item.refundedAt == null &&
    Date.now() - item.deliveredAt < REORDER_WINDOW_MS
  );
}

// 주문 상태 카드. 게스트/회원에 따라 재주문 버튼이 다르게 동작한다.
export function OrderStatusCard({ order }: { order: Order }) {
  const isGuest = useAuth().type === "guest";

  useEffect(() => {
    // 노출 임프레션은 회원에게만 집계한다.
    if (isGuest) {
      return;
    }
    trackImpression(order.id);
  }, [isGuest, order.id]);

  const canReorder = order.items.some(isReorderable);

  return (
    <div className="card">
      <span>{order.title}</span>
      {isGuest ? (
        <Button disabled>재주문</Button>
      ) : (
        <Button disabled={!canReorder} onClick={() => reorder(order.id)}>
          재주문
        </Button>
      )}
    </div>
  );
}
```

### 무엇이 좋아졌나
- **중복 제거**: `div.card` + `<span>` 껍데기를 한 번만 작성. 레이아웃 변경 시 한 곳만 수정.
- **의미가 드러남**: `2592000000` → `REORDER_WINDOW_MS`(30일), 판별 규칙 → `isReorderable`로 이름 부여.
- **의도가 정확한 API**: `filter(...).length > 0` → `some(...)`.
- **왜를 설명하는 주석**: "회원에게만 노출 집계"로 비즈니스 의도 명시.

---

## 우선순위 요약

| 순위 | 항목 | 이유 |
|------|------|------|
| 1 (필수) | JSX 중복 제거 | 버그 유발 + 가독성 최대 저해. 가장 먼저 고칠 것 |
| 2 (필수) | 매직 넘버 `2592000000` → 상수 | 정책 의미가 코드에서 사라져 있음 |
| 3 (권장) | `isReorderable` 함수 추출 + `some` 사용 | 본문이 선언적으로 읽힘, 의도 정확 |
| 4 (권장) | `useEffect`에 "왜" 주석 | 게스트 제외 이유 명시 |
| 5 (보류) | `useCanReorder` 커스텀 훅화 | 지금은 과한 추상화. 분기 늘어나면 검토 |

가장 효과가 큰 건 **1번(JSX 중복 제거)**과 **2번(매직 넘버)**입니다. 이 둘만 해도 "읽기 힘들다"는 느낌이 크게 줄어들 겁니다.
