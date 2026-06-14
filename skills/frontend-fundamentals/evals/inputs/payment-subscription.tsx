// PaymentPage.tsx
async function handlePay() {
  logger.log("payment_confirm_opened");
  const ok = await confirmDialog.open({ title: "결제하시겠어요?" });
  if (ok) {
    logger.log("payment_confirmed");
    await pay();
  }
  closeView();
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
