-- Laboratorio 5: tabla profiles con Row Level Security.
--
-- Es idempotente y no borra datos: crea la tabla solo si no existe (con las
-- mismas columnas que las migraciones anteriores), activa RLS y deja que cada
-- usuario autenticado lea, cree y actualice únicamente su propio perfil.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null,
  full_name text not null,
  email text not null
);

alter table public.profiles enable row level security;

-- Permisos de tabla: anon no necesita nada; authenticated, solo lo que usa la app.
revoke all on table public.profiles from anon;
revoke all on table public.profiles from authenticated;
grant select, insert, update on table public.profiles to authenticated;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);
