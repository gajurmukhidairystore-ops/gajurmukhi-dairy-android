# Gajurmukhi Admin — Phone Validation Checklist

Use the generated debug APK on the shopkeeper’s Android phone. Record each item as Pass, Fail, or Not available and attach a short note for every failure.

## 1. Login and roles

- [ ] First launch creates the Admin account with a four-digit-or-longer PIN.
- [ ] Admin login opens the overview and can open Users & Roles.
- [ ] Admin creates one Shop user and one Collector user.
- [ ] Shop login opens the shopkeeper overview and can open POS, customers, inventory, payments, and reports.
- [ ] Collector login opens the collection workflow and cannot open retail billing, stock editing, or staff management.
- [ ] Sign out returns to the role login screen and does not expose the previous session.

## 2. Retail and grocery billing

- [ ] Create grocery and dairy products with unit, price, stock, and low-stock threshold.
- [ ] Create a customer with name and WhatsApp-capable phone number.
- [ ] Create a mixed grocery/dairy bill with quantities, discount, and customer selection.
- [ ] Confirm stock decreases exactly once after saving the bill.
- [ ] Confirm due balance, payment mode, and invoice number are displayed.
- [ ] Confirm the bill remains visible after closing and reopening the app.

## 3. Smart QR and customer delivery

- [ ] Select QR payment and confirm the QR payload displays the exact invoice total.
- [ ] Confirm the customer is not asked to enter the amount manually.
- [ ] Mark QR as received only after checking the payment app/bank confirmation.
- [ ] Confirm pending/received status appears on the bill, WhatsApp summary, and printed receipt.
- [ ] Tap direct WhatsApp share and verify the itemized message reaches the selected customer.
- [ ] Test native share fallback when WhatsApp is unavailable.

## 4. Dairy and farmer collection

- [ ] Add/select a farmer and record morning and evening milk.
- [ ] Enter litres, FAT, and SNF and confirm the configured rate slab and payout.
- [ ] Confirm collection history and totals remain available offline.

## 5. Inventory, staff, and cashflow

- [ ] Add stock through a purchase or manual stock-in adjustment.
- [ ] Test stock-out adjustment and confirm it cannot reduce stock below zero.
- [ ] Confirm low-stock products appear in the inventory view.
- [ ] Add an expense/payment-out entry and confirm it appears in cashflow/report totals.
- [ ] Confirm Shop cannot modify staff, system settings, or rate slabs.
- [ ] Confirm Collector cannot modify retail inventory or customer payments.

## 6. Printing and branding

- [ ] Confirm the Gajurmukhi logo appears on login and primary app surfaces.
- [ ] Pair a supported Bluetooth thermal printer and print a 58 mm receipt.
- [ ] Print an 80 mm receipt where supported.
- [ ] Confirm receipt totals, due, payment mode, and QR status are legible.

## 7. Offline, sync, and AI

- [ ] Enable airplane mode and create a bill, collection, payment, and stock adjustment.
- [ ] Close and reopen the app while offline and confirm records remain visible.
- [ ] Restore connectivity and confirm queued records synchronize once without duplicates.
- [ ] Ask the AI assistant a question about current sales or stock and confirm it does not invent unavailable figures.

## 8. Foreground GPS check-in

- [ ] Configure the shop point with Android location permission.
- [ ] Deny permission and confirm the app explains that GPS permission is required.
- [ ] Start collector check-in and confirm a visible TRACKING state.
- [ ] Confirm the distance from the shop updates while the collection screen is active.
- [ ] Stop check-in and confirm location updates stop.
- [ ] Confirm the app does not request hidden/background tracking.

## 9. Release validation

- [ ] Install the release APK and repeat login, billing, QR, WhatsApp, and printing smoke tests.
- [ ] Keep the AAB for Google Play upload only after configuring a real upload keystore and secrets.
