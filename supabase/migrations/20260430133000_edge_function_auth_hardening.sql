create or replace function public.create_marketplace_payment(
  p_order_id text,
  p_idempotency_key text default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_payment_id uuid;
  v_seller_id text;
  v_items_total numeric(12,2) := 0;
  v_commission_rate numeric(5,4) := 0.10;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if auth.uid()::text <> v_order."buyerId" and not public.is_admin() then
    raise exception 'Not authorized to create a payment for this order';
  end if;

  if v_order."paymentStatus" = 'paid' then
    raise exception 'Order is already paid';
  end if;

  select p.id
  into v_payment_id
  from public.payments p
  where p."orderId" = v_order.id
    and p.status in ('pending', 'checkout_created', 'processing')
  order by p."createdAt" desc
  limit 1
  for update;

  if v_payment_id is not null then
    update public.orders
    set
      "paymentMethod" = 'chargily',
      "paymentStatus" = 'checkout_created'
    where id = p_order_id
      and "paymentStatus" <> 'paid';
    return v_payment_id;
  end if;

  select seller_id
  into v_seller_id
  from unnest(v_order."sellerIds") seller_id
  limit 1;

  select coalesce(sum(
    coalesce((item.value->>'total')::numeric,
      coalesce((item.value->>'price')::numeric,
        coalesce((item.value->'product'->>'discountPrice')::numeric,
          (item.value->'product'->>'price')::numeric
        )
      ) * greatest(coalesce((item.value->>'quantity')::integer, 1), 1)
    )
  ), 0)::numeric(12,2)
  into v_items_total
  from jsonb_array_elements(coalesce(v_order.items, '[]'::jsonb)) item(value);

  update public.orders
  set
    "paymentMethod" = 'chargily',
    "paymentStatus" = 'pending',
    "commissionAmount" = round(v_items_total * v_commission_rate, 2),
    "sellerAmount" = round(v_items_total - round(v_items_total * v_commission_rate, 2), 2)
  where id = p_order_id;

  insert into public.payments (
    "orderId",
    "buyerId",
    "sellerId",
    amount,
    status,
    "idempotencyKey",
    metadata
  ) values (
    v_order.id,
    v_order."buyerId",
    v_seller_id,
    v_order."totalAmount",
    'pending',
    nullif(trim(coalesce(p_idempotency_key, '')), ''),
    jsonb_build_object('orderNumber', v_order."orderNumber")
  )
  returning id into v_payment_id;

  return v_payment_id;
end;
$$;

create or replace function public.release_seller_funds(
  p_order_id text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_payment_id uuid;
  v_seller_id text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_admin() then
    raise exception 'Only admin can release seller funds';
  end if;

  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order."paymentStatus" <> 'paid' then
    raise exception 'Order is not paid';
  end if;

  if v_order.status not in ('Delivered', 'Completed', 'Received') then
    raise exception 'Order is not eligible for payout release yet';
  end if;

  if v_order."disputeStatus" not in ('none', 'resolved', 'rejected') then
    raise exception 'Order has an open dispute';
  end if;

  if coalesce(v_order."sellerAmount", 0) <= 0 then
    return;
  end if;

  select seller_id
  into v_seller_id
  from unnest(v_order."sellerIds") seller_id
  limit 1;

  perform public.ensure_seller_wallet(v_seller_id);

  select id
  into v_payment_id
  from public.payments
  where "orderId" = p_order_id
    and status = 'paid'
  order by "paidAt" desc nulls last, "createdAt" desc
  limit 1;

  update public.seller_wallets
  set
    "pendingBalance" = greatest("pendingBalance" - v_order."sellerAmount", 0),
    "availableBalance" = "availableBalance" + v_order."sellerAmount",
    "lastPayoutReleasedAt" = timezone('utc', now())
  where "sellerId" = v_seller_id;

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
    v_seller_id,
    v_order.id,
    v_payment_id,
    'payout_release',
    'credit',
    'available',
    v_order."sellerAmount",
    'Delivered order released to available seller balance'
  );

  update public.orders
  set
    status = case when status in ('Delivered', 'Received') then 'Completed' else status end,
    "completedAt" = coalesce("completedAt", timezone('utc', now()))
  where id = p_order_id;
end;
$$;

create or replace function public.request_seller_withdrawal(
  p_seller_id text,
  p_amount numeric,
  p_method text,
  p_account_number text,
  p_account_name text default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_user_id text := auth.uid()::text;
  v_seller_id text := auth.uid()::text;
  v_wallet public.seller_wallets%rowtype;
  v_withdrawal_id uuid;
begin
  if v_auth_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_seller_id is distinct from v_auth_user_id then
    raise exception 'Not authorized to request another seller''s withdrawal';
  end if;

  if not public.can_sell_products(v_seller_id) then
    raise exception 'Seller account is not approved for withdrawals';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Invalid withdrawal amount';
  end if;

  perform public.ensure_seller_wallet(v_seller_id);

  select *
  into v_wallet
  from public.seller_wallets
  where "sellerId" = v_seller_id
  for update;

  if coalesce(v_wallet."availableBalance", 0) < p_amount then
    raise exception 'Insufficient available balance';
  end if;

  insert into public.withdrawals (
    "sellerId",
    amount,
    method,
    "accountNumber",
    "accountName"
  ) values (
    v_seller_id,
    round(p_amount, 2),
    p_method,
    trim(p_account_number),
    nullif(trim(coalesce(p_account_name, '')), '')
  )
  returning id into v_withdrawal_id;

  update public.seller_wallets
  set
    "availableBalance" = "availableBalance" - p_amount,
    "heldBalance" = "heldBalance" + p_amount
  where "sellerId" = v_seller_id;

  insert into public.wallet_transactions (
    "sellerId",
    "withdrawalId",
    type,
    direction,
    bucket,
    amount,
    description
  ) values (
    v_seller_id,
    v_withdrawal_id,
    'withdrawal_hold',
    'debit',
    'held',
    round(p_amount, 2),
    'Seller withdrawal request moved from available to held balance'
  );

  return v_withdrawal_id;
end;
$$;

revoke all on function public.update_own_profile(jsonb) from public;
revoke all on function public.update_own_profile(jsonb) from anon;
revoke all on function public.update_own_profile(jsonb) from authenticated;
grant execute on function public.update_own_profile(jsonb) to authenticated;

revoke all on function public.admin_set_seller_approval(text, boolean, boolean, text, numeric) from public;
revoke all on function public.admin_set_seller_approval(text, boolean, boolean, text, numeric) from anon;
revoke all on function public.admin_set_seller_approval(text, boolean, boolean, text, numeric) from authenticated;
grant execute on function public.admin_set_seller_approval(text, boolean, boolean, text, numeric) to authenticated;

revoke all on function public.admin_set_user_ban(text, boolean, text, timestamptz, boolean) from public;
revoke all on function public.admin_set_user_ban(text, boolean, text, timestamptz, boolean) from anon;
revoke all on function public.admin_set_user_ban(text, boolean, text, timestamptz, boolean) from authenticated;
grant execute on function public.admin_set_user_ban(text, boolean, text, timestamptz, boolean) to authenticated;

revoke all on function public.increment_product_stock(text, integer) from public;
revoke all on function public.increment_product_stock(text, integer) from anon;
revoke all on function public.increment_product_stock(text, integer) from authenticated;
grant execute on function public.increment_product_stock(text, integer) to authenticated;

revoke all on function public.add_review(jsonb) from public;
revoke all on function public.add_review(jsonb) from anon;
revoke all on function public.add_review(jsonb) from authenticated;
grant execute on function public.add_review(jsonb) to authenticated;

revoke all on function public.mark_conversation_read(text, text) from public;
revoke all on function public.mark_conversation_read(text, text) from anon;
revoke all on function public.mark_conversation_read(text, text) from authenticated;
grant execute on function public.mark_conversation_read(text, text) to authenticated;

revoke all on function public.place_order(jsonb) from public;
revoke all on function public.place_order(jsonb) from anon;
revoke all on function public.place_order(jsonb) from authenticated;
grant execute on function public.place_order(jsonb) to authenticated;

revoke all on function public.set_order_status(text, text) from public;
revoke all on function public.set_order_status(text, text) from anon;
revoke all on function public.set_order_status(text, text) from authenticated;
grant execute on function public.set_order_status(text, text) to authenticated;

revoke all on function public.vendor_update_order_status(text, text, text) from public;
revoke all on function public.vendor_update_order_status(text, text, text) from anon;
revoke all on function public.vendor_update_order_status(text, text, text) from authenticated;
grant execute on function public.vendor_update_order_status(text, text, text) to authenticated;

revoke all on function public.follow_store(text, text) from public;
revoke all on function public.follow_store(text, text) from anon;
revoke all on function public.follow_store(text, text) from authenticated;
grant execute on function public.follow_store(text, text) to authenticated;

revoke all on function public.unfollow_store(text, text) from public;
revoke all on function public.unfollow_store(text, text) from anon;
revoke all on function public.unfollow_store(text, text) from authenticated;
grant execute on function public.unfollow_store(text, text) to authenticated;

revoke all on function public.set_default_address(text, uuid) from public;
revoke all on function public.set_default_address(text, uuid) from anon;
revoke all on function public.set_default_address(text, uuid) from authenticated;
grant execute on function public.set_default_address(text, uuid) to authenticated;

revoke all on function public.set_primary_payment_method(text, uuid) from public;
revoke all on function public.set_primary_payment_method(text, uuid) from anon;
revoke all on function public.set_primary_payment_method(text, uuid) from authenticated;
grant execute on function public.set_primary_payment_method(text, uuid) to authenticated;

revoke all on function public.get_seller_dashboard(text, timestamptz) from public;
revoke all on function public.get_seller_dashboard(text, timestamptz) from anon;
revoke all on function public.get_seller_dashboard(text, timestamptz) from authenticated;
grant execute on function public.get_seller_dashboard(text, timestamptz) to authenticated;

revoke all on function public.submit_product_report(text, text, text) from public;
revoke all on function public.submit_product_report(text, text, text) from anon;
revoke all on function public.submit_product_report(text, text, text) from authenticated;
grant execute on function public.submit_product_report(text, text, text) to authenticated;

revoke all on function public.submit_refund_request(text, text, text) from public;
revoke all on function public.submit_refund_request(text, text, text) from anon;
revoke all on function public.submit_refund_request(text, text, text) from authenticated;
grant execute on function public.submit_refund_request(text, text, text) to authenticated;

revoke all on function public.admin_update_support_ticket(uuid, text, text) from public;
revoke all on function public.admin_update_support_ticket(uuid, text, text) from anon;
revoke all on function public.admin_update_support_ticket(uuid, text, text) from authenticated;
grant execute on function public.admin_update_support_ticket(uuid, text, text) to authenticated;

revoke all on function public.admin_update_product_report(uuid, text, text) from public;
revoke all on function public.admin_update_product_report(uuid, text, text) from anon;
revoke all on function public.admin_update_product_report(uuid, text, text) from authenticated;
grant execute on function public.admin_update_product_report(uuid, text, text) to authenticated;

revoke all on function public.admin_update_refund_request(uuid, text, text) from public;
revoke all on function public.admin_update_refund_request(uuid, text, text) from anon;
revoke all on function public.admin_update_refund_request(uuid, text, text) from authenticated;
grant execute on function public.admin_update_refund_request(uuid, text, text) to authenticated;

revoke all on function public.create_marketplace_payment(text, text) from public;
revoke all on function public.create_marketplace_payment(text, text) from anon;
revoke all on function public.create_marketplace_payment(text, text) from authenticated;
grant execute on function public.create_marketplace_payment(text, text) to authenticated;

revoke all on function public.apply_successful_payment(uuid, text, text, text, jsonb) from public;
revoke all on function public.apply_successful_payment(uuid, text, text, text, jsonb) from anon;
revoke all on function public.apply_successful_payment(uuid, text, text, text, jsonb) from authenticated;
grant execute on function public.apply_successful_payment(uuid, text, text, text, jsonb) to service_role;

revoke all on function public.release_seller_funds(text) from public;
revoke all on function public.release_seller_funds(text) from anon;
revoke all on function public.release_seller_funds(text) from authenticated;
grant execute on function public.release_seller_funds(text) to authenticated;

revoke all on function public.request_seller_withdrawal(text, numeric, text, text, text) from public;
revoke all on function public.request_seller_withdrawal(text, numeric, text, text, text) from anon;
revoke all on function public.request_seller_withdrawal(text, numeric, text, text, text) from authenticated;
grant execute on function public.request_seller_withdrawal(text, numeric, text, text, text) to authenticated;
