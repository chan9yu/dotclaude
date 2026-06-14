# 예측 가능성 (Predictability)

> 함께 일하는 동료가 함수/컴포넌트의 동작을 얼마나 예측할 수 있는가. 예측 가능한 코드는 일관된 규칙을 따르고, **이름·파라미터·반환값만 보고도** 동작을 알 수 있다.

## 목차
1. [이름 겹치지 않게 관리하기](#1-이름-겹치지-않게-관리하기)
2. [같은 종류의 함수는 반환 타입 통일하기](#2-같은-종류의-함수는-반환-타입-통일하기)
3. [숨은 로직 드러내기](#3-숨은-로직-드러내기)

---

## 1. 이름 겹치지 않게 관리하기

**냄새**: 같은 이름은 같은 동작을 해야 한다. 라이브러리 `http`를 감싼 모듈도 이름이 `http`라서, `http.get`을 단순 GET으로 예상하지만 실제로는 토큰까지 가져온다. 기대와 실제가 어긋나 버그·디버깅 혼란을 부른다.

```typescript
// before — http.ts: 라이브러리와 같은 이름이지만 인증 로직이 숨어 있음
import { http as httpLibrary } from "@some-library/http";

export const http = {
  async get(url: string) {
    const token = await fetchToken();
    return httpLibrary.get(url, { headers: { Authorization: `Bearer ${token}` } });
  }
};
```

**개선**: 서비스가 만든 함수엔 라이브러리와 **구분되는 명확한 이름**을 준다. 동작이 이름에 드러난다.

```typescript
// httpService.ts
import { http as httpLibrary } from "@some-library/http";

export const httpService = {
  async getWithAuth(url: string) {       // 인증된 요청임을 이름으로 전달
    const token = await fetchToken();
    return httpLibrary.get(url, { headers: { Authorization: `Bearer ${token}` } });
  }
};

// fetchUser.ts
import { httpService } from "./httpService";
export async function fetchUser() {
  return await httpService.getWithAuth("...");
}
```

---

## 2. 같은 종류의 함수는 반환 타입 통일하기

같은 종류의 함수/Hook이 서로 다른 반환 타입을 가지면 일관성이 깨져, 쓸 때마다 반환 타입을 확인해야 하고 혼란·버그를 부른다.

### 예시 A — API Hook

**냄새**: `useUser`는 react-query의 `Query` 객체를, `useServerTime`은 `query.data`만 반환한다. 쓰는 쪽이 매번 "이건 `.data`를 꺼내야 하나?"를 확인해야 한다.

```typescript
// before
function useUser() {
  const query = useQuery({ queryKey: ["user"], queryFn: fetchUser });
  return query;          // Query 객체
}
function useServerTime() {
  const query = useQuery({ queryKey: ["serverTime"], queryFn: fetchServerTime });
  return query.data;     // 데이터만 ← 불일치
}
```

**개선**: API 호출 Hook은 일관되게 `Query` 객체를 반환한다.

```typescript
function useServerTime() {
  const query = useQuery({ queryKey: ["serverTime"], queryFn: fetchServerTime });
  return query;          // 통일
}
```

### 예시 B — 유효성 검사 함수

**냄새**: `checkIsNameValid`는 `boolean`을, `checkIsAgeValid`는 `{ ok, reason }` 객체를 반환한다. 객체는 항상 truthy라서 `if (checkIsAgeValid(age))`가 **항상 통과**하는 버그가 난다(엄격한 불리언 검사를 안 쓰면 특히 위험).

```typescript
// before
function checkIsNameValid(name: string) {
  const isValid = name.length > 0 && name.length < 20;
  return isValid;                       // boolean
}
function checkIsAgeValid(age: number) {
  if (!Number.isInteger(age)) return { ok: false, reason: "나이는 정수여야 해요." };
  // ... return { ok: true } | { ok: false, reason }  ← 객체
}
```

**개선**: 같은 종류(유효성 검사)는 일관되게 `{ ok, ... }` 객체를 반환한다.

```typescript
function checkIsNameValid(name: string) {
  if (name.length === 0) return { ok: false, reason: "이름은 빈 값일 수 없어요." };
  if (name.length >= 20) return { ok: false, reason: "이름은 20자 이상 입력할 수 없어요." };
  return { ok: true };
}
```

> 팁: 반환 타입을 Discriminated Union으로 정의하면 컴파일러가 불필요한 접근을 막아준다.
> ```typescript
> type ValidationCheckReturnType = { ok: true } | { ok: false; reason: string };
> // isAgeValid.ok 가 true인 분기에서 reason 접근 시 타입 에러
> ```

---

## 3. 숨은 로직 드러내기

**냄새**: 이름·파라미터·반환값에 안 드러나는 **숨은 부수효과**. `fetchBalance`가 호출될 때마다 몰래 `balance_fetched` 로깅을 한다. 로깅을 원치 않는 곳에서도 로깅되고, 로깅이 깨지면 잔액 조회까지 망가질 수 있다.

```typescript
// before
async function fetchBalance(): Promise<number> {
  const balance = await http.get<number>("...");
  logging.log("balance_fetched");        // ← 숨은 부수효과
  return balance;
}
```

**개선**: 이름·파라미터·반환 타입으로 예측 가능한 로직만 본문에 남기고, 부수효과(로깅)는 호출하는 쪽에서 명시적으로 분리한다.

```typescript
async function fetchBalance(): Promise<number> {
  const balance = await http.get<number>("...");
  return balance;
}

// 사용처에서 명시적으로
<Button
  onClick={async () => {
    const balance = await fetchBalance();
    logging.log("balance_fetched");
    await syncBalance(balance);
  }}
>
  계좌 잔액 갱신하기
</Button>
```
