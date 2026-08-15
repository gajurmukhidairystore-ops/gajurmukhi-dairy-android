export type ThermalPaperWidth = 58 | 80;

export type DailyDairyTransactionItem = {
  name: string;
  quantity: number;
  unitPrice: number;
  unit?: string;
};

export type DailyDairyTransactionInput = {
  invoiceNumber: string;
  date?: Date;
  customerName?: string;
  customerPhone?: string;
  items: DailyDairyTransactionItem[];
  subtotal: number;
  discount?: number;
  total: number;
  paid: number;
  due?: number;
  paymentMode?: string;
  upiId?: string;
  qrStatus?: "not_applicable" | "pending" | "received";
};

function amount(value: number): string {
  return `NPR ${value.toFixed(2)}`;
}

function quantity(value: number): string {
  return Number.isInteger(value) ? String(value) : value.toFixed(2);
}

function paymentLabel(value?: string): string {
  if (!value) return "Not specified";
  return value.charAt(0).toUpperCase() + value.slice(1);
}

export function formatDailyDairyTransaction(input: DailyDairyTransactionInput): string {
  const date = (input.date ?? new Date()).toLocaleString("en-IN", {
    dateStyle: "medium",
    timeStyle: "short",
  });
  const discount = Math.max(0, input.discount ?? 0);
  const due = Math.max(0, input.due ?? input.total - input.paid);
  const itemLines = input.items.length
    ? input.items.map((item, index) => {
        const itemTotal = item.quantity * item.unitPrice;
        const unit = item.unit ? ` ${item.unit}` : "";
        return `${index + 1}. ${item.name} — ${quantity(item.quantity)}${unit} × ${amount(item.unitPrice)} = ${amount(itemTotal)}`;
      })
    : ["No line items recorded"];

  return [
    "*GAJURMUKHI DAIRY & STORE*",
    "_Daily dairy transaction summary_",
    "────────────────────",
    `*Invoice:* ${input.invoiceNumber}`,
    `*Date:* ${date}`,
    `*Customer:* ${input.customerName?.trim() || "Walk-in customer"}`,
    ...(input.customerPhone ? [`*Phone:* ${input.customerPhone}`] : []),
    "",
    "*Items*",
    ...itemLines,
    "",
    `*Subtotal:* ${amount(input.subtotal)}`,
    ...(discount > 0 ? [`*Discount:* -${amount(discount)}`] : []),
    `*Total:* ${amount(input.total)}`,
    `*Paid:* ${amount(Math.max(0, input.paid))}`,
    `*Balance due:* ${amount(due)}`,
    `*Payment mode:* ${paymentLabel(input.paymentMode)}`,
    ...(input.upiId ? [`*UPI:* ${input.upiId}`] : []),
    ...(input.qrStatus && input.qrStatus !== "not_applicable" ? [`*QR payment:* ${input.qrStatus === "received" ? "Received" : "Pending confirmation"}`] : []),
    "",
    due > 0 ? "Please settle the balance at your convenience." : "Payment received in full. Thank you!",
    "Value for Life",
  ].join("\n");
}

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
  const text = invoiceUrl ? `${message}\n\nView invoice: ${invoiceUrl}` : message;
  return `https://wa.me/${digits}?text=${encodeURIComponent(text)}`;
}
