create extension if not exists pgcrypto;

create table if not exists public.users (
  id text primary key,
  name text not null default '',
  email text not null default '',
  "profileImageUrl" text,
  "phoneNumber" text,
  role text not null default 'buyer',
  "storeName" text,
  "storeDescription" text,
  "coverImageUrl" text,
  "storeLogo" text,
  "followerCount" integer not null default 0,
  "followingStores" text[] not null default '{}'::text[],
  "fcmToken" text,
  "createdAt" timestamptz not null default timezone('utc', now()),
  "updatedAt" timestamptz not null default timezone('utc', now())
);

create table if not exists public.products (
  id text primary key,
  name text not null default '',
  description text not null default '',
  price numeric not null default 0,
  "discountPrice" numeric,
  "imageUrl" text not null default '',
  images text[] not null default '{}'::text[],
  rating double precision not null default 0,
  "reviewsCount" integer not null default 0,
  category text not null default '',
  "isFlashDeal" boolean not null default false,
  stock integer not null default 0,
  "sellerId" text,
  "availableColors" text[] not null default '{}'::text[],
  "availableSizes" text[] not null default '{}'::text[],
  "detailImageUrls" text[] not null default '{}'::text[]
);

create table if not exists public.reviews (
  id text primary key,
  "productId" text not null references public.products(id) on delete cascade,
  "userId" text not null references public.users(id) on delete cascade,
  "userName" text not null default '',
  "userImageUrl" text not null default '',
  rating double precision not null default 0,
  comment text not null default '',
  "createdAt" timestamptz not null default timezone('utc', now())
);

create table if not exists public.chats (
  id text primary key,
  "lastMessage" text not null default '',
  "lastTimestamp" timestamptz not null default timezone('utc', now()),
  participants text[] not null default '{}'::text[]
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  "chatId" text not null references public.chats(id) on delete cascade,
  "senderId" text not null references public.users(id) on delete cascade,
  "receiverId" text not null references public.users(id) on delete cascade,
  text text not null default '',
  "imageUrl" text,
  "timestamp" timestamptz not null default timezone('utc', now()),
  "isRead" boolean not null default false
);

create table if not exists public.orders (
  id text primary key,
  items jsonb not null default '[]'::jsonb,
  "totalAmount" numeric not null default 0,
  "orderDate" timestamptz not null default timezone('utc', now()),
  status text not null default 'Pending',
  "buyerId" text not null references public.users(id) on delete cascade,
  "sellerIds" text[] not null default '{}'::text[]
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  "userId" text not null references public.users(id) on delete cascade,
  title text not null default '',
  body text not null default '',
  "timestamp" timestamptz not null default timezone('utc', now()),
  type text not null default 'system',
  "isRead" boolean not null default false,
  data jsonb
);

create table if not exists public.addresses (
  id uuid primary key default gen_random_uuid(),
  "userId" text not null references public.users(id) on delete cascade,
  title text not null default '',
  address text not null default '',
  wilaya text,
  "postalCode" text,
  phone text,
  "isDefault" boolean not null default false,
  "updatedAt" timestamptz not null default timezone('utc', now())
);

create table if not exists public."paymentMethods" (
  id uuid primary key default gen_random_uuid(),
  "userId" text not null references public.users(id) on delete cascade,
  "holderName" text not null default '',
  "cardNumber" text not null default '',
  expiry text not null default '',
  brand text not null default 'Visa',
  "isPrimary" boolean not null default false,
  "createdAt" timestamptz not null default timezone('utc', now())
);

create table if not exists public."storeFollowers" (
  id uuid primary key default gen_random_uuid(),
  "userId" text not null references public.users(id) on delete cascade,
  "vendorId" text not null references public.users(id) on delete cascade,
  "createdAt" timestamptz not null default timezone('utc', now()),
  unique ("userId", "vendorId")
);

alter table public.users enable row level security;
alter table public.products enable row level security;
alter table public.reviews enable row level security;
alter table public.chats enable row level security;
alter table public.messages enable row level security;
alter table public.orders enable row level security;
alter table public.notifications enable row level security;
alter table public.addresses enable row level security;
alter table public."paymentMethods" enable row level security;
alter table public."storeFollowers" enable row level security;

drop policy if exists "users read authenticated" on public.users;
create policy "users read authenticated"
on public.users for select
to authenticated
using (true);

drop policy if exists "users insert self" on public.users;
create policy "users insert self"
on public.users for insert
to authenticated
with check (auth.uid()::text = id);

drop policy if exists "users update self" on public.users;
create policy "users update self"
on public.users for update
to authenticated
using (auth.uid()::text = id)
with check (auth.uid()::text = id);

drop policy if exists "products read public" on public.products;
create policy "products read public"
on public.products for select
to anon, authenticated
using (true);

drop policy if exists "products insert seller" on public.products;
create policy "products insert seller"
on public.products for insert
to authenticated
with check (auth.uid()::text = "sellerId");

drop policy if exists "products update seller" on public.products;
create policy "products update seller"
on public.products for update
to authenticated
using (auth.uid()::text = "sellerId")
with check (auth.uid()::text = "sellerId");

drop policy if exists "products delete seller" on public.products;
create policy "products delete seller"
on public.products for delete
to authenticated
using (auth.uid()::text = "sellerId");

drop policy if exists "reviews read public" on public.reviews;
create policy "reviews read public"
on public.reviews for select
to anon, authenticated
using (true);

drop policy if exists "reviews insert self" on public.reviews;
create policy "reviews insert self"
on public.reviews for insert
to authenticated
with check (auth.uid()::text = "userId");

drop policy if exists "chats read participants" on public.chats;
create policy "chats read participants"
on public.chats for select
to authenticated
using (auth.uid()::text = any(participants));

drop policy if exists "chats write participants" on public.chats;
create policy "chats write participants"
on public.chats for insert
to authenticated
with check (auth.uid()::text = any(participants));

drop policy if exists "chats update participants" on public.chats;
create policy "chats update participants"
on public.chats for update
to authenticated
using (auth.uid()::text = any(participants))
with check (auth.uid()::text = any(participants));

drop policy if exists "messages read participants" on public.messages;
create policy "messages read participants"
on public.messages for select
to authenticated
using (
  auth.uid()::text = "senderId"
  or auth.uid()::text = "receiverId"
);

drop policy if exists "messages send self" on public.messages;
create policy "messages send self"
on public.messages for insert
to authenticated
with check (auth.uid()::text = "senderId");

drop policy if exists "orders read participants" on public.orders;
create policy "orders read participants"
on public.orders for select
to authenticated
using (
  auth.uid()::text = "buyerId"
  or auth.uid()::text = any("sellerIds")
);

drop policy if exists "orders insert buyer" on public.orders;
create policy "orders insert buyer"
on public.orders for insert
to authenticated
with check (auth.uid()::text = "buyerId");

drop policy if exists "notifications read self" on public.notifications;
create policy "notifications read self"
on public.notifications for select
to authenticated
using (auth.uid()::text = "userId");

drop policy if exists "notifications update self" on public.notifications;
create policy "notifications update self"
on public.notifications for update
to authenticated
using (auth.uid()::text = "userId")
with check (auth.uid()::text = "userId");

drop policy if exists "notifications insert self" on public.notifications;
create policy "notifications insert self"
on public.notifications for insert
to authenticated
with check (auth.uid()::text = "userId");

drop policy if exists "addresses manage self" on public.addresses;
create policy "addresses manage self"
on public.addresses for all
to authenticated
using (auth.uid()::text = "userId")
with check (auth.uid()::text = "userId");

drop policy if exists "payment methods manage self" on public."paymentMethods";
create policy "payment methods manage self"
on public."paymentMethods" for all
to authenticated
using (auth.uid()::text = "userId")
with check (auth.uid()::text = "userId");

drop policy if exists "store followers read authenticated" on public."storeFollowers";
create policy "store followers read authenticated"
on public."storeFollowers" for select
to authenticated
using (true);

drop policy if exists "store followers insert self" on public."storeFollowers";
create policy "store followers insert self"
on public."storeFollowers" for insert
to authenticated
with check (auth.uid()::text = "userId");

drop policy if exists "store followers delete self" on public."storeFollowers";
create policy "store followers delete self"
on public."storeFollowers" for delete
to authenticated
using (auth.uid()::text = "userId");

create or replace function public.increment_product_stock(
  p_product_id text,
  p_quantity_change integer
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.products
  set stock = stock + p_quantity_change
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
begin
  if auth.uid()::text is distinct from p_review->>'userId' then
    raise exception 'Not authorized to add this review';
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
  v_seller_id text;
  v_order_id text := p_order->>'id';
  v_buyer_id text := p_order->>'buyerId';
  v_short_id text := upper(left(v_order_id, 8));
  v_product_id text;
begin
  if auth.uid()::text is distinct from v_buyer_id then
    raise exception 'Not authorized to place this order';
  end if;

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
    coalesce((p_order->>'totalAmount')::numeric, 0),
    coalesce((p_order->>'orderDate')::timestamptz, timezone('utc', now())),
    coalesce(p_order->>'status', 'Pending'),
    v_buyer_id,
    coalesce(
      array(select jsonb_array_elements_text(coalesce(p_order->'sellerIds', '[]'::jsonb))),
      '{}'::text[]
    )
  );

  for v_item in
    select value from jsonb_array_elements(coalesce(p_order->'items', '[]'::jsonb))
  loop
    v_product_id := coalesce(v_item->>'productId', v_item->'product'->>'id');
    if v_product_id is not null then
      update public.products
      set stock = stock - coalesce((v_item->>'quantity')::integer, 0)
      where id = v_product_id;
    end if;
  end loop;

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

  for v_seller_id in
    select distinct value
    from jsonb_array_elements_text(coalesce(p_order->'sellerIds', '[]'::jsonb))
  loop
    insert into public.notifications ("userId", title, body, "timestamp", type, "isRead", data)
    values (
      v_seller_id,
      'New Order Received!',
      'You have a new order #' || v_short_id || '.',
      timezone('utc', now()),
      'order',
      false,
      jsonb_build_object('orderId', v_order_id)
    );
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
  v_title text := '';
  v_body text := '';
  v_recipient text;
begin
  select "buyerId", "sellerIds"
  into v_buyer_id, v_seller_ids
  from public.orders
  where id = p_order_id
  for update;

  if v_buyer_id is null then
    raise exception 'Order not found';
  end if;

  if auth.uid()::text <> v_buyer_id and not (auth.uid()::text = any(v_seller_ids)) then
    raise exception 'Not authorized to update this order';
  end if;

  update public.orders
  set status = p_new_status
  where id = p_order_id;

  if p_new_status = 'Cancelled' then
    v_title := 'Order Cancelled';
    v_body := 'Order #' || upper(left(p_order_id, 8)) || ' was cancelled.';
  elsif p_new_status = 'Received' then
    v_title := 'Order Received';
    v_body := 'Order #' || upper(left(p_order_id, 8)) || ' was marked as received.';
  end if;

  if v_title = '' then
    return;
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
  v_title text := '';
  v_body text := '';
begin
  select "buyerId", "sellerIds"
  into v_buyer_id, v_seller_ids
  from public.orders
  where id = p_order_id
  for update;

  if v_buyer_id is null then
    raise exception 'Order not found';
  end if;

  if auth.uid()::text <> any(v_seller_ids) then
    raise exception 'Not authorized to update this order';
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
    v_title := 'Order Cancelled';
    v_body := 'Your order #' || upper(left(p_order_id, 8)) || ' has been cancelled.';
  end if;

  if v_title = '' then
    return;
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
begin
  if auth.uid()::text is distinct from p_user_id then
    raise exception 'Not authorized to follow for another user';
  end if;

  update public.users
  set
    "followingStores" = case
      when p_vendor_id = any("followingStores") then "followingStores"
      else array_append("followingStores", p_vendor_id)
    end,
    "updatedAt" = timezone('utc', now())
  where id = p_user_id;

  update public.users
  set
    "followerCount" = "followerCount" + 1,
    "updatedAt" = timezone('utc', now())
  where id = p_vendor_id
    and not exists (
      select 1
      from public."storeFollowers"
      where "userId" = p_user_id and "vendorId" = p_vendor_id
    );

  insert into public."storeFollowers" ("userId", "vendorId")
  values (p_user_id, p_vendor_id)
  on conflict ("userId", "vendorId") do nothing;
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
begin
  if auth.uid()::text is distinct from p_user_id then
    raise exception 'Not authorized to unfollow for another user';
  end if;

  update public.users
  set
    "followingStores" = array_remove("followingStores", p_vendor_id),
    "updatedAt" = timezone('utc', now())
  where id = p_user_id;

  if exists (
    select 1
    from public."storeFollowers"
    where "userId" = p_user_id and "vendorId" = p_vendor_id
  ) then
    update public.users
    set
      "followerCount" = greatest("followerCount" - 1, 0),
      "updatedAt" = timezone('utc', now())
    where id = p_vendor_id;
  end if;

  delete from public."storeFollowers"
  where "userId" = p_user_id and "vendorId" = p_vendor_id;
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

  update public."paymentMethods"
  set "isPrimary" = id = p_method_id
  where "userId" = p_user_id;
end;
$$;

insert into storage.buckets (id, name, public)
values
  ('user-profiles', 'user-profiles', true),
  ('chat-media', 'chat-media', true),
  ('store-media', 'store-media', true),
  ('product-media', 'product-media', true)
on conflict (id) do update
set public = excluded.public;

drop policy if exists "public read user-profiles" on storage.objects;
create policy "public read user-profiles"
on storage.objects for select
using (bucket_id = 'user-profiles');

drop policy if exists "auth write user-profiles" on storage.objects;
create policy "auth write user-profiles"
on storage.objects for all
to authenticated
using (bucket_id = 'user-profiles')
with check (bucket_id = 'user-profiles');

drop policy if exists "public read chat-media" on storage.objects;
create policy "public read chat-media"
on storage.objects for select
using (bucket_id = 'chat-media');

drop policy if exists "auth write chat-media" on storage.objects;
create policy "auth write chat-media"
on storage.objects for all
to authenticated
using (bucket_id = 'chat-media')
with check (bucket_id = 'chat-media');

drop policy if exists "public read store-media" on storage.objects;
create policy "public read store-media"
on storage.objects for select
using (bucket_id = 'store-media');

drop policy if exists "auth write store-media" on storage.objects;
create policy "auth write store-media"
on storage.objects for all
to authenticated
using (bucket_id = 'store-media')
with check (bucket_id = 'store-media');

drop policy if exists "public read product-media" on storage.objects;
create policy "public read product-media"
on storage.objects for select
using (bucket_id = 'product-media');

drop policy if exists "auth write product-media" on storage.objects;
create policy "auth write product-media"
on storage.objects for all
to authenticated
using (bucket_id = 'product-media')
with check (bucket_id = 'product-media');

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'users',
    'products',
    'chats',
    'messages',
    'orders',
    'notifications',
    'addresses',
    'paymentMethods',
    'storeFollowers'
  ] loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = v_table
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        v_table
      );
    end if;
  end loop;
end
$$;
