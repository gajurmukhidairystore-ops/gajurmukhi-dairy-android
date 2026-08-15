# Gajurmukhi Admin — Smart Business App PRO

A production-oriented Flutter architecture for:
1. Real billing/POS
2. Thermal 58/80mm receipt printing
3. A4 PDF invoices
4. Customer ledger + due/credit
5. Advance/payment collection
6. Stock + low-stock alerts
7. Dairy milk collection with FAT/SNF
8. Farmer accounts and settlements
9. Sales/collection/expense/profit reports
10. AI business assistant
11. Cloud sync API
12. Role-based users + audit logs
13. Offline-first operation
14. Android APK/AAB build

## Important
This repository is a complete application scaffold and business logic foundation, but production deployment still requires:
- Your business/cloud credentials
- Payment provider credentials if online payments are enabled
- Printer testing with your exact thermal printer
- Android signing key for Play Store release
- Cloud database/server deployment
- Final VAT/tax/accounting rules configured for your business

Never put AI, cloud database, payment, or private signing secrets inside the APK.

## Architecture
Flutter UI
  -> Providers
  -> Repositories
  -> Local SQLite
  -> Sync Queue
  -> Cloud REST API

AI requests go:
Flutter -> your secure backend -> AI provider

## Run
Install Flutter + Android Studio/SDK, then:
flutter pub get
flutter run

Build:
flutter build apk --release
flutter build appbundle --release

## Business defaults
Currency: NPR
Business: Gajurmukhi Admin
Tagline: Value for Life
