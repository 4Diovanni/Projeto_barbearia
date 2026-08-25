# Design: Monorepo Turborepo + pnpm (Issue #18)

**Épico:** #12 · **Fase 1** · Ref: `docs/gk-barber-arquitetura.md` §3.1, §10
**Issue:** https://github.com/4Diovanni/Projeto_barbearia/issues/18
**Branch:** `chore/monorepo-turborepo-pnpm`

## Objetivo

Um `pnpm install` na raiz e `pnpm turbo run build lint test typecheck` verde. Base sem a qual
nenhuma outra issue do épico #12 tem onde morar.

## Escopo

Entrega única (uma PR) cobrindo:

1. Esqueleto do workspace (pnpm + turborepo)
2. `packages/config` — ESLint e tsconfig compartilhados
3. `packages/core` — regra de negócio pura, zero dependência de framework, com TDD
4. `apps/web` — scaffold Next.js via `create-next-app` + `shadcn/ui`
5. `.env.example`

Fora de escopo (fica para issues futuras do épico #12):

- Configuração do Playwright / testes E2E (job `e2e` do CI permanece desligado até existir
  `apps/web/playwright.config.*`)
- `apps/mobile` (Expo) — outra issue
- Qualquer regra de negócio real dentro de `packages/core` além do placeholder de versão
- Modificação de `.github/workflows/ci.yml` — **não é necessária**. O job `detect` já liga os
  jobs `quality`, `test`, `build-web` dinamicamente assim que os arquivos correspondentes
  aparecem no repo (`package.json`, `apps/web/package.json`). Confirmado lendo o workflow atual.

## Estrutura de diretórios

```
projeto_barbearia/
├── package.json                    # raiz, private, packageManager: pnpm@9.15.9
├── pnpm-workspace.yaml             # apps/*, packages/*
├── turbo.json                      # tasks: build, lint, typecheck, test
├── tsconfig.base.json
├── .nvmrc                          # 22
├── .env.example
├── packages/
│   ├── config/
│   │   ├── package.json            # @gk/config
│   │   ├── eslint/index.js
│   │   └── tsconfig/base.json
│   └── core/
│       ├── package.json            # @gk/core — zero deps de framework
│       ├── vitest.config.ts
│       └── src/
│           ├── index.ts            # export const CORE_VERSION = "0.1.0"
│           └── index.test.ts
└── apps/
    └── web/                        # pnpm create next-app@latest + shadcn init
```

## Sequência de execução (TDD)

1. Esqueleto do workspace: `package.json` raiz, `pnpm-workspace.yaml`, `turbo.json`,
   `tsconfig.base.json`, `.nvmrc`.
2. `packages/config` (eslint + tsconfig compartilhados) e `packages/core/package.json`.
3. Escrever `packages/core/src/index.test.ts` — teste que falha (`Cannot resolve "./index"`).
4. Rodar `pnpm --filter @gk/core test` → **FAIL** confirmado antes de implementar.
5. Implementação mínima: `packages/core/src/index.ts` com `CORE_VERSION = "0.1.0"`.
6. Rodar de novo → **PASS**.
7. Scaffold `apps/web` via `pnpm create next-app@latest apps/web --typescript --tailwind --app
   --eslint --src-dir --import-alias "@/*"`, depois `pnpm dlx shadcn@latest init` dentro de
   `apps/web`.
8. `.env.example` com `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`,
   `SUPABASE_SERVICE_ROLE_KEY` (comentado como server-side apenas).
9. Rodar `pnpm turbo run build lint test typecheck` na raiz → tudo verde.
10. Commit na branch `chore/monorepo-turborepo-pnpm`.

## Decisões técnicas travadas

| Decisão | Valor | Motivo |
| --- | --- | --- |
| `packageManager` | `pnpm@9.15.9` | Última da linha 9.x — o que a issue especifica (pnpm já vai na 11.x, mas isso não foi validado contra a arquitetura documentada) |
| Next.js | 15.x | `docs/gk-barber-arquitetura.md` §3.1 — Server Components, App Router |
| React | 19.x | Requisito do Next 15 |
| Node | 22 (`.nvmrc`) | Igual ao `NODE_VERSION` do `ci.yml` |
| Estilo | Tailwind CSS + shadcn/ui | §3.1 — componentes copiados para o repo, não dependência opaca |
| Testes unitários | Vitest | §3.1 |
| `ci.yml` | Sem alteração | Já é dinâmico via job `detect` |

## Workflow Git/CI

- Branch: `chore/monorepo-turborepo-pnpm` (já criada a partir de `main`)
- Commit(s) seguindo conventional commits, ex.: `chore: estrutura do monorepo com turborepo,
  pnpm e packages/core`
- PR para `main` referenciando `Closes #18`
- Pós-abertura: acompanhar `gh pr checks` até a pipeline concluir; investigar e corrigir
  qualquer falha antes de pedir revisão

## Critérios de aceite

- [ ] `pnpm install` na raiz resolve todos os workspaces sem warning de peer dependency quebrada
- [ ] `pnpm turbo run build lint test typecheck` 100% verde
- [ ] `packages/core/package.json` **não** tem React, Next, Supabase nem framework em `dependencies`
- [ ] `.env` no `.gitignore` (já está) e `.env.example` commitado
- [ ] CI verde no PR
