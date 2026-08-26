import { describe, expect, it } from "vitest";
import { CORE_VERSION } from "./index";

describe("packages/core", () => {
  it("exporta a versão do domínio", () => {
    expect(CORE_VERSION).toBe("0.1.0");
  });
});
