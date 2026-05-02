create table if not exists public.user_public_profiles (
  id text primary key references public.users(id) on delete cascade,
  name text not null default '',
  "profileImageUrl" text,
  role text not null default 'buyer',
  "storeName" text,
  "storeDescription" text,
  "coverImageUrl" text,
  "storeLogo" text,
  "followerCount" integer not null default 0,
  "createdAt" timestamptz not null default timezone('utc', now()),
  "updatedAt" timestamptz not null default timezone('utc', now())
);

insert into public.user_public_profiles (
  id,
  name,
  "profileImageUrl",
  role,
  "storeName",
  "storeDescription",
  "coverImageUrl",
  "storeLogo",
  "followerCount",
  "createdAt",
  "updatedAt"
)
select
  id,
  name,
  "profileImageUrl",
  role,
  "storeName",
  "storeDescription",
  "coverImageUrl",
  "storeLogo",
  "followerCount",
  "createdAt",
  "updatedAt"
from public.users
on conflict (id) do update
set
  name = excluded.name,
  "profileImageUrl" = excluded."profileImageUrl",
  role = excluded.role,
  "storeName" = excluded."storeName",
  "storeDescription" = excluded."storeDescription",
  "coverImageUrl" = excluded."coverImageUrl",
  "storeLogo" = excluded."storeLogo",
  "followerCount" = excluded."followerCount",
  "createdAt" = excluded."createdAt",
  "updatedAt" = excluded."updatedAt";

create or replace function public.sync_user_public_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.user_public_profiles where id = old.id;
    return old;
  end if;

  insert into public.user_public_profiles (
    id,
    name,
    "profileImageUrl",
    role,
    "storeName",
    "storeDescription",
    "coverImageUrl",
    "storeLogo",
    "followerCount",
    "createdAt",
    "updatedAt"
  ) values (
    new.id,
    new.name,
    new."profileImageUrl",
    new.role,
    new."storeName",
    new."storeDescription",
    new."coverImageUrl",
    new."storeLogo",
    new."followerCount",
    new."createdAt",
    new."updatedAt"
  )
  on conflict (id) do update
  set
    name = excluded.name,
    "profileImageUrl" = excluded."profileImageUrl",
    role = excluded.role,
    "storeName" = excluded."storeName",
    "storeDescription" = excluded."storeDescription",
    "coverImageUrl" = excluded."coverImageUrl",
    "storeLogo" = excluded."storeLogo",
    "followerCount" = excluded."followerCount",
    "createdAt" = excluded."createdAt",
    "updatedAt" = excluded."updatedAt";

  return new;
end;
$$;

drop trigger if exists sync_user_public_profile_trg on public.users;
create trigger sync_user_public_profile_trg
after insert or update or delete on public.users
for each row execute function public.sync_user_public_profile();

alter table public.user_public_profiles enable row level security;

drop policy if exists "public profiles read" on public.user_public_profiles;
create policy "public profiles read"
on public.user_public_profiles for select
to anon, authenticated
using (true);

drop policy if exists "users read authenticated" on public.users;
drop policy if exists "users read self" on public.users;
create policy "users read self"
on public.users for select
to authenticated
using ((select auth.uid()::text) = id);

create index if not exists user_public_profiles_role_idx
on public.user_public_profiles (role);

create index if not exists user_public_profiles_store_name_idx
on public.user_public_profiles ("storeName");

update public.products
set stock = greatest(stock, 0),
    rating = least(greatest(rating, 0), 5),
    "reviewsCount" = greatest("reviewsCount", 0),
    price = greatest(price, 0),
    "discountPrice" = case
      when "discountPrice" is null then null
      when "discountPrice" < 0 then 0
      when "discountPrice" > price then price
      else "discountPrice"
    end;

delete from public.reviews r
using (
  select id
  from (
    select
      id,
      row_number() over (
        partition by "productId", "userId"
        order by "createdAt" desc, id desc
      ) as rn
    from public.reviews
  ) ranked
  where ranked.rn > 1
) duplicates
where r.id = duplicates.id;

with ranked as (
  select
    id,
    row_number() over (
      partition by "userId"
      order by "updatedAt" desc, id desc
    ) as rn
  from public.addresses
  where "isDefault" = true
)
update public.addresses a
set "isDefault" = false
from ranked
where a.id = ranked.id
  and ranked.rn > 1;

with ranked as (
  select
    id,
    row_number() over (
      partition by "userId"
      order by "createdAt" desc, id desc
    ) as rn
  from public."paymentMethods"
  where "isPrimary" = true
)
update public."paymentMethods" p
set "isPrimary" = false
from ranked
where p.id = ranked.id
  and ranked.rn > 1;

create unique index if not exists reviews_unique_user_product_idx
on public.reviews ("productId", "userId");

create unique index if not exists addresses_single_default_idx
on public.addresses ("userId")
where "isDefault" = true;

create unique index if not exists payment_methods_single_primary_idx
on public."paymentMethods" ("userId")
where "isPrimary" = true;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'users_role_check'
      and conrelid = 'public.users'::regclass
  ) then
    alter table public.users
    add constraint users_role_check
    check (role in ('buyer', 'seller'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'products_price_nonnegative_check'
      and conrelid = 'public.products'::regclass
  ) then
    alter table public.products
    add constraint products_price_nonnegative_check
    check (price >= 0);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'products_discount_range_check'
      and conrelid = 'public.products'::regclass
  ) then
    alter table public.products
    add constraint products_discount_range_check
    check (
      "discountPrice" is null
      or ("discountPrice" >= 0 and "discountPrice" <= price)
    );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'products_stock_nonnegative_check'
      and conrelid = 'public.products'::regclass
  ) then
    alter table public.products
    add constraint products_stock_nonnegative_check
    check (stock >= 0);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'products_rating_range_check'
      and conrelid = 'public.products'::regclass
  ) then
    alter table public.products
    add constraint products_rating_range_check
    check (rating >= 0 and rating <= 5);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'products_reviews_count_nonnegative_check'
      and conrelid = 'public.products'::regclass
  ) then
    alter table public.products
    add constraint products_reviews_count_nonnegative_check
    check ("reviewsCount" >= 0);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'reviews_rating_range_check'
      and conrelid = 'public.reviews'::regclass
  ) then
    alter table public.reviews
    add constraint reviews_rating_range_check
    check (rating >= 1 and rating <= 5);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_total_nonnegative_check'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
    add constraint orders_total_nonnegative_check
    check ("totalAmount" >= 0);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_status_valid_check'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
    add constraint orders_status_valid_check
    check (status in ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled', 'Received'));
  end if;
end
$$;

create or replace function public.increment_product_stock(
  p_product_id text,
  p_quantity_change integer
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller_id text;
  v_stock integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select "sellerId", stock
  into v_seller_id, v_stock
  from public.products
  where id = p_product_id
  for update;

  if v_seller_id is null then
    raise exception 'Product not found';
  end if;

  if auth.uid()::text <> v_seller_id then
    raise exception 'Not authorized to update this product stock';
  end if;

  if v_stock + p_quantity_change < 0 then
    raise exception 'Insufficient stock';
  end if;

  update public.products
  set stock = v_stock + p_quantity_change
  where id = p_product_id;
end;
$$;

create or replace function public.add_review(p_review jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_id text := p_review->>'productId';
  v_rating double precision := coalesce((p_review->>'rating')::double precision, 0);
  v_current_rating double precision;
  v_current_count integer;
  v_can_review boolean := false;
begin
  if auth.uid()::text is distinct from p_review->>'userId' then
    raise exception 'Not authorized to add this review';
  end if;

  if v_rating < 1 or v_rating > 5 then
    raise exception 'Review rating must be between 1 and 5';
  end if;

  select exists (
    select 1
    from public.orders o
    cross join lateral jsonb_array_elements(o.items) as item(value)
    where o."buyerId" = p_review->>'userId'
      and o.status in ('Delivered', 'Received')
      and coalesce(item.value->>'productId', item.value->'product'->>'id') = v_product_id
  )
  into v_can_review;

  if not v_can_review then
    raise exception 'You can review only purchased products';
  end if;

  if exists (
    select 1
    from public.reviews
    where "productId" = v_product_id
      and "userId" = p_review->>'userId'
  ) then
    raise exception 'You have already reviewed this product';
  end if;

  insert into public.reviews (
    id,
    "productId",
    "userId",
    "userName",
    "userImageUrl",
    rating,
    comment,
    "createdAt"
  ) values (
    p_review->>'id',
    v_product_id,
    p_review->>'userId',
    coalesce(p_review->>'userName', ''),
    coalesce(p_review->>'userImageUrl', ''),
    v_rating,
    coalesce(p_review->>'comment', ''),
    coalesce((p_review->>'createdAt')::timestamptz, timezone('utc', now()))
  );

  select rating, "reviewsCount"
  into v_current_rating, v_current_count
  from public.products
  where id = v_product_id
  for update;

  update public.products
  set
    rating = ((coalesce(v_current_rating, 0) * coalesce(v_current_count, 0)) + v_rating)
      / greatest(coalesce(v_current_count, 0) + 1, 1),
    "reviewsCount" = coalesce(v_current_count, 0) + 1
  where id = v_product_id;
end;
$$;

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
  v_total numeric := 0;
  v_seller_ids text[] := '{}'::text[];
begin
  if auth.uid()::text is distinct from v_buyer_id then
    raise exception 'Not authorized to place this order';
  end if;

  if jsonb_array_length(coalesce(p_order->'items', '[]'::jsonb)) = 0 then
    raise exception 'Order must contain at least one item';
  end if;

  for v_item in
    select value from jsonb_array_elements(coalesce(p_order->'items', '[]'::jsonb))
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

    if v_product.stock < v_quantity then
      raise exception 'Insufficient stock for product %', v_product_id;
    end if;

    update public.products
    set stock = stock - v_quantity
    where id = v_product_id;

    v_total := v_total + (coalesce(v_product."discountPrice", v_product.price) * v_quantity);
    if not (v_product."sellerId" = any(v_seller_ids)) then
      v_seller_ids := array_append(v_seller_ids, v_product."sellerId");
    end if;
  end loop;

  insert into public.orders (
    id,
    items,
    "totalAmount",
    "orderDate",
    status,
    "buyerId",
    "sellerIds"
  ) values (
    v_order_id,
    coalesce(p_order->'items', '[]'::jsonb),
    v_total,
    coalesce((p_order->>'orderDate')::timestamptz, timezone('utc', now())),
    'Processing',
    v_buyer_id,
    v_seller_ids
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

create or replace function public.restore_order_item_stock(p_items jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_product_id text;
  v_quantity integer;
begin
  for v_item in
    select value from jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
  loop
    v_product_id := coalesce(v_item->>'productId', v_item->'product'->>'id');
    v_quantity := coalesce((v_item->>'quantity')::integer, 0);

    if v_product_id is not null and v_quantity > 0 then
      update public.products
      set stock = stock + v_quantity
      where id = v_product_id;
    end if;
  end loop;
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
  v_title text := '';
  v_body text := '';
  v_recipient text;
begin
  select "buyerId", "sellerIds", items, status
  into v_buyer_id, v_seller_ids, v_items, v_current_status
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
    v_body := 'Order #' || upper(left(p_order_id, 8)) || ' was cancelled.';
  elsif p_new_status = 'Received' then
    v_title := 'Order Received';
    v_body := 'Order #' || upper(left(p_order_id, 8)) || ' was marked as received.';
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
      jsonb_build_object('orderId', p_order_id)
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
  v_title text := '';
  v_body text := '';
begin
  select "buyerId", "sellerIds", items, status
  into v_buyer_id, v_seller_ids, v_items, v_current_status
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
    v_body := 'Your order #' || upper(left(p_order_id, 8)) || ' is being prepared.';
  elsif p_new_status = 'Shipped' then
    v_title := 'Order Shipped';
    v_body := 'Your order #' || upper(left(p_order_id, 8)) || ' has been handed over to the courier.';
  elsif p_new_status = 'Delivered' then
    v_title := 'Order Delivered';
    v_body := 'Your order #' || upper(left(p_order_id, 8)) || ' has been successfully delivered.';
  elsif p_new_status = 'Cancelled' then
    perform public.restore_order_item_stock(v_items);
    v_title := 'Order Cancelled';
    v_body := 'Your order #' || upper(left(p_order_id, 8)) || ' has been cancelled.';
  end if;

  insert into public.notifications ("userId", title, body, "timestamp", type, "isRead", data)
  values (
    coalesce(v_buyer_id, p_buyer_id),
    v_title,
    v_body,
    timezone('utc', now()),
    'order',
    false,
    jsonb_build_object('orderId', p_order_id)
  );
end;
$$;

create or replace function public.follow_store(
  p_user_id text,
  p_vendor_id text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_follow_inserted integer := 0;
begin
  if auth.uid()::text is distinct from p_user_id then
    raise exception 'Not authorized to follow for another user';
  end if;

  if p_user_id = p_vendor_id then
    raise exception 'You cannot follow your own store';
  end if;

  if not exists (
    select 1
    from public.users
    where id = p_vendor_id
      and role = 'seller'
  ) then
    raise exception 'Store not found';
  end if;

  insert into public."storeFollowers" ("userId", "vendorId")
  values (p_user_id, p_vendor_id)
  on conflict ("userId", "vendorId") do nothing;

  get diagnostics v_follow_inserted = row_count;

  update public.users
  set
    "followingStores" = case
      when p_vendor_id = any("followingStores") then "followingStores"
      else array_append("followingStores", p_vendor_id)
    end,
    "updatedAt" = timezone('utc', now())
  where id = p_user_id;

  if v_follow_inserted > 0 then
    update public.users
    set
      "followerCount" = "followerCount" + 1,
      "updatedAt" = timezone('utc', now())
    where id = p_vendor_id;
  end if;
end;
$$;

create or replace function public.unfollow_store(
  p_user_id text,
  p_vendor_id text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_follow_deleted integer := 0;
begin
  if auth.uid()::text is distinct from p_user_id then
    raise exception 'Not authorized to unfollow for another user';
  end if;

  if p_user_id = p_vendor_id then
    raise exception 'You cannot unfollow your own store';
  end if;

  delete from public."storeFollowers"
  where "userId" = p_user_id and "vendorId" = p_vendor_id;

  get diagnostics v_follow_deleted = row_count;

  update public.users
  set
    "followingStores" = array_remove("followingStores", p_vendor_id),
    "updatedAt" = timezone('utc', now())
  where id = p_user_id;

  if v_follow_deleted > 0 then
    update public.users
    set
      "followerCount" = greatest("followerCount" - 1, 0),
      "updatedAt" = timezone('utc', now())
    where id = p_vendor_id;
  end if;
end;
$$;

create or replace function public.set_default_address(
  p_user_id text,
  p_address_id uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid()::text is distinct from p_user_id then
    raise exception 'Not authorized to update another user''s addresses';
  end if;

  if not exists (
    select 1
    from public.addresses
    where id = p_address_id
      and "userId" = p_user_id
  ) then
    raise exception 'Address not found';
  end if;

  update public.addresses
  set
    "isDefault" = id = p_address_id,
    "updatedAt" = timezone('utc', now())
  where "userId" = p_user_id;
end;
$$;

create or replace function public.set_primary_payment_method(
  p_user_id text,
  p_method_id uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid()::text is distinct from p_user_id then
    raise exception 'Not authorized to update another user''s cards';
  end if;

  if not exists (
    select 1
    from public."paymentMethods"
    where id = p_method_id
      and "userId" = p_user_id
  ) then
    raise exception 'Payment method not found';
  end if;

  update public."paymentMethods"
  set "isPrimary" = id = p_method_id
  where "userId" = p_user_id;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'user_public_profiles'
  ) then
    alter publication supabase_realtime add table public.user_public_profiles;
  end if;
end
$$;
