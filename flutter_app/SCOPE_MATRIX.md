# Gajurmukhi One Scope Matrix

This document is the current product boundary for the unified Flutter application. The Android repository contains one role-aware app with Admin, Store, Collector, and Customer sessions. Shared local SQLite data is synchronized through the authenticated cloud API; the web project provides the branded delivery-tracking page and Admin controls.

## Implemented in the current build

The current build includes offline-first dairy collection with FAT/SNF and farmer rates, Collector-only inventory intake, grocery and dairy stock, barcode-ready product records and camera-to-billing entry, Store Sell/Billing, customer and party ledgers, direct ledger entries, monthly-settlement customers, payment-in and payment-out, returns, discounts with reasons, lucky-draw tokens and winner publication, QR/Fonepay display contracts, WhatsApp invoice and reminder sharing, reports, loans, alarms, AI assistant entry points, role-based local login, biometric unlock, cloud push/pull synchronization, welcome messages, secure delivery tracking links, Collector location updates, arrival-radius call unlocking, and the Collector-to-Store order-ready/delivery-complete lifecycle.

The latest verified source milestone also adds dashboard financial drill-down sheets. Tapping sales, money received, farmer payable, party purchase, customer receivable, or walking-customer receivable opens records from the exact underlying SQLite tables. Customer rows expose practical phone-dialer and WhatsApp shortcuts. The dashboard displays pending sync count, last successful sync, error state, and a manual Retry/Sync action.

## Intentionally constrained or later-phase features

The in-app browser is a safe navigation surface, not a general unrestricted browser automation system. Music playback must use authorized online sources or user-owned local files; the app must not extract or redistribute copyrighted audio from YouTube. Background playback and lock-screen controls need a dedicated Android media-service implementation and physical-device verification.

Email/Gmail notifications, push-notification delivery, and periodic reminder scheduling require production notification credentials, explicit consent, device permission flows, and a tested background execution design. The current order and tracking foundation is additive and secure, but full customer-order commerce, payment-provider settlement, route optimization, multi-stop dispatch, and Admin live-map operations need a separate production phase with API contracts and operational policies.

The requested MC-POS capabilities are partly present in the unified app. Tax groups, payment splits, returns, discounts, branded receipts, barcode-ready inventory, reports, quotes, cloud backup, QR payment display, and Bluetooth printing foundations exist. Restaurant tables, kitchen ticketing, cash-drawer hardware, vendor-specific scanners, jurisdiction-specific VAT/ZATCA compliance, and every printer model remain integration work rather than claims of completed compliance.

## Verification boundary

GitHub Actions is the reproducible source-validation and packaging path. The successful Android run validates Flutter analysis, deterministic tests, debug APK creation, release APK creation, release AAB creation, and artifact upload. Actual Bluetooth printing, camera scanning, phone-call behavior, QR payment confirmation, WhatsApp handoff, biometric prompts, Android location permissions, two-phone conflict behavior, release signing, and update installation must still be tested on the owner’s physical Android devices.

No customer reviews, ratings, or testimonials are fabricated in the app or its test data. Any future public-commerce feature must use real customer-generated data with appropriate consent and moderation controls.
