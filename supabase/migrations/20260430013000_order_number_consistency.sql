alter table public.orders
add column if not exists "orderNumber" text;

create or replace function public.build_order_number(
  p_order_date timestamptz,
  p_order_id text
) returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v_digits text := regexp_replace(coalesce(p_order_id, ''), '\D', '', 'g');
  v_suffix text;
begin
  if length(v_digits) >= 6 then
    v_suffix := right(v_digits, 6);
  elsif nullif(trim(coalesce(p_order_id, '')), '') is not null then
    v_suffix := upper(right(trim(p_order_id), 6));
  else
    v_suffix := '000000';
  end if;

  return 'ORD-' || to_char(coalesce(p_order_date, timezone('utc', now())), 'YYYYMMDD') || '-' || v_suffix;
end;
$$;

update public.orders
set "orderNumber" = public.build_order_number("orderDate", id)
where nullif(trim(coalesce("orderNumber", '')), '') is null;

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
  v_order_date timestamptz := coalesce((p_order->>'orderDate')::timestamptz, timezone('utc', now()));
  v_order_number text := coalesce(
    nullif(trim(p_order->>'orderNumber'), ''),
    public.build_order_number(v_order_date, v_order_id)
  );
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
    "orderNumber",
    "shippingFee",
    "deliveryType",
    "paymentMethod",
    "shippingAddress"
  ) values (
    v_order_id,
    v_items,
    v_order_total,
    v_order_date,
    'Processing',
    v_buyer_id,
    v_seller_ids,
    v_order_number,
    v_shipping_fee,
    v_delivery_type,
    'cod',
    v_shipping_address
  );

  insert into public.notifications ("userId", title, body, "timestamp", type, "isRead", data)
  values (
    v_buyer_id,
    'Order Placed!',
    'Your order #' || v_order_number || ' has been placed successfully.',
    timezone('utc', now()),
    'order',
    false,
    jsonb_build_object('orderId', v_order_id, 'orderNumber', v_order_number)
  );

  insert into public.notifications ("userId", title, body, "timestamp", type, "isRead", data)
  select
    seller_id,
    'New Order Received!',
    'You have a new order #' || v_order_number || '.',
    timezone('utc', now()),
    'order',
    false,
    jsonb_build_object('orderId', v_order_id, 'orderNumber', v_order_number)
  from unnest(v_seller_ids) as seller_id;
end;
$$;

create or replace function public.set_order_status(
  p_order_id text,
  p_new_status text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_buyer_id text;
  v_seller_ids text[];
  v_items jsonb;
  v_current_status text;
  v_order_number text;
  v_title text := '';
  v_body text := '';
  v_recipient text;
begin
  select "buyerId", "sellerIds", items, status, coalesce(nullif(trim("orderNumber"), ''), public.build_order_number("orderDate", id))
  into v_buyer_id, v_seller_ids, v_items, v_current_status, v_order_number
  from public.orders
  where id = p_order_id
  for update;

  if v_buyer_id is null then
    raise exception 'Order not found';
  end if;

  if auth.uid()::text <> v_buyer_id then
    raise exception 'Only the buyer can perform this action';
  end if;

  if p_new_status = v_current_status then
    return;
  end if;

  if p_new_status not in ('Cancelled', 'Received') then
    raise exception 'Invalid buyer order status transition';
  end if;

  if p_new_status = 'Cancelled'
    and v_current_status not in ('Pending', 'Processing') then
    raise exception 'Order can no longer be cancelled';
  end if;

  if p_new_status = 'Received'
    and v_current_status not in ('Shipped', 'Delivered') then
    raise exception 'Only shipped or delivered orders can be confirmed';
  end if;

  update public.orders
  set status = p_new_status
  where id = p_order_id;

  if p_new_status = 'Cancelled' then
    perform public.restore_order_item_stock(v_items);
    v_title := 'Order Cancelled';
    v_body := 'Order #' || v_order_number || ' was cancelled.';
  elsif p_new_status = 'Received' then
    v_title := 'Order Received';
    v_body := 'Order #' || v_order_number || ' was marked as received.';
  end if;

  for v_recipient in
    select distinct value
    from unnest(array_append(coalesce(v_seller_ids, '{}'::text[]), v_buyer_id)) as value
  loop
    insert into public.notifications ("userId", title, body, "timestamp", type, "isRead", data)
    values (
      v_recipient,
      v_title,
      v_body,
      timezone('utc', now()),
      'order',
      false,
      jsonb_build_object('orderId', p_order_id, 'orderNumber', v_order_number)
    );
  end loop;
end;
$$;

create or replace function public.vendor_update_order_status(
  p_order_id text,
  p_buyer_id text,
  p_new_status text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_buyer_id text;
  v_seller_ids text[];
  v_items jsonb;
  v_current_status text;
  v_order_number text;
  v_title text := '';
  v_body text := '';
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.can_sell_products(auth.uid()::text) then
    raise exception 'Seller access is not approved';
  end if;

  select "buyerId", "sellerIds", items, status, coalesce(nullif(trim("orderNumber"), ''), public.build_order_number("orderDate", id))
  into v_buyer_id, v_seller_ids, v_items, v_current_status, v_order_number
  from public.orders
  where id = p_order_id
  for update;

  if v_buyer_id is null then
    raise exception 'Order not found';
  end if;

  if auth.uid()::text <> any(v_seller_ids) then
    raise exception 'Not authorized to update this order';
  end if;

  if p_new_status = v_current_status then
    return;
  end if;

  if p_new_status not in ('Processing', 'Shipped', 'Delivered', 'Cancelled') then
    raise exception 'Invalid seller order status transition';
  end if;

  if p_new_status = 'Processing'
    and v_current_status not in ('Pending', 'Processing') then
    raise exception 'Order cannot move back to processing';
  end if;

  if p_new_status = 'Shipped'
    and v_current_status not in ('Pending', 'Processing') then
    raise exception 'Only pending or processing orders can be shipped';
  end if;

  if p_new_status = 'Delivered'
    and v_current_status <> 'Shipped' then
    raise exception 'Only shipped orders can be marked delivered';
  end if;

  if p_new_status = 'Cancelled'
    and v_current_status not in ('Pending', 'Processing') then
    raise exception 'Order can no longer be cancelled';
  end if;

  update public.orders
  set status = p_new_status
  where id = p_order_id;

  if p_new_status = 'Processing' then
    v_title := 'Order Processing';
    v_body := 'Your order #' || v_order_number || ' is being prepared.';
  elsif p_new_status = 'Shipped' then
    v_title := 'Order Shipped';
    v_body := 'Your order #' || v_order_number || ' has been handed over to the courier.';
  elsif p_new_status = 'Delivered' then
    v_title := 'Order Delivered';
    v_body := 'Your order #' || v_order_number || ' has been successfully delivered.';
  elsif p_new_status = 'Cancelled' then
    perform public.restore_order_item_stock(v_items);
    v_title := 'Order Cancelled';
    v_body := 'Your order #' || v_order_number || ' has been cancelled.';
  end if;

  insert into public.notifications ("userId", title, body, "timestamp", type, "isRead", data)
  values (
    coalesce(v_buyer_id, p_buyer_id),
    v_title,
    v_body,
    timezone('utc', now()),
    'order',
    false,
    jsonb_build_object('orderId', p_order_id, 'orderNumber', v_order_number)
  );
end;
$$;
