# Shared contracts and backend events

All three apps should use one authenticated backend. The backend owns stock, prices, order transitions, payment confirmation, delivery assignments, and audit history. Offline clients may queue mutations, but the server must apply an idempotency key to every mutation.

| Contract | Required fields | Authorized writers |
|---|---|---|
| Catalog item | Product ID, name, category, unit, sale price, available stock, barcode | Admin; Shop for permitted stock operations |
| Customer order | Order ID, customer, lines, total, delivery address, status, payment status | Customer creates; Admin/Shop transitions; Delivery updates assigned delivery state |
| Fonepay submission | Order ID, exact amount, payment reference, submitted time, QR asset version | Customer submits; Admin/Shop confirms or rejects |
| Delivery assignment | Order ID, delivery agent, assigned time, delivery status | Admin/Shop |
| Location ping | Delivery agent, order, latitude, longitude, accuracy, recorded time | Assigned delivery agent with consent |

## Suggested event names

`catalog.updated`, `stock.changed`, `order.created`, `order.accepted`, `order.preparing`, `order.assigned`, `order.out_for_delivery`, `order.delivered`, `order.cancelled`, `payment.submitted`, `payment.confirmed`, `payment.rejected`, and `delivery.location_updated`.

## Location and privacy requirements

Location updates must be limited to an active assigned order, require explicit delivery-agent permission, record accuracy and timestamp, and stop after delivery completion. Customers receive the most recent location for their own active order only. Admin audit logs should record assignment and confirmation actions without exposing location history beyond the configured retention period.
