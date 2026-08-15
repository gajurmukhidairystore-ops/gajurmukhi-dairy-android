# Android Source Audit — Gajurmukhi Dairy & Store

## Executive finding

The supplied files are a **Flutter source scaffold and business-logic foundation**, not a complete runnable Flutter project. The upload contains flat Dart files and documentation, but no `android/` directory, Gradle files, AndroidManifest, `pubspec.lock`, `analysis_options.yaml`, or complete `lib/data`, `lib/providers`, `lib/services`, and `lib/ui` directory structure. `main.dart` imports paths such as `data/database.dart`, `providers/business_provider.dart`, and `ui/app.dart`, while the uploaded files are all at the upload root. The source therefore cannot be compiled into an APK as uploaded without first reconstructing the Flutter project structure.

The current sandbox also has **no Flutter, Dart, Android SDK, adb, sdkmanager, or Gradle command** available. Java is present, but Java alone cannot build a Flutter APK/AAB. Consequently, an APK/AAB cannot honestly be claimed or produced in this environment until a Flutter/Android build environment is supplied or enabled.

## Workflow audit

| Area | Source status | Evidence and required work |
|---|---|---|
| Offline database | Partially implemented | SQLite schema and totals exist, but the project layout is incomplete; migration/versioning, sync queue execution, conflict handling, backup/restore, and encryption are not complete. |
| Retail billing | Partially implemented | Cart, discount, paid, due, payment modes, invoice items, stock decrement, and sale stock movement exist in `BusinessProvider`; product search is not barcode-enabled and customer selection is hardcoded to null in the billing screen. |
| Customer ledger | Incomplete | Customer list exists, but payment and advance actions use a hardcoded amount of 1000; there is no amount/method form, statement screen, running transaction history, due reminder, or WhatsApp statement flow. |
| Farmer collection | Partially implemented | Morning/evening, litres, FAT, SNF, rate, amount, and farmer records exist. Settlement statements, rejection/quality records, analyzer import, and robust rate management are absent. |
| FAT/SNF engine | Partially implemented | Range matching works and falls back to a fallback rate. A complete UI/editor and automatic rate chart administration are not present in the supplied files. |
| Stock | Partially implemented | Product master, low-stock display, sale stock reduction, and stock movements exist in provider/schema. Purchase, supplier ledger, batch/expiry, wastage, physical count, and stock movement UI are absent. |
| Reports | Incomplete | The dashboard/report UI only displays current totals for sales, collection, expenses, due, and milk. Date-range filters, profit/margin, farmer settlement, yield, export, and periodized charts are absent. |
| Bluetooth printing | Partially implemented | Bluetooth transport can list paired devices, connect, write bytes, and disconnect. ESC/POS formatting is hardcoded to 80mm; 58mm settings, printer pairing UI, permissions, error/reconnect handling, and testing on an exact printer are absent. |
| A4/PDF invoice | Partially implemented | A4 PDF generation exists, but the complete share/export workflow and integration into the invoice lifecycle are not wired end to end. |
| QR payments | Incomplete | The helper renders a simple `merchant/invoice/amount` QR string. It does not validate a provider format or verify completed payments server-side. |
| WhatsApp | Partially implemented | A PDF share helper and `wa.me` text launcher exist, but invoice PDF generation, customer-specific invoice sharing, delivery status, and statement/reminder workflows are not connected. |
| Authentication | Partially implemented | Supabase password auth wrapper exists, but the app shell does not show a complete sign-in/session UX and the cloud multi-store role model is not implemented in the local provider. |
| Cloud synchronization | Incomplete | Push/pull HTTP wrappers exist, but the backend endpoints are stubs, the SQLite sync queue is not processed, and conflict resolution, idempotency, retries, multi-device merge, and cloud persistence are absent. |
| AI assistant | Incomplete | `AiBusinessService` can call a backend, but `ai.dart` only generates a local placeholder response and does not invoke the service. Auth/session propagation, rate limiting UX, Nepali/English behavior, and robust error handling are absent. |
| Android release | Blocked in current environment | No Flutter or Android SDK toolchain, no Android project directory, no application ID/signing configuration, and no physical-device test capability are present. |

## Security and production findings

The supplied security documentation correctly states that AI, Supabase service-role, payment, and signing secrets must not be shipped in the APK. The backend contract uses bearer authentication and a server-side AI client, but sync routes are currently stubs and the source cloud schema’s multi-store/RLS model is not represented in the supplied local database. Production work must preserve the source requirement to recalculate financial totals on a trusted backend, use idempotency keys, audit refunds/voids/stock/rate/role changes, and minimize data sent to AI.

## Implementation order

The Android completion path is: reconstruct the Flutter project directory and Android shell; wire the existing provider into a complete auth/session shell; replace placeholder ledger actions with real amount/method forms and statements; connect the AI screen to the secure service; add 58/80mm printer settings and robust Bluetooth handling; complete QR configuration and verification boundaries; implement sync queue push/pull/retry/conflict behavior; add periodized reports and exports; write Flutter tests; then run `flutter analyze`, `flutter test`, `flutter build apk`, and `flutter build appbundle` in a real Flutter/Android environment. Hardware-dependent claims will remain explicitly unverified until tested on the user’s Android phone, printer, QR flow, and WhatsApp installation.
