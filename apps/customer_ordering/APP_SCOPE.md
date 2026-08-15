# Customer Ordering App

This app is the customer-facing shopping and delivery experience. Customers browse the shop’s available dairy and grocery catalog, search products, add items to a cart, choose a delivery address, submit an order, and follow its status.

## Checkout

Checkout shows the order total in NPR, the supplied Gajurmukhi Fonepay QR image, the shop name, the order reference, and a payment-reference field. The initial safe mode is static QR plus manual Admin/Shop confirmation. The app must not claim payment success until the backend records confirmation. Cash on delivery can remain available if enabled by Admin.

## Order lifecycle

Customers see pending, accepted, preparing, ready, assigned, out-for-delivery, delivered, cancelled, and payment states. They can view order history and receive status notifications. A customer sees only their own orders and the latest location associated with an assigned delivery.

## Delivery tracking

The customer app displays a map or privacy-preserving status card only after an order is assigned and the delivery agent has granted location permission. It should show the last update time and an accuracy indicator rather than implying continuous precision. Location sharing stops when the order is delivered or cancelled.

## Security boundary

Customers cannot edit inventory, prices, payment confirmation, staff, delivery assignments, or other customers’ data. All order and payment transitions are checked by the shared backend.
