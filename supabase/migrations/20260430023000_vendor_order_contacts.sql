create or replace function public.get_vendor_order_contacts(
  p_vendor_id text default auth.uid()::text
) returns table (
  buyer_id text,
  buyer_name text,
  phone_number text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if coalesce(p_vendor_id, '') <> auth.uid()::text and not public.is_admin() then
    raise exception 'Forbidden';
  end if;

  if not public.is_admin() and not exists (
    select 1
    from public.users u
    where u.id = auth.uid()::text
      and u.role = 'seller'
      and not public.is_account_banned(u.id)
  ) then
    raise exception 'Seller account required';
  end if;

  return query
  select distinct
    u.id as buyer_id,
    u.name as buyer_name,
    u."phoneNumber" as phone_number
  from public.orders o
  join public.users u
    on u.id = o."buyerId"
  where p_vendor_id = any (o."sellerIds")
    and nullif(trim(coalesce(u."phoneNumber", '')), '') is not null;
end;
$$;

revoke all on function public.get_vendor_order_contacts(text) from public;
grant execute on function public.get_vendor_order_contacts(text) to authenticated;
