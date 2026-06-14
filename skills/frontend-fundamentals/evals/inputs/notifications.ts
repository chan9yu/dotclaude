import { useQuery } from "@tanstack/react-query";

// 알림 관련 데이터 훅과 액션 함수 모음

export function useNotifications() {
  const query = useQuery({
    queryKey: ["notifications"],
    queryFn: fetchNotifications,
  });
  return query;
}

export function useUnreadCount() {
  const query = useQuery({
    queryKey: ["unreadCount"],
    queryFn: fetchUnreadCount,
  });
  return query.data ?? 0;
}

export async function markAsRead(id: string): Promise<void> {
  await http.post(`/notifications/${id}/read`);
  analytics.track("notification_read", { id });
}
