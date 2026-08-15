import { describe, expect, it } from "vitest";
import { escPosColumns, formatEscPosReceipt, invoiceShareUrl, whatsappInvoiceUrl } from "./webIntegrations";

describe("web dairy integrations", () => {
  it("formats both supported thermal widths", () => {
    expect(escPosColumns(58)).toBe(32);
    expect(escPosColumns(80)).toBe(48);
    const receipt = new TextDecoder().decode(formatEscPosReceipt({ width: 80, total: 250, paid: 200 }));
    expect(receipt).toContain("TOTAL  NPR 250.00");
    expect(receipt).toContain("DUE    NPR 50.00");
    expect(receipt).toContain("-".repeat(48));
  });

  it("builds a stable invoice link for WhatsApp sharing", () => {
    const link = invoiceShareUrl("https://store.example", "INV/2026-001");
    expect(link).toBe("https://store.example/invoice/INV%2F2026-001");
    const whatsapp = whatsappInvoiceUrl("+977 981-234-5678", "Gajurmukhi invoice", link);
    expect(whatsapp).toContain("https://wa.me/9779812345678?text=");
    expect(decodeURIComponent(whatsapp.split("text=")[1] ?? "")).toContain(link);
  });
});
