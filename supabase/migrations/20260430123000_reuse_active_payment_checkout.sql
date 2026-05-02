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
  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if auth.uid()::text is not null and auth.uid()::text <> v_order."buyerId" and not public.is_admin() then
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
