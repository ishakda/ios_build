-- Migration: Add notification logic to apply_successful_payment
-- This ensures sellers and buyers get notified when a Chargily payment is confirmed.

create or replace function public.apply_successful_payment(
  p_payment_id uuid,
  p_provider_payment_id text default null,
  p_provider_checkout_id text default null,
  p_provider_reference text default null,
  p_payload jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.payments%rowtype;
  v_order public.orders%rowtype;
  v_short_id text;
begin
  select *
  into v_payment
  from public.payments
  where id = p_payment_id
  for update;

  if v_payment.id is null then
    raise exception 'Payment not found';
  end if;

  if v_payment.status = 'paid' then
    return;
  end if;

  select *
  into v_order
  from public.orders
  where id = v_payment."orderId"
  for update;

  v_short_id := upper(left(v_order.id, 8));

  perform public.ensure_seller_wallet(v_payment."sellerId");

  update public.payments
  set
    status = 'paid',
    "providerPaymentId" = coalesce(p_provider_payment_id, "providerPaymentId"),
    "providerCheckoutId" = coalesce(p_provider_checkout_id, "providerCheckoutId"),
    "providerReference" = coalesce(p_provider_reference, "providerReference"),
    metadata = coalesce(metadata, '{}'::jsonb) || coalesce(p_payload, '{}'::jsonb),
    "paidAt" = timezone('utc', now())
  where id = p_payment_id;

  update public.orders
  set
    status = case when status = 'Pending' or status = 'AwaitingPayment' then 'Paid' else status end,
    "paymentMethod" = 'chargily',
    "paymentStatus" = 'paid',
    "paymentReference" = coalesce(p_provider_reference, "paymentReference"),
    "chargilyCheckoutId" = coalesce(p_provider_checkout_id, "chargilyCheckoutId"),
    "confirmedAt" = coalesce("confirmedAt", timezone('utc', now()))
  where id = v_order.id;

  -- Add Notification for Buyer
  insert into public.notifications ("userId", title, body, type, data)
  values (
    v_order."buyerId",
    'Payment Confirmed!',
    'Your payment for order #' || v_short_id || ' was successful.',
    'wallet',
    jsonb_build_object('orderId', v_order.id, 'paymentId', p_payment_id)
  );

  if v_payment."sellerId" is not null and coalesce(v_order."sellerAmount", 0) > 0 then
    update public.seller_wallets
    set
      "pendingBalance" = "pendingBalance" + v_order."sellerAmount",
      "totalEarned" = "totalEarned" + v_order."sellerAmount"
    where "sellerId" = v_payment."sellerId";

    insert into public.wallet_transactions (
      "sellerId",
      "orderId",
      "paymentId",
      type,
      direction,
      bucket,
      amount,
      description
    ) values (
      v_payment."sellerId",
      v_order.id,
      v_payment.id,
      'sale_hold',
      'credit',
      'pending',
      v_order."sellerAmount",
      'Paid order credited to pending seller balance'
    );

    -- Add Notification for Seller
    insert into public.notifications ("userId", title, body, type, data)
    values (
      v_payment."sellerId",
      'New Payment Received!',
      'Payment for order #' || v_short_id || ' has been confirmed and added to your pending balance.',
      'wallet',
      jsonb_build_object('orderId', v_order.id, 'amount', v_order."sellerAmount")
    );
  end if;
end;
$$;
