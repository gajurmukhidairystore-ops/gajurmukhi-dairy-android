# Gajurmukhi Dairy & Store — Three-App Platform

This source bundle is the foundation for three coordinated Android applications backed by one shared business system. The apps are deliberately separated by workflow while sharing the same domain vocabulary, permissions, inventory concepts, and order lifecycle.

| Application | Primary users | Core responsibility |
|---|---|---|
| **Gajurmukhi Admin** (`apps/collection_inventory`) | Admin, Shop, Collector | Milk collection, FAT/SNF rates, farmers, grocery/dairy inventory, stock adjustments, payment-out records, returns, offline-first sync, GPS check-in, and staff controls. |
| **Gajurmukhi Store** (`apps/shop_counter`) | Admin, Shop | Retail POS, customer selection, invoices, payment-in, exact-order QR display, payment-reference capture, WhatsApp sharing, Bluetooth printing, returns, and stock decrement. |
| **Gajurmukhi Customer** (`apps/customer_ordering`) | Customers and delivery staff | Product catalog, cart, order placement, Fonepay QR payment submission, order status, delivery assignment, customer tracking, and delivery-agent location sharing. |

## Current implementation status

The existing production-tested Flutter application is included under `apps/collection_inventory/flutter_app` and is the strongest operational foundation. It includes the existing dairy, billing, ledger, inventory, WhatsApp, QR, printing, GPS, roles, and offline-first workflows, plus barcode-ready products, sales/purchase returns, credit reminders, AI assistant access, daily progress challenges, achievement-style rewards, and Gajurmukhi branding.

The `shop_counter` and `customer_ordering` folders contain the separation boundary and shared-contract foundation for the next application builds. All three packages use the supplied Gajurmukhi shop logo asset and have distinct Android application labels. Their workflows must use the contracts under `shared/contracts` rather than creating incompatible data models. This package does not claim that automatic Fonepay gateway confirmation or production realtime delivery tracking is complete without merchant API credentials and a deployed realtime backend.

## AI assistant and game features

Each packaged Flutter shell includes the AI Business Assistant route, using the existing authenticated server contract and controlled business snapshots rather than exposing private credentials in the app. Admin prompts focus on sales, receivables, stock, milk collection, and staff activity. Store prompts focus on billing, stock, payment, and order fulfillment. Customer prompts should be limited to catalog, order status, delivery, and account questions.

The Daily Progress screen provides non-cash challenges such as completing collection entries, reviewing low stock, finishing accurate bills, placing an order, or confirming delivery. Points and badges are engagement signals only; they are not gambling, cash prizes, or a substitute for payroll or customer discounts. Shared data structures are in `shared/contracts/ai_game_models.dart`.

## YouTube Music

All three named apps include a YouTube Music screen available from the protected More menu. Users can save YouTube video links locally, play them inside the app through the official YouTube iFrame-based player, use the built-in play/pause, seek, and fullscreen controls, and move to the previous or next saved video. The app does not download, extract, cache, or redistribute YouTube audio. Playback therefore follows YouTube’s account, advertising, connectivity, and copyright rules.

## Payment behavior

The supplied Fonepay QR is stored at `shared/assets/gajurmukhi-fonepay-qr.jpg`. The safe initial behavior is static QR checkout: the app shows the exact order amount, customer/order reference, QR image, and a payment-reference submission field. Admin or Shop confirms the payment. Automatic amount-locked confirmation requires Fonepay merchant API access, callbacks, and credentials, which are not included in this bundle.

## Shared roles

Admin manages users, products, rates, payment settings, orders, refunds, delivery assignments, and audit records. Shop staff manage billing, inventory, customer payments, and order fulfillment. Collectors record milk collection and authorized GPS check-ins. Delivery staff can see only assigned orders and publish consent-based location updates. Customers can browse catalog, place orders, submit payment references, see their own order history, and track assigned deliveries.

## Build direction

The recommended next implementation step is to extract the shared backend into the cloud dashboard project, then create two focused Flutter applications from the same shared contracts: the shop counter app and the customer ordering app. Configure Fonepay merchant integration before enabling automatic payment confirmation. Configure location consent, foreground/background policies, retention, and delivery-zone rules before enabling live tracking.
