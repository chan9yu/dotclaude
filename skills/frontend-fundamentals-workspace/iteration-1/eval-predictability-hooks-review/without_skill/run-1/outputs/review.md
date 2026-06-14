# `notifications.ts` 코드 리뷰

알림 관련 데이터 훅과 액션 함수를 살펴봤어요. 지금도 충분히 짧고 읽기 쉬운 코드지만, **PR로 올리기 전에 일관성과 예측 가능성을 높일 수 있는 지점**이 몇 군데 보입니다. 아래에 우선순위 순으로 정리했고, 마지막에 개선된 전체 코드를 첨부했어요.

---

## 핵심 요약

| # | 이슈 | 심각도 | 한 줄 요약 |
|---|------|--------|-----------|
| 1 | 훅 간 반환 타입 불일치 | 높음 | `useNotifications`는 `query` 객체를, `useUnreadCount`는 가공된 `number`를 반환해 호출부 패턴이 달라짐 |
| 2 | queryKey 관리 분산 | 중간 | 문자열 배열 키가 인라인으로 흩어져 오타·중복·무효화 누락 위험 |
| 3 | 의존성(`http`, `analytics`, `fetch*`)이 암묵적 전역 | 중간 | import도 정의도 없이 등장 → 타입 안전성과 테스트 가능성 저하 |
| 4 | `markAsRead` 성공 후 캐시 무효화 누락 | 중간 | 읽음 처리해도 목록/카운트 캐시가 갱신 안 됨 (mutation으로 승격 권장) |
| 5 | 불필요한 중간 변수 / 주석 | 낮음 | `const query = ...; return query;` 패턴, 모호한 한글 주석 |

---

## 1. 훅의 반환 타입을 일관되게 (가장 중요)

지금 두 훅의 "모양"이 서로 다릅니다.

```ts
export function useNotifications() {
  const query = useQuery({ ... });
  return query;                 // ← query 객체 전체 (data, isLoading, error ...)
}

export function useUnreadCount() {
  const query = useQuery({ ... });
  return query.data ?? 0;        // ← number 하나만
}
```

호출하는 쪽 입장에서 보면 이렇게 갈립니다.

```ts
const { data, isLoading } = useNotifications(); // 객체 구조분해
const unreadCount = useUnreadCount();           // 값 그대로
```

같은 파일에 있는 "같은 종류"의 훅인데 한쪽은 React Query 객체를, 다른 한쪽은 가공된 값을 돌려줍니다. 이러면 사용하는 사람이 **매번 "이 훅은 뭘 돌려주더라?"를 확인**해야 해서 예측 가능성이 떨어져요. 게다가 `useUnreadCount`는 값만 주기 때문에 호출부에서 `isLoading`/`error`를 알 수 없어, 로딩 스피너나 에러 처리가 필요해지는 순간 훅을 다시 고쳐야 합니다.

**선택지 A — 둘 다 query 객체를 반환 (React Query 관례에 가장 충실, 추천)**

```ts
export function useNotifications() {
  return useQuery({
    queryKey: notificationKeys.list(),
    queryFn: fetchNotifications,
  });
}

export function useUnreadCount() {
  return useQuery({
    queryKey: notificationKeys.unreadCount(),
    queryFn: fetchUnreadCount,
    // 기본값이 필요하면 select 또는 placeholderData로 표현
    select: (count) => count ?? 0,
  });
}
```

이렇게 하면 두 훅 모두 `{ data, isLoading, error, ... }`를 반환해 호출 패턴이 통일되고, `useUnreadCount`도 로딩/에러 상태를 그대로 노출할 수 있습니다. 불필요한 중간 변수(`const query = ...; return query;`)도 함께 제거했어요.

**선택지 B — 정말로 "값"만 쓰는 게 의도라면 이름으로 드러내기**

값만 반환하는 게 팀의 명확한 컨벤션이라면, 그 사실을 이름에 담아 두 훅의 추상화 수준이 다르다는 걸 드러내는 것도 방법입니다. 예를 들어 값 반환 훅은 `useXxxValue`처럼 접미사를 붙이거나, 카운트 훅은 셀렉터 형태로 분리합니다. 다만 같은 파일 안에서 한쪽만 가공하는 현재 상태가 가장 헷갈리므로, 가능하면 **A로 통일하는 걸 추천**합니다.

---

## 2. queryKey를 한곳에서 관리 (Query Key Factory)

```ts
queryKey: ["notifications"],
queryKey: ["unreadCount"],
```

키가 문자열로 인라인되어 있으면 다음 문제가 생기기 쉽습니다.

- `markAsRead` 이후 `["notifications"]` / `["unreadCount"]`를 무효화하려 할 때, 키 문자열을 **수동으로 다시 적어야 하고 오타가 나도 컴파일러가 못 잡습니다.**
- 키 네이밍 규칙(`"unreadCount"` vs `["notifications", "unread"]`)이 파일마다 제각각이 됩니다.

키 팩토리로 모아 두면 자동완성·타입 안전·일괄 무효화가 쉬워집니다.

```ts
export const notificationKeys = {
  all: ["notifications"] as const,
  list: () => [...notificationKeys.all, "list"] as const,
  unreadCount: () => [...notificationKeys.all, "unreadCount"] as const,
};
```

이렇게 하면 `queryClient.invalidateQueries({ queryKey: notificationKeys.all })` 한 번으로 알림 관련 캐시를 전부 무효화할 수도 있습니다.

> 참고: 키 팩토리 도입은 "지금 당장 꼭 필요한가?"를 따져 보세요. 이 파일만 본다면 다소 과해 보일 수 있지만, 다음 항목(무효화)과 직접 맞물려 있어 이번에 함께 정리해 두면 비용 대비 효과가 좋습니다.

---

## 3. 암묵적 전역 의존성을 명시적으로

```ts
queryFn: fetchNotifications,   // 어디서 옴?
await http.post(...)           // http 는?
analytics.track(...)           // analytics 는?
```

`fetchNotifications`, `fetchUnreadCount`, `http`, `analytics`가 import도 정의도 없이 등장합니다. 전역으로 주입되는 구조일 수도 있지만, 그러면:

- 타입 추론이 약해지고(특히 `useQuery`의 `data` 타입),
- 이 모듈을 테스트할 때 전역을 모킹해야 해서 테스트가 까다로워지며,
- 이 파일만 봐서는 의존성을 파악할 수 없습니다.

**최소한 명시적으로 import** 해 주세요.

```ts
import { http } from "@/lib/http";
import { analytics } from "@/lib/analytics";
import { fetchNotifications, fetchUnreadCount } from "./api";
```

`queryFn`의 반환 타입(`fetchNotifications: () => Promise<Notification[]>` 등)이 잡혀 있으면 `useQuery`의 제네릭을 따로 안 적어도 `data` 타입이 정확히 추론됩니다.

---

## 4. `markAsRead`를 mutation으로 승격 + 캐시 무효화

```ts
export async function markAsRead(id: string): Promise<void> {
  await http.post(`/notifications/${id}/read`);
  analytics.track("notification_read", { id });
}
```

현재는 **순수 async 함수**라서 두 가지가 빠져 있습니다.

1. **캐시 무효화 누락** — 읽음 처리 후 `["notifications"]` 목록과 `["unreadCount"]`가 그대로라, UI가 즉시 갱신되지 않습니다. (이게 알림 기능에서 가장 흔히 발견되는 버그예요.)
2. **상태 노출 부재** — `isPending`/`error`를 호출부에서 알 수 없어 버튼 로딩/에러 토스트를 직접 구현해야 합니다.

파일의 다른 멤버가 전부 React Query 훅인데 이것만 생짜 함수라는 점에서도 일관성이 떨어집니다. `useMarkAsRead` 훅으로 통일하길 권합니다.

```ts
export function useMarkAsRead() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      await http.post(`/notifications/${id}/read`);
      return id;
    },
    onSuccess: (id) => {
      analytics.track("notification_read", { id });
      queryClient.invalidateQueries({ queryKey: notificationKeys.all });
    },
  });
}
```

> 만약 "훅이 아닌 단순 함수로 두는 게 의도"라면(예: 리액트 컴포넌트 밖에서 호출), 그 경우엔 최소한 무효화 책임을 호출부에 넘기거나 `queryClient`를 인자로 받도록 만들어 **캐시 갱신 누락만큼은 막아 주세요.**

부수효과 순서에 대한 작은 디테일: 현재 코드는 `await` 성공 직후에만 `analytics.track`이 실행되므로, 요청이 실패하면 트래킹도 건너뛰는 동작입니다(보통 이게 맞습니다). mutation으로 옮기면 `onSuccess`에 두어 같은 의미를 유지했어요.

---

## 5. 자잘한 정리

- **중간 변수 제거**: `const query = useQuery(...); return query;` → 바로 `return useQuery(...)`.
- **주석**: `// 알림 관련 데이터 훅과 액션 함수 모음`은 코드가 이미 말해 주는 내용이라 가치가 적습니다. 파일 상단 JSDoc으로 "이 모듈의 책임/사용법"을 적거나, 없애도 됩니다.
- **`?? 0` 위치**: 위 4번처럼 `select`로 옮기면 기본값 로직이 훅 정의 한곳에 모여 호출부가 깔끔해집니다.

---

## 개선된 전체 코드 (선택지 A 기준)

```ts
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { analytics } from "@/lib/analytics";
import { http } from "@/lib/http";
import { fetchNotifications, fetchUnreadCount } from "./api";

/**
 * 알림 도메인의 React Query 키 팩토리.
 * notificationKeys.all 로 알림 관련 캐시를 일괄 무효화할 수 있습니다.
 */
export const notificationKeys = {
  all: ["notifications"] as const,
  list: () => [...notificationKeys.all, "list"] as const,
  unreadCount: () => [...notificationKeys.all, "unreadCount"] as const,
};

/** 알림 목록 조회 */
export function useNotifications() {
  return useQuery({
    queryKey: notificationKeys.list(),
    queryFn: fetchNotifications,
  });
}

/** 안 읽은 알림 개수 (없으면 0) */
export function useUnreadCount() {
  return useQuery({
    queryKey: notificationKeys.unreadCount(),
    queryFn: fetchUnreadCount,
    select: (count) => count ?? 0,
  });
}

/** 알림 읽음 처리 + 관련 캐시 무효화 */
export function useMarkAsRead() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      await http.post(`/notifications/${id}/read`);
      return id;
    },
    onSuccess: (id) => {
      analytics.track("notification_read", { id });
      queryClient.invalidateQueries({ queryKey: notificationKeys.all });
    },
  });
}
```

호출부도 세 훅 모두 동일한 패턴이 됩니다.

```ts
const { data: notifications, isLoading } = useNotifications();
const { data: unreadCount } = useUnreadCount();
const { mutate: markAsRead, isPending } = useMarkAsRead();
```

---

## 트레이드오프 / 적용 가이드

- **이 파일만의 변경으로 끝나지 않습니다.** `markAsRead`를 훅으로 바꾸면 기존 호출부(컴포넌트)도 함께 수정해야 해요. PR 범위가 커진다면, 우선 **1·3·5번(반환 타입 통일 / 명시적 import / 자잘한 정리)**만 먼저 반영하고, **2·4번(키 팩토리 / mutation 승격)**은 별도 PR로 나누는 것도 합리적입니다.
- 만약 `markAsRead`가 **컴포넌트 밖(이벤트 핸들러 모듈, 서버 액션 등)에서도 호출되어야 한다면** 훅으로 못 바꿉니다. 그 경우엔 함수 형태를 유지하되 **4번의 캐시 무효화 누락만큼은 반드시 해결**해 주세요 — 이게 기능상 가장 위험한 부분입니다.

전반적으로 코드 자체는 깔끔합니다. 가장 임팩트 큰 한 가지만 꼽자면 **훅 반환 타입 통일(1번)**, 가장 버그 위험이 큰 한 가지는 **`markAsRead` 후 캐시 무효화(4번)**입니다.
