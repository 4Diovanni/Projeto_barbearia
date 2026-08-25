# Monorepo Turborepo + pnpm Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar a base do monorepo GK-Barber (Turborepo + pnpm workspaces) com `packages/config`,
`packages/core` (TDD) e o scaffold do `apps/web` (Next.js 15 + shadcn/ui), fechando a issue #18.

**Architecture:** pnpm workspaces (`apps/*`, `packages/*`) orquestrados por Turborepo, com um
pacote `@gk/config` centralizando ESLint (flat config) e tsconfig compartilhados, e `@gk/core`
nascendo vazio (só a prova via TDD) como o lugar onde regra de negócio pura vai morar nas
próximas issues do épico #12. `apps/web` é um scaffold padrão do Next.js, sem wiring com
`@gk/core` ainda (fora de escopo desta issue).

**Tech Stack:** pnpm 9, Turborepo 2, TypeScript 5.9, Next.js 15.5 + React 19, Tailwind + shadcn/ui,
Vitest 2.1 + @vitest/coverage-v8, ESLint 9 (flat config) + typescript-eslint 8, Prettier 3.

## Global Constraints

- `packageManager` da raiz: `pnpm@9.15.9` (exato — é o que resolve o `corepack prepare`)
- Node: `>=22` (`.nvmrc` = `22`, igual ao `NODE_VERSION` do `ci.yml`)
- `packages/core/package.json` **não pode ter** React, Next, Supabase ou qualquer dependência de
  framework em `dependencies` — é o critério de aceite mais importante da issue #18
- Nenhuma alteração em `.github/workflows/ci.yml` ou `.github/actions/setup-workspace/action.yml`
  — ambos já funcionam dinamicamente
- Todo commit segue Conventional Commits (`chore:`, `feat:`, `docs:`, `test:`)
- `.env` real nunca é commitado (já garantido pelo `.gitignore` existente); só `.env.example`

---

### Task 1: Esqueleto do workspace (pnpm + Turborepo)

**Files:**
- Create: `package.json` (raiz)
- Create: `pnpm-workspace.yaml`
- Create: `turbo.json`
- Create: `tsconfig.base.json`
- Create: `.nvmrc`
- Create: `.prettierignore`

**Interfaces:**
- Consumes: nada — primeira task do projeto.
- Produces: scripts raiz `pnpm build|lint|test|typecheck|format|format:check` (delegam para
  `turbo run <task>`); `tsconfig.base.json` na raiz é a fonte canônica de `compilerOptions`
  estritas que `packages/config/tsconfig/base.json` (Task 2) reexporta.

- [ ] **Step 1: Ativar o pnpm via corepack**

```bash
corepack enable
corepack prepare pnpm@9.15.9 --activate
pnpm --version
```

Expected: imprime `9.15.9`.

- [ ] **Step 2: Criar `pnpm-workspace.yaml`**

```yaml
packages:
  - "apps/*"
  - "packages/*"
```

- [ ] **Step 3: Criar `turbo.json`**

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"]
    },
    "lint": {},
    "typecheck": {
      "dependsOn": ["^build"]
    },
    "test": {
      "dependsOn": ["^build"],
      "outputs": ["coverage/**"]
    },
    "//#format:check": {}
  }
}
```

Nota: `"//#format:check"` é a sintaxe do Turborepo para uma task que só existe no `package.json`
da raiz (o pseudo-workspace `//`). É isso que faz `pnpm turbo run format:check` (chamado pelo
`ci.yml`) rodar o Prettier do repo inteiro.

- [ ] **Step 4: Criar `tsconfig.base.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "moduleDetection": "force",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "isolatedModules": true,
    "resolveJsonModule": true,
    "noEmit": true
  }
}
```

- [ ] **Step 5: Criar `.nvmrc`**

```
22
```

- [ ] **Step 6: Criar `.prettierignore`**

```
node_modules
.turbo
.next
dist
coverage
pnpm-lock.yaml
apps/web/next-env.d.ts
```

- [ ] **Step 7: Criar `package.json` da raiz**

```json
{
  "name": "gk-barber",
  "private": true,
  "packageManager": "pnpm@9.15.9",
  "engines": {
    "node": ">=22"
  },
  "scripts": {
    "build": "turbo run build",
    "lint": "turbo run lint",
    "test": "turbo run test",
    "typecheck": "turbo run typecheck",
    "format": "prettier --write .",
    "format:check": "prettier --check ."
  },
  "devDependencies": {
    "prettier": "^3.9.6",
    "turbo": "^2.10.12",
    "typescript": "^5.9.3"
  }
}
```

- [ ] **Step 8: Instalar e verificar**

```bash
pnpm install
```

Expected: instala `turbo`, `typescript`, `prettier` na raiz sem erro. É esperado um aviso
`WARN no workspace packages found` ou similar já que `apps/*` e `packages/*` ainda estão vazios —
isso não é um erro (verifique que o comando termina com código de saída `0`).

- [ ] **Step 9: Commit**

```bash
git add package.json pnpm-workspace.yaml turbo.json tsconfig.base.json .nvmrc .prettierignore pnpm-lock.yaml
git commit -m "chore: esqueleto do workspace pnpm + turborepo"
```

---

### Task 2: `packages/config` — ESLint e tsconfig compartilhados

**Files:**
- Create: `packages/config/package.json`
- Create: `packages/config/eslint/index.js`
- Create: `packages/config/tsconfig/base.json`

**Interfaces:**
- Consumes: `tsconfig.base.json` da raiz (Task 1) — `packages/config/tsconfig/base.json` apenas
  reexporta esse arquivo, para não duplicar `compilerOptions`.
- Produces: pacote de workspace `@gk/config`, resolvível por `workspace:*`. Subpaths consumidos
  por outros pacotes:
  - `@gk/config/eslint/index.js` — `export default` de um array de configs ESLint flat config.
  - `@gk/config/tsconfig/base.json` — usado em `"extends"` de outros `tsconfig.json`.

- [ ] **Step 1: Criar `packages/config/package.json`**

```json
{
  "name": "@gk/config",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "dependencies": {
    "@eslint/js": "^9.39.5",
    "typescript-eslint": "^8.68.0"
  },
  "peerDependencies": {
    "eslint": "^9.0.0",
    "typescript": ">=5.0.0"
  }
}
```

- [ ] **Step 2: Criar `packages/config/eslint/index.js`**

```js
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default [
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    rules: {
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
    },
  },
];
```

- [ ] **Step 3: Criar `packages/config/tsconfig/base.json`**

```json
{
  "extends": "../../../tsconfig.base.json"
}
```

- [ ] **Step 4: Instalar e verificar que o workspace resolve**

```bash
pnpm install
pnpm list --filter @gk/config --depth -1
```

Expected: lista o pacote `@gk/config` em `packages/config`, sem erro de resolução.

- [ ] **Step 5: Verificar que a config ESLint carrega como um array válido**

```bash
node --input-type=module -e "import('./packages/config/eslint/index.js').then(m => { if (!Array.isArray(m.default)) throw new Error('não é array'); console.log('OK', m.default.length, 'entradas'); })"
```

Expected: imprime `OK <N> entradas` (sem lançar erro).

- [ ] **Step 6: Commit**

```bash
git add packages/config pnpm-lock.yaml
git commit -m "chore: packages/config com eslint e tsconfig compartilhados"
```

---

### Task 3: `packages/core` — TDD (regra de negócio pura)

**Files:**
- Create: `packages/core/package.json`
- Create: `packages/core/tsconfig.json`
- Create: `packages/core/vitest.config.ts`
- Create: `packages/core/eslint.config.js`
- Test: `packages/core/src/index.test.ts`
- Create: `packages/core/src/index.ts`

**Interfaces:**
- Consumes: `@gk/config/eslint/index.js` e `@gk/config/tsconfig/base.json` (Task 2), via
  `"@gk/config": "workspace:*"`.
- Produces: `export const CORE_VERSION: string` de `packages/core/src/index.ts` — é o único
  símbolo que este pacote exporta nesta issue. Issues futuras do épico #12 adicionam regra de
  negócio real aqui.

- [ ] **Step 1: Criar `packages/core/package.json`**

```json
{
  "name": "@gk/core",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": {
    "test": "vitest run",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@gk/config": "workspace:*"
  },
  "devDependencies": {
    "@vitest/coverage-v8": "^2.1.9",
    "eslint": "^9.39.5",
    "typescript": "^5.9.3",
    "vitest": "^2.1.9"
  }
}
```

- [ ] **Step 2: Criar `packages/core/tsconfig.json`**

```json
{
  "extends": "@gk/config/tsconfig/base.json",
  "compilerOptions": {
    "rootDir": "src"
  },
  "include": ["src"]
}
```

- [ ] **Step 3: Criar `packages/core/eslint.config.js`**

```js
import shared from "@gk/config/eslint/index.js";

export default [...shared, { ignores: ["dist/**", "coverage/**"] }];
```

- [ ] **Step 4: Criar `packages/core/vitest.config.ts`**

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      include: ["src/**/*.ts"],
      exclude: ["src/**/*.test.ts"],
    },
  },
});
```

- [ ] **Step 5: Instalar dependências do pacote**

```bash
pnpm install
```

Expected: resolve `@gk/config` via `workspace:*`, instala `vitest`, `@vitest/coverage-v8`,
`eslint` em `packages/core`. Sem warning de peer dependency quebrada.

- [ ] **Step 6: Escrever o teste que falha**

```ts
// packages/core/src/index.test.ts
import { describe, expect, it } from "vitest";
import { CORE_VERSION } from "./index";

describe("packages/core", () => {
  it("exporta a versão do domínio", () => {
    expect(CORE_VERSION).toBe("0.1.0");
  });
});
```

- [ ] **Step 7: Rodar e confirmar que falha**

```bash
pnpm --filter @gk/core test
```

Expected: FAIL — erro de resolução do módulo `./index` (arquivo `src/index.ts` ainda não existe).

- [ ] **Step 8: Implementação mínima**

```ts
// packages/core/src/index.ts
export const CORE_VERSION = "0.1.0";
```

- [ ] **Step 9: Rodar e confirmar que passa**

```bash
pnpm --filter @gk/core test
```

Expected: PASS — 1 test passou.

- [ ] **Step 10: Rodar lint e typecheck do pacote**

```bash
pnpm --filter @gk/core lint
pnpm --filter @gk/core typecheck
```

Expected: ambos terminam sem erro (código de saída `0`).

- [ ] **Step 11: Commit**

```bash
git add packages/core pnpm-lock.yaml
git commit -m "test: packages/core com TDD (CORE_VERSION)"
```

---

### Task 4: `apps/web` — scaffold Next.js 15 + shadcn/ui

**Files:**
- Create: `apps/web/` (gerado por `create-next-app`, não é conteúdo literal deste plano)
- Modify: `apps/web/package.json` (adicionar script `typecheck`)

**Interfaces:**
- Consumes: nada de `@gk/core`/`@gk/config` ainda — wiring fica para issues futuras do épico #12
  quando `apps/web` de fato importar regra de negócio de `@gk/core`.
- Produces: workspace `apps/web` com scripts `dev`, `build`, `lint`, `typecheck` — é o que os
  jobs `quality` e `build-web` do `ci.yml` esperam encontrar.

- [ ] **Step 1: Scaffold do Next.js (versão pinada em 15.5.24)**

```bash
CI=1 pnpm create next-app@15.5.24 apps/web \
  --typescript \
  --tailwind \
  --app \
  --eslint \
  --src-dir \
  --import-alias "@/*" \
  --use-pnpm
```

Expected: cria `apps/web/` com `package.json`, `tsconfig.json`, `next.config.ts`,
`eslint.config.mjs`, `src/app/page.tsx`, etc. `CI=1` evita qualquer prompt interativo (usa
defaults). Não usar `@latest` — hoje resolve Next 16, que diverge da arquitetura documentada
(Next 15 + React 19).

- [ ] **Step 2: shadcn/ui init**

```bash
cd apps/web
CI=1 pnpm dlx shadcn@latest init -y -d
cd ../..
```

Expected: cria `apps/web/components.json`, ajusta `apps/web/src/app/globals.css` com as
variáveis de tema shadcn, adiciona `apps/web/src/lib/utils.ts` (helper `cn`). `-y -d` pula
prompts e usa a configuração default (New York style, cor base neutra, CSS variables).

- [ ] **Step 3: Adicionar script `typecheck` ao `apps/web/package.json`**

Abra `apps/web/package.json` e adicione `"typecheck": "tsc --noEmit"` ao objeto `"scripts"`,
mantendo os scripts gerados (`dev`, `build`, `start`, `lint`) intactos. Não mexer em
`apps/web/tsconfig.json` nem em `apps/web/eslint.config.mjs` — ambos são gerados pelo Next com
configuração específica de framework (plugin do Next, `jsx: preserve`, etc.) e não devem ser
substituídos pelo `@gk/config` compartilhado, que é voltado para `packages/*`.

- [ ] **Step 4: Instalar e verificar build**

```bash
pnpm install
pnpm --filter=./apps/web build
```

Expected: `pnpm install` resolve o novo workspace sem conflito de peer dependency. `next build`
termina com sucesso (rota estática `/` gerada).

- [ ] **Step 5: Verificar lint e typecheck**

```bash
pnpm --filter=./apps/web lint
pnpm --filter=./apps/web typecheck
```

Expected: ambos terminam sem erro.

- [ ] **Step 6: Commit**

```bash
git add apps/web pnpm-lock.yaml
git commit -m "chore: scaffold do apps/web (Next.js 15 + shadcn/ui)"
```

---

### Task 5: `.env.example`

**Files:**
- Create: `.env.example`

**Interfaces:**
- Consumes: nada.
- Produces: documentação das variáveis de ambiente que `apps/web` vai precisar quando o Supabase
  for integrado (issue futura do épico #12). Não é lido automaticamente pelo Next — é referência
  para o dev copiar para `.env.local` dentro de `apps/web` quando chegar a hora.

- [ ] **Step 1: Criar `.env.example`**

```bash
# NEXT_PUBLIC_SUPABASE_URL=
# NEXT_PUBLIC_SUPABASE_ANON_KEY=
# ⚠️ server-side apenas — jamais com prefixo NEXT_PUBLIC_
# SUPABASE_SERVICE_ROLE_KEY=
```

Conteúdo exato do arquivo `.env.example` (sem o prefixo `# ` das linhas de variável — só o
comentário de aviso leva `#`):

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
# ⚠️ server-side apenas — jamais com prefixo NEXT_PUBLIC_
SUPABASE_SERVICE_ROLE_KEY=
```

- [ ] **Step 2: Verificar que `.env` real continua ignorado**

```bash
git check-ignore -v .env
```

Expected: imprime a regra do `.gitignore` que ignora `.env` (confirma que `.env.example` é a
única exceção, como já configurado).

- [ ] **Step 3: Commit**

```bash
git add .env.example
git commit -m "chore: adiciona .env.example com placeholders do Supabase"
```

---

### Task 6: Verificação completa, PR e status da pipeline

**Files:** nenhum arquivo novo — task de integração e entrega.

**Interfaces:**
- Consumes: tudo das Tasks 1–5.
- Produces: PR aberto contra `main`, com o status da pipeline verificado e reportado.

- [ ] **Step 1: Normalizar formatação com Prettier**

```bash
pnpm exec prettier --write .
git status --short
```

Expected: pode haver diffs em arquivos gerados pelo `create-next-app`/`shadcn` que não batem
100% com o Prettier padrão. Se houver mudanças, siga para o Step 2 para commitá-las.

- [ ] **Step 2: Commit da normalização (se houve diff no Step 1)**

```bash
git add -A
git commit -m "style: normaliza formatação com prettier"
```

Se `git status --short` no Step 1 não mostrou nada, pule este commit.

- [ ] **Step 3: Rodar a verificação completa da raiz**

```bash
pnpm turbo run build lint test typecheck
```

Expected: todas as tasks com status `success` (ou `cached`, em reruns). Se algo falhar, corrija
o pacote correspondente e repita este step antes de prosseguir — não abra o PR com a raiz
quebrada.

- [ ] **Step 4: Rodar a checagem de formatação isoladamente**

```bash
pnpm turbo run format:check
```

Expected: `success` — confirma que o Step 1 realmente normalizou tudo.

- [ ] **Step 5: Confirmar o critério de aceite mais importante da issue**

```bash
node -e "const pkg = require('./packages/core/package.json'); const deps = Object.keys(pkg.dependencies || {}); const frameworks = deps.filter(d => /^(react|next|@supabase)/.test(d)); if (frameworks.length) { console.error('FALHOU:', frameworks); process.exit(1); } console.log('OK — sem dependências de framework:', deps);"
```

Expected: imprime `OK — sem dependências de framework: [ '@gk/config' ]` (código de saída `0`).

- [ ] **Step 6: Push da branch**

```bash
git push -u origin chore/monorepo-turborepo-pnpm
```

- [ ] **Step 7: Abrir o PR**

```bash
gh pr create \
  --title "chore: monorepo Turborepo + pnpm com apps/web e packages/core" \
  --body "Closes #18

Base do monorepo: pnpm workspaces + Turborepo, \`packages/config\` (eslint/tsconfig
compartilhados), \`packages/core\` com TDD (\`CORE_VERSION\`) e scaffold do \`apps/web\`
(Next.js 15 + shadcn/ui).

## Checklist da issue
- [x] \`pnpm install\` resolve todos os workspaces sem warning de peer dependency quebrada
- [x] \`pnpm turbo run build lint test typecheck\` verde
- [x] \`packages/core/package.json\` sem React/Next/Supabase em \`dependencies\`
- [x] \`.env\` no \`.gitignore\`, \`.env.example\` commitado
- [ ] CI verde no PR (verificando)"
```

Expected: imprime a URL do PR criado.

- [ ] **Step 8: Acompanhar o status da pipeline**

```bash
gh pr checks --watch
```

Expected: aguarda até todos os checks concluírem. Se algum falhar:
1. Rode `gh run view --log-failed` (ou abra o link do check) para ver o motivo.
2. Corrija localmente, repita o Step 3, comite a correção, dê push de novo.
3. Repita este step até o gate `CI OK` (`ci-ok` no `ci.yml`) passar.

- [ ] **Step 9: Reportar o resultado**

Depois que `gh pr checks --watch` terminar com sucesso, rode:

```bash
gh pr view --json url,statusCheckRollup --jq '.url, (.statusCheckRollup | map(.state) | unique)'
```

Expected: imprime a URL do PR e um array de estados únicos dos checks — deve conter só
`"SUCCESS"` (jobs pulados pelo `detect` aparecem como `SKIPPED`/`NEUTRAL`, o que é aceito pelo
gate `ci-ok`).
