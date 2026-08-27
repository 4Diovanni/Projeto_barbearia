begin;
select plan(2);

insert into tenants (id, slug, name) values
  ('11111111-1111-1111-1111-111111111111', 'barbearia-a', 'Barbearia A'),
  ('22222222-2222-2222-2222-222222222222', 'barbearia-b', 'Barbearia B');

-- Vincula o usuário de teste à barbearia A. Precisa existir em auth.users
-- por causa da FK de tenant_members; um insert mínimo basta para o RLS local.
insert into auth.users (id, instance_id, aud, role, email)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'membro-a@teste.local'
);

insert into tenant_members (tenant_id, user_id, role) values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'owner');

-- simula usuário membro apenas da barbearia A
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';

select is(
  (select count(*)::int from tenants where slug = 'barbearia-b'),
  0,
  'membro de A nao enxerga o tenant B'
);
select is(
  (select count(*)::int from tenants where slug = 'barbearia-a'),
  1,
  'membro de A enxerga o proprio tenant'
);

select * from finish();
rollback;
