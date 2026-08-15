# Shop Counter App

This app is the focused counter workflow for Admin and Shop staff. It should authenticate against the shared backend and consume the shared catalog, customer, inventory, invoice, payment, and order contracts.

## Initial screen map

The home screen shows today’s sales, outstanding balances, low-stock alerts, pending customer orders, and quick actions for New Bill, Payment In, Return, Print, and Order Dispatch. Billing supports product/barcode search, quantities, discounts, customer selection, payment mode, exact total display, Fonepay QR presentation, payment-reference capture, WhatsApp invoice sharing, and Bluetooth thermal printing. Fulfillment shows pending online orders, acceptance, preparation, dispatch assignment, and delivery status.

## Permission boundary

Admin can manage products, prices, refunds, payment confirmation, staff, and reports. Shop staff can create bills, receive payments, adjust permitted stock, confirm customer payment submissions, and dispatch orders. Customers and delivery staff must not access counter inventory mutation screens.

## Offline behavior

Bills and stock movements are written locally first and queued for synchronization. Online customer orders use a conflict-safe server state machine; the counter must never decrement stock twice when a queued mutation is retried.
