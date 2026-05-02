update storage.buckets
set public = false
where id = 'chat-media';

drop policy if exists "chat-media insert own folder" on storage.objects;
drop policy if exists "chat-media select own objects" on storage.objects;
drop policy if exists "chat-media update own objects" on storage.objects;
drop policy if exists "chat-media delete own objects" on storage.objects;

create policy "chat-media insert participant room"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'chat-media'
  and (storage.foldername(name))[1] = 'chats'
  and (storage.foldername(name))[3] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
  and exists (
    select 1
    from public.chats c
    where c.id = (storage.foldername(name))[2]
      and (select auth.uid()::text) = any(c.participants)
  )
);

create policy "chat-media select participant room"
on storage.objects for select
to authenticated
using (
  bucket_id = 'chat-media'
  and (storage.foldername(name))[1] = 'chats'
  and exists (
    select 1
    from public.chats c
    where c.id = (storage.foldername(name))[2]
      and (select auth.uid()::text) = any(c.participants)
  )
);

create policy "chat-media update uploader room"
on storage.objects for update
to authenticated
using (
  bucket_id = 'chat-media'
  and owner_id = (select auth.uid()::text)
  and (storage.foldername(name))[1] = 'chats'
  and exists (
    select 1
    from public.chats c
    where c.id = (storage.foldername(name))[2]
      and (select auth.uid()::text) = any(c.participants)
  )
)
with check (
  bucket_id = 'chat-media'
  and (storage.foldername(name))[1] = 'chats'
  and (storage.foldername(name))[3] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
  and exists (
    select 1
    from public.chats c
    where c.id = (storage.foldername(name))[2]
      and (select auth.uid()::text) = any(c.participants)
  )
);

create policy "chat-media delete uploader room"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'chat-media'
  and owner_id = (select auth.uid()::text)
  and (storage.foldername(name))[1] = 'chats'
  and exists (
    select 1
    from public.chats c
    where c.id = (storage.foldername(name))[2]
      and (select auth.uid()::text) = any(c.participants)
  )
);
