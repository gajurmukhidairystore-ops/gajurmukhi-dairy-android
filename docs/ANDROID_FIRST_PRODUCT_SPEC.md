# Gajurmukhi Dairy & Store — Android-First Product Specification

## Product boundary

The primary product is a native Flutter Android application for a dairy and grocery shopkeeper. The web dashboard is a secondary cloud administration and reporting surface. Currency is NPR and the business identity is Gajurmukhi Dairy & Store with the “Value for Life” brand direction.

## Roles and permissions

| Role | Primary access | Restricted operations |
|---|---|---|
| Admin | Staff management, settings, rates, reports, inventory, billing, customer ledger, farmer collection, AI assistant, synchronization | None within the business workspace |
| Shop | Retail POS, customer ledger, grocery/dairy catalog, inventory, payments, QR bills, receipts, WhatsApp sharing, reports | Staff management, system settings, rate-slab administration |
| Collector | Farmer directory, milk collection, FAT/SNF entry, collection history, collection reports, foreground shop-distance check-in | Retail billing, inventory edits, staff management, customer payment administration |

The same role vocabulary is used by local-first Android authentication and cloud session guards. Unknown or unsupported roles are denied by default.

## Offline-first behavior

The Android app stores customers, products, invoices, invoice items, ledger entries, payments, expenses, farmers, milk collections, stock movements, users, audit records, and sync queue entries in SQLite. Billing, collection, ledger, stock, printing preparation, QR payload generation, and formatted sharing remain usable without connectivity. Sync envelopes are queued locally and can be uploaded when the connection returns. The cloud database remains the secondary synchronized system of record for the web dashboard.

## Retail and dairy workflows

Retail billing supports mixed grocery and dairy products, customer selection, editable quantity and price, discount, payment mode, exact invoice total, stock decrement, due balance, receipt printing, and formatted WhatsApp sharing. Dairy collection supports farmer selection, morning/evening shift, litres, FAT, SNF, rate, and calculated payout. Configurable FAT/SNF slabs determine the applicable farmer rate.

## Smart QR payments

When QR is selected, the app and web dashboard generate a UPI payload containing the exact invoice amount. The customer does not enter the amount manually. QR state is stored as `not_applicable`, `pending`, or `received` and is displayed in customer summaries, WhatsApp messages, and printable receipts. The shopkeeper remains responsible for confirming receipt after checking the payment.

## Staff and inventory

Admins can create Shop and Collector accounts with PINs. Inventory supports grocery, dairy, household, and other categories, product units, sale prices, opening stock, low-stock thresholds, stock-in adjustments, stock-out adjustments, and stock movement history. The catalog is used by the POS and stock is reduced when invoices are saved.

## Sharing and printing

Customer bills contain a detailed itemized summary with customer, invoice, date, quantities, prices, subtotal, discount, total, paid amount, due balance, payment mode, UPI details, and QR state. Android uses direct WhatsApp delivery when a customer phone number is present and native sharing fallback otherwise. ESC/POS receipt support includes 58 mm and 80 mm formatting where the device/browser/printer supports it.

## Foreground GPS check-in

Collector tracking is foreground-only by default. The collector explicitly sets the shop point on the device, grants Android foreground location permission, and taps Start check-in. While the collection screen is active, the app displays the latest distance from the shop and last location update. Stop check-in ends the stream. No hidden or background tracking is enabled by this specification.

## Verification contract

The repository must pass web TypeScript checks and Vitest tests, Flutter analysis and deterministic unit tests in GitHub Actions, and the hosted debug APK, release APK, and release AAB packaging stages. Physical-device validation is still required for Bluetooth pairing, WhatsApp installation, QR payment confirmation, Android location permission behavior, offline/online sync, and signed release installation.
