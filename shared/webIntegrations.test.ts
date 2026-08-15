import { describe, expect, it } from "vitest";
import { escPosColumns, formatDailyDairyTransaction, formatEscPosReceipt, invoiceShareUrl, whatsappInvoiceUrl } from "./webIntegrations";

describe("web dairy integrations", () => {
  it("formats both supported thermal widths", () => {
    expect(escPosColumns(58)).toBe(32);
    expect(escPosColumns(80)).toBe(48);
    const receipt = new TextDecoder().decode(formatEscPosReceipt({ width: 80, total: 250, paid: 200 }));
    expect(receipt).toContain("TOTAL  NPR 250.00");
    expect(receipt).toContain("DUE    NPR 50.00");
    expect(receipt).toContain("-".repeat(48));
  });

  it("formats a detailed daily dairy transaction summary", () => {
    const message = formatDailyDairyTransaction({
      invoiceNumber: "INV-2026-001",
      date: new Date("2026-08-15T09:30:00Z"),
      customerName: "Sita Sharma",
      customerPhone: "+977 9812345678",
      items: [
        { name: "Fresh milk", quantity: 2, unitPrice: 90, unit: "L" },
        { name: "Curd", quantity: 1, unitPrice: 75, unit: "pack" },
      ],
      subtotal: 255,
      discount: 5,
      total: 250,
      paid: 200,
      paymentMode: "credit",
    });
    expect(message).toContain("*GAJURMUKHI DAIRY & STORE*");
    expect(message).toContain("*Invoice:* INV-2026-001");
    expect(message).toContain("*Customer:* Sita Sharma");
    expect(message).toContain("1. Fresh milk — 2 L × NPR 90.00 = NPR 180.00");
    expect(message).toContain("*Discount:* -NPR 5.00");
    expect(message).toContain("*Balance due:* NPR 50.00");
    expect(message).toContain("*Payment mode:* Credit");
  });

  it("builds a stable invoice link for WhatsApp sharing", () => {
    const link = invoiceShareUrl("https://store.example", "INV/2026-001");
    expect(link).toBe("https://store.example/invoice/INV%2F2026-001");
    const whatsapp = whatsappInvoiceUrl("+977 981-234-5678", "Gajurmukhi invoice", link);
    expect(whatsapp).toContain("https://wa.me/9779812345678?text=");
    expect(decodeURIComponent(whatsapp.split("text=")[1] ?? "")).toContain("View invoice: ");
    expect(decodeURIComponent(whatsapp.split("text=")[1] ?? "")).toContain(link);
  });
});
