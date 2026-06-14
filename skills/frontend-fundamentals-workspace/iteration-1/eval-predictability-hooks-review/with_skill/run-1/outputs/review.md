# notifications.ts 코드 리뷰

> 기준: Frontend Fundamentals (변경하기 쉬운 코드) — 가독성·예측 가능성·응집도·결합도
> 결론 먼저: PR 자체를 막을 버그는 없지만, **예측 가능성**에서 팀이 두고두고 헷갈릴 불일치가 두 군데 있습니다. 이 두 개만 먼저 잡고 올리는 걸 권합니다. 나머지는 취향/소규모 개선입니다.

---

## 코드 냄새 진단

### 🔴 예측 가능성 — 같은 종류의 Hook인데 반환 타입이 다름 (`useNotifications` vs `useUnreadCount`)

- **무엇이**: 둘 다 "알림 데이터를 가져오는 API Hook"이라는 같은 종류인데, 반환값이 제각각입니다.
  - `useNotifications` → react-query의 `Query` 객체 전체를 반환 (`isLoading`, `error`, `data` 다 들어 있음)
  - `useUnreadCount` → `query.data ?? 0`, 즉 **숫자만** 반환 (로딩/에러 상태가 사라짐)
- **왜 변경하기 어려운가**: 쓰는 쪽이 Hook 이름만 보고 동작을 예측할 수 없습니다. 매번 "이건 `.data`를 꺼내야 하나, 아니면 바로 값인가?"를 구현을 열어 확인해야 합니다. 알림 Hook이 앞으로 더 늘어나면(`useNotificationSettings` 등) 이 들쭉날쭉함이 그대로 전염됩니다. 특히 `useUnreadCount`는 로딩/에러를 `0`으로 뭉개버려서, "아직 안 불러온 0"과 "진짜 0개"를 호출하는 쪽에서 구분할 수 없습니다 — 배지에 잠깐 0이 깜빡이는 류의 버그가 여기서 납니다.
- **개선**: API 호출 Hook은 일관되게 `Query` 객체를 반환합니다. "읽지 않은 개수만 필요하면 `.data`에서 꺼낸다"는 규칙 하나로 통일됩니다. `?? 0` 같은 기본값은 **호출하는 쪽**에서 그 화면 맥락에 맞게 정하게 둡니다.

```typescript
// before
export function useUnreadCount() {
  const query = useQuery({
    queryKey: ["unreadCount"],
    queryFn: fetchUnreadCount,
  });
  return query.data ?? 0;   // ← 숫자만. 로딩/에러가 사라지고, 반환 타입이 useNotifications와 불일치
}

// after — 같은 종류 Hook은 같은 반환 타입(Query 객체)으로 통일
export function useUnreadCount() {
  return useQuery({
    queryKey: notificationKeys.unreadCount(),
    queryFn: fetchUnreadCount,
  });
}

// 사용처에서 그 화면에 맞는 기본값을 명시적으로
const { data: unreadCount = 0 } = useUnreadCount();
```

> 적용 패턴: 예측 가능성 — *같은 종류의 함수는 반환 타입 통일하기*

---

### 🔴 예측 가능성 — `markAsRead`에 숨은 부수효과 (`analytics.track`)

- **무엇이**: `markAsRead(id)`는 이름·파라미터·반환 타입(`Promise<void>`) 어디에도 "분석 이벤트를 쏜다"는 신호가 없는데, 본문에서 몰래 `analytics.track("notification_read", ...)`를 호출합니다.
- **왜 변경하기 어려운가**: 두 가지 책임("읽음 처리"라는 서버 상태 변경 + "사용자 행동 추적"이라는 분석)이 한 함수에 묶여 있습니다.
  - **원치 않는 곳에서도 추적됩니다.** 예를 들어 "모두 읽음" 버튼이 `markAsRead`를 루프로 100번 부르면 `notification_read`가 100번 쌓여 지표가 오염됩니다. 시스템이 자동으로 읽음 처리하는 경우에도 사용자가 읽은 것처럼 기록됩니다.
  - **분석이 본질 로직을 망가뜨릴 수 있습니다.** `analytics.track`이 동기적으로 던지거나 느려지면, 단순 "읽음 처리"가 같이 깨지거나 느려집니다.
  - 호출하는 사람은 이 부수효과를 예측할 수 없어, 디버깅할 때 "왜 이 이벤트가 여기서 찍히지?"를 추적하느라 시간을 씁니다.
- **개선**: 함수에는 이름이 약속한 일(읽음 처리)만 남기고, 분석 이벤트는 **그 행동을 유발한 사용자 인터랙션 지점**(클릭 핸들러 등)에서 명시적으로 호출합니다.

```typescript
// before
export async function markAsRead(id: string): Promise<void> {
  await http.post(`/notifications/${id}/read`);
  analytics.track("notification_read", { id });   // ← 이름·반환값에 안 드러나는 숨은 부수효과
}

// after — markAsRead는 "읽음 처리"만. 추적은 호출하는 쪽에서 명시적으로
export async function markAsRead(id: string): Promise<void> {
  await http.post(`/notifications/${id}/read`);
}

// 사용처(예: 알림 클릭 핸들러)에서
async function onNotificationClick(id: string) {
  await markAsRead(id);
  analytics.track("notification_read", { id });   // 사용자가 실제로 읽은 그 지점에서만
}
```

> 적용 패턴: 예측 가능성 — *숨은 로직 드러내기*
>
> ⚖️ **트레이드오프 메모**: "여러 호출처에서 매번 `analytics.track`을 잊지 않고 부르게 하려면, 차라리 함수 안에 묶는 게 응집도 아니냐?"는 반론이 가능합니다. 하지만 여기서는 **분석을 원하는 맥락과 원치 않는 맥락이 갈립니다**(개별 클릭 vs 일괄 읽음 vs 시스템 자동 읽음). 모든 호출처가 같은 추적을 원할 운명이 아니므로, 응집도를 위해 묶기보다 예측 가능성을 우선해 드러내는 게 맞습니다. 만약 정말 "이 함수가 불릴 때는 항상·정확히 한 번 이벤트를 쏴야 한다"가 확정이라면 그땐 `trackNotificationRead`처럼 추적을 이름에 드러낸 별도 함수로 묶으세요 — 핵심은 "숨기지 않는 것"입니다.

---

### 🟡 응집도 — query key가 문자열 리터럴로 흩어져 있음

- **무엇이**: `["notifications"]`, `["unreadCount"]` 같은 query key가 Hook마다 인라인 문자열로 박혀 있습니다.
- **왜 변경하기 어려운가**: `markAsRead`로 읽음 처리한 뒤 목록과 안 읽은 개수를 무효화(invalidate)하려면 이 key들을 **다른 파일에서 똑같이 다시 적어야** 합니다. 한쪽에서 `"unreadCount"`를 `"unread-count"`로 바꾸면, 무효화 코드는 조용히 어긋나 캐시가 갱신되지 않는 버그가 납니다(타입 에러도 안 납니다). 함께 바뀌어야 할 값이 흩어져 있는 전형적인 낮은 응집도입니다.
- **개선**: query key를 한 곳(key factory)에 모아 단일 출처로 만듭니다. 매직 문자열에 이름을 붙이는 것과 같은 효과입니다.

```typescript
// after — key를 한 곳에서 관리 (단일 출처)
export const notificationKeys = {
  all: ["notifications"] as const,
  list: () => [...notificationKeys.all, "list"] as const,
  unreadCount: () => [...notificationKeys.all, "unreadCount"] as const,
};

export function useNotifications() {
  return useQuery({
    queryKey: notificationKeys.list(),
    queryFn: fetchNotifications,
  });
}
```

> 적용 패턴: 응집도 — *매직 넘버(매직 문자열) 없애기*. 다만 이건 "지금 당장 깨지는 버그"는 아니라 🟡입니다. 무효화 로직이 아직 이 파일/PR에 없다면 과한 선반영일 수 있으니, **읽음 처리 후 invalidate를 붙일 계획이 있는지** 확인하고 도입하세요. 계획이 없다면 지금은 보류해도 됩니다.

---

### 🟢 예측 가능성 — `http` 래퍼 이름이 라이브러리와 겹치는지 확인

- **무엇이**: `markAsRead`가 쓰는 `http.post`가 무엇인지 이 파일만으론 알 수 없습니다. 만약 이 `http`가 사내에서 인증 토큰 주입 등을 하는 **자체 래퍼**라면, 라이브러리 `http`와 이름이 같아 동작을 오해하게 만듭니다.
- **왜 변경하기 어려운가**: `http.post`를 단순 POST로 기대했는데 토큰/리트라이/에러 변환 같은 숨은 동작이 있으면, 쓰는 쪽 예측이 어긋납니다.
- **개선**: 자체 래퍼라면 `apiClient`, `httpService.postWithAuth`처럼 라이브러리와 **구분되는 이름**을 쓰세요. 이미 표준 라이브러리(axios 인스턴스 등)를 그대로 쓰는 거라면 문제없습니다 — 그래서 🟢입니다.

> 적용 패턴: 예측 가능성 — *이름 겹치지 않게 관리하기*. 코드베이스 전반의 컨벤션이라 이 PR 범위에서 손댈 일은 아닐 수 있습니다. 확인만.

---

## 🟢 사소한 정리 (가독성)

- `useNotifications`의 `const query = ...; return query;`는 한 단계 우회입니다. 바로 `return useQuery({...})`로 줄이면 읽는 사람이 추적할 변수 하나가 줄어듭니다. (위 after에 반영)
- 파일 상단 주석 `// 알림 관련 데이터 훅과 액션 함수 모음`은 정확하지만, 이 파일이 커지면 "조회 Hook"과 "액션 함수(markAsRead)"를 파일로 나누는 걸 고려하세요. 지금 규모(3개)에선 그대로 두는 게 낫습니다 — **섣부른 분리는 가독성만 해칩니다.**

---

## 정리: 무엇부터 고칠까

| 우선순위 | 항목 | 이유 |
|---|---|---|
| 1 (🔴) | `useUnreadCount` 반환 타입을 `Query`로 통일 | 같은 종류 Hook 불일치 — 호출처가 늘기 전에 잡아야 전염 안 됨 |
| 2 (🔴) | `markAsRead`에서 `analytics.track` 분리 | 숨은 부수효과 — 일괄/자동 읽음 시 지표 오염, 디버깅 혼란 |
| 3 (🟡) | query key를 `notificationKeys`로 모으기 | invalidate를 붙일 계획이 있을 때. 없으면 보류 |
| 4 (🟢) | `http` 래퍼 이름 확인 / `return useQuery` 단축 | 컨벤션 확인 + 미세 가독성 |

**1·2번만 반영하면 PR 올리기 충분합니다.** 3번은 "읽음 처리 후 캐시 무효화" 코드를 이 작업에서 같이 넣을 거냐에 달려 있으니, 그 계획을 알려주시면 도입 여부를 같이 정하겠습니다.

### 적용 후 최종 형태 (1·2번 반영)

```typescript
import { useQuery } from "@tanstack/react-query";

// 알림 데이터 조회 Hook과 액션 함수

export function useNotifications() {
  return useQuery({
    queryKey: ["notifications"],
    queryFn: fetchNotifications,
  });
}

export function useUnreadCount() {
  return useQuery({
    queryKey: ["unreadCount"],
    queryFn: fetchUnreadCount,
  });
}

export async function markAsRead(id: string): Promise<void> {
  await http.post(`/notifications/${id}/read`);
}
```

```typescript
// 사용처 예시 — 기본값과 분석 이벤트는 호출하는 쪽에서 명시적으로
const { data: unreadCount = 0 } = useUnreadCount();

async function onNotificationClick(id: string) {
  await markAsRead(id);
  analytics.track("notification_read", { id });
}
```
