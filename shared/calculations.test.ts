import { describe, expect, it } from "vitest";
import { calculateInvoiceTotals, calculateLedgerBalance, findMatchingRate } from "./calculations";

describe("dairy business calculations", () => {
  it("calculates invoice subtotal, discount, and total", () => {
    expect(calculateInvoiceTotals([{ quantity: 2, unitPrice: 45 }, { quantity: 1, unitPrice: 30 }], 10)).toEqual({ subtotal: 120, discount: 10, total: 110 });
  });
  it("never returns a negative invoice total", () => {
    expect(calculateInvoiceTotals([{ quantity: 1, unitPrice: 20 }], 25).total).toBe(0);
  });
  it("matches the configured FAT/SNF slab", () => {
    const slab = findMatchingRate([{ minFat: 3, maxFat: 4.5, minSnf: 8, maxSnf: 9, ratePerLiter: 42 }], 4, 8.5);
    expect(slab?.ratePerLiter).toBe(42);
    expect(findMatchingRate([{ minFat: 3, maxFat: 4.5, minSnf: 8, maxSnf: 9, ratePerLiter: 42 }], 5, 8.5)).toBeUndefined();
  });
  it("calculates outstanding balance from debits and credits", () => {
    expect(calculateLedgerBalance([{ type: "debit", amount: 500 }, { type: "credit", amount: 125 }], 100)).toBe(475);
  });
});
