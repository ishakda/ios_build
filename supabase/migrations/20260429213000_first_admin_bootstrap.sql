create or replace function public.bootstrap_first_admin(
  p_user_id text default null,
  p_email text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_request_role text := coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    nullif(
      case
        when nullif(current_setting('request.jwt.claims', true), '') is null then null
        else (current_setting('request.jwt.claims', true)::jsonb ->> 'role')
      end,
      ''
    )
  );
  v_target_user_id text := nullif(trim(coalesce(p_user_id, '')), '');
  v_target_email text := nullif(lower(trim(coalesce(p_email, ''))), '');
  v_target public.users%rowtype;
  v_auth_user auth.users%rowtype;
  v_name text;
begin
  if coalesce(v_request_role, '') <> 'service_role' and current_user <> 'postgres' then
    raise exception 'Only the service role may bootstrap the first admin';
  end if;

  if v_target_user_id is null and v_target_email is null then
    raise exception 'Provide p_user_id or p_email';
  end if;

  if exists (
    select 1
    from public.users
    where role = 'admin'
  ) then
    raise exception 'An admin account already exists';
  end if;

  if v_target_user_id is not null then
    select *
    into v_target
    from public.users
    where id = v_target_user_id
    for update;
  end if;

  if v_target.id is null and v_target_email is not null then
    select *
    into v_target
    from public.users
    where lower(trim(coalesce(email, ''))) = v_target_email
    order by "createdAt" asc
    limit 1
    for update;
  end if;

  if v_target.id is null then
    if v_target_user_id is not null then
      select *
      into v_auth_user
      from auth.users
      where id::text = v_target_user_id;
    else
      select *
      into v_auth_user
      from auth.users
      where lower(trim(coalesce(email, ''))) = v_target_email
      order by created_at asc
      limit 1;
    end if;

    if v_auth_user.id is null then
      raise exception 'Target user not found';
    end if;

    v_name := nullif(
      trim(
        coalesce(
          v_auth_user.raw_user_meta_data ->> 'name',
          v_auth_user.raw_user_meta_data ->> 'full_name',
          split_part(coalesce(v_auth_user.email, ''), '@', 1),
          'Admin'
        )
      ),
      ''
    );

    insert into public.users (
      id,
      name,
      email,
      "profileImageUrl",
      "phoneNumber",
      role,
      "storeName",
      "storeDescription",
      "storeLogo",
      "createdAt",
      "updatedAt"
    ) values (
      v_auth_user.id::text,
      coalesce(v_name, 'Admin'),
      coalesce(v_auth_user.email, ''),
      nullif(v_auth_user.raw_user_meta_data ->> 'profileImageUrl', ''),
      nullif(v_auth_user.phone, ''),
      'buyer',
      nullif(v_auth_user.raw_user_meta_data ->> 'storeName', ''),
      nullif(v_auth_user.raw_user_meta_data ->> 'storeDescription', ''),
      nullif(v_auth_user.raw_user_meta_data ->> 'storeLogo', ''),
      coalesce(v_auth_user.created_at, timezone('utc', now())),
      timezone('utc', now())
    )
    on conflict (id) do update
    set
      email = case
        when excluded.email = '' then public.users.email
        else excluded.email
      end,
      name = case
        when coalesce(trim(public.users.name), '') = '' then excluded.name
        else public.users.name
      end,
      "profileImageUrl" = coalesce(
        public.users."profileImageUrl",
        excluded."profileImageUrl"
      ),
      "phoneNumber" = coalesce(
        public.users."phoneNumber",
        excluded."phoneNumber"
      ),
      "storeName" = coalesce(
        public.users."storeName",
        excluded."storeName"
      ),
      "storeDescription" = coalesce(
        public.users."storeDescription",
        excluded."storeDescription"
      ),
      "storeLogo" = coalesce(
        public.users."storeLogo",
        excluded."storeLogo"
      ),
      "updatedAt" = timezone('utc', now());

    select *
    into v_target
    from public.users
    where id = v_auth_user.id::text
    for update;
  end if;

  update public.users
  set
    role = 'admin',
    "isBanned" = false,
    "bannedUntil" = null,
    "banReason" = null,
    "isCodBlocked" = false,
    "updatedAt" = timezone('utc', now())
  where id = v_target.id
  returning *
  into v_target;

  update auth.users
  set
    raw_user_meta_data = (
      coalesce(raw_user_meta_data, '{}'::jsonb) - 'banReason'
    ) || jsonb_build_object(
      'role', 'admin',
      'isBanned', false,
      'isCodBlocked', false
    ),
    raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
      || jsonb_build_object('role', 'admin'),
    updated_at = timezone('utc', now())
  where id = v_target.id::uuid;

  insert into public.notifications (
    "userId",
    title,
    body,
    type,
    "isRead",
    data
  ) values (
    v_target.id,
    'Admin Access Enabled',
    'Your account can now access the admin panel.',
    'system',
    false,
    jsonb_build_object('role', 'admin')
  );

  return (
    select jsonb_build_object(
      'id', u.id,
      'name', u.name,
      'email', u.email,
      'role', u.role,
      'isBanned', u."isBanned",
      'isCodBlocked', u."isCodBlocked",
      'updatedAt', u."updatedAt"
    )
    from public.users u
    where u.id = v_target.id
  );
end;
$$;

revoke all on function public.bootstrap_first_admin(text, text) from public;
revoke all on function public.bootstrap_first_admin(text, text) from anon;
revoke all on function public.bootstrap_first_admin(text, text) from authenticated;
grant execute on function public.bootstrap_first_admin(text, text) to service_role;
