alter table public.users
add column if not exists "isVerifiedSeller" boolean not null default false,
add column if not exists "verificationLevel" text not null default 'none',
add column if not exists "trustScore" numeric not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'users_verification_level_check'
      and conrelid = 'public.users'::regclass
  ) then
    alter table public.users
    add constraint users_verification_level_check
    check ("verificationLevel" in ('none', 'basic', 'verified', 'premium'));
  end if;
end
$$;

alter table public.user_public_profiles
add column if not exists "isVerifiedSeller" boolean not null default false,
add column if not exists "verificationLevel" text not null default 'none',
add column if not exists "trustScore" numeric not null default 0;

update public.user_public_profiles p
set
  "isVerifiedSeller" = u."isVerifiedSeller",
  "verificationLevel" = u."verificationLevel",
  "trustScore" = u."trustScore"
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
    "createdAt" = excluded."createdAt",
    "updatedAt" = excluded."updatedAt";

  return new;
end;
$$;

alter table public.reviews
add column if not exists "isVerifiedPurchase" boolean not null default false,
add column if not exists "isModerated" boolean not null default true;

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
  v_comment text := trim(coalesce(p_review->>'comment', ''));
begin
  if auth.uid()::text is distinct from p_review->>'userId' then
    raise exception 'Not authorized to add this review';
  end if;

  if v_rating < 1 or v_rating > 5 then
    raise exception 'Review rating must be between 1 and 5';
  end if;

  if length(v_comment) < 3 then
    raise exception 'Review comment must be at least 3 characters';
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
    "isVerifiedPurchase",
    "isModerated",
    "createdAt"
  ) values (
    p_review->>'id',
    v_product_id,
    p_review->>'userId',
    coalesce(p_review->>'userName', ''),
    coalesce(p_review->>'userImageUrl', ''),
    v_rating,
    v_comment,
    true,
    true,
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

create index if not exists messages_receiver_unread_idx
on public.messages ("receiverId", "isRead", "timestamp" desc);

drop policy if exists "messages update receiver read" on public.messages;
create policy "messages update receiver read"
on public.messages for update
to authenticated
using ((select auth.uid()::text) = "receiverId")
with check (
  (select auth.uid()::text) = "receiverId"
  and "senderId" <> "receiverId"
);

drop policy if exists "messages delete participants" on public.messages;
create policy "messages delete participants"
on public.messages for delete
to authenticated
using (
  (select auth.uid()::text) = "senderId"
  or (select auth.uid()::text) = "receiverId"
);

drop policy if exists "chats delete participants" on public.chats;
create policy "chats delete participants"
on public.chats for delete
to authenticated
using ((select auth.uid()::text) = any(participants));

create or replace function public.mark_conversation_read(
  p_user_id text,
  p_other_user_id text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid()::text is distinct from p_user_id then
    raise exception 'Not authorized to update another user conversation';
  end if;

  update public.messages
  set "isRead" = true
  where "receiverId" = p_user_id
    and "senderId" = p_other_user_id
    and "isRead" = false;
end;
$$;

create table if not exists public.product_events (
  id uuid primary key default gen_random_uuid(),
  "productId" text not null references public.products(id) on delete cascade,
  "sellerId" text not null references public.users(id) on delete cascade,
  "viewerId" text references public.users(id) on delete set null,
  "eventType" text not null,
  "createdAt" timestamptz not null default timezone('utc', now())
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'product_events_type_check'
      and conrelid = 'public.product_events'::regclass
  ) then
    alter table public.product_events
    add constraint product_events_type_check
    check ("eventType" in ('view', 'click', 'wishlist', 'cart', 'purchase'));
  end if;
end
$$;

create index if not exists product_events_seller_created_idx
on public.product_events ("sellerId", "createdAt" desc);

create index if not exists product_events_product_type_created_idx
on public.product_events ("productId", "eventType", "createdAt" desc);

alter table public.product_events enable row level security;

drop policy if exists "product events read seller" on public.product_events;
create policy "product events read seller"
on public.product_events for select
to authenticated
using ((select auth.uid()::text) = "sellerId");

create or replace function public.track_product_event(
  p_product_id text,
  p_event_type text,
  p_viewer_id text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller_id text;
  v_safe_viewer_id text;
begin
  if p_event_type not in ('view', 'click', 'wishlist', 'cart', 'purchase') then
    raise exception 'Invalid event type';
  end if;

  select "sellerId"
  into v_seller_id
  from public.products
  where id = p_product_id;

  if v_seller_id is null then
    return;
  end if;

  v_safe_viewer_id := nullif(coalesce(p_viewer_id, auth.uid()::text), '');

  if v_safe_viewer_id is not null and not exists (
    select 1 from public.users u where u.id = v_safe_viewer_id
  ) then
    v_safe_viewer_id := null;
  end if;

  insert into public.product_events (
    "productId",
    "sellerId",
    "viewerId",
    "eventType",
    "createdAt"
  ) values (
    p_product_id,
    v_seller_id,
    v_safe_viewer_id,
    p_event_type,
    timezone('utc', now())
  );
end;
$$;

create or replace function public.get_seller_dashboard(
  p_vendor_id text,
  p_since timestamptz default timezone('utc', now()) - interval '7 days'
) returns table (
  views_count bigint,
  clicks_count bigint,
  wishlist_count bigint,
  cart_count bigint,
  purchase_count bigint,
  sales_this_week bigint,
  top_product_id text,
  top_product_name text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid()::text is distinct from p_vendor_id then
    raise exception 'Not authorized to fetch seller analytics';
  end if;

  if not exists (
    select 1
    from public.users u
    where u.id = p_vendor_id
      and u.role = 'seller'
  ) then
    raise exception 'Seller not found';
  end if;

  return query
  with events as (
    select *
    from public.product_events e
    where e."sellerId" = p_vendor_id
      and e."createdAt" >= p_since
  ),
  top_event as (
    select
      e."productId",
      count(*) as total_count
    from events e
    group by e."productId"
    order by total_count desc
    limit 1
  ),
  seller_sales as (
    select count(*)::bigint as total_sales
    from public.orders o
    where o."orderDate" >= p_since
      and o.status in ('Delivered', 'Received')
      and p_vendor_id = any(o."sellerIds")
  )
  select
    coalesce(sum((e."eventType" = 'view')::int), 0)::bigint as views_count,
    coalesce(sum((e."eventType" = 'click')::int), 0)::bigint as clicks_count,
    coalesce(sum((e."eventType" = 'wishlist')::int), 0)::bigint as wishlist_count,
    coalesce(sum((e."eventType" = 'cart')::int), 0)::bigint as cart_count,
    coalesce(sum((e."eventType" = 'purchase')::int), 0)::bigint as purchase_count,
    coalesce((select total_sales from seller_sales), 0)::bigint as sales_this_week,
    te."productId"::text as top_product_id,
    p.name::text as top_product_name
  from events e
  left join top_event te on true
  left join public.products p on p.id = te."productId";
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'product_events'
  ) then
    alter publication supabase_realtime add table public.product_events;
  end if;
end
$$;
