alter table public.orders
add column if not exists "paymentMethod" text not null default 'cod',
add column if not exists "paymentStatus" text not null default 'pending',
add column if not exists "deliveryStatus" text not null default 'pending',
add column if not exists "paymentReference" text,
add column if not exists "chargilyCheckoutId" text,
add column if not exists "commissionAmount" numeric(12,2) not null default 0,
add column if not exists "sellerAmount" numeric(12,2) not null default 0,
add column if not exists "shippingAddressId" uuid references public.addresses(id) on delete set null,
add column if not exists "customerPhone" text,
add column if not exists "deliveryNotes" text,
add column if not exists "confirmedAt" timestamptz,
add column if not exists "shippedAt" timestamptz,
add column if not exists "deliveredAt" timestamptz,
add column if not exists "completedAt" timestamptz,
add column if not exists "cancelledAt" timestamptz,
add column if not exists "disputeStatus" text not null default 'none',
add column if not exists "refundStatus" text not null default 'none';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_payment_method_check'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
    add constraint orders_payment_method_check
    check ("paymentMethod" in ('cod', 'chargily'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_payment_status_check'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
    add constraint orders_payment_status_check
    check ("paymentStatus" in ('pending', 'checkout_created', 'processing', 'paid', 'failed', 'expired', 'cancelled', 'refunded'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_delivery_status_check'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
    add constraint orders_delivery_status_check
    check ("deliveryStatus" in ('pending', 'processing', 'ready_to_ship', 'shipped', 'out_for_delivery', 'delivered', 'returned', 'failed_delivery'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_dispute_status_check'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
    add constraint orders_dispute_status_check
    check ("disputeStatus" in ('none', 'open', 'under_review', 'resolved', 'rejected'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_refund_status_check'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
    add constraint orders_refund_status_check
    check ("refundStatus" in ('none', 'requested', 'approved', 'rejected', 'refunded', 'partial_refund'));
  end if;
end
$$;

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  "orderId" text not null references public.orders(id) on delete cascade,
  "buyerId" text not null references public.users(id) on delete cascade,
  "sellerId" text references public.users(id) on delete set null,
  provider text not null default 'chargily',
  method text not null default 'cib_edahabia',
  amount numeric(12,2) not null,
  currency text not null default 'DZD',
  status text not null default 'pending',
  "providerPaymentId" text,
  "providerCheckoutId" text,
  "providerCheckoutUrl" text,
  "providerReference" text,
  "idempotencyKey" text,
  metadata jsonb not null default '{}'::jsonb,
  "paidAt" timestamptz,
  "failedAt" timestamptz,
  "expiresAt" timestamptz,
  "createdAt" timestamptz not null default timezone('utc', now()),
  "updatedAt" timestamptz not null default timezone('utc', now())
);

create unique index if not exists payments_provider_reference_uidx
on public.payments ("providerReference")
where "providerReference" is not null;

create index if not exists payments_order_created_idx
on public.payments ("orderId", "createdAt" desc);

create index if not exists payments_buyer_created_idx
on public.payments ("buyerId", "createdAt" desc);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'payments_provider_check'
      and conrelid = 'public.payments'::regclass
  ) then
    alter table public.payments
    add constraint payments_provider_check
    check (provider in ('chargily'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'payments_status_check'
      and conrelid = 'public.payments'::regclass
  ) then
    alter table public.payments
    add constraint payments_status_check
    check (status in ('pending', 'checkout_created', 'processing', 'paid', 'failed', 'expired', 'cancelled', 'refunded'));
  end if;
end
$$;

create table if not exists public.payment_webhook_logs (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'chargily',
  "eventType" text,
  signature text,
  headers jsonb not null default '{}'::jsonb,
  payload jsonb not null default '{}'::jsonb,
  "paymentId" uuid references public.payments(id) on delete set null,
  "receivedAt" timestamptz not null default timezone('utc', now()),
  "processedAt" timestamptz,
  "processingStatus" text not null default 'received',
  notes text
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'payment_webhook_logs_status_check'
      and conrelid = 'public.payment_webhook_logs'::regclass
  ) then
    alter table public.payment_webhook_logs
    add constraint payment_webhook_logs_status_check
    check ("processingStatus" in ('received', 'processed', 'ignored', 'failed'));
  end if;
end
$$;

create table if not exists public.seller_wallets (
  "sellerId" text primary key references public.users(id) on delete cascade,
  "availableBalance" numeric(12,2) not null default 0,
  "pendingBalance" numeric(12,2) not null default 0,
  "heldBalance" numeric(12,2) not null default 0,
  "totalEarned" numeric(12,2) not null default 0,
  "totalWithdrawn" numeric(12,2) not null default 0,
  currency text not null default 'DZD',
  "lastPayoutReleasedAt" timestamptz,
  "createdAt" timestamptz not null default timezone('utc', now()),
  "updatedAt" timestamptz not null default timezone('utc', now())
);

create table if not exists public.withdrawals (
  id uuid primary key default gen_random_uuid(),
  "sellerId" text not null references public.users(id) on delete cascade,
  amount numeric(12,2) not null,
  currency text not null default 'DZD',
  method text not null,
  "accountNumber" text not null,
  "accountName" text,
  status text not null default 'pending',
  notes text,
  "reviewedBy" text references public.users(id) on delete set null,
  "reviewedAt" timestamptz,
  "paidAt" timestamptz,
  "createdAt" timestamptz not null default timezone('utc', now()),
  "updatedAt" timestamptz not null default timezone('utc', now())
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'withdrawals_method_check'
      and conrelid = 'public.withdrawals'::regclass
  ) then
    alter table public.withdrawals
    add constraint withdrawals_method_check
    check (method in ('ccp', 'bank_transfer'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'withdrawals_status_check'
      and conrelid = 'public.withdrawals'::regclass
  ) then
    alter table public.withdrawals
    add constraint withdrawals_status_check
    check (status in ('pending', 'approved', 'rejected', 'paid'));
  end if;
end
$$;

create table if not exists public.disputes (
  id uuid primary key default gen_random_uuid(),
  "orderId" text not null references public.orders(id) on delete cascade,
  "buyerId" text not null references public.users(id) on delete cascade,
  "sellerId" text references public.users(id) on delete set null,
  reason text not null,
  details text,
  status text not null default 'open',
  "resolutionType" text,
  "resolutionNotes" text,
  "resolvedBy" text references public.users(id) on delete set null,
  "resolvedAt" timestamptz,
  evidence jsonb not null default '[]'::jsonb,
  "createdAt" timestamptz not null default timezone('utc', now()),
  "updatedAt" timestamptz not null default timezone('utc', now())
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'disputes_status_check'
      and conrelid = 'public.disputes'::regclass
  ) then
    alter table public.disputes
    add constraint disputes_status_check
    check (status in ('open', 'under_review', 'resolved', 'rejected'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'disputes_resolution_type_check'
      and conrelid = 'public.disputes'::regclass
  ) then
    alter table public.disputes
    add constraint disputes_resolution_type_check
    check ("resolutionType" is null or "resolutionType" in ('release_to_seller', 'full_refund', 'partial_refund'));
  end if;
end
$$;

create table if not exists public.shipment_tracking (
  id uuid primary key default gen_random_uuid(),
  "orderId" text not null references public.orders(id) on delete cascade,
  "sellerId" text references public.users(id) on delete set null,
  "trackingNumber" text,
  "carrierName" text,
  status text not null default 'processing',
  location text,
  notes text,
  "estimatedDeliveryDate" timestamptz,
  "eventAt" timestamptz not null default timezone('utc', now()),
  "createdAt" timestamptz not null default timezone('utc', now())
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'shipment_tracking_status_check'
      and conrelid = 'public.shipment_tracking'::regclass
  ) then
    alter table public.shipment_tracking
    add constraint shipment_tracking_status_check
    check (status in ('processing', 'ready_to_ship', 'shipped', 'out_for_delivery', 'delivered', 'returned', 'failed_delivery'));
  end if;
end
$$;

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  "orderId" text not null references public.orders(id) on delete cascade,
  status text not null,
  "paymentStatus" text,
  "deliveryStatus" text,
  actor text not null default 'system',
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  "createdAt" timestamptz not null default timezone('utc', now())
);

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  "sellerId" text not null references public.users(id) on delete cascade,
  "orderId" text references public.orders(id) on delete set null,
  "paymentId" uuid references public.payments(id) on delete set null,
  "withdrawalId" uuid references public.withdrawals(id) on delete set null,
  "disputeId" uuid references public.disputes(id) on delete set null,
  type text not null,
  direction text not null,
  bucket text not null,
  amount numeric(12,2) not null,
  currency text not null default 'DZD',
  status text not null default 'posted',
  description text,
  metadata jsonb not null default '{}'::jsonb,
  "createdAt" timestamptz not null default timezone('utc', now())
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'wallet_transactions_type_check'
      and conrelid = 'public.wallet_transactions'::regclass
  ) then
    alter table public.wallet_transactions
    add constraint wallet_transactions_type_check
    check (type in ('sale_hold', 'payout_release', 'withdrawal_hold', 'withdrawal_release', 'withdrawal_reversal', 'refund', 'adjustment'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'wallet_transactions_direction_check'
      and conrelid = 'public.wallet_transactions'::regclass
  ) then
    alter table public.wallet_transactions
    add constraint wallet_transactions_direction_check
    check (direction in ('credit', 'debit'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'wallet_transactions_bucket_check'
      and conrelid = 'public.wallet_transactions'::regclass
  ) then
    alter table public.wallet_transactions
    add constraint wallet_transactions_bucket_check
    check (bucket in ('pending', 'available', 'held'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'wallet_transactions_status_check'
      and conrelid = 'public.wallet_transactions'::regclass
  ) then
    alter table public.wallet_transactions
    add constraint wallet_transactions_status_check
    check (status in ('posted', 'reversed'));
  end if;
end
$$;

create index if not exists wallet_transactions_seller_created_idx
on public.wallet_transactions ("sellerId", "createdAt" desc);

create index if not exists withdrawals_seller_created_idx
on public.withdrawals ("sellerId", "createdAt" desc);

create index if not exists disputes_order_created_idx
on public.disputes ("orderId", "createdAt" desc);

alter table public.payments enable row level security;
alter table public.payment_webhook_logs enable row level security;
alter table public.seller_wallets enable row level security;
alter table public.withdrawals enable row level security;
alter table public.disputes enable row level security;
alter table public.shipment_tracking enable row level security;
alter table public.order_status_history enable row level security;
alter table public.wallet_transactions enable row level security;

create or replace function public.touch_marketplace_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new."updatedAt" := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists seller_wallets_touch_updated_at on public.seller_wallets;
create trigger seller_wallets_touch_updated_at
before update on public.seller_wallets
for each row execute function public.touch_marketplace_updated_at();

drop trigger if exists payments_touch_updated_at on public.payments;
create trigger payments_touch_updated_at
before update on public.payments
for each row execute function public.touch_marketplace_updated_at();

drop trigger if exists withdrawals_touch_updated_at on public.withdrawals;
create trigger withdrawals_touch_updated_at
before update on public.withdrawals
for each row execute function public.touch_marketplace_updated_at();

drop trigger if exists disputes_touch_updated_at on public.disputes;
create trigger disputes_touch_updated_at
before update on public.disputes
for each row execute function public.touch_marketplace_updated_at();

create or replace function public.ensure_seller_wallet(
  p_seller_id text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_seller_id is null then
    return;
  end if;

  insert into public.seller_wallets ("sellerId")
  values (p_seller_id)
  on conflict ("sellerId") do nothing;
end;
$$;

create or replace function public.append_order_status_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.order_status_history (
      "orderId",
      status,
      "paymentStatus",
      "deliveryStatus",
      actor,
      metadata
    ) values (
      new.id,
      new.status,
      new."paymentStatus",
      new."deliveryStatus",
      'system',
      jsonb_build_object('source', 'order_insert')
    );
    return new;
  end if;

  if old.status is distinct from new.status
    or old."paymentStatus" is distinct from new."paymentStatus"
    or old."deliveryStatus" is distinct from new."deliveryStatus" then
    insert into public.order_status_history (
      "orderId",
      status,
      "paymentStatus",
      "deliveryStatus",
      actor,
      metadata
    ) values (
      new.id,
      new.status,
      new."paymentStatus",
      new."deliveryStatus",
      coalesce(auth.uid()::text, 'system'),
      jsonb_build_object(
        'oldStatus', old.status,
        'oldPaymentStatus', old."paymentStatus",
        'oldDeliveryStatus', old."deliveryStatus"
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists orders_append_status_history on public.orders;
create trigger orders_append_status_history
after insert or update on public.orders
for each row execute function public.append_order_status_history();

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

create or replace function public.apply_successful_payment(
  p_payment_id uuid,
  p_provider_payment_id text default null,
  p_provider_checkout_id text default null,
  p_provider_reference text default null,
  p_payload jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.payments%rowtype;
  v_order public.orders%rowtype;
begin
  select *
  into v_payment
  from public.payments
  where id = p_payment_id
  for update;

  if v_payment.id is null then
    raise exception 'Payment not found';
  end if;

  if v_payment.status = 'paid' then
    return;
  end if;

  select *
  into v_order
  from public.orders
  where id = v_payment."orderId"
  for update;

  perform public.ensure_seller_wallet(v_payment."sellerId");

  update public.payments
  set
    status = 'paid',
    "providerPaymentId" = coalesce(p_provider_payment_id, "providerPaymentId"),
    "providerCheckoutId" = coalesce(p_provider_checkout_id, "providerCheckoutId"),
    "providerReference" = coalesce(p_provider_reference, "providerReference"),
    metadata = coalesce(metadata, '{}'::jsonb) || coalesce(p_payload, '{}'::jsonb),
    "paidAt" = timezone('utc', now())
  where id = p_payment_id;

  update public.orders
  set
    status = case when status = 'Pending' then 'Paid' else status end,
    "paymentMethod" = 'chargily',
    "paymentStatus" = 'paid',
    "paymentReference" = coalesce(p_provider_reference, "paymentReference"),
    "chargilyCheckoutId" = coalesce(p_provider_checkout_id, "chargilyCheckoutId"),
    "confirmedAt" = coalesce("confirmedAt", timezone('utc', now()))
  where id = v_order.id;

  if v_payment."sellerId" is not null and coalesce(v_order."sellerAmount", 0) > 0 then
    update public.seller_wallets
    set
      "pendingBalance" = "pendingBalance" + v_order."sellerAmount",
      "totalEarned" = "totalEarned" + v_order."sellerAmount"
    where "sellerId" = v_payment."sellerId";

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
      v_payment."sellerId",
      v_order.id,
      v_payment.id,
      'sale_hold',
      'credit',
      'pending',
      v_order."sellerAmount",
      'Paid order credited to pending seller balance'
    );
  end if;
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
  if auth.uid()::text is not null and not public.is_admin() then
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
  v_seller_id text := p_seller_id;
  v_wallet public.seller_wallets%rowtype;
  v_withdrawal_id uuid;
begin
  if v_seller_id is null then
    raise exception 'Authentication required';
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

drop policy if exists "payments read participants" on public.payments;
create policy "payments read participants"
on public.payments for select
to authenticated
using (
  public.is_admin()
  or auth.uid()::text = "buyerId"
  or auth.uid()::text = "sellerId"
);

drop policy if exists "seller wallets read owner or admin" on public.seller_wallets;
create policy "seller wallets read owner or admin"
on public.seller_wallets for select
to authenticated
using (
  public.is_admin()
  or auth.uid()::text = "sellerId"
);

drop policy if exists "wallet transactions read owner or admin" on public.wallet_transactions;
create policy "wallet transactions read owner or admin"
on public.wallet_transactions for select
to authenticated
using (
  public.is_admin()
  or auth.uid()::text = "sellerId"
);

drop policy if exists "withdrawals read owner or admin" on public.withdrawals;
create policy "withdrawals read owner or admin"
on public.withdrawals for select
to authenticated
using (
  public.is_admin()
  or auth.uid()::text = "sellerId"
);

drop policy if exists "withdrawals insert owner" on public.withdrawals;
create policy "withdrawals insert owner"
on public.withdrawals for insert
to authenticated
with check (auth.uid()::text = "sellerId");

drop policy if exists "disputes read order participants" on public.disputes;
create policy "disputes read order participants"
on public.disputes for select
to authenticated
using (
  public.is_admin()
  or auth.uid()::text = "buyerId"
  or auth.uid()::text = "sellerId"
);

drop policy if exists "disputes insert buyer" on public.disputes;
create policy "disputes insert buyer"
on public.disputes for insert
to authenticated
with check (auth.uid()::text = "buyerId");

drop policy if exists "shipment tracking read participants" on public.shipment_tracking;
create policy "shipment tracking read participants"
on public.shipment_tracking for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.orders o
    where o.id = "orderId"
      and (
        auth.uid()::text = o."buyerId"
        or auth.uid()::text = any(o."sellerIds")
      )
  )
);

drop policy if exists "shipment tracking insert seller or admin" on public.shipment_tracking;
create policy "shipment tracking insert seller or admin"
on public.shipment_tracking for insert
to authenticated
with check (
  public.is_admin()
  or (
    auth.uid()::text = "sellerId"
    and exists (
      select 1
      from public.orders o
      where o.id = "orderId"
        and auth.uid()::text = any(o."sellerIds")
    )
  )
);

drop policy if exists "order status history read participants" on public.order_status_history;
create policy "order status history read participants"
on public.order_status_history for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.orders o
    where o.id = "orderId"
      and (
        auth.uid()::text = o."buyerId"
        or auth.uid()::text = any(o."sellerIds")
      )
  )
);

drop policy if exists "payment webhook logs read admin" on public.payment_webhook_logs;
create policy "payment webhook logs read admin"
on public.payment_webhook_logs for select
to authenticated
using (public.is_admin());
