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
