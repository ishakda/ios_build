alter table public.products
add column if not exists "brand" text,
add column if not exists "parentCategory" text,
add column if not exists "subCategory" text;

update public.products
set
  "parentCategory" = coalesce("parentCategory", category),
  "subCategory" = coalesce("subCategory", category)
where "parentCategory" is null
   or "subCategory" is null;

create index if not exists products_parent_category_idx
on public.products ("parentCategory");

create index if not exists products_sub_category_idx
on public.products ("subCategory");

