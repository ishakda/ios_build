alter table public.orders
add column if not exists "shippingFee" numeric not null default 0,
add column if not exists "deliveryType" text not null default 'home',
add column if not exists "paymentMethod" text not null default 'cod',
add column if not exists "shippingAddress" jsonb not null default '{}'::jsonb;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_shipping_fee_nonnegative_check'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
    add constraint orders_shipping_fee_nonnegative_check
    check ("shippingFee" >= 0);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_delivery_type_check'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
    add constraint orders_delivery_type_check
    check ("deliveryType" in ('home', 'stopdesk'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_payment_method_check'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
    add constraint orders_payment_method_check
    check ("paymentMethod" = 'cod');
  end if;
end
$$;

create or replace function public.assert_masked_payment_method()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new."cardNumber" is null or trim(new."cardNumber") = '' then
    raise exception 'Card number is required';
  end if;

  if new."cardNumber" !~ '^\*{4} \*{4} \*{4} \d{4}$'
     and new."cardNumber" !~ '^token:[A-Za-z0-9_\-]+$' then
    raise exception 'Only masked card references may be stored';
  end if;

  return new;
end;
$$;

drop trigger if exists payment_methods_masked_guard_trg on public."paymentMethods";
create trigger payment_methods_masked_guard_trg
before insert or update on public."paymentMethods"
for each row execute function public.assert_masked_payment_method();

create or replace function public.place_order(p_order jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_order_id text := p_order->>'id';
  v_buyer_id text := p_order->>'buyerId';
  v_short_id text := upper(left(v_order_id, 8));
  v_product_id text;
  v_quantity integer;
  v_product record;
  v_items jsonb := coalesce(p_order->'items', '[]'::jsonb);
  v_shipping_address jsonb := coalesce(p_order->'shippingAddress', '{}'::jsonb);
  v_shipping_fee numeric := 0;
  v_items_total numeric := 0;
  v_order_total numeric := 0;
  v_seller_ids text[] := '{}'::text[];
  v_delivery_type text := lower(coalesce(p_order->>'deliveryType', 'home'));
  v_payment_method text := lower(coalesce(p_order->>'paymentMethod', 'cod'));
  v_wilaya text := trim(coalesce(v_shipping_address->>'wilaya', ''));
  v_wilaya_code integer := 16;
begin
  perform public.assert_buyer_can_place_order(v_buyer_id);

  if jsonb_array_length(v_items) = 0 then
    raise exception 'Order must contain at least one item';
  end if;

  if v_payment_method <> 'cod' then
    raise exception 'Only cash on delivery is currently supported';
  end if;

  if v_delivery_type not in ('home', 'stopdesk') then
    raise exception 'Invalid delivery type';
  end if;

  if nullif(trim(coalesce(v_shipping_address->>'address', '')), '') is null then
    raise exception 'Shipping address is required';
  end if;

  if nullif(trim(coalesce(v_shipping_address->>'commune', '')), '') is null then
    raise exception 'Shipping commune is required';
  end if;

  if v_wilaya ~ '^\d+' then
    v_wilaya_code := split_part(v_wilaya, '-', 1)::integer;
  end if;

  if v_wilaya_code in (1, 8, 11, 30, 32, 33, 37, 39, 47, 49, 50, 52, 53, 54, 55, 56, 57, 58) then
    v_shipping_fee := 1100;
  elsif v_wilaya_code in (9, 16, 31, 35, 42) then
    v_shipping_fee := 500;
  else
    v_shipping_fee := 700;
  end if;

  if v_delivery_type = 'stopdesk' then
    v_shipping_fee := greatest(350, least(1200, v_shipping_fee - 200));
  end if;

  for v_item in
    select value from jsonb_array_elements(v_items)
  loop
    v_product_id := coalesce(v_item->>'productId', v_item->'product'->>'id');
    v_quantity := coalesce((v_item->>'quantity')::integer, 0);

    if v_product_id is null or v_quantity <= 0 then
      raise exception 'Invalid order item payload';
    end if;

    select id, "sellerId", stock, price, "discountPrice"
    into v_product
    from public.products
    where id = v_product_id
    for update;

    if v_product.id is null or v_product."sellerId" is null then
      raise exception 'Product % is unavailable', v_product_id;
    end if;

    if not public.can_sell_products(v_product."sellerId") then
      raise exception 'Product % is not available for checkout right now', v_product_id;
    end if;

    if v_product.stock < v_quantity then
      raise exception 'Insufficient stock for product %', v_product_id;
    end if;

    update public.products
    set stock = stock - v_quantity
    where id = v_product_id;

    v_items_total := v_items_total + (coalesce(v_product."discountPrice", v_product.price) * v_quantity);
    if not (v_product."sellerId" = any(v_seller_ids)) then
      v_seller_ids := array_append(v_seller_ids, v_product."sellerId");
    end if;
  end loop;

  v_order_total := v_items_total + v_shipping_fee;

  insert into public.orders (
    id,
    items,
    "totalAmount",
    "orderDate",
    status,
    "buyerId",
    "sellerIds",
    "shippingFee",
    "deliveryType",
    "paymentMethod",
    "shippingAddress"
  ) values (
    v_order_id,
    v_items,
    v_order_total,
    coalesce((p_order->>'orderDate')::timestamptz, timezone('utc', now())),
    'Processing',
    v_buyer_id,
    v_seller_ids,
    v_shipping_fee,
    v_delivery_type,
    'cod',
    v_shipping_address
  );

  insert into public.notifications ("userId", title, body, "timestamp", type, "isRead", data)
  values (
    v_buyer_id,
    'Order Placed!',
    'Your order #' || v_short_id || ' has been placed successfully.',
    timezone('utc', now()),
    'order',
    false,
    jsonb_build_object('orderId', v_order_id)
  );

  insert into public.notifications ("userId", title, body, "timestamp", type, "isRead", data)
  select
    seller_id,
    'New Order Received!',
    'You have a new order #' || v_short_id || '.',
    timezone('utc', now()),
    'order',
    false,
    jsonb_build_object('orderId', v_order_id)
  from unnest(v_seller_ids) as seller_id;
end;
$$;
