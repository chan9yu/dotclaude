# 결제·구독 확인 다이얼로그 중복 — 공통 훅으로 빼기 전에

요청은 "`useConfirmAction`으로 빼서 중복 제거"인데, 이 코드는 **섣부른 공통화를 가장 경계해야 하는 전형적인 형태**입니다. 결론부터 말하면: **지금 바로 공통 훅으로 묶지 않는 것을 권합니다.** 아래에서 왜 그런지, 그리고 그래도 공통화한다면 어떻게 해야 결합도 폭탄이 안 되는지를 같이 보여드립니다.

먼저 두 함수를 나란히 놓고 무엇이 같고 무엇이 다른지 봅니다.

```tsx
// PaymentPage.tsx
async function handlePay() {
  logger.log("payment_confirm_opened");                      // (A) 로그 키
  const ok = await confirmDialog.open({ title: "결제하시겠어요?" }); // (B) 다이얼로그 문구
  if (ok) {
    logger.log("payment_confirmed");                         // (C) 로그 키
    await pay();                                             // (D) 확정 액션
  }
  closeView();                                               // (E) 뒷정리
}

// SubscriptionPage.tsx
async function handleSubscribe() {
  logger.log("subscription_confirm_opened");
  const ok = await confirmDialog.open({ title: "구독을 시작할까요?" });
  if (ok) {
    logger.log("subscription_confirmed");
    await subscribe();
  }
  closeView();
}
```

**같은 것**: 흐름의 뼈대 — "열림 로그 → 확인 다이얼로그 → (확인 시) 확정 로그 + 액션 → closeView".
**다른 것**: (A)(C) 로그 키 2개, (B) 다이얼로그 문구, (D) 확정 액션. 즉 **5개 자리 중 4개가 페이지마다 다릅니다.**

---

## 코드 냄새 진단

### 🟡 결합도 — 공통화하면 인자만 4개짜리 훅이 됨 (중복 코드 허용하기)

- **무엇이**: 두 핸들러를 `useConfirmAction` 하나로 묶으면, 달라지는 자리(로그 키 2개 + 문구 + 액션)를 전부 인자로 받아야 합니다. 흐름의 뼈대(고작 5줄)만 공통이고 **변동 지점이 변동되지 않는 지점보다 많은** 구조입니다.
- **왜 변경하기 어려운가**: 이건 references의 `useOpenMaintenanceBottomSheet` 예시와 거의 같은 형태입니다. 지금은 깔끔해 보여도, 요구사항이 한 번 갈라지는 순간 공통 훅이 인자를 더 받기 시작하고, 그때부터 **결제든 구독이든 한쪽을 고치려면 다른 쪽까지 매번 회귀 테스트**해야 합니다. 영향 범위가 두 페이지로 묶여버립니다. 갈라질 만한 변경은 이미 보입니다:
  - 구독은 확인 후 약관 동의 단계가 추가될 수 있음 → `if (ok)` 분기 안의 흐름이 달라짐
  - 결제는 실패 시 에러 토스트, 구독은 성공 화면 이동 등 **뒤처리(closeView 자리)가 갈라짐**
  - 로그 스키마에 페이지별 파라미터(금액, 플랜 id)가 붙음 → 로그 시그니처가 갈라짐
- **개선**: **지금은 공통화하지 않습니다.** 중복은 2곳, 각 5줄, 뼈대만 같고 알맹이는 다릅니다. 중복을 허용해 두 페이지를 **독립적으로 수정 가능**하게 두는 편이 변경 비용이 더 쌉니다(결합도 우선). references "중복 코드 허용하기"의 판단을 그대로 적용한 결과입니다.

### 🟡 예측 가능성 — confirm과 logging이 한 덩어리로 엉켜 있음 (숨은 로직 드러내기)

- **무엇이**: 진짜 중복이자 진짜 가치 있는 추상화 대상은 "전체 핸들러"가 아니라 **"열림 로그 → 확인 → 확정 로그"라는 confirm+logging 패턴 한 조각**입니다. 다만 이걸 통째로 훅에 숨기면, `fetchBalance`가 몰래 로깅하던 예시처럼 "확인 다이얼로그를 띄웠더니 로그도 알아서 찍힌다"는 **숨은 부수효과**가 됩니다. 로그 키를 못 바꾸거나, 로그 안 찍고 싶은 곳에서도 강제로 찍힙니다.
- **개선**: 공통화를 한다면 **흐름 전체가 아니라 confirm+logging 조각만**, 그리고 **달라지는 값은 전부 인자로 드러내서** 추출합니다. 핸들러 본문이 스스로 무엇을 로깅하고 무엇을 실행하는지 읽히도록 유지합니다.

---

## ⚖️ 트레이드오프 메모 (이 리뷰의 핵심)

이 과제는 "중복을 제거하라 vs 결합도를 낮춰라"가 정면충돌하는 자리입니다.

- **공통화(응집도↑)의 이득**: 흐름이 한 곳에 모여 "확인 다이얼로그 패턴"을 일관되게 관리. 로그 누락 같은 실수 방지.
- **공통화(결합도↑)의 비용**: 변동 지점이 4개라 인자가 비대해지고, 페이지별 요구사항이 갈라질 때 모든 사용처를 함께 손봐야 함.

판단 기준은 단 하나, **"이 둘은 미래에 함께 바뀔 운명인가?"** 입니다.
- 결제와 구독은 **도메인이 다른 별개 기능**이고, 약관·결제수단·성공 후 동작 등에서 갈라질 여지가 큽니다. "지금 비슷해 보인다"는 것뿐이지 "함께 바뀔 운명"이라는 근거는 약합니다.
- 따라서 **기본 권고는 중복 허용**(현 상태 유지)입니다. references 표현대로, 섣부른 공통화는 가장 흔한 실수입니다.

> ❓ **확인이 필요한 부분**: "확인 다이얼로그 + 열림/확정 로깅"이 결제·구독을 넘어 **앞으로 여러 페이지에 계속 늘어날 표준 패턴**인가요? (예: 탈퇴, 포인트 전환 등에도 동일 패턴 예정) 만약 그렇다면 — 즉 사용처가 3곳 이상이고 패턴이 사내 표준으로 굳어질 거라면 — 공통화의 손익이 역전됩니다. 그 경우엔 아래 절충안을 권합니다.

---

## 절충안 — 그래도 공통화한다면: "흐름 전체"가 아니라 "로깅되는 confirm 한 조각"만

전체 핸들러를 삼키지 말고, **달라지는 값을 전부 인자로 노출**하고 **확정 후 동작은 호출부에 남깁니다.** 이렇게 하면 숨은 부수효과를 없애고, 페이지별 갈라짐(약관 추가, 뒤처리 변경)을 공통 훅 밖에서 자유롭게 흡수할 수 있습니다.

```tsx
// useConfirmAction.ts — 공통화하는 것은 "흐름 전체"가 아니라
// "열림 로그 → 확인 → 확정 로그" 조각뿐. 확정 액션·뒷정리는 돌려주지 않고 호출부가 가짐.
function useConfirmAction() {
  const logger = useLogger();
  const confirmDialog = useConfirmDialog();

  // 달라지는 값(문구·로그 키 2개)을 전부 인자로 드러낸다 → 숨은 로직 없음
  return async ({
    title,
    openLog,
    confirmLog,
  }: {
    title: string;
    openLog: string;
    confirmLog: string;
  }): Promise<boolean> => {
    logger.log(openLog);
    const ok = await confirmDialog.open({ title });
    if (ok) {
      logger.log(confirmLog);
    }
    return ok; // 확정 후 무엇을 할지는 호출부의 책임으로 남긴다
  };
}
```

```tsx
// PaymentPage.tsx — 확정 액션과 closeView 같은 페이지 고유 흐름은 여기에 그대로 남는다
const confirmAction = useConfirmAction();

async function handlePay() {
  const ok = await confirmAction({
    title: "결제하시겠어요?",
    openLog: "payment_confirm_opened",
    confirmLog: "payment_confirmed",
  });
  if (ok) {
    await pay();
  }
  closeView();
}

// SubscriptionPage.tsx
const confirmAction = useConfirmAction();

async function handleSubscribe() {
  const ok = await confirmAction({
    title: "구독을 시작할까요?",
    openLog: "subscription_confirm_opened",
    confirmLog: "subscription_confirmed",
  });
  if (ok) {
    await subscribe(); // 구독이 약관 동의를 추가해도 여기만 바꾸면 됨 — 결제는 안 흔들림
  }
  closeView();
}
```

**이 절충안이 결합도 폭탄을 피하는 이유**
- 공통 훅이 떠안는 책임을 **"로깅이 붙은 확인 다이얼로그"로만 좁힘**. `pay()`/`subscribe()`, `closeView`, 약관 추가 같은 갈라짐은 전부 호출부에 남아 **페이지별로 독립 수정** 가능.
- 달라지는 값(문구·로그 키)이 **이름 있는 인자로 드러나** 숨은 부수효과가 없음. 호출부만 봐도 무엇이 로깅되는지 읽힘.
- `if (ok) await pay()`를 훅 안으로 빨아들이지 않으므로, "확정 후 흐름이 갈라지는" 가장 흔한 변경에 강함.

---

## 최종 권고

1. **1순위 — 현 상태 유지(중복 허용).** 사용처가 2곳뿐이고 결제·구독은 갈라질 여지가 크므로, 지금은 결합도를 낮게 두는 편이 변경하기 쉽습니다. "거슬리는 중복"의 실체는 고작 5줄짜리 뼈대이고, 알맹이는 이미 다릅니다.
2. **2순위 — 같은 패턴이 3곳 이상으로 늘어나거나 사내 표준으로 굳는 게 확실해지면**, 위 절충안처럼 **confirm+logging 조각만, 값은 인자로 드러내고, 확정 후 동작은 호출부에 남겨** 추출하세요. 흐름 전체(`if (ok) await action(); closeView();`)를 훅에 삼키는 형태는 피하세요.

> 한 줄 요약: 중복 제거 자체가 목적이 되면 안 됩니다. **"이 둘이 미래에 함께 바뀔 운명인가?"**에 자신 있게 "예"라고 답할 수 있을 때만 공통화하고, 그때도 흐름 전체가 아니라 변하지 않는 조각만 묶으세요.
