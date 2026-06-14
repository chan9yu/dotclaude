# 결합도 (Coupling)

> 코드를 수정했을 때의 **영향 범위**. 영향 범위가 좁아 변경에 따른 파장을 예측할 수 있는 코드가 수정하기 쉽다.
>
> ⚠️ **응집도와 상충**: 중복을 제거해 하나로 묶으면 응집도는 오르지만 결합도도 같이 올라(공통 코드를 고치면 모든 사용처가 흔들림) 수정이 어려워질 수 있다. 동작이 페이지마다 **달라질 여지**가 있으면 중복을 허용해 결합도를 낮춰라.

## 목차
1. [책임을 하나씩 관리하기](#1-책임을-하나씩-관리하기)
2. [중복 코드 허용하기](#2-중복-코드-허용하기)
3. [Props Drilling 지우기](#3-props-drilling-지우기)

---

## 1. 책임을 하나씩 관리하기

**냄새**: 한 Hook/함수가 너무 넓은 책임을 떠안는다. `usePageState()`는 "이 페이지의 모든 쿼리 파라미터 관리"라는 광범위한 책임 탓에, 페이지의 많은 컴포넌트·훅이 여기에 의존하게 되고, 한 번 수정하면 영향 범위가 급격히 퍼진다.

```typescript
// before — 모든 쿼리 파라미터를 한 Hook이 떠안음
export function usePageState() {
  const [query, setQuery] = useQueryParams({
    cardId: NumberParam, statementId: NumberParam,
    dateFrom: DateParam, dateTo: DateParam, statusList: ArrayParam
  });
  return useMemo(() => ({ values: { /* ... */ }, controls: { /* ... */ } }), [query, setQuery]);
}
```

**개선**: 쿼리 파라미터별로 **책임을 하나씩** 분리한다. 수정의 영향 범위가 좁아져 예상 못한 파장을 막는다.

```typescript
export function useCardIdQueryParam() {
  const [cardId, _setCardId] = useQueryParam("cardId", NumberParam);
  const setCardId = useCallback((cardId: number) => {
    _setCardId({ cardId }, "replaceIn");
  }, []);
  return [cardId ?? undefined, setCardId] as const;
}
```

> [가독성 — 로직 종류로 합쳐진 함수 쪼개기](./readability.md#3-로직-종류에-따라-합쳐진-함수-쪼개기)와 같은 코드의 다른 관점.

---

## 2. 중복 코드 허용하기

> ⚠️ 이 패턴은 직관에 반한다. **"중복을 제거하라"가 항상 옳지 않다.**

**냄새**: 여러 페이지에 반복되던 로직을 공통 Hook으로 묶었다. 하지만 앞으로 페이지마다 요구사항이 갈라질 수 있다.

```typescript
// 여러 페이지에서 반복되어 공통화한 Hook
export const useOpenMaintenanceBottomSheet = () => {
  const maintenanceBottomSheet = useMaintenanceBottomSheet();
  const logger = useLogger();

  return async (maintainingInfo: TelecomMaintenanceInfo) => {
    logger.log("점검 바텀시트 열림");
    const result = await maintenanceBottomSheet.open(maintainingInfo);
    if (result) {
      logger.log("점검 바텀시트 알림받기 클릭");
    }
    closeView();
  };
};
```

다음 변경이 닥치면 이 Hook은 복잡한 인자를 받게 되고, 수정할 때마다 **모든 사용처를 테스트**해야 한다:
- 페이지마다 로깅 값이 다르다면?
- 어떤 페이지는 바텀시트를 닫아도 화면은 안 닫아야 한다면?
- 바텀시트의 텍스트·이미지가 페이지마다 달라야 한다면?

**개선(판단)**: 동료와 적극적으로 소통해 동작을 정확히 이해하라.
- 로깅 값·동작·모양이 **동일하고 앞으로도 그럴 예정**이면 → 공통화로 응집도를 챙긴다.
- 페이지마다 **달라질 여지**가 있으면 → 공통화하지 말고 **중복 코드를 허용**하는 것이 더 좋다(결합도를 낮춰 각 페이지를 독립적으로 수정 가능).

> 섣부른 공통화는 가장 흔한 실수다. 추상화는 "지금 비슷해 보이는가"가 아니라 **"미래에 함께 바뀔 운명인가"**로 결정한다.

---

## 3. Props Drilling 지우기

**냄새**: 부모가 받은 prop을 쓰지도 않으면서 자식에게 **그대로 패스스루**(props drilling)한다. `ItemEditModal` → `ItemEditBody` → `ItemEditList`가 `keyword`, `recommendedItems`, `onConfirm` 등을 단순 전달한다. prop 이름 하나(`name`→`firstName`)만 바뀌어도, 또는 `recommendedItems`를 없애려 해도 거치는 **모든 컴포넌트를 수정**해야 한다 — 결합도가 높다.

```tsx
// before — 같은 값을 여러 계층이 그대로 전달
function ItemEditModal({ open, items, recommendedItems, onConfirm, onClose }) {
  const [keyword, setKeyword] = useState("");
  return (
    <Modal open={open} onClose={onClose}>
      <ItemEditBody
        items={items} keyword={keyword} onKeywordChange={setKeyword}
        recommendedItems={recommendedItems} onConfirm={onConfirm} onClose={onClose}
      />
    </Modal>
  );
}
```

### 개선 A — 조합(Composition) 패턴

부모가 자식을 `children`으로 직접 조립하면 중간 전달이 사라지고, 각 컴포넌트의 역할·의도가 명확해진다.

```tsx
function ItemEditModal({ open, items, recommendedItems, onConfirm, onClose }) {
  const [keyword, setKeyword] = useState("");
  return (
    <Modal open={open} onClose={onClose}>
      <ItemEditBody keyword={keyword} onKeywordChange={setKeyword} onClose={onClose}>
        <ItemEditList
          keyword={keyword} items={items}
          recommendedItems={recommendedItems} onConfirm={onConfirm}
        />
      </ItemEditBody>
    </Modal>
  );
}

function ItemEditBody({ children, keyword, onKeywordChange, onClose }) {
  return (
    <>
      <div style={{ display: "flex", justifyContent: "space-between" }}>
        <Input value={keyword} onChange={(e) => onKeywordChange(e.target.value)} />
        <Button onClick={onClose}>닫기</Button>
      </div>
      {children}
    </>
  );
}
```

조합만으로 안 풀리거나 트리가 깊으면 ↓

### 개선 B — Context API

깊은 계층에 공유할 값을 Context로 내려, 중간 전달을 제거한다.

```tsx
function ItemEditList({ keyword, onConfirm }) {
  const { items, recommendedItems } = useItemEditModalContext();
  // ...
}
```

> ⚠️ Props Drilling이라고 무조건 Context로 가지 마라. 우선순위:
> 1. **props가 컴포넌트의 역할·의도를 잘 표현**한다면 그대로 두는 게 낫다.
> 2. 단순 전달용이라면 먼저 **`children`(조합 패턴)**으로 depth를 줄여본다.
> 3. 그래도 안 되는 깊고 복잡한 경우에만 **최후의 수단으로 Context API**를 쓴다.
