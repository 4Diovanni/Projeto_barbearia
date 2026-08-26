-- Fundação multi-tenant: tenants, tenant_members, units e RLS (issue #19).
-- Toda tabela de negócio criada a partir daqui usa `tenant_id` + a policy
-- padrão `tenant_id in (select auth.user_tenants())`.

create extension if not exists btree_gist;

create type member_role as enum ('owner', 'manager', 'barber', 'receptionist');

create table tenants (
  id         uuid primary key default gen_random_uuid(),
  slug       text not null unique,
  name       text not null,
  logo_url   text,
  brand_color text not null default '#111111',
  timezone   text not null default 'America/Sao_Paulo',
  license_valid_until date,
  created_at timestamptz not null default now()
);

create table tenant_members (
  tenant_id uuid not null references tenants(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  role      member_role not null default 'barber',
  created_at timestamptz not null default now(),
  primary key (tenant_id, user_id)
);

create table units (
  tenant_id uuid not null references tenants(id) on delete cascade,
  id        uuid primary key default gen_random_uuid(),
  name      text not null,
  address   text,
  created_at timestamptz not null default now()
);

-- STABLE + SECURITY DEFINER: o planner cacheia o resultado por statement, e
-- roda com os privilégios do dono da função em vez dos do usuário logado, o
-- que evita que a própria política de tenant_members bloqueie a subquery.
create or replace function auth.user_tenants()
returns setof uuid
language sql stable security definer set search_path = '' as $$
  select tenant_id from public.tenant_members
  where user_id = (select auth.uid())
$$;

alter table tenants        enable row level security;
alter table tenant_members enable row level security;
alter table units          enable row level security;

create policy "membros acessam a propria barbearia" on tenants for all
  using      (id in (select auth.user_tenants()))
  with check (id in (select auth.user_tenants()));

create policy "membros veem o proprio vinculo" on tenant_members for all
  using      (tenant_id in (select auth.user_tenants()))
  with check (tenant_id in (select auth.user_tenants()));

create policy "membros acessam as proprias unidades" on units for all
  using      (tenant_id in (select auth.user_tenants()))
  with check (tenant_id in (select auth.user_tenants()));
