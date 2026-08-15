# Supplied Flutter Source Audit

The supplied source is a Flutter/SQLite application foundation for Gajurmukhi Dairy & Store. Its business defaults are **NPR** currency, the **Value for Life** tagline, an offline-first local database, cloud sync, role-aware users, audit logs, and secure server-side AI access.

The core provider implements customer, product, farmer, milk collection, advance, payment, expense, invoice, stock-reduction, stock-movement, ledger, and snapshot workflows. Invoice creation calculates subtotal, discount, total, paid, and due; it writes invoice items, decrements product stock, records a sale stock movement, and writes a SALE_DUE ledger entry when due remains. The source billing screen supports **CASH, QR, BANK, and CREDIT** modes and A4 invoice printing.

The farmer rate service selects the first configured rule whose FAT and SNF ranges contain the readings, with a fallback rate when no rule matches. Milk collection captures farmer, litres, FAT, SNF, rate, amount, date, and MORNING/EVENING shift.

The cloud schema is multi-store: stores and store_members scope business tables, with owner/manager/cashier/collector/viewer roles and row-level security policies. The source backend requires bearer authentication, rate-limits API routes, validates AI requests, sends only a controlled business snapshot to the model, uses NPR-aware instructions, and exposes sync push/pull contracts.

The web port has been updated to preserve NPR formatting, paid/due invoice semantics, cash/QR/bank/credit payment modes, cloud payment/settings tables, stock reduction, customer due ledger entries, configurable rate slabs, and a secure server-side built-in LLM assistant. Remaining production parity items include full multi-store tenancy/role policies, true Bluetooth ESC/POS byte transport, PDF invoice generation, WhatsApp PDF sharing, complete ledger/payment screens, and source-level sync/audit workflows.
