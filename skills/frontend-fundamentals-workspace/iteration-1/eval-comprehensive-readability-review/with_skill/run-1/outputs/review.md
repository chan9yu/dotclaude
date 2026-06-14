# OrderStatusCard 코드 리뷰

"자꾸 손이 가고 읽기 힘들다"는 느낌의 정체를 4가지 렌즈(가독성·예측 가능성·응집도·결합도)로 진단했습니다. 핵심 원인은 **게스트/회원이라는 같이 실행되지 않는 두 분기가 한 컴포넌트에 뒤섞여 있고**, 그 위에 **이름 없는 복잡한 조건**과 **매직 넘버**가 얹혀 있어, 한 줄을 읽을 때 머릿속에 담아야 할 맥락이 너무 많다는 점입니다.

먼저 원본을 다시 정리합니다.

```tsx
import { useEffect } from "react";

// 주문 상태 카드. 게스트/회원에 따라 재주문 버튼이 다르게 동작한다.
export function OrderStatusCard({ order }: { order: Order }) {
  const isGuest = useAuth().type === "guest";

  useEffect(() => {
    if (isGuest) {
      return;
    }
    trackImpression(order.id);
  }, [isGuest, order.id]);

  const canReorder =
    order.items.filter(
      (item) =>
        item.status === "delivered" &&
        item.refundedAt == null &&
        Date.now() - item.deliveredAt < 2592000000
    ).length > 0;

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
}
```

---

## 코드 냄새 진단

### 🔴 가독성 — `isGuest` 분기가 컴포넌트 전체에 흩어져 있음 (같이 실행되지 않는 코드 분리하기)

- **무엇이**: `isGuest`라는 한 가지 조건이 컴포넌트의 **세 군데**에 영향을 줍니다. ① `useEffect` 안의 early-return(게스트면 impression 추적 안 함), ② `canReorder` 계산(게스트일 땐 계산해봐야 안 쓰임), ③ 마지막 삼항(게스트용 카드 vs 회원용 카드). 게스트 경로와 회원 경로가 한 함수 본문에서 교차합니다.
- **왜 변경하기 어려운가**: 이 컴포넌트를 읽는 사람은 게스트일 때의 동작과 회원일 때의 동작을 **항상 동시에** 머릿속에 올려야 합니다. "게스트면 impression을 안 보내고, 버튼은 항상 disabled이고, canReorder는 무시되고…" — 분기 하나가 본문 곳곳에 퍼져 있어, 한쪽 동작만 바꾸려 해도 컴포넌트 전체를 다시 읽어야 합니다. 게스트 경로엔 `canReorder`가 죽은 계산으로 매번 돌아가는 점도 신호입니다(실행되지만 결과가 안 쓰임).
- **개선**: 분기를 **단 하나(맨 위)로 모으고**, 각 경우를 별도 컴포넌트로 완전히 분리합니다. 각 컴포넌트는 분기 하나만 다루므로 맥락이 절반으로 줄어듭니다. 이것이 `references/readability.md`의 "1. 같이 실행되지 않는 코드 분리하기" 그대로의 상황입니다(원문의 `SubmitButton`/`isViewer` 예시와 구조가 동일).

```tsx
// after — 분기를 맨 위 한 곳으로 모으고, 경우별로 컴포넌트를 쪼갬
export function OrderStatusCard({ order }: { order: Order }) {
  const isGuest = useAuth().type === "guest";
  return isGuest ? (
    <GuestOrderStatusCard order={order} />
  ) : (
    <MemberOrderStatusCard order={order} />
  );
}

// 게스트: impression 추적 없음, 재주문은 항상 비활성
function GuestOrderStatusCard({ order }: { order: Order }) {
  return (
    <div className="card">
      <span>{order.title}</span>
      <Button disabled>재주문</Button>
    </div>
  );
}

// 회원: impression 추적 + 재주문 가능 여부 판단
function MemberOrderStatusCard({ order }: { order: Order }) {
  useEffect(() => {
    trackImpression(order.id);
  }, [order.id]);

  const canReorder = order.items.some(isReorderable);

  return (
    <div className="card">
      <span>{order.title}</span>
      <Button disabled={!canReorder} onClick={() => reorder(order.id)}>
        재주문
      </Button>
    </div>
  );
}
```

분리 후 각 컴포넌트가 가져가는 이점:
- `GuestOrderStatusCard`에는 `useEffect`도, `canReorder`도 없습니다. 게스트는 추적도 안 하고 버튼도 항상 막혀 있다는 사실이 **코드 양만 봐도** 드러납니다.
- `MemberOrderStatusCard`의 `useEffect`는 `if (isGuest) return;` 가드가 사라져 의존성 배열이 `[order.id]`로 단순해집니다. "왜 게스트 체크가 effect 안에 있지?"라는 시점 이동이 없어집니다.
- 게스트 경로에서 헛돌던 `canReorder` 계산이 자연스럽게 사라집니다(불필요한 연산 제거는 덤).

### 🟡 가독성 — `canReorder`의 `filter(...)` 안 익명 조건이 이름 없이 길다 (복잡한 조건에 이름 붙이기)

- **무엇이**: `filter` 콜백 안에 `item.status === "delivered" && item.refundedAt == null && Date.now() - item.deliveredAt < 2592000000` 세 조건이 익명으로 묶여 있고, 바깥은 `.length > 0`로 "하나라도 있으면"을 표현합니다.
- **왜 변경하기 어려운가**: 이 콜백이 "무엇이 재주문 가능한 아이템인가"라는 **도메인 규칙**인데, 코드엔 그 이름이 없습니다. 읽는 사람은 세 조건을 직접 해석해 "아, 배송 완료 + 환불 안 됨 + 배송한 지 한 달 이내구나"를 매번 머릿속에서 재구성해야 합니다. `.filter(...).length > 0`은 의도(존재 여부)보다 구현(전체를 거른 뒤 길이를 셈)을 드러내는 패턴이기도 합니다.
- **개선**: 조건에 **이름을 붙여** 별도 함수(`isReorderable`)로 빼고, `.filter(...).length > 0` 대신 의도를 그대로 말하는 `.some(...)`을 씁니다. `references/readability.md`의 "4. 복잡한 조건에 이름 붙이기" 기준(여러 줄에 걸친 복잡한 로직 → 이름을 붙일 가치가 있음)에 정확히 해당합니다.

```tsx
// after — 도메인 규칙에 이름을 붙임
const REORDER_WINDOW_MS = 30 * 24 * 60 * 60 * 1000; // 배송 완료 후 30일

function isReorderable(item: OrderItem): boolean {
  const isDelivered = item.status === "delivered";
  const isNotRefunded = item.refundedAt == null;
  const isWithinReorderWindow = Date.now() - item.deliveredAt < REORDER_WINDOW_MS;
  return isDelivered && isNotRefunded && isWithinReorderWindow;
}

// 사용처
const canReorder = order.items.some(isReorderable);
```

`canReorder = order.items.some(isReorderable)` 한 줄만 읽어도 "재주문 가능한 아이템이 하나라도 있는가"가 그대로 읽힙니다. 세부 규칙이 궁금할 때만 `isReorderable`로 내려가면 되므로, 평소엔 시점을 옮길 필요가 없습니다. 더불어 이 규칙은 독립적인 단위 테스트가 붙기 좋아집니다(경계값 테스트: 정확히 30일째 등).

### 🟡 가독성 + 응집도 — `2592000000`은 정체불명의 매직 넘버 (매직 넘버에 이름 붙이기)

- **무엇이**: `Date.now() - item.deliveredAt < 2592000000`의 `2592000000`. 사실 `30 * 24 * 60 * 60 * 1000`(= 30일을 밀리초로)이지만, 코드만 봐선 알 수 없습니다.
- **왜 변경하기 어려운가**:
  - (가독성) 이 숫자가 30일인지 31일인지, 시간 단위가 ms인지 s인지 작성자 외엔 알 수 없습니다. 읽는 사람이 매번 암산해야 합니다.
  - (응집도) "재주문 가능 기간"이라는 정책이 바뀌어 45일이 되면 이 숫자도 함께 바뀌어야 합니다. 그런데 이름이 없으면, 같은 정책이 다른 화면(예: 안내 문구 "배송 후 30일 이내 재주문 가능")에도 박혀 있을 때 **한쪽만 바뀌어 조용히 어긋납니다**. 함께 수정될 값이 묶여 있지 않은, 응집도가 낮은 코드입니다(`references/cohesion.md` "2. 매직 넘버 없애기").
- **개선**: 위 after에서 이미 `REORDER_WINDOW_MS = 30 * 24 * 60 * 60 * 1000`로 이름을 붙였습니다. `2592000000`이라는 결과값을 직접 적지 않고 `30 * 24 * 60 * 60 * 1000`처럼 **계산식 그대로** 두면 "30일"이라는 의미가 식에 드러나 더 좋습니다. 이 상수는 재주문 정책이 사는 곳(도메인 모듈)에 두어, 정책이 바뀔 때 한 곳만 고치면 모든 사용처가 함께 바뀌도록 합니다.

### 🟢 예측 가능성 — `useAuth().type === "guest"`가 인증 구현 상세를 본문에 노출 (선택)

- **무엇이**: `const isGuest = useAuth().type === "guest";` — 인증 객체의 내부 구조(`type` 필드, `"guest"`라는 문자열 리터럴)가 이 카드 컴포넌트에 그대로 새어 나와 있습니다.
- **왜 변경하기 어려운가**: 인증 모델이 바뀌어 `type`이 `role`이 되거나 `"guest"`가 `"anonymous"`로 바뀌면, 같은 비교를 하는 모든 컴포넌트를 찾아 고쳐야 합니다. "게스트인가?"라는 **질문의 의미**는 그대로인데 구현이 흩어져 결합도가 올라갑니다.
- **개선(판단 보류)**: 만약 `isGuest` 같은 판별이 이 컴포넌트 말고도 여러 곳에서 쓰인다면, `useAuth`가 `isGuest`(또는 `useIsGuest()`)를 직접 노출하도록 모아두는 게 좋습니다. 다만 **이 카드에서만 쓰이고 다른 데선 안 쓴다면 지금처럼 두는 것도 충분**합니다 — 섣불리 추상화하면 오히려 시점 이동만 늘 수 있습니다. 사용 범위를 확인한 뒤 결정하시길 권합니다.

```tsx
// 여러 곳에서 게스트 판별이 필요할 때만:
// const isGuest = useIsGuest();  // useAuth 내부에서 type === "guest"를 캡슐화
```

---

## ⚖️ 트레이드오프 메모

이 리뷰에서 가장 신경 쓴 판단은 **"게스트/회원 두 카드의 공통 JSX(`<div className="card"><span>{order.title}</span>...</div>`)를 공통 컴포넌트로 묶을 것인가"** 였습니다.

- **묶고 싶은 유혹(응집도·DRY)**: 카드 껍데기와 제목이 똑같으니 `<OrderCardShell>` 같은 걸로 추출하면 중복이 사라집니다.
- **묶지 않기로 한 이유(가독성·결합도 우선)**: 이 컴포넌트의 핵심 가치는 **게스트 경로와 회원 경로를 따로 읽을 수 있게 만드는 것**입니다. 공통 껍데기로 묶으면 다시 한 겹 추상화가 끼어 "껍데기는 어디서 오지?"라는 시점 이동이 생기고, 더 중요하게는 **두 경로가 앞으로 갈라질 여지가 큽니다**. 게스트 카드엔 "로그인하고 재주문하기" 안내가 붙거나, 회원 카드엔 배송 추적/리뷰가 추가되는 식의 변경은 흔합니다. `references/coupling.md`의 "2. 중복 코드 허용하기" 기준대로, **미래에 함께 바뀔 운명이 아니라 갈라질 운명**으로 보이므로 지금은 중복(`<div className="card">`)을 허용해 각 카드를 독립적으로 수정 가능하게 두는 편이 낫습니다.
- 다만 `order.title` 표시 방식 같은 **정말로 항상 동일할** 부분이 늘어난다면 그때 추출을 재검토하면 됩니다. 지금 단계에선 컴포넌트 분리만으로 충분합니다.

또한 `isReorderable`을 별도 함수로 빼는 것은 가독성과 응집도를 **동시에** 올립니다(맥락 줄이기 + 정책의 한 곳 모음). 이건 트레이드오프 없이 이득인 변경이라 우선순위가 높습니다.

---

## 정리 — 우선순위 순 적용 가이드

영향이 큰 것부터, 작게 나눠 적용하시길 권합니다.

1. **🔴 게스트/회원 컴포넌트 분리** — `OrderStatusCard`를 얇은 분기로 두고 `GuestOrderStatusCard` / `MemberOrderStatusCard`로 쪼개기. "손이 가고 읽기 힘들다"의 가장 큰 원인이 여기서 해소됩니다.
2. **🟡 `isReorderable` 함수 추출 + `.some()` 사용** — 도메인 규칙에 이름 붙이기. 가독성·응집도 동시 개선, 테스트 용이.
3. **🟡 `REORDER_WINDOW_MS` 상수화** — `2592000000` 제거, `30 * 24 * 60 * 60 * 1000`로 의미 드러내기.
4. **🟢 (조건부) `isGuest` 캡슐화** — 게스트 판별이 여러 곳에서 쓰일 때만. 사용 범위 확인 후 결정.

### 최종 after 전체 코드

```tsx
import { useEffect } from "react";

// 배송 완료 후 30일까지 재주문 가능
const REORDER_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;

function isReorderable(item: OrderItem): boolean {
  const isDelivered = item.status === "delivered";
  const isNotRefunded = item.refundedAt == null;
  const isWithinReorderWindow = Date.now() - item.deliveredAt < REORDER_WINDOW_MS;
  return isDelivered && isNotRefunded && isWithinReorderWindow;
}

export function OrderStatusCard({ order }: { order: Order }) {
  const isGuest = useAuth().type === "guest";
  return isGuest ? (
    <GuestOrderStatusCard order={order} />
  ) : (
    <MemberOrderStatusCard order={order} />
  );
}

function GuestOrderStatusCard({ order }: { order: Order }) {
  return (
    <div className="card">
      <span>{order.title}</span>
      <Button disabled>재주문</Button>
    </div>
  );
}

function MemberOrderStatusCard({ order }: { order: Order }) {
  useEffect(() => {
    trackImpression(order.id);
  }, [order.id]);

  const canReorder = order.items.some(isReorderable);

  return (
    <div className="card">
      <span>{order.title}</span>
      <Button disabled={!canReorder} onClick={() => reorder(order.id)}>
        재주문
      </Button>
    </div>
  );
}
```

읽는 사람이 한 번에 담아야 하는 맥락이 "게스트 카드 하나" 또는 "회원 카드 하나"로 줄었고, 재주문 규칙은 이름이 붙어 본문 흐름을 끊지 않습니다. 정책 숫자는 한 곳에 모여 함께 바뀝니다. 이 세 가지가 "자꾸 손이 가던" 피로의 핵심 원인이었습니다.
