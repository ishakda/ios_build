create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  "userId" text not null references public.users(id) on delete cascade,
  subject text not null,
  message text not null,
  "contactMethod" text not null default 'in_app',
  "contactValue" text,
  status text not null default 'open',
  "createdAt" timestamptz not null default timezone('utc', now()),
  "updatedAt" timestamptz not null default timezone('utc', now())
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'support_tickets_status_check'
      and conrelid = 'public.support_tickets'::regclass
  ) then
    alter table public.support_tickets
    add constraint support_tickets_status_check
    check (status in ('open', 'in_progress', 'resolved', 'closed'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'support_tickets_contact_method_check'
      and conrelid = 'public.support_tickets'::regclass
  ) then
    alter table public.support_tickets
    add constraint support_tickets_contact_method_check
    check ("contactMethod" in ('in_app', 'email', 'phone', 'chat'));
  end if;
end
$$;

create index if not exists support_tickets_user_created_idx
on public.support_tickets ("userId", "createdAt" desc);

alter table public.support_tickets enable row level security;

drop policy if exists "support tickets read self" on public.support_tickets;
create policy "support tickets read self"
on public.support_tickets for select
to authenticated
using ((select auth.uid()::text) = "userId");

drop policy if exists "support tickets insert self" on public.support_tickets;
create policy "support tickets insert self"
on public.support_tickets for insert
to authenticated
with check (
  (select auth.uid()::text) = "userId"
  and length(trim(subject)) >= 3
  and length(trim(message)) >= 8
);

drop policy if exists "support tickets update self" on public.support_tickets;
create policy "support tickets update self"
on public.support_tickets for update
to authenticated
using ((select auth.uid()::text) = "userId")
with check ((select auth.uid()::text) = "userId");

drop function if exists public.get_seller_dashboard(text, timestamptz);

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
  top_product_name text,
  ctr numeric,
  click_to_cart_rate numeric,
  cart_to_purchase_rate numeric,
  overall_purchase_rate numeric,
  low_stock_count bigint
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
  rollup as (
    select
      coalesce(sum((e."eventType" = 'view')::int), 0)::bigint as views_count,
      coalesce(sum((e."eventType" = 'click')::int), 0)::bigint as clicks_count,
      coalesce(sum((e."eventType" = 'wishlist')::int), 0)::bigint as wishlist_count,
      coalesce(sum((e."eventType" = 'cart')::int), 0)::bigint as cart_count,
      coalesce(sum((e."eventType" = 'purchase')::int), 0)::bigint as purchase_count
    from events e
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
  ),
  low_stock as (
    select count(*)::bigint as low_stock_count
    from public.products p
    where p."sellerId" = p_vendor_id
      and p.stock between 1 and 5
  )
  select
    r.views_count,
    r.clicks_count,
    r.wishlist_count,
    r.cart_count,
    r.purchase_count,
    coalesce((select total_sales from seller_sales), 0)::bigint as sales_this_week,
    te."productId"::text as top_product_id,
    p.name::text as top_product_name,
    case
      when r.views_count = 0 then 0
      else round((r.clicks_count::numeric / r.views_count::numeric) * 100, 2)
    end as ctr,
    case
      when r.clicks_count = 0 then 0
      else round((r.cart_count::numeric / r.clicks_count::numeric) * 100, 2)
    end as click_to_cart_rate,
    case
      when r.cart_count = 0 then 0
      else round((r.purchase_count::numeric / r.cart_count::numeric) * 100, 2)
    end as cart_to_purchase_rate,
    case
      when r.views_count = 0 then 0
      else round((r.purchase_count::numeric / r.views_count::numeric) * 100, 2)
    end as overall_purchase_rate,
    coalesce((select low_stock_count from low_stock), 0)::bigint as low_stock_count
  from rollup r
  left join top_event te on true
  left join public.products p on p.id = te."productId";
end;
$$;
