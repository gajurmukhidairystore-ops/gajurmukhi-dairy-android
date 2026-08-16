# Gajurmukhi Monthly Promotional Lucky Draw

## Confirmed rules

The lucky draw is a **free promotional program**, not a paid lottery. A customer receives one token for an eligible completed purchase of **NPR 1,000 or more**. The token is issued from the Store billing flow after the bill is saved and may also be included in the WhatsApp bill message.

The Admin configures one monthly draw with three prizes: first prize, second prize, and third prize. The Admin enters the prize titles, prize details, draw month, draw date, and announcement message. On or after the configured draw date, the Admin generates the winners. The selection uses a deterministic seed in the current offline-first implementation, records the selected token and prize, marks the draw as published, and prevents a second publication for the same draw.

## Token registration

Store staff must record the customer name, token number, identity type, and a private identity-photo or document reference. The customer must consent before the identity reference is stored. Leaving the token number blank allows the app to generate one. Duplicate token numbers are rejected within the same monthly draw.

The identity reference is kept in a separate private identity-record table rather than in the public token row. The record includes a retention date, and deletion is an Admin-only action. Store staff may access private identity records for operational verification; Customer users cannot access them. The current local-first app stores a private device reference, so production teams should use a protected cloud/S3 document flow before relying on the identity record for long-term legal or compliance purposes.

## Public winner display

Public results display only the **winning token number and masked customer name**. Identity photos, identity-document references, phone numbers, and full customer details must never be included in public results or WhatsApp announcements.

Example public result:

> First Prize: GJ-123 · S*** S*****

## Month-end procedure

Before the draw date, the Admin should confirm that the three prize details and announcement message are correct and that eligible token records are complete. On or after the draw date, the Admin opens **More → Monthly Lucky Draw**, reviews the eligible-token count, and selects **Select and publish winners**. At least three eligible tokens are required for the three configured prizes. The app then shows a formatted announcement that can be copied or shared by the shop team.

## Customer communication

The bill and WhatsApp message may state that the purchase qualified for one free token and show the token number. Announcements should explain that the draw is promotional and free, state the month and prizes, and publish only token numbers with masked names. The shop should retain its own terms, consent wording, winner-claim process, and any locally required promotional disclosure before operating the draw publicly.
