-- Migration: Add push notification trigger
-- This uses the pg_net extension to call the Edge Function asynchronously whenever a notification is created

create or replace function public.on_notification_inserted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_host text;
  v_auth text;
begin
  -- Get host and auth from current session context (request headers)
  -- Note: In some background contexts (like RPCs called from other triggers),
  -- request.headers might be missing. We default to a standard placeholder or service role if needed.
  begin
    v_host := current_setting('request.headers', true)::json->>'host';
    v_auth := current_setting('request.headers', true)::json->>'authorization';
  exception when others then
    -- Fallback for background tasks if needed
    v_host := null;
  end;

  -- Only attempt if we are in a web request context or we have a hardcoded URL
  -- For production, it's safer to use the internal project URL or a config variable
  -- However, using the request header host is common for dynamic environments.

  -- We'll use the supabase_url if available or construct it.
  -- For this project, we'll assume the standard Edge Function path.

  perform
    net.http_post(
      url := 'https://' || coalesce(v_host, 'placeholder-url-replaced-by-actual-host') || '/functions/v1/push-notifications',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', coalesce(v_auth, 'Bearer ' || current_setting('app.settings.service_role_key', true))
      ),
      body := jsonb_build_object('record', row_to_json(new))
    );

  return new;
end;
$$;

drop trigger if exists tr_push_notification on public.notifications;
create trigger tr_push_notification
after insert on public.notifications
for each row execute function public.on_notification_inserted();
