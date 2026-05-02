create index if not exists users_email_idx
on public.users (email);

create index if not exists products_category_idx
on public.products (category);

create index if not exists products_seller_id_idx
on public.products ("sellerId");

create index if not exists reviews_product_id_idx
on public.reviews ("productId");

create index if not exists reviews_user_id_idx
on public.reviews ("userId");

create index if not exists chats_participants_gin_idx
on public.chats
using gin (participants);

create index if not exists messages_chat_id_timestamp_idx
on public.messages ("chatId", "timestamp" desc);

create index if not exists orders_buyer_id_idx
on public.orders ("buyerId");

create index if not exists orders_seller_ids_gin_idx
on public.orders
using gin ("sellerIds");

create index if not exists notifications_user_id_timestamp_idx
on public.notifications ("userId", "timestamp" desc);

create index if not exists addresses_user_id_default_idx
on public.addresses ("userId", "isDefault" desc);

create index if not exists payment_methods_user_id_primary_idx
on public."paymentMethods" ("userId", "isPrimary" desc);

drop policy if exists "notifications insert self" on public.notifications;

drop policy if exists "store followers read authenticated" on public."storeFollowers";
create policy "store followers read participants"
on public."storeFollowers" for select
to authenticated
using (
  (select auth.uid()::text) = "userId"
  or (select auth.uid()::text) = "vendorId"
);

drop policy if exists "chats write participants" on public.chats;
create policy "chats write participants"
on public.chats for insert
to authenticated
with check (
  (select auth.uid()::text) = any(participants)
  and array_length(participants, 1) = 2
);

drop policy if exists "chats update participants" on public.chats;
create policy "chats update participants"
on public.chats for update
to authenticated
using (
  (select auth.uid()::text) = any(participants)
)
with check (
  (select auth.uid()::text) = any(participants)
  and array_length(participants, 1) = 2
);

drop policy if exists "public read user-profiles" on storage.objects;
drop policy if exists "auth write user-profiles" on storage.objects;
drop policy if exists "public read chat-media" on storage.objects;
drop policy if exists "auth write chat-media" on storage.objects;
drop policy if exists "public read store-media" on storage.objects;
drop policy if exists "auth write store-media" on storage.objects;
drop policy if exists "public read product-media" on storage.objects;
drop policy if exists "auth write product-media" on storage.objects;

create policy "user-profiles insert own folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'user-profiles'
  and (storage.foldername(name))[1] = 'profiles'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

create policy "user-profiles select own objects"
on storage.objects for select
to authenticated
using (
  bucket_id = 'user-profiles'
  and owner_id = (select auth.uid()::text)
);

create policy "user-profiles update own objects"
on storage.objects for update
to authenticated
using (
  bucket_id = 'user-profiles'
  and owner_id = (select auth.uid()::text)
)
with check (
  bucket_id = 'user-profiles'
  and (storage.foldername(name))[1] = 'profiles'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

create policy "user-profiles delete own objects"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'user-profiles'
  and owner_id = (select auth.uid()::text)
);

create policy "chat-media insert own folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'chat-media'
  and (storage.foldername(name))[1] = 'chats'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

create policy "chat-media select own objects"
on storage.objects for select
to authenticated
using (
  bucket_id = 'chat-media'
  and owner_id = (select auth.uid()::text)
);

create policy "chat-media update own objects"
on storage.objects for update
to authenticated
using (
  bucket_id = 'chat-media'
  and owner_id = (select auth.uid()::text)
)
with check (
  bucket_id = 'chat-media'
  and (storage.foldername(name))[1] = 'chats'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

create policy "chat-media delete own objects"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'chat-media'
  and owner_id = (select auth.uid()::text)
);

create policy "store-media insert own folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'store-media'
  and (storage.foldername(name))[1] = 'stores'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

create policy "store-media select own objects"
on storage.objects for select
to authenticated
using (
  bucket_id = 'store-media'
  and owner_id = (select auth.uid()::text)
);

create policy "store-media update own objects"
on storage.objects for update
to authenticated
using (
  bucket_id = 'store-media'
  and owner_id = (select auth.uid()::text)
)
with check (
  bucket_id = 'store-media'
  and (storage.foldername(name))[1] = 'stores'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

create policy "store-media delete own objects"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'store-media'
  and owner_id = (select auth.uid()::text)
);

create policy "product-media insert own folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'product-media'
  and (storage.foldername(name))[1] = 'products'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

create policy "product-media select own objects"
on storage.objects for select
to authenticated
using (
  bucket_id = 'product-media'
  and owner_id = (select auth.uid()::text)
);

create policy "product-media update own objects"
on storage.objects for update
to authenticated
using (
  bucket_id = 'product-media'
  and owner_id = (select auth.uid()::text)
)
with check (
  bucket_id = 'product-media'
  and (storage.foldername(name))[1] = 'products'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

create policy "product-media delete own objects"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'product-media'
  and owner_id = (select auth.uid()::text)
);
