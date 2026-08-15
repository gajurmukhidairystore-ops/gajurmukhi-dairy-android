# Build and setup guide

This bundle contains three Flutter source trees. Each app currently starts from the tested Gajurmukhi Flutter foundation so the source can be opened and built independently while the role-specific screens and shared backend are specialized.

| App folder | Cloud build command from that folder | First test focus |
|---|---|---|
| `apps/collection_inventory/flutter_app` | `flutter build apk --debug` | Farmers, milk collection, inventory, stock, offline sync, GPS check-in |
| `apps/shop_counter/flutter_app` | `flutter build apk --debug` | Billing, customer ledger, payment in/out, returns, printing, order dispatch |
| `apps/customer_ordering/flutter_app` | `flutter build apk --debug` | Catalog, cart, checkout, Fonepay QR submission, order status, delivery tracking |

For a phone-only workflow, upload one app folder at a time to a GitHub repository with a Flutter Android Actions workflow, or configure a matrix workflow that runs the same validation and packaging steps for all three folders. Each release build needs its own application ID and signing configuration before Play Store publication.

## Fonepay static QR

The supplied image is at `shared/assets/gajurmukhi-fonepay-qr.jpg`. Copy it into the customer and counter app asset declarations. The first implementation should display the exact order total and collect a payment reference for Admin/Shop confirmation. Automatic payment confirmation requires Fonepay merchant API credentials, callback configuration, and an approved integration; do not mark an order paid based only on a screenshot or customer claim.

## Required production configuration

Configure a shared API base URL, secure authentication, database migrations, push notification credentials, map/location policy, delivery zones, and storage for payment evidence. Never commit signing keys, gateway secrets, database passwords, or personal customer data into this ZIP or GitHub.
