// @ts-check
import { defineConfig } from "eslint/config";
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import prettier from "eslint-config-prettier";

/**
 * Config compartilhada do monorepo (ADR 1 — zero `any` implícito).
 * Consumida por cada pacote via `import gkConfig from "@gk/config/eslint"`.
 */
export default defineConfig(
  js.configs.recommended,
  tseslint.configs.recommended,
  {
    rules: {
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
    },
  },
  prettier,
  {
    ignores: ["dist/**", ".next/**", "node_modules/**", "coverage/**"],
  },
);
