# GK-Barber

Sistema de agendamento para barbearias — monorepo Turborepo + pnpm.

## Pré-requisitos

- Node `>=22` (veja `.nvmrc`)
- pnpm via [corepack](https://nodejs.org/api/corepack.html)

## Setup

```bash
corepack enable
corepack prepare pnpm@9.15.9 --activate
pnpm install
```

Copie o arquivo de variáveis de ambiente e preencha os valores do Supabase:

```bash
cp .env.example apps/web/.env.local
```

## Scripts

| Script           | Descrição                                |
| ---------------- | ---------------------------------------- |
| `pnpm build`     | Build de todos os workspaces (Turborepo) |
| `pnpm lint`      | Lint de todos os workspaces              |
| `pnpm test`      | Testes de todos os workspaces            |
| `pnpm typecheck` | Checagem de tipos de todos os workspaces |
| `pnpm format`    | Formata o repositório com Prettier       |

## Estrutura do workspace

| Pacote            | Descrição                                       |
| ----------------- | ----------------------------------------------- |
| `apps/web`        | Next.js — painel + agenda pública               |
| `packages/core`   | `@gk/core` — regra de negócio pura              |
| `packages/config` | `@gk/config` — ESLint e tsconfig compartilhados |

Para a arquitetura completa do projeto, veja [`docs/gk-barber-arquitetura.md`](docs/gk-barber-arquitetura.md).
