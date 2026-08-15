export type ThermalPaperWidth = 58 | 80;

export function escPosColumns(width: ThermalPaperWidth): number {
  return width === 80 ? 48 : 32;
}

export function formatEscPosReceipt(input: {
  width: ThermalPaperWidth;
  total: number;
  paid: number;
  currency?: string;
}): Uint8Array {
  const currency = input.currency ?? "NPR";
  const due = Math.max(0, input.total - input.paid);
  const line = "-".repeat(escPosColumns(input.width));
  const body = [
    "GAJURMUKHI DAIRY & STORE",
    "Value for Life",
    line,
    `TOTAL  ${currency} ${input.total.toFixed(2)}`,
    `PAID   ${currency} ${input.paid.toFixed(2)}`,
    `DUE    ${currency} ${due.toFixed(2)}`,
    "Thank you",
    "",
  ].join("\n");
  return new TextEncoder().encode(`\x1b@${body}\x1dV\x00`);
}

export function invoiceShareUrl(origin: string, invoiceNumber: string): string {
  return new URL(`/invoice/${encodeURIComponent(invoiceNumber)}`, origin).toString();
}

export function whatsappInvoiceUrl(phone: string, message: string, invoiceUrl?: string): string {
  const digits = phone.replace(/[^0-9]/g, "");
  const text = invoiceUrl ? `${message}\n${invoiceUrl}` : message;
  return `https://wa.me/${digits}?text=${encodeURIComponent(text)}`;
}
