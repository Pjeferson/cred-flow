import { describe, it, expect } from "vitest";
import {
  formatCurrency,
  formatDate,
  formatDateShort,
  formatDateOnly,
  formatTTL,
  policyReason,
} from "@/lib/formatters";

describe("formatCurrency", () => {
  it("formats cents to BRL string", () => {
    expect(formatCurrency(100_000)).toBe("R$ 1.000,00");
  });

  it("formats zero", () => {
    expect(formatCurrency(0)).toBe("R$ 0,00");
  });

  it("formats fractional cents", () => {
    expect(formatCurrency(150)).toBe("R$ 1,50");
  });
});

describe("formatDate", () => {
  it("returns day month and time", () => {
    // 2024-03-15T14:30:00.000Z
    const result = formatDate("2024-03-15T14:30:00.000Z");
    expect(result).toMatch(/^\d{1,2} \w+, \d{2}:\d{2}$/);
  });
});

describe("formatDateShort", () => {
  it("returns day month year without time", () => {
    const result = formatDateShort("2024-06-01T00:00:00.000Z");
    expect(result).toMatch(/^\d{1,2} \w+ \d{4}$/);
  });
});

describe("formatDateOnly", () => {
  it("parses YYYY-MM-DD without timezone shift", () => {
    // formatDateOnly interpreta a data como local, sem conversão UTC
    const result = formatDateOnly("2024-12-25");
    expect(result).toContain("2024");
    expect(result).toMatch(/^\d{1,2} \w+ \d{4}$/);
  });

  it("returns 25 for christmas", () => {
    const result = formatDateOnly("2024-12-25");
    expect(result).toMatch(/^25 /);
  });
});

describe("formatTTL", () => {
  it("returns a relative time string", () => {
    const inOneHour = new Date(Date.now() + 3_600_000).toISOString();
    const result = formatTTL(inOneHour);
    expect(typeof result).toBe("string");
    expect(result.length).toBeGreaterThan(0);
  });
});

describe("policyReason", () => {
  it("translates known keys", () => {
    expect(policyReason("amount_threshold")).toBe("valor acima do limite");
    expect(policyReason("new_beneficiary")).toBe("beneficiário novo");
    expect(policyReason("daily_limit_exceeded")).toBe("limite diário atingido");
    expect(policyReason("outside_banking_hours")).toBe("fora do horário SPB");
  });

  it("returns the raw key for unknown values", () => {
    expect(policyReason("unknown_reason")).toBe("unknown_reason");
  });
});
