# `useConfirmAction` 공통 훅 리팩토링

## 중복 패턴 분석

두 페이지의 핸들러는 동일한 흐름을 따릅니다.

1. "다이얼로그 열림" 로그를 남긴다 (`*_confirm_opened`)
2. 확인 다이얼로그를 연다
3. 사용자가 확인하면 "확인됨" 로그를 남기고 (`*_confirmed`) 실제 액션을 실행한다
4. 어떤 경우든 뷰를 닫는다

차이가 나는 부분은 딱 네 가지입니다.

- 로그 이벤트 이름 (`payment` / `subscription`)
- 다이얼로그 제목
- 실행할 액션 (`pay` / `subscribe`)

즉, **흐름(구조)은 같고 값(설정)만 다른** 전형적인 중복이라 훅으로 빼기 좋은 케이스입니다.

다만 로그 이벤트 이름 규칙이 `{name}_confirm_opened` / `{name}_confirmed`로 일관적인지부터 확인하는 게 좋습니다. 아래 구현은 이 규칙이 의도된 것이라 보고 `eventPrefix` 하나로 두 이벤트를 파생시켰습니다. 만약 두 이벤트 이름이 우연히 비슷할 뿐 독립적으로 바뀔 수 있다면, 아래 "대안" 절처럼 두 이름을 따로 받는 편이 안전합니다.

## 제안 구현

```tsx
// hooks/useConfirmAction.ts
type ConfirmActionOptions = {
  /** 로그 이벤트 접두사. 예) "payment" -> payment_confirm_opened / payment_confirmed */
  eventPrefix: string;
  /** 확인 다이얼로그 제목 */
  title: string;
  /** 사용자가 확인했을 때 실행할 액션 */
  action: () => Promise<void>;
};

export function useConfirmAction({ eventPrefix, title, action }: ConfirmActionOptions) {
  const confirmDialog = useConfirmDialog();
  const closeView = useCloseView();

  return async function confirmAndRun() {
    logger.log(`${eventPrefix}_confirm_opened`);

    const ok = await confirmDialog.open({ title });
    if (ok) {
      logger.log(`${eventPrefix}_confirmed`);
      await action();
    }

    closeView();
  };
}
```

> `confirmDialog` / `closeView`가 원래 어디서 오는지는 입력 코드에 드러나 있지 않습니다. 위에서는 훅 내부에서 가져오는 형태(`useConfirmDialog`, `useCloseView`)로 가정했는데, 실제로는 모듈 싱글턴이거나 상위에서 주입받는 값일 수 있습니다. 프로젝트 구조에 맞게 이 부분만 맞춰 주세요. 핵심 중복 제거(로깅 + 다이얼로그 + 액션 + 닫기 흐름)는 그대로 유효합니다.

## 사용처

```tsx
// PaymentPage.tsx
const handlePay = useConfirmAction({
  eventPrefix: "payment",
  title: "결제하시겠어요?",
  action: pay,
});

// SubscriptionPage.tsx
const handleSubscribe = useConfirmAction({
  eventPrefix: "subscription",
  title: "구독을 시작할까요?",
  action: subscribe,
});
```

두 핸들러가 `useConfirmAction(...)` 호출 한 줄로 줄어듭니다. 새 페이지에서 같은 "확인 → 로깅 → 액션 → 닫기" 패턴이 필요하면 설정 객체만 넘기면 됩니다.

## 트레이드오프 — 무엇을 얻고 무엇을 주의해야 하나

이 리팩토링은 명백히 이득인 부분과, 한 번 짚고 넘어가야 할 부분이 같이 있습니다.

**얻는 것**
- 동일한 제어 흐름이 한 곳(`useConfirmAction`)에만 존재합니다. "확인 후에는 항상 닫는다", "확인을 누르면 로그를 남긴다" 같은 정책이 바뀌어도 한 곳만 고치면 됩니다.
- 로그 이벤트 누락 같은 실수가 줄어듭니다. (`opened`는 찍고 `confirmed`는 빠뜨리는 식의 불일치 방지)

**주의할 것 — 결합도(coupling)**
- 이제 결제와 구독이 같은 훅에 묶입니다. 둘이 "겉모습만 비슷한" 코드가 아니라 **진짜로 같은 정책을 공유해야 하는 흐름**일 때만 이 결합이 정당합니다.
- 예를 들어 나중에 "결제는 확인 후에도 뷰를 닫지 않고 결과 화면으로 전환" 같은 요구가 생기면, 공통 훅에 `if (eventPrefix === "payment")` 같은 분기가 끼기 시작합니다. 그 순간 중복 제거로 얻은 이득이 사라지고 오히려 읽기 어려워집니다.
- 그래서 권장 기준은 단순합니다. **지금처럼 흐름이 완전히 동일한 동안에만 공유하고, 한쪽만 달라지기 시작하면 주저 없이 그 케이스를 훅 밖으로 다시 꺼내는 것**입니다. 중복 제거가 목적이 아니라 "함께 바뀌는 것을 함께 두는 것"이 목적입니다.

지금 상태는 두 흐름이 토씨 하나 빼고 같으므로, 훅으로 빼는 게 적절합니다.

## 대안 — 이벤트 이름을 명시적으로 받기

`eventPrefix` 한 개에서 두 이벤트 이름을 문자열 조합으로 파생시키는 방식이 불편하다면(이름 규칙이 깨질 수 있거나, 로그 이벤트가 타입으로 관리되는 경우), 두 이름을 그대로 받는 편이 더 안전하고 검색도 잘 됩니다.

```tsx
type ConfirmActionOptions = {
  title: string;
  action: () => Promise<void>;
  events: {
    onOpen: string;
    onConfirm: string;
  };
};

export function useConfirmAction({ title, action, events }: ConfirmActionOptions) {
  const confirmDialog = useConfirmDialog();
  const closeView = useCloseView();

  return async function confirmAndRun() {
    logger.log(events.onOpen);

    const ok = await confirmDialog.open({ title });
    if (ok) {
      logger.log(events.onConfirm);
      await action();
    }

    closeView();
  };
}
```

```tsx
const handlePay = useConfirmAction({
  title: "결제하시겠어요?",
  action: pay,
  events: { onOpen: "payment_confirm_opened", onConfirm: "payment_confirmed" },
});
```

`payment_confirm_opened` 같은 문자열이 코드에 그대로 박혀 있어 전역 검색(grep)이 잘 되고, 로그 이벤트 이름이 규칙에 묶이지 않습니다. 대신 호출부가 살짝 길어집니다. 로그 이벤트가 분석 도구에서 enum/상수로 관리되는 팀이라면 이 방식을 추천합니다.

## 정리

- 두 핸들러는 값만 다른 동일 흐름이므로 `useConfirmAction`으로 추출하는 게 맞습니다.
- 핵심은 **"확인 → 로깅 → 액션 → 닫기" 정책을 한 곳에 모으는 것**이고, 그 결과 호출부는 설정 객체 한 번으로 끝납니다.
- 단, 결제/구독이 한쪽만 달라지기 시작하면 공통 훅에 분기를 넣지 말고 해당 케이스를 다시 분리하세요. 이 훅의 가치는 "흐름이 같은 동안"에만 유지됩니다.
- 로그 이벤트 이름을 규칙으로 묶을지(`eventPrefix`) 명시적으로 받을지(`events`)는 팀의 로깅 관리 방식에 맞춰 선택하면 됩니다.
