-- Dados de exemplo para `supabase db reset` em desenvolvimento local.
-- Não semeia tenant_members: associar alguém a um tenant exige uma conta
-- real em auth.users (criada via signup ou pelo Studio local).

insert into public.tenants (id, slug, name, timezone)
values (
  '00000000-0000-0000-0000-000000000001',
  'gk-barber-demo',
  'GK Barber (demo)',
  'America/Sao_Paulo'
)
on conflict (id) do nothing;

insert into public.units (id, tenant_id, name, address)
values (
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  'Unidade Centro',
  'Rua Principal, 100'
)
on conflict (id) do nothing;
