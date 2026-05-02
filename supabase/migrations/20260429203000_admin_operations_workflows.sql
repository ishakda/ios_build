alter table public.support_tickets
add column if not exists "adminNote" text;

create table if not exists public.product_reports (
  id uuid primary key default gen_random_uuid(),
  "productId" text not null references public.products(id) on delete cascade,
  "reporterUserId" text not null references public.users(id) on delete cascade,
  "sellerId" text references public.users(id) on delete set null,
  reason text not null,
  details text,
  status text not null default 'open',
  "adminNote" text,
  "createdAt" timestamptz not null default timezone('utc', now()),
  "updatedAt" timestamptz not null default timezone('utc', now())
);

create table if not exists public.refund_requests (
  id uuid primary key default gen_random_uuid(),
  "orderId" text not null references public.orders(id) on delete cascade,
  "buyerId" text not null references public.users(id) on delete cascade,
  reason text not null,
  details text,
  status text not null default 'pending',
  "adminNote" text,
  "createdAt" timestamptz not null default timezone('utc', now()),
  "updatedAt" timestamptz not null default timezone('utc', now())
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'product_reports_status_check'
      and conrelid = 'public.product_reports'::regclass
  ) then
    alter table public.product_reports
    add constraint product_reports_status_check
    check (status in ('open', 'reviewing', 'resolved', 'dismissed'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'refund_requests_status_check'
      and conrelid = 'public.refund_requests'::regclass
  ) then
    alter table public.refund_requests
    add constraint refund_requests_status_check
    check (status in ('pending', 'approved', 'rejected', 'refunded'));
  end if;
end
$$;

create index if not exists product_reports_reporter_created_idx
on public.product_reports ("reporterUserId", "createdAt" desc);

create index if not exists product_reports_product_created_idx
on public.product_reports ("productId", "createdAt" desc);

create index if not exists refund_requests_buyer_created_idx
on public.refund_requests ("buyerId", "createdAt" desc);

create index if not exists refund_requests_order_created_idx
on public.refund_requests ("orderId", "createdAt" desc);

create unique index if not exists product_reports_single_open_idx
on public.product_reports ("productId", "reporterUserId")
where status in ('open', 'reviewing');

create unique index if not exists refund_requests_single_pending_idx
on public.refund_requests ("orderId", "buyerId")
where status = 'pending';

alter table public.product_reports enable row level security;
alter table public.refund_requests enable row level security;

drop policy if exists "product reports read self" on public.product_reports;
create policy "product reports read self"
on public.product_reports for select
to authenticated
using (
  public.is_admin()
  or (select auth.uid()::text) = "reporterUserId"
);

drop policy if exists "product reports insert self" on public.product_reports;
create policy "product reports insert self"
on public.product_reports for insert
to authenticated
with check ((select auth.uid()::text) = "reporterUserId");

drop policy if exists "product reports admin manage" on public.product_reports;
create policy "product reports admin manage"
on public.product_reports for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "refund requests read self" on public.refund_requests;
create policy "refund requests read self"
on public.refund_requests for select
to authenticated
using (
  public.is_admin()
  or (select auth.uid()::text) = "buyerId"
);

drop policy if exists "refund requests insert self" on public.refund_requests;
create policy "refund requests insert self"
on public.refund_requests for insert
to authenticated
with check ((select auth.uid()::text) = "buyerId");

drop policy if exists "refund requests admin manage" on public.refund_requests;
create policy "refund requests admin manage"
on public.refund_requests for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.submit_product_report(
  p_product_id text,
  p_reason text,
  p_details text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id text := auth.uid()::text;
  v_seller_id text;
begin
  if v_user_id is null then
    raise exception 'Sign in required';
  end if;

  if public.is_account_banned(v_user_id) then
    raise exception 'Your account is suspended. Contact support for help.';
  end if;

  if length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception 'Report reason is too short';
  end if;

  select "sellerId"
  into v_seller_id
  from public.products
  where id = p_product_id;

  if v_seller_id is null then
    raise exception 'Product not found';
  end if;

  if v_seller_id = v_user_id then
    raise exception 'You cannot report your own product';
  end if;

  insert into public.product_reports (
    "productId",
    "reporterUserId",
    "sellerId",
    reason,
    details,
    status,
    "createdAt",
    "updatedAt"
  ) values (
    p_product_id,
    v_user_id,
    v_seller_id,
    trim(p_reason),
    nullif(trim(coalesce(p_details, '')), ''),
    'open',
    timezone('utc', now()),
    timezone('utc', now())
  );

  insert into public.notifications ("userId", title, body, type, "isRead", data)
  values (
    v_user_id,
    'Report Submitted',
    'Your product report was submitted for review.',
    'system',
    false,
    jsonb_build_object('productId', p_product_id)
  );
end;
$$;

create or replace function public.submit_refund_request(
  p_order_id text,
  p_reason text,
  p_details text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id text := auth.uid()::text;
  v_order public.orders%rowtype;
begin
  if v_user_id is null then
    raise exception 'Sign in required';
  end if;

  if public.is_account_banned(v_user_id) then
    raise exception 'Your account is suspended. Contact support for help.';
  end if;

  if length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception 'Refund reason is too short';
  end if;

  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if v_order.id is null or v_order."buyerId" <> v_user_id then
    raise exception 'Order not found';
  end if;

  if lower(v_order.status) not in ('delivered', 'received', 'cancelled') then
    raise exception 'Refund requests are available only for delivered, received, or cancelled orders';
  end if;

  insert into public.refund_requests (
    "orderId",
    "buyerId",
    reason,
    details,
    status,
    "createdAt",
    "updatedAt"
  ) values (
    p_order_id,
    v_user_id,
    trim(p_reason),
    nullif(trim(coalesce(p_details, '')), ''),
    'pending',
    timezone('utc', now()),
    timezone('utc', now())
  );

  insert into public.notifications ("userId", title, body, type, "isRead", data)
  values (
    v_user_id,
    'Refund Request Submitted',
    'Your refund request was sent to the admin team.',
    'system',
    false,
    jsonb_build_object('orderId', p_order_id)
  );
end;
$$;

create or replace function public.admin_update_support_ticket(
  p_ticket_id uuid,
  p_status text,
  p_admin_note text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id text;
begin
  if not public.is_admin() then
    raise exception 'Not authorized to update support tickets';
  end if;

  if p_status not in ('open', 'in_progress', 'resolved', 'closed') then
    raise exception 'Invalid support ticket status';
  end if;

  update public.support_tickets
  set
    status = p_status,
    "adminNote" = nullif(trim(coalesce(p_admin_note, '')), ''),
    "updatedAt" = timezone('utc', now())
  where id = p_ticket_id
  returning "userId"
  into v_user_id;

  if v_user_id is null then
    raise exception 'Support ticket not found';
  end if;

  insert into public.notifications ("userId", title, body, type, "isRead", data)
  values (
    v_user_id,
    'Support Ticket Updated',
    'Your support ticket status is now ' || p_status || '.',
    'system',
    false,
    jsonb_build_object('ticketId', p_ticket_id, 'status', p_status)
  );
end;
$$;

create or replace function public.admin_update_product_report(
  p_report_id uuid,
  p_status text,
  p_admin_note text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reporter_id text;
begin
  if not public.is_admin() then
    raise exception 'Not authorized to update product reports';
  end if;

  if p_status not in ('open', 'reviewing', 'resolved', 'dismissed') then
    raise exception 'Invalid product report status';
  end if;

  update public.product_reports
  set
    status = p_status,
    "adminNote" = nullif(trim(coalesce(p_admin_note, '')), ''),
    "updatedAt" = timezone('utc', now())
  where id = p_report_id
  returning "reporterUserId"
  into v_reporter_id;

  if v_reporter_id is null then
    raise exception 'Product report not found';
  end if;

  insert into public.notifications ("userId", title, body, type, "isRead", data)
  values (
    v_reporter_id,
    'Product Report Updated',
    'Your product report status is now ' || p_status || '.',
    'system',
    false,
    jsonb_build_object('reportId', p_report_id, 'status', p_status)
  );
end;
$$;

create or replace function public.admin_update_refund_request(
  p_request_id uuid,
  p_status text,
  p_admin_note text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_buyer_id text;
begin
  if not public.is_admin() then
    raise exception 'Not authorized to update refund requests';
  end if;

  if p_status not in ('pending', 'approved', 'rejected', 'refunded') then
    raise exception 'Invalid refund request status';
  end if;

  update public.refund_requests
  set
    status = p_status,
    "adminNote" = nullif(trim(coalesce(p_admin_note, '')), ''),
    "updatedAt" = timezone('utc', now())
  where id = p_request_id
  returning "buyerId"
  into v_buyer_id;

  if v_buyer_id is null then
    raise exception 'Refund request not found';
  end if;

  insert into public.notifications ("userId", title, body, type, "isRead", data)
  values (
    v_buyer_id,
    'Refund Request Updated',
    'Your refund request status is now ' || p_status || '.',
    'system',
    false,
    jsonb_build_object('refundRequestId', p_request_id, 'status', p_status)
  );
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'support_tickets'
  ) then
    alter publication supabase_realtime add table public.support_tickets;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'product_reports'
  ) then
    alter publication supabase_realtime add table public.product_reports;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'refund_requests'
  ) then
    alter publication supabase_realtime add table public.refund_requests;
  end if;
end
$$;
