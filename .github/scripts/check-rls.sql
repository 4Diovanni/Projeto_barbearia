-- ═══════════════════════════════════════════════════════════════════════════
-- Guarda de multi-tenancy — Risco #13 da arquitetura ("RLS esquecida numa
-- tabela nova"). Roda no CI contra o Supabase local, depois das migrations.
--
-- Regra 1 (ERRO):   tabela com coluna `tenant_id` e RLS desabilitada.
--                   É vazamento de dados entre barbearias — falha o build.
-- Regra 2 (ERRO):   tabela com RLS habilitada e nenhuma policy.
--                   Nega tudo silenciosamente; quase sempre é policy esquecida.
--
-- Uso local (a conexão vem do CLI, não escrita à mão):
--   eval "$(supabase status -o env)"
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f .github/scripts/check-rls.sql
-- ═══════════════════════════════════════════════════════════════════════════

\set ON_ERROR_STOP on

do $$
declare
  sem_rls        text;
  sem_policy     text;
begin
  -- ── Regra 1 ───────────────────────────────────────────────────────────────
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ' order by c.relname)
    into sem_rls
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where c.relkind = 'r'
     and n.nspname = 'public'
     and not c.relrowsecurity
     and exists (
       select 1
         from pg_attribute a
        where a.attrelid = c.oid
          and a.attname  = 'tenant_id'
          and a.attnum   > 0
          and not a.attisdropped
     );

  if sem_rls is not null then
    raise exception
      E'RLS desabilitada em tabela(s) com tenant_id: %\n'
      'Toda tabela com tenant_id precisa de `enable row level security`. Sem exceção.',
      sem_rls;
  end if;

  -- ── Regra 2 ───────────────────────────────────────────────────────────────
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ' order by c.relname)
    into sem_policy
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where c.relkind = 'r'
     and n.nspname = 'public'
     and c.relrowsecurity
     and not exists (select 1 from pg_policy p where p.polrelid = c.oid);

  if sem_policy is not null then
    raise exception
      E'RLS habilitada sem nenhuma policy em: %\n'
      'A tabela está negando todo acesso. Crie a policy ou remova a tabela.',
      sem_policy;
  end if;

  raise notice 'RLS: todas as tabelas com tenant_id estão protegidas e com policy.';
end $$;
