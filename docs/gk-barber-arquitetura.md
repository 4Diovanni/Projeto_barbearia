# GK-Barber — Arquitetura do Produto

> Documento de arquitetura e plano de implementação.
> Status: **draft v1** · Última revisão: 2026-08-15

---

## 1. O Conceito

**GK-Barber** é um sistema de gestão para barbearias, vendido **localmente e por licença direta** — o barbeiro compra o software, não uma assinatura de marketplace. Nenhum centavo da transação entre barbeiro e cliente passa pela plataforma.

Três princípios inegociáveis guiam todas as decisões abaixo:

| Princípio | O que significa na prática |
|---|---|
| **Sem intermediação financeira** | O app **organiza e registra** dinheiro, nunca o **processa**. Sem gateway, sem split, sem taxa, sem conta de pagamento. O PIX é direto na chave do barbeiro. |
| **Customizável por barbeiro** | Cada instalação liga/desliga módulos via *feature flags*, com logo, cores e nome próprios. Um código-base, N configurações. |
| **Intuitivo antes de completo** | O usuário-alvo é um barbeiro com o celular numa mão e a máquina na outra. Se um fluxo precisa de treinamento, o fluxo está errado. |

---

## 2. Visão Geral

O produto tem **três superfícies** distintas, com públicos e necessidades diferentes:

```
┌─────────────────────────┐   ┌─────────────────────────┐   ┌─────────────────────────┐
│   PAINEL DO BARBEIRO    │   │   AGENDA PÚBLICA        │   │   APP DO BARBEIRO       │
│   (Next.js · web)       │   │   (Next.js · rota /b/)  │   │   (Expo · iOS/Android)  │
├─────────────────────────┤   ├─────────────────────────┤   ├─────────────────────────┤
│ Dashboard de lucros     │   │ Sem login (OTP no fim)  │   │ Agenda do dia           │
│ Configuração de horários│   │ Escolhe serviço/horário │   │ Check-in / finalizar    │
│ Financeiro e comissões  │   │ Vê o QR PIX do sinal    │   │ Push de novo agendamento│
│ Clientes e pacotes      │   │ Recebe confirmação zap  │   │ Contato rápido c/ cliente│
│ Relatórios e metas      │   │ Link p/ bio do Instagram│   │ Modo offline (balcão)   │
└───────────┬─────────────┘   └───────────┬─────────────┘   └───────────┬─────────────┘
            │                             │                             │
            └─────────────────────────────┼─────────────────────────────┘
                                          ▼
                        ┌──────────────────────────────────┐
                        │           SUPABASE               │
                        │  Postgres + RLS · Auth · Storage │
                        │  Realtime · Edge Functions (Deno)│
                        └────────────────┬─────────────────┘
                                         │
                    ┌────────────────────┼────────────────────┐
                    ▼                    ▼                    ▼
            WhatsApp Cloud API      Gerador BR Code      pg_cron + pg_net
            (lembretes oficiais)    (QR PIX estático)    (jobs de lembrete)
```

---

## 3. Stack Tecnológica

### 3.1 Linguagem do frontend — a recomendação

**TypeScript**, sem hesitação, em **100% do stack**.

O motivo não é preferência estética. É que o Supabase gera tipos TypeScript diretamente do schema Postgres (`supabase gen types typescript`). Com isso, **uma coluna renomeada no banco quebra o build do app na hora**, não em produção às 19h de sexta com a barbearia cheia. As Edge Functions do Supabase também rodam Deno (TypeScript), então o mesmo tipo `Appointment` percorre o caminho inteiro — do `CREATE TABLE` até o botão na tela — sem uma única reescrita manual.

| Camada | Escolha | Por quê |
|---|---|---|
| **Web** (painel + agenda pública) | **Next.js 15** (App Router) + React 19 | Server Components deixam o dashboard rápido mesmo em 4G ruim; a agenda pública precisa de SSR para carregar instantâneo e ser indexável pelo Google ("barbearia + bairro"). |
| **Mobile** | **Expo** (React Native) + Expo Router | Mesma linguagem, mesma lógica de negócio, mesmos devs. Expo Router usa roteamento por arquivos igual ao Next — a troca de contexto entre os dois apps é quase zero. OTA update via EAS entrega correção sem passar pela loja. |
| **Estilo (web)** | Tailwind CSS + shadcn/ui | Componentes copiados para dentro do repo, não uma dependência opaca. Customização por barbearia vira troca de token CSS. |
| **Estilo (mobile)** | NativeWind | Mesmas classes Tailwind no React Native, mesmos tokens de design. |
| **Estado de servidor** | TanStack Query | Cache, revalidação, *optimistic update* e — crucial — fila offline no balcão. |
| **Formulários + validação** | React Hook Form + **Zod** | O mesmo schema Zod valida no cliente, na Edge Function e vira o tipo TypeScript. Uma fonte de verdade. |
| **Datas** | date-fns + date-fns-tz | Agenda é 90% manipulação de fuso e duração. Ver §6.2 — é onde sistemas de agendamento morrem. |
| **Testes** | Vitest + Testing Library + Playwright | Playwright cobre o fluxo público de agendamento ponta a ponta. |
| **Monorepo** | Turborepo + pnpm | Cache de build e código compartilhado entre web e mobile sem publicar pacote em registry. |

> **Sobre UI universal (Tamagui / Solito):** avaliado e **descartado**. A promessa de "escreva o componente uma vez, rode nos dois" cobra caro em configuração e em bugs difíceis de diagnosticar. A decisão aqui é **compartilhar lógica, não pixels**: hooks, schemas, regras de negócio e tipos são 100% compartilhados; a camada visual é nativa de cada plataforma. É mais código de UI e muito menos sofrimento.

### 3.2 Backend — Supabase

| Recurso | Uso no GK-Barber |
|---|---|
| **Postgres + RLS** | Núcleo de tudo. O isolamento entre barbearias é garantido **no banco**, não no código do app. |
| **Auth** | Barbeiro/equipe por e-mail+senha ou magic link. Cliente final por **OTP de telefone** (não obrigamos ninguém a criar senha para marcar um corte). |
| **Storage** | Logo da barbearia, fotos de portfólio, fotos antes/depois na ficha do cliente, recibos em PDF. |
| **Realtime** | A agenda atualiza sozinha em todas as telas. Dois barbeiros no balcão nunca veem estados diferentes. |
| **Edge Functions** (Deno) | Geração do QR PIX, webhook e envio do WhatsApp, geração de PDF, relatórios pesados. Tudo que precisa de segredo fica aqui. |
| **pg_cron + pg_net** | Disparo dos lembretes ("amanhã às 14h") sem precisar de servidor extra ligado. |

---

## 4. Modelo de Distribuição

Você respondeu que a transação é **local, direto com o barbeiro, sem SaaS**. Isso define duas coisas diferentes que vale separar, porque elas são frequentemente confundidas:

**O dinheiro do corte** → nunca toca a plataforma. Cliente paga o barbeiro via PIX direto (ou dinheiro/cartão na maquininha dele). O app apenas **registra** que foi pago.

**A hospedagem do software** → aqui a recomendação é **multi-tenant mesmo assim**. Um único projeto Supabase servindo todas as barbearias, isoladas por `tenant_id` + RLS.

Por que multi-tenant se não é SaaS? Porque é o que torna as *feature flags* que você pediu realmente viáveis. Com uma instância Supabase por barbearia, cada correção de bug vira N deploys manuais, N migrations rodadas na mão, N chances de errar — inviável a partir de ~10 clientes, e é aí que o produto começa a dar dinheiro. Multi-tenant, você corrige uma vez e todos recebem, e ligar um módulo para um barbeiro específico é um `UPDATE` numa linha.

A licença permanece uma venda local e direta: **o barbeiro te paga fora do app** (PIX seu, contrato, o que for). O sistema só guarda uma data de validade da licença. Sem billing, sem cartão, sem cobrança automática dentro do produto.

> **Escape hatch:** o schema já nasce preparado para *instância dedicada*. Se um cliente grande exigir banco isolado, é o mesmo código apontando para outro projeto Supabase — sem refatoração, porque o `tenant_id` continua lá.

---

## 5. Módulos do Produto

Os 7 tópicos originais, mapeados para módulos reais — cada um com sua *feature flag*.

### 5.1 Agendas Múltiplas para toda a equipe · `agenda.multi_profissional`
- Cada profissional tem agenda, horário de trabalho e serviços próprios (nem todo barbeiro faz barba, nem todo faz química).
- Visões: **dia** (colunas por profissional), **semana**, **lista** (a preferida no celular).
- Recursos compartilhados: cadeiras, lavatório — impede agendar 3 clientes para 2 cadeiras.
- Bloqueios: almoço, folga, feriado, atestado, "hoje saio às 16h".
- Drag & drop para remarcar, com aviso automático ao cliente.

### 5.2 Agendamento Online para o cliente · `agenda.publica`
- Rota pública `gkbarber.app/b/{slug}` — o link que vai na bio do Instagram e no status do WhatsApp.
- Fluxo em 4 toques: **serviço → profissional (ou "tanto faz") → horário → confirmar**.
- Sem cadastro. Nome + telefone, confirmado por OTP no WhatsApp. Cliente recorrente é reconhecido pelo número.
- Motor de disponibilidade respeita duração do serviço, intervalo de limpeza, antecedência mínima ("não aceita agendamento para daqui a 10 minutos") e janela máxima ("não abre agenda além de 60 dias").
- **Fila de espera**: cliente entra na fila de um horário lotado e é avisado automaticamente se vagar.

### 5.3 Pagamento via PIX na Agenda · `pagamento.pix_qr`

⚠️ **Leia esta seção inteira antes de implementar.** Aqui moram duas armadilhas.

**Como funciona:** ao confirmar o agendamento, uma Edge Function gera um **BR Code** (payload EMV do PIX) com a chave do barbeiro e o valor do serviço, e devolve só a imagem/string do QR. O cliente escaneia e paga direto na conta do barbeiro.

**Armadilha 1 — "chave escondida" tem limite técnico.**
O payload EMV do PIX **carrega a chave em texto claro** (campo `26-01`). Qualquer pessoa que escaneie o QR **vai ver a chave no app do banco** — é assim que o PIX funciona, e nenhum sistema muda isso. O que é possível e o que faremos:

| Proteção | Viável? |
|---|---|
| Não exibir a chave em nenhuma tela do app | ✅ Sim |
| Não expor a chave em nenhuma resposta de API pública | ✅ Sim |
| Guardar cifrada no banco (Supabase Vault / pgsodium), nunca em texto | ✅ Sim |
| Gerar o QR **exclusivamente no servidor** (a chave nunca chega ao navegador) | ✅ Sim |
| Impedir que quem escaneia descubra a chave | ❌ **Impossível** |

Se o objetivo real é a chave não ser pública, a saída correta é o barbeiro **cadastrar uma chave aleatória** (o PIX permite chaves EVP — um UUID sem relação com CPF ou telefone). Aí, mesmo visível, ela não revela dado pessoal nenhum. **Essa é a recomendação: exigir chave aleatória no onboarding.**

**Armadilha 2 — sem gateway, não existe baixa automática.**
Nada avisa o sistema de que o PIX caiu. O fluxo real, então:

1. Cliente escaneia e paga.
2. Cliente anexa o comprovante no app (opcional, mas incentivado).
3. Barbeiro confere na conta dele e marca **"Recebido"** com um toque.
4. Só então o agendamento vira `pago`.

O status default é `aguardando_confirmacao`, e o dashboard mostra um badge de pendências. **Não invente confirmação automática** — vai gerar prejuízo real. Se um dia houver volume que justifique, um adapter de gateway (Asaas/Mercado Pago) entra sem quebrar nada, porque o registro de pagamento já é uma entidade própria.

- **Sinal antecipado** configurável (ex.: 30% para segurar o horário) — a arma real contra *no-show*.

### 5.4 Monitoramento de Pacotes · `pacotes`
- Venda de pacotes: "10 cortes por R$ 250", "Corte + Barba mensal".
- Saldo de sessões por cliente, consumo automático ao finalizar o atendimento, validade e alerta de expiração.
- Cliente vê o saldo na página pública; barbeiro vê no atendimento.
- **Financeiramente correto:** a receita entra no caixa **na venda**, mas o *reconhecimento* por sessão é rastreado à parte — senão o relatório mente sobre o faturamento do mês.

### 5.5 Controle Financeiro Detalhado · `financeiro`
- Caixa diário: abertura, sangria, fechamento, conferência.
- Entradas (serviços, produtos, pacotes) e saídas (aluguel, insumos, energia, comissão).
- **Comissão por barbeiro**: percentual fixo, valor fixo por serviço, ou escalonado por faixa de faturamento. Fechamento e recibo automáticos.
- Formas de pagamento: dinheiro, PIX, débito, crédito, pacote, fiado.
- **Taxa de maquininha** por bandeira — o lucro real só aparece descontando isso.
- DRE simplificado mensal, comparativo mês a mês.

### 5.6 Emissão de Carnês · `financeiro.carne`

⚠️ **Ajuste de escopo necessário.** *Boleto bancário registrado* exige convênio com banco ou gateway — incompatível com "sem intermediação". O que o módulo entrega de verdade:

- **Carnê de parcelas**: um valor dividido em N parcelas com vencimentos (ex.: pacote anual em 12x).
- Cada parcela gera **seu próprio QR PIX** com o valor exato.
- **PDF do carnê** com todas as parcelas e QR Codes, imprimível ou enviável pelo WhatsApp.
- Régua de cobrança automática: lembrete 3 dias antes, no dia, e aviso de atraso.
- Recibo em PDF a cada baixa.

Na prática do balcão isso resolve o mesmo problema que o carnê de boleto — parcelar e cobrar — sem exigir banco. Se boleto registrado virar requisito de venda, entra depois via adapter (Asaas emite carnê nativamente).

### 5.7 Lembretes e Confirmações via WhatsApp · `whatsapp`
- **WhatsApp Business Cloud API oficial** (Meta) — decisão correta para produto pago. Client não-oficial (Baileys/Evolution) tem risco real de banir o número do seu cliente, e o problema vira seu.
- Templates aprovados: confirmação de agendamento, lembrete 24h/2h antes, cancelamento, aniversário, retorno ("faz 45 dias").
- **Confirmação interativa**: botões *Confirmar* / *Remarcar* / *Cancelar*. A resposta cai no webhook e atualiza a agenda sozinha.
- Envio agendado via `pg_cron`, com fila e retry — mensagem que falha não some silenciosamente.
- Opt-out obrigatório (LGPD).

---

## 6. O que adiciono ao escopo

Módulos que fazem sentido no contexto e aumentam o valor de venda:

### 6.1 Diferenciais de produto
1. **Ficha completa do cliente** — histórico, preferências ("máquina 2 nas laterais", "não gosta de navalha"), alergias a química, fotos antes/depois no Storage, aniversário. É o que faz o cliente sentir que o barbeiro lembra dele.
2. **Anti no-show** — score de faltas por cliente, exigência de sinal para reincidentes, bloqueio após N faltas.
3. **Fidelidade** — "a cada 10 cortes, o 11º é grátis", com cartão digital na página pública.
4. **Estoque e venda de produtos** — pomada, minoxidil, shampoo. Baixa automática, alerta de estoque mínimo, margem por produto.
5. **Campanhas de reativação** — lista automática de quem não aparece há X dias + disparo WhatsApp em lote. A funcionalidade com maior ROI direto do sistema inteiro.
6. **NPS pós-atendimento** — nota via WhatsApp; avaliação alta vira convite para avaliar no Google.
7. **Metas e ranking da equipe** — meta mensal por barbeiro, barra de progresso, ranking interno. Gamificação funciona muito bem nesse público.
8. **Multi-unidade** — filiais sob a mesma marca, com consolidado. Já contemplado no schema desde o dia 1.
9. **Modo offline no balcão** — PWA com fila de sincronização. Internet de barbearia cai, e o corte não pode parar.
10. **White-label** — logo, cor primária, nome e domínio próprio por barbearia. É literalmente o argumento de venda "é o seu app".

### 6.2 Dashboard de lucros — o que realmente mostrar

Você pediu "visão de lucros". Faturamento bruto é a métrica menos útil. O painel abre com:

| Bloco | Métrica |
|---|---|
| **Topo** | Faturamento do mês · Lucro líquido (bruto − comissões − despesas − taxas) · Ticket médio · vs. mês anterior |
| **Ocupação** | % da agenda preenchida por dia/profissional. Revela o buraco: **quais horários estão mortos** |
| **Retenção** | % de clientes que voltaram em 60 dias · quantos sumiram · frequência média de retorno |
| **Ranking** | Faturamento e ocupação por barbeiro · serviços mais lucrativos (não os mais vendidos — os mais lucrativos) |
| **Alertas** | Pagamentos pendentes · parcelas vencidas · pacotes expirando · estoque baixo · clientes sumidos |

> Todo gráfico responde a uma pergunta que muda uma decisão. Se não muda, não entra no dashboard.

---

## 7. Modelo de Dados

Tabelas centrais (nomes em inglês no banco, UI em pt-BR):

```sql
-- ══ TENANT & ACESSO ══
tenants                 -- barbearia: slug, nome, logo, cores, timezone, licença
tenant_members          -- usuário ↔ tenant, com role (owner|manager|barber|receptionist)
units                   -- filiais
professionals           -- barbeiro: vinculado a um user, comissão, cor na agenda
professional_schedules  -- grade semanal de trabalho
schedule_exceptions     -- folgas, feriados, bloqueios pontuais

-- ══ CATÁLOGO ══
services                -- nome, duração, preço, buffer de limpeza, cor
service_professionals   -- quem executa o quê (e por qual preço, se variar)
resources               -- cadeiras, lavatório
products                -- estoque para revenda
packages                -- pacotes de sessões

-- ══ AGENDA ══
customers               -- nome, telefone, preferências, score de no-show, opt-in whatsapp
appointments            -- ⭐ núcleo do sistema
appointment_services    -- múltiplos serviços num mesmo atendimento
waitlist                -- fila de espera
customer_packages       -- saldo de pacotes por cliente
package_usages          -- consumo de sessão

-- ══ FINANCEIRO ══
cash_sessions           -- caixa: abertura/fechamento
transactions            -- entradas e saídas
payments                -- pagamento vinculado a atendimento/parcela
pix_charges             -- BR Code gerado, valor, txid, status
installment_plans       -- carnê
installments            -- parcelas do carnê
commissions             -- apuração por barbeiro

-- ══ COMUNICAÇÃO ══
message_templates       -- templates aprovados na Meta
message_queue           -- fila de envio com retry
message_logs            -- auditoria de entrega
reviews                 -- NPS

-- ══ PLATAFORMA ══
feature_flags           -- catálogo de flags
tenant_features         -- override por barbearia (+ config jsonb)
audit_logs              -- quem fez o quê, quando
```

### 7.1 A tabela que decide tudo

```sql
create table appointments (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  unit_id       uuid references units(id),
  professional_id uuid not null references professionals(id),
  customer_id   uuid not null references customers(id),

  -- ⚠️ intervalo, não duas colunas soltas: habilita a constraint abaixo
  slot          tstzrange not null,

  status        appointment_status not null default 'scheduled',
  -- scheduled | confirmed | in_progress | completed | no_show | cancelled

  total_amount  numeric(10,2) not null default 0,
  deposit_amount numeric(10,2) default 0,
  source        text not null default 'internal',  -- internal | online | whatsapp
  notes         text,
  created_at    timestamptz not null default now(),

  -- ⭐ IMPEDE DUPLA MARCAÇÃO NO NÍVEL DO BANCO.
  -- Nenhuma corrida entre dois clientes clicando ao mesmo tempo passa daqui.
  constraint no_double_booking exclude using gist (
    professional_id with =,
    slot            with &&
  ) where (status not in ('cancelled', 'no_show'))
);

create index on appointments (tenant_id, slot);
create index on appointments (tenant_id, professional_id, status);
```

> **Por que a exclusion constraint importa tanto:** validar disponibilidade no frontend é teatro. Dois clientes abrindo o mesmo horário no mesmo segundo passam por qualquer verificação em JavaScript. Só o banco resolve isso de verdade. Requer `create extension btree_gist;`.

### 7.2 Fuso horário — a causa nº 1 de bug em agenda

Regras, sem exceção:

- **Armazenar sempre `timestamptz` em UTC.** Nunca `timestamp` puro, nunca string.
- **Cada tenant tem seu `timezone`** (`America/Sao_Paulo` por padrão) — porque o produto vai ser vendido em outros estados.
- **Converter só na borda de exibição.** Toda lógica interna roda em UTC.
- A grade de trabalho é *hora local* (`09:00`–`19:00`); a conversão para UTC acontece **por data**, não uma vez só. Horário de verão pode voltar, e código que assume offset fixo quebra em silêncio.

---

## 8. Segurança e Multi-tenancy

### 8.1 RLS é a fronteira — não o código do app

Toda tabela com `tenant_id` tem RLS habilitada. **Nenhuma exceção**, nem em tabela auxiliar: um único `select` sem política é um vazamento de dados de outra barbearia.

```sql
-- Função auxiliar: STABLE + SECURITY DEFINER para o planner cachear por statement
create or replace function auth.user_tenants()
returns setof uuid
language sql stable security definer set search_path = '' as $$
  select tenant_id from public.tenant_members
  where user_id = (select auth.uid())
$$;

alter table appointments enable row level security;

create policy "membros acessam a própria barbearia"
  on appointments for all
  using  (tenant_id in (select auth.user_tenants()))
  with check (tenant_id in (select auth.user_tenants()));
```

> **Detalhe de performance:** use `(select auth.uid())` e não `auth.uid()` direto. Envolto em subquery, o Postgres avalia **uma vez por statement** em vez de uma vez por linha — a diferença aparece rápido numa agenda com milhares de registros.

### 8.2 Agenda pública sem vazar a base de clientes

A página pública precisa mostrar horários livres **sem** expor nome, telefone ou histórico de ninguém. A solução não é uma policy permissiva — é **nunca dar acesso direto à tabela**:

- Uma função `security definer` (`get_available_slots(tenant_slug, service_id, date)`) devolve **apenas horários vagos**. O anônimo lê a função, jamais a tabela.
- A criação do agendamento passa por Edge Function que valida, verifica o OTP e aplica rate limit por IP e por telefone.
- `service_role key` **jamais** sai do servidor. Nem em variável `NEXT_PUBLIC_`, nem em app Expo (bundle de mobile é lido trivialmente).

### 8.3 Segredos

| Dado | Onde vive |
|---|---|
| Chave PIX do barbeiro | Cifrada no Supabase Vault. Decifrada só dentro da Edge Function que monta o BR Code. |
| Token WhatsApp Cloud API | Secret da Edge Function. Nunca no cliente. |
| `service_role key` | Só em Edge Function / server-side do Next. |
| Senhas | Supabase Auth. Não reinventar. |

### 8.4 LGPD
Consentimento explícito para WhatsApp (com opt-out em toda mensagem) · exportação dos dados do cliente · exclusão com anonimização (preserva o histórico financeiro, apaga o dado pessoal) · `audit_logs` de acesso a dado sensível · política de privacidade acessível na página pública.

---

## 9. Feature Flags — a customização por barbeiro

O mecanismo que sustenta "customizável conforme o barbeiro".

```sql
create table feature_flags (
  key         text primary key,          -- 'financeiro.carne'
  name        text not null,
  description text,
  default_enabled boolean not null default false,
  tier        text not null default 'basic'  -- basic | pro | premium
);

create table tenant_features (
  tenant_id uuid references tenants(id) on delete cascade,
  key       text references feature_flags(key) on delete cascade,
  enabled   boolean not null,
  config    jsonb not null default '{}',   -- limites, percentuais, textos
  primary key (tenant_id, key)
);
```

**Resolução em cascata:** `tenant_features.enabled` → senão `tier` do plano contratado → senão `default_enabled`.

**Consumo, idêntico em web e mobile:**

```tsx
const carne = useFeature('financeiro.carne');
if (!carne.enabled) return <UpsellCard feature="carne" />;
// carne.config.max_parcelas → 12
```

Três regras que evitam que isso vire um pesadelo:

1. **A flag nunca protege só a UI.** Esconder o botão e deixar a rota aberta não é feature flag, é decoração. A checagem também roda na Edge Function / policy.
2. **Toda flag tem data de morte.** Ou vira padrão, ou é removida. Flag esquecida é dívida técnica que se multiplica — cada uma dobra os caminhos de código a testar.
3. **`config` em jsonb** carrega os parâmetros (limite de parcelas, % de sinal, dias de antecedência). Assim o barbeiro é customizado **sem branch de código**.

Flags iniciais: `agenda.multi_profissional` · `agenda.publica` · `agenda.fila_espera` · `pagamento.pix_qr` · `pagamento.sinal` · `pacotes` · `financeiro` · `financeiro.comissao` · `financeiro.carne` · `whatsapp` · `whatsapp.campanhas` · `estoque` · `fidelidade` · `nps` · `multi_unidade` · `white_label`

---

## 10. Estrutura de Diretórios

```text
gk-barber/
│
├── apps/
│   ├── web/                      # Next.js 15 — painel + agenda pública (PWA)
│   │   ├── app/
│   │   │   ├── (dashboard)/      # painel autenticado do barbeiro
│   │   │   │   ├── agenda/
│   │   │   │   ├── clientes/
│   │   │   │   ├── financeiro/
│   │   │   │   ├── relatorios/
│   │   │   │   └── configuracoes/
│   │   │   ├── b/[slug]/         # agenda pública (SSR, sem login)
│   │   │   └── api/
│   │   └── public/manifest.json  # PWA
│   │
│   └── mobile/                   # Expo — app do barbeiro
│       └── app/                  # Expo Router (file-based, igual ao Next)
│
├── packages/
│   ├── core/                     # ⭐ domínio puro, zero dependência de framework
│   │   ├── scheduling/           # motor de disponibilidade e conflitos
│   │   ├── pricing/              # preços, descontos, pacotes
│   │   ├── commission/           # cálculo de comissão
│   │   └── pix/                  # gerador de BR Code (EMV + CRC16)
│   ├── db/                       # tipos gerados do Supabase + queries tipadas
│   ├── flags/                    # SDK de feature flags
│   ├── ui/                       # design system web (shadcn + tokens)
│   ├── ui-native/                # componentes Expo (NativeWind, mesmos tokens)
│   └── config/                   # eslint, tsconfig, tailwind preset
│
├── supabase/
│   ├── migrations/               # versionadas, sempre no git
│   ├── functions/                # Edge Functions (Deno)
│   │   ├── pix-generate/
│   │   ├── whatsapp-webhook/
│   │   ├── whatsapp-send/
│   │   ├── booking-create/       # criação pública com OTP + rate limit
│   │   └── reports/
│   └── seed.sql
│
├── docs/
│   └── gk-barber-arquitetura.md  # este arquivo
│
├── .github/workflows/            # CI já configurado
├── turbo.json
├── pnpm-workspace.yaml
└── .env.example                  # ⚠️ nunca commitar .env real
```

> **`packages/core` é o ativo mais valioso do repo.** Regra de negócio pura, sem React, sem Supabase, sem `window` — testável em milissegundos e reutilizável em qualquer superfície. Se o Next.js sair de moda em 3 anos, essa pasta sobrevive intacta.

---

## 11. Roadmap

**Fase 1 — A Base (semanas 1–3)**
Monorepo · schema + RLS + exclusion constraint · Auth · CRUD de serviços, profissionais e horários · agenda interna funcionando. *Entregável: o barbeiro já consegue substituir o caderno.*

**Fase 2 — O Cliente Chega (semanas 4–6)**
Agenda pública `/b/{slug}` · motor de disponibilidade · OTP por telefone · ficha do cliente · PWA instalável. *Entregável: link compartilhável na bio do Instagram.*

**Fase 3 — O Dinheiro (semanas 7–9)**
Caixa · transações · comissões · gerador de QR PIX (com confirmação manual) · dashboard de lucros. *Entregável: o barbeiro vê quanto realmente lucrou.*

**Fase 4 — A Retenção (semanas 10–12)**
WhatsApp Cloud API · lembretes automáticos · confirmação com botões · campanhas de reativação · NPS. *Entregável: queda mensurável de no-show — o argumento de venda mais forte.*

**Fase 5 — O App (semanas 13–15)**
Expo · agenda do dia · push nativo · check-in · modo offline · build EAS.

**Fase 6 — Escala Comercial (semanas 16+)**
Feature flags completas · white-label · pacotes e carnês · estoque · fidelidade · multi-unidade · console interno de licenças.

> **Ordem deliberada:** valor visível antes de infraestrutura. Ao fim da Fase 3 já existe produto vendável. Feature flags entram na Fase 6 porque antes disso não há clientes suficientes para justificar a complexidade — mas o `tenant_id` está no schema desde o dia 1, e é isso que torna a Fase 6 uma adição, não uma reescrita.

---

## 12. Decisões Registradas (ADR resumido)

| # | Decisão | Alternativa descartada | Razão |
|---|---|---|---|
| 1 | TypeScript em todo o stack | Kotlin/Swift nativo, Flutter | Tipos gerados do Postgres percorrem até a UI; um time, um idioma |
| 2 | Next.js + Expo separados | Tamagui/Solito universal | Compartilhar lógica é barato; compartilhar pixels é caro |
| 3 | Multi-tenant com RLS | Instância por barbearia | Manutenção linear é inviável; RLS isola no banco |
| 4 | PIX estático sem gateway | Asaas / Mercado Pago | Requisito explícito de zero intermediação financeira |
| 5 | Confirmação manual de pagamento | Baixa automática | Sem gateway não há webhook — automatizar aqui geraria prejuízo |
| 6 | Chave PIX aleatória (EVP) obrigatória | Chave CPF/telefone | O QR expõe a chave por design; EVP não revela dado pessoal |
| 7 | Carnê de parcelas com PIX | Boleto registrado | Boleto exige convênio bancário, incompatível com a decisão 4 |
| 8 | WhatsApp Cloud API oficial | Baileys / Evolution | Risco de banir o número do cliente é inaceitável em produto pago |
| 9 | Exclusion constraint contra double-booking | Validação na aplicação | Só o banco vence condição de corrida |
| 10 | Feature flags com `config` jsonb | Branch de código por cliente | Customização sem fork; um binário para todos |

---

## 13. Riscos Conhecidos

| Risco | Mitigação |
|---|---|
| Barbeiro esquece de dar baixa no PIX | Badge persistente de pendências no dashboard + resumo diário no WhatsApp dele |
| Aprovação de templates na Meta demora | Submeter os templates na Fase 3, antes de precisar deles na Fase 4 |
| Internet cai no balcão | PWA offline-first com fila de sincronização (Fase 5) |
| Cliente marca e não aparece | Sinal via PIX + confirmação 24h + score de no-show |
| Custo do WhatsApp escala | Monitorar custo/conversa por tenant; limite configurável por flag |
| RLS esquecida numa tabela nova | Teste automatizado no CI que falha se existir tabela com `tenant_id` e RLS desabilitada |
