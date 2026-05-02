update storage.buckets
set public = true
where id in ('user-profiles', 'store-media', 'product-media');

drop policy if exists "user-profiles select own objects" on storage.objects;
drop policy if exists "store-media select own objects" on storage.objects;
drop policy if exists "product-media select own objects" on storage.objects;

create policy "user-profiles public read"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'user-profiles');

create policy "store-media public read"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'store-media');

create policy "product-media public read"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'product-media');

drop policy if exists "store-media insert own folder" on storage.objects;
drop policy if exists "store-media update own objects" on storage.objects;
drop policy if exists "store-media delete own objects" on storage.objects;

create policy "store-media insert seller folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'store-media'
  and (storage.foldername(name))[1] = 'stores'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
  and exists (
    select 1
    from public.users u
    where u.id = (select auth.uid()::text)
      and u.role = 'seller'
  )
);

create policy "store-media update seller objects"
on storage.objects for update
to authenticated
using (
  bucket_id = 'store-media'
  and owner_id = (select auth.uid()::text)
  and exists (
    select 1
    from public.users u
    where u.id = (select auth.uid()::text)
      and u.role = 'seller'
  )
)
with check (
  bucket_id = 'store-media'
  and (storage.foldername(name))[1] = 'stores'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
  and exists (
    select 1
    from public.users u
    where u.id = (select auth.uid()::text)
      and u.role = 'seller'
  )
);

create policy "store-media delete seller objects"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'store-media'
  and owner_id = (select auth.uid()::text)
  and exists (
    select 1
    from public.users u
    where u.id = (select auth.uid()::text)
      and u.role = 'seller'
  )
);

drop policy if exists "product-media insert own folder" on storage.objects;
drop policy if exists "product-media update own objects" on storage.objects;
drop policy if exists "product-media delete own objects" on storage.objects;

create policy "product-media insert seller folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'product-media'
  and (storage.foldername(name))[1] = 'products'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
  and exists (
    select 1
    from public.users u
    where u.id = (select auth.uid()::text)
      and u.role = 'seller'
  )
);

create policy "product-media update seller objects"
on storage.objects for update
to authenticated
using (
  bucket_id = 'product-media'
  and owner_id = (select auth.uid()::text)
  and exists (
    select 1
    from public.users u
    where u.id = (select auth.uid()::text)
      and u.role = 'seller'
  )
)
with check (
  bucket_id = 'product-media'
  and (storage.foldername(name))[1] = 'products'
  and (storage.foldername(name))[2] = (select auth.uid()::text)
  and storage.extension(name) = any (array['jpg', 'jpeg', 'png', 'webp'])
  and exists (
    select 1
    from public.users u
    where u.id = (select auth.uid()::text)
      and u.role = 'seller'
  )
);

create policy "product-media delete seller objects"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'product-media'
  and owner_id = (select auth.uid()::text)
  and exists (
    select 1
    from public.users u
    where u.id = (select auth.uid()::text)
      and u.role = 'seller'
  )
);

drop policy if exists "products insert seller" on public.products;
create policy "products insert seller"
on public.products for insert
to authenticated
with check (
  auth.uid()::text = "sellerId"
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()::text
      and u.role = 'seller'
  )
);

drop policy if exists "products update seller" on public.products;
create policy "products update seller"
on public.products for update
to authenticated
using (
  auth.uid()::text = "sellerId"
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()::text
      and u.role = 'seller'
  )
)
with check (
  auth.uid()::text = "sellerId"
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()::text
      and u.role = 'seller'
  )
);

drop policy if exists "products delete seller" on public.products;
create policy "products delete seller"
on public.products for delete
to authenticated
using (
  auth.uid()::text = "sellerId"
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()::text
      and u.role = 'seller'
  )
);
