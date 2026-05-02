alter table public.users
add column if not exists "isSellerApproved" boolean not null default false,
add column if not exists "sellerApprovedAt" timestamptz,
add column if not exists "sellerApprovedBy" text references public.users(id) on delete set null,
add column if not exists "isBanned" boolean not null default false,
add column if not exists "bannedUntil" timestamptz,
add column if not exists "banReason" text,
add column if not exists "isCodBlocked" boolean not null default false;

alter table public.user_public_profiles
add column if not exists "isSellerApproved" boolean not null default false;

update public.user_public_profiles p
set "isSellerApproved" = u."isSellerApproved"
from public.users u
where u.id = p.id;

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
    "isVerifiedSeller",
    "verificationLevel",
    "trustScore",
    "isSellerApproved",
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
    new."isVerifiedSeller",
    new."verificationLevel",
    new."trustScore",
    new."isSellerApproved",
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
    "isVerifiedSeller" = excluded."isVerifiedSeller",
    "verificationLevel" = excluded."verificationLevel",
    "trustScore" = excluded."trustScore",
    "isSellerApproved" = excluded."isSellerApproved",
    "createdAt" = excluded."createdAt",
    "updatedAt" = excluded."updatedAt";

  return new;
end;
$$;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'users_role_check'
      and conrelid = 'public.users'::regclass
  ) then
    alter table public.users
    drop constraint users_role_check;
  end if;

  alter table public.users
  add constraint users_role_check
  check (role in ('buyer', 'seller', 'admin'));
end
$$;

create or replace function public.is_account_banned(
  p_user_id text default auth.uid()::text
) returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = coalesce(p_user_id, '')
      and coalesce(u."isBanned", false)
      and (u."bannedUntil" is null or u."bannedUntil" > timezone('utc', now()))
  );
$$;

create or replace function public.is_admin(
  p_user_id text default auth.uid()::text
) returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = coalesce(p_user_id, '')
      and u.role = 'admin'
      and not public.is_account_banned(u.id)
  );
$$;

create or replace function public.auth_email_is_verified(
  p_user_id text default auth.uid()::text
) returns boolean
language sql
security definer
stable
set search_path = public, auth
as $$
  select exists (
    select 1
    from auth.users au
    where au.id::text = coalesce(p_user_id, '')
      and au.email_confirmed_at is not null
  );
$$;

create or replace function public.can_manage_store_profile(
  p_user_id text default auth.uid()::text
) returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = coalesce(p_user_id, '')
      and u.role = 'seller'
      and not public.is_account_banned(u.id)
      and public.auth_email_is_verified(u.id)
  );
$$;

create or replace function public.can_sell_products(
  p_user_id text default auth.uid()::text
) returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = coalesce(p_user_id, '')
      and u.role = 'seller'
      and coalesce(u."isSellerApproved", false)
      and not public.is_account_banned(u.id)
      and public.auth_email_is_verified(u.id)
      and nullif(trim(coalesce(u."phoneNumber", '')), '') is not null
  );
$$;

create table if not exists public.admin_moderation_actions (
  id uuid primary key default gen_random_uuid(),
  "adminUserId" text not null references public.users(id) on delete cascade,
  "targetUserId" text not null references public.users(id) on delete cascade,
  "actionType" text not null,
  reason text,
  metadata jsonb,
  "createdAt" timestamptz not null default timezone('utc', now())
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'admin_moderation_actions_type_check'
      and conrelid = 'public.admin_moderation_actions'::regclass
  ) then
    alter table public.admin_moderation_actions
    add constraint admin_moderation_actions_type_check
    check ("actionType" in ('seller_approval', 'seller_rejection', 'ban', 'unban', 'cod_block', 'cod_unblock'));
  end if;
end
$$;

create index if not exists admin_moderation_actions_target_created_idx
on public.admin_moderation_actions ("targetUserId", "createdAt" desc);

alter table public.admin_moderation_actions enable row level security;

drop policy if exists "admin moderation actions read admin" on public.admin_moderation_actions;
create policy "admin moderation actions read admin"
on public.admin_moderation_actions for select
to authenticated
using (public.is_admin());

drop policy if exists "users insert self" on public.users;
create policy "users insert self"
on public.users for insert
to authenticated
with check (
  auth.uid()::text = id
  and role in ('buyer', 'seller')
  and coalesce("isSellerApproved", false) = false
  and coalesce("isBanned", false) = false
  and coalesce("isVerifiedSeller", false) = false
  and coalesce("verificationLevel", 'none') = 'none'
  and coalesce("trustScore", 0) = 0
  and "sellerApprovedAt" is null
  and "sellerApprovedBy" is null
  and "bannedUntil" is null
  and coalesce("banReason", '') = ''
  and coalesce("isCodBlocked", false) = false
);

drop policy if exists "users update self" on public.users;
create policy "users update self"
on public.users for update
to authenticated
using (auth.uid()::text = id)
with check (
  auth.uid()::text = id
  and role = (select u.role from public.users u where u.id = auth.uid()::text)
  and "isSellerApproved" = (select u."isSellerApproved" from public.users u where u.id = auth.uid()::text)
  and "sellerApprovedAt" is not distinct from (select u."sellerApprovedAt" from public.users u where u.id = auth.uid()::text)
  and "sellerApprovedBy" is not distinct from (select u."sellerApprovedBy" from public.users u where u.id = auth.uid()::text)
  and "isBanned" = (select u."isBanned" from public.users u where u.id = auth.uid()::text)
  and "bannedUntil" is not distinct from (select u."bannedUntil" from public.users u where u.id = auth.uid()::text)
  and coalesce("banReason", '') = coalesce((select u."banReason" from public.users u where u.id = auth.uid()::text), '')
  and "isCodBlocked" = (select u."isCodBlocked" from public.users u where u.id = auth.uid()::text)
  and "isVerifiedSeller" = (select u."isVerifiedSeller" from public.users u where u.id = auth.uid()::text)
  and "verificationLevel" = (select u."verificationLevel" from public.users u where u.id = auth.uid()::text)
  and "trustScore" = (select u."trustScore" from public.users u where u.id = auth.uid()::text)
);

drop policy if exists "users admin read" on public.users;
create policy "users admin read"
on public.users for select
to authenticated
using (public.is_admin());

drop policy if exists "products read public" on public.products;
create policy "products read public"
on public.products for select
to anon, authenticated
using (
  public.is_admin()
  or auth.uid()::text = "sellerId"
  or public.can_sell_products("sellerId")
);

drop policy if exists "products insert seller" on public.products;
create policy "products insert seller"
on public.products for insert
to authenticated
with check (
  auth.uid()::text = "sellerId"
  and public.can_sell_products(auth.uid()::text)
);

drop policy if exists "products update seller" on public.products;
create policy "products update seller"
on public.products for update
to authenticated
using (
  public.is_admin()
  or (
    auth.uid()::text = "sellerId"
    and public.can_sell_products(auth.uid()::text)
  )
)
with check (
  public.is_admin()
  or (
    auth.uid()::text = "sellerId"
    and public.can_sell_products(auth.uid()::text)
  )
);

drop policy if exists "products delete seller" on public.products;
create policy "products delete seller"
on public.products for delete
to authenticated
using (
  public.is_admin()
  or (
    auth.uid()::text = "sellerId"
    and public.can_sell_products(auth.uid()::text)
  )
);

drop policy if exists "products admin manage" on public.products;
create policy "products admin manage"
on public.products for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "reviews insert self" on public.reviews;

drop policy if exists "orders insert buyer" on public.orders;

drop policy if exists "orders admin read" on public.orders;
create policy "orders admin read"
on public.orders for select
to authenticated
using (public.is_admin());

drop policy if exists "support tickets admin manage" on public.support_tickets;
create policy "support tickets admin manage"
on public.support_tickets for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.update_own_profile(p_profile jsonb)
returns public.users
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user public.users%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select *
  into v_user
  from public.users
  where id = auth.uid()::text
  for update;

  if v_user.id is null then
    raise exception 'User profile not found';
  end if;

  update public.users
  set
    name = coalesce(nullif(trim(p_profile->>'name'), ''), v_user.name),
    "profileImageUrl" = case
      when p_profile ? 'profileImageUrl' then nullif(trim(coalesce(p_profile->>'profileImageUrl', '')), '')
      else v_user."profileImageUrl"
    end,
    "phoneNumber" = case
      when p_profile ? 'phoneNumber' then nullif(trim(coalesce(p_profile->>'phoneNumber', '')), '')
      else v_user."phoneNumber"
    end,
    "storeName" = case
      when v_user.role = 'seller' and p_profile ? 'storeName' then nullif(trim(coalesce(p_profile->>'storeName', '')), '')
      else v_user."storeName"
    end,
    "storeDescription" = case
      when v_user.role = 'seller' and p_profile ? 'storeDescription' then nullif(trim(coalesce(p_profile->>'storeDescription', '')), '')
      else v_user."storeDescription"
    end,
    "storeLogo" = case
      when v_user.role = 'seller' and p_profile ? 'storeLogo' then nullif(trim(coalesce(p_profile->>'storeLogo', '')), '')
      else v_user."storeLogo"
    end,
    "coverImageUrl" = case
      when v_user.role = 'seller' and p_profile ? 'coverImageUrl' then nullif(trim(coalesce(p_profile->>'coverImageUrl', '')), '')
      else v_user."coverImageUrl"
    end,
    "updatedAt" = timezone('utc', now())
  where id = auth.uid()::text
  returning *
  into v_user;

  return v_user;
end;
$$;

create or replace function public.admin_set_seller_approval(
  p_target_user_id text,
  p_is_approved boolean,
  p_is_verified_seller boolean default null,
  p_verification_level text default null,
  p_trust_score numeric default null
) returns public.users
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id text := auth.uid()::text;
  v_user public.users%rowtype;
  v_previous_cod_blocked boolean;
  v_action_type text;
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'Not authorized to approve sellers';
  end if;

  select *
  into v_user
  from public.users
  where id = p_target_user_id
  for update;

  if v_user.id is null or v_user.role <> 'seller' then
    raise exception 'Seller account not found';
  end if;

  update public.users
  set
    "isSellerApproved" = p_is_approved,
    "sellerApprovedAt" = case when p_is_approved then timezone('utc', now()) else null end,
    "sellerApprovedBy" = case when p_is_approved then v_admin_id else null end,
    "isVerifiedSeller" = coalesce(
      p_is_verified_seller,
      case when p_is_approved then v_user."isVerifiedSeller" else false end
    ),
    "verificationLevel" = coalesce(
      p_verification_level,
      case when p_is_approved then v_user."verificationLevel" else 'none' end
    ),
    "trustScore" = coalesce(
      p_trust_score,
      case when p_is_approved then v_user."trustScore" else 0 end
    ),
    "updatedAt" = timezone('utc', now())
  where id = p_target_user_id
  returning *
  into v_user;

  insert into public.admin_moderation_actions (
    "adminUserId",
    "targetUserId",
    "actionType",
    metadata
  ) values (
    v_admin_id,
    p_target_user_id,
    case when p_is_approved then 'seller_approval' else 'seller_rejection' end,
    jsonb_build_object(
      'isApproved', p_is_approved,
      'isVerifiedSeller', v_user."isVerifiedSeller",
      'verificationLevel', v_user."verificationLevel",
      'trustScore', v_user."trustScore"
    )
  );

  return v_user;
end;
$$;

create or replace function public.admin_set_user_ban(
  p_target_user_id text,
  p_is_banned boolean,
  p_reason text default null,
  p_banned_until timestamptz default null,
  p_is_cod_blocked boolean default null
) returns public.users
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id text := auth.uid()::text;
  v_user public.users%rowtype;
  v_previous_cod_blocked boolean;
  v_action_type text;
begin
  if not public.is_admin(v_admin_id) then
    raise exception 'Not authorized to manage bans';
  end if;

  if p_target_user_id = v_admin_id then
    raise exception 'Admins cannot ban themselves';
  end if;

  select *
  into v_user
  from public.users
  where id = p_target_user_id
  for update;

  if v_user.id is null then
    raise exception 'User not found';
  end if;

  v_previous_cod_blocked := coalesce(v_user."isCodBlocked", false);

  update public.users
  set
    "isBanned" = p_is_banned,
    "bannedUntil" = case when p_is_banned then p_banned_until else null end,
    "banReason" = case
      when p_is_banned then nullif(trim(coalesce(p_reason, '')), '')
      else null
    end,
    "isCodBlocked" = coalesce(p_is_cod_blocked, v_user."isCodBlocked"),
    "updatedAt" = timezone('utc', now())
  where id = p_target_user_id
  returning *
  into v_user;

  if p_is_banned then
    v_action_type := 'ban';
  elsif p_is_cod_blocked is not null and p_is_cod_blocked <> v_previous_cod_blocked then
    v_action_type := case when p_is_cod_blocked then 'cod_block' else 'cod_unblock' end;
  else
    v_action_type := 'unban';
  end if;

  insert into public.admin_moderation_actions (
    "adminUserId",
    "targetUserId",
    "actionType",
    reason,
    metadata
  ) values (
    v_admin_id,
    p_target_user_id,
    v_action_type,
    nullif(trim(coalesce(p_reason, '')), ''),
    jsonb_build_object(
      'isBanned', p_is_banned,
      'bannedUntil', p_banned_until,
      'isCodBlocked', v_user."isCodBlocked"
    )
  );

  return v_user;
end;
$$;

create or replace function public.assert_buyer_can_place_order(p_user_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user public.users%rowtype;
  v_recent_orders integer;
begin
  if auth.uid()::text is distinct from p_user_id then
    raise exception 'Not authorized to place this order';
  end if;

  select *
  into v_user
  from public.users
  where id = p_user_id;

  if v_user.id is null then
    raise exception 'Buyer account not found';
  end if;

  if public.is_account_banned(p_user_id) then
    raise exception 'Your account is suspended. Contact support for help.';
  end if;

  if not public.auth_email_is_verified(p_user_id) then
    raise exception 'Please verify your email before placing orders.';
  end if;

  if nullif(trim(coalesce(v_user."phoneNumber", '')), '') is null then
    raise exception 'Add a phone number before placing orders.';
  end if;

  select count(*)
  into v_recent_orders
  from public.orders o
  where o."buyerId" = p_user_id
    and o."orderDate" >= timezone('utc', now()) - interval '1 minute';

  if v_recent_orders >= 3 then
    raise exception 'Too many orders in a short time. Please wait a minute and try again.';
  end if;
end;
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

  if not public.can_sell_products(auth.uid()::text) then
    raise exception 'Seller access is not approved';
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
  perform public.assert_buyer_can_place_order(v_buyer_id);

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

    if not public.can_sell_products(v_product."sellerId") then
      raise exception 'Product % is not available for checkout right now', v_product_id;
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
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.can_sell_products(auth.uid()::text) then
    raise exception 'Seller access is not approved';
  end if;

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

  if public.is_account_banned(p_user_id) then
    raise exception 'Your account is suspended. Contact support for help.';
  end if;

  if p_user_id = p_vendor_id then
    raise exception 'You cannot follow your own store';
  end if;

  if not public.can_sell_products(p_vendor_id) then
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

drop policy if exists "store-media insert seller folder" on storage.objects;
create policy "store-media insert seller folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'store-media'
  and public.can_manage_store_profile(auth.uid()::text)
  and (storage.foldername(name))[1] = 'stores'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

drop policy if exists "store-media update seller objects" on storage.objects;
create policy "store-media update seller objects"
on storage.objects for update
to authenticated
using (
  bucket_id = 'store-media'
  and public.can_manage_store_profile(auth.uid()::text)
  and (storage.foldername(name))[1] = 'stores'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
)
with check (
  bucket_id = 'store-media'
  and public.can_manage_store_profile(auth.uid()::text)
  and (storage.foldername(name))[1] = 'stores'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

drop policy if exists "store-media delete seller objects" on storage.objects;
create policy "store-media delete seller objects"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'store-media'
  and public.can_manage_store_profile(auth.uid()::text)
  and (storage.foldername(name))[1] = 'stores'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
);

drop policy if exists "product-media insert seller folder" on storage.objects;
create policy "product-media insert seller folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'product-media'
  and public.can_sell_products(auth.uid()::text)
  and (storage.foldername(name))[1] = 'products'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

drop policy if exists "product-media update seller objects" on storage.objects;
create policy "product-media update seller objects"
on storage.objects for update
to authenticated
using (
  bucket_id = 'product-media'
  and public.can_sell_products(auth.uid()::text)
  and (storage.foldername(name))[1] = 'products'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
)
with check (
  bucket_id = 'product-media'
  and public.can_sell_products(auth.uid()::text)
  and (storage.foldername(name))[1] = 'products'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

drop policy if exists "product-media delete seller objects" on storage.objects;
create policy "product-media delete seller objects"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'product-media'
  and public.can_sell_products(auth.uid()::text)
  and (storage.foldername(name))[1] = 'products'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
);
