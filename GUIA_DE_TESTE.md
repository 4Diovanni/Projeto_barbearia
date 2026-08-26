# Guia de Teste — Base do Monorepo (GK-Barber)

Guia para quem vai testar localmente a base do monorepo entregue na issue
[#18](https://github.com/4Diovanni/Projeto_barbearia/issues/18) — Turborepo + pnpm workspaces,
`packages/config`, `packages/core` e o scaffold do `apps/web`.

> **Antes de começar:** esse código ainda não está na `main` — está no
> [PR #65](https://github.com/4Diovanni/Projeto_barbearia/pull/65), branch
> `chore/monorepo-turborepo-pnpm`. O passo 2 abaixo faz o checkout dela. Depois que o PR for
> mergeado, o passo 2 deixa de ser necessário (a `main` já vem com o código).

## 1. Pré-requisitos

- [Git](https://git-scm.com/)
- [Node.js](https://nodejs.org/) `>=22` (o repositório fixa a versão em `.nvmrc`)
- [GitHub CLI](https://cli.github.com/) (`gh`) — opcional, só se for usar o passo 2 via PR

Não precisa instalar `pnpm` manualmente — o repositório usa
[Corepack](https://nodejs.org/api/corepack.html), que já vem com o Node e ativa a versão certa
do pnpm sozinho (passo 3).

## 2. Baixar o código

Se você já tem o repositório clonado:

```bash
git fetch origin
git checkout chore/monorepo-turborepo-pnpm
```

Se ainda não tem:

```bash
git clone https://github.com/4Diovanni/Projeto_barbearia.git
cd Projeto_barbearia
git checkout chore/monorepo-turborepo-pnpm
```

(Alternativa: `gh pr checkout 65` faz o mesmo, direto pelo número do PR.)

## 3. Ativar o pnpm e instalar as dependências

```bash
corepack enable
corepack prepare pnpm@9.15.9 --activate
pnpm install
```

Esperado: instala tudo sem erro. Nenhum warning de peer dependency quebrada.

## 4. (Opcional) variáveis de ambiente

Nada no código ainda usa isso — é só o placeholder para quando o Supabase for integrado (issue
futura). Só faça esse passo se quiser deixar já preparado:

```bash
cp .env.example apps/web/.env.local
```

## 5. Rodar a verificação completa

```bash
pnpm build lint test typecheck
```

Esperado: `Tasks: 7 successful, 7 total`. Isso builda o `apps/web`, roda lint em todos os
workspaces, os testes do `packages/core` e o typecheck geral.

## 6. Subir o app em modo desenvolvimento

```bash
pnpm --filter=./apps/web dev
```

Abra [http://localhost:3000](http://localhost:3000) — deve carregar a página inicial padrão do
Next.js (ainda sem nenhuma tela do GK-Barber — essa é só a base do monorepo, as telas reais vêm
em issues futuras).

Pare o servidor com `Ctrl+C`.

## 7. Comandos úteis para testar partes isoladas

- `pnpm --filter @gk/core test` — só os testes do `packages/core`
- `pnpm --filter @gk/core lint` — só o lint do `packages/core`
- `pnpm --filter=./apps/web build` — só o build de produção do `apps/web`
- `pnpm format` — formata o repositório inteiro com Prettier
- `pnpm format:check` — só verifica formatação, sem alterar arquivos

## 8. O que validar

- [ ] `pnpm install` termina sem erro e sem warning de peer dependency
- [ ] `pnpm build lint test typecheck` termina com os 7 tasks em sucesso
- [ ] `pnpm --filter=./apps/web dev` sobe o servidor e a página carrega em `localhost:3000`
- [ ] `packages/core/package.json` não tem nenhuma dependência de framework (React, Next,
      Supabase) — só `@gk/config` em `devDependencies`

## Problemas comuns

**`corepack: command not found`** — Node muito antigo ou instalação sem Corepack. Atualize o
Node para `>=22` (ou instale pnpm manualmente na versão `9.15.9`: `npm install -g pnpm@9.15.9`).

**Erro de rede durante `pnpm install`** — o comando `pnpm install --frozen-lockfile` (usado no
CI) falha se `pnpm-lock.yaml` estiver dessincronizado; rodar `pnpm install` sem essa flag (como
no passo 3) resolve na maioria dos casos.

**Porta 3000 já em uso** — outro processo já está rodando nela; encerre-o ou rode
`pnpm --filter=./apps/web dev -- -p 3001` para usar outra porta.
