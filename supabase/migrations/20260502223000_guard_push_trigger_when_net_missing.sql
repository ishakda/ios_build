create or replace function public.on_notification_inserted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_headers json;
  v_host text;
  v_auth text;
begin
  begin
    v_headers := current_setting('request.headers', true)::json;
    v_host := coalesce(
      v_headers->>'x-forwarded-host',
      v_headers->>'host'
    );
    v_auth := v_headers->>'authorization';
  exception when others then
    v_headers := null;
    v_host := null;
    v_auth := null;
  end;

  if new."userId" is null or nullif(trim(coalesce(new.title, '')), '') is null then
    return new;
  end if;

  if to_regnamespace('net') is null then
    return new;
  end if;

  execute $sql$
    select net.http_post(
      url := $1,
      headers := $2,
      body := $3
    )
  $sql$
  using
    'https://' || coalesce(v_host, 'placeholder-url-replaced-by-actual-host') || '/functions/v1/push-notifications',
    jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', coalesce(v_auth, 'Bearer ' || current_setting('app.settings.service_role_key', true))
    ),
    jsonb_build_object('record', row_to_json(new));

  return new;
end;
$$;
