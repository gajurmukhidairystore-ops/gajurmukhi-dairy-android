export type BillLine = { quantity: number; unitPrice: number };
export type RateRange = { minFat: number | string; maxFat: number | string; minSnf: number | string; maxSnf: number | string; ratePerLiter: number | string };
export function calculateInvoiceTotals(items: BillLine[], discount = 0) { const subtotal = items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0); return { subtotal, discount, total: Math.max(0, subtotal - discount) }; }
export function findMatchingRate(slabs: RateRange[], fat: number, snf: number) { return slabs.find(slab => fat >= Number(slab.minFat) && fat <= Number(slab.maxFat) && snf >= Number(slab.minSnf) && snf <= Number(slab.maxSnf)); }
export function calculateLedgerBalance(entries: Array<{ type: "debit" | "credit"; amount: number | string }>, openingBalance = 0) { return entries.reduce((sum, entry) => sum + (entry.type === "debit" ? Number(entry.amount) : -Number(entry.amount)), openingBalance); }
