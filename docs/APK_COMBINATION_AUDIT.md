# Supplied APK Combination Audit

## Evidence reviewed

The supplied `MilkKhata.apk` and `Karobar.apk` are compiled Flutter Android applications. Their APK contents include Flutter assets and compiled Dart code rather than editable Flutter source. They can be inspected as references, but the binaries cannot be safely merged into one maintainable APK by concatenating files or copying compiled classes.

## Feature evidence

| Supplied APK | Observed feature direction | Existing Gajurmukhi implementation |
|---|---|---|
| MilkKhata | Milk collection, Khata/ledger, customer payments, QR, reports, location/GPS, login | Present in Flutter app: dairy collection, customer ledger, QR payments, reports, role login, GPS check-in |
| Karobar | Billing, inventory, stock in/out, payments in/out, staff, barcode scanning, QR, WhatsApp, thermal/network printing, reports, sales/purchase returns, credit reminders | Present or partially present: billing, grocery/dairy inventory, stock adjustments, staff roles, QR, WhatsApp, Bluetooth printing, reports, ledger, expenses |

The current project is already the correct integration base because it is the supplied Flutter source application. The combined rebuild should reproduce the useful workflows from both references in the existing offline-first database and role-permission model rather than embedding either compiled APK.

## Combination boundary

The following workflows are safe to combine immediately in source: Milk Khata collection and farmer payout calculation; Karobar-style grocery/dairy POS and stock management; customer/farmer ledgers; payments in/out and expenses; QR and WhatsApp bill sharing; thermal printing; reports; staff roles; and collector GPS check-in.

Features that require additional product decisions or external setup are barcode scanning hardware behavior, network-printer protocols, sales/purchase return accounting, credit-reminder scheduling, and any bank/cooperative withdrawal integration. The supplied APKs do not provide editable source or a documented API contract for those workflows.

## Implementation decision

Do not merge the APK binaries directly. Extend the existing Flutter source and generate a new cloud-built Android APK/AAB from that source. This preserves offline-first behavior, the existing database, role guards, Android signing workflow, and the Gajurmukhi branding while incorporating the reference workflows that are technically identifiable.
