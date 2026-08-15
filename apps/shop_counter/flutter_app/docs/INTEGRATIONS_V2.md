# V2 Integrations
- Bluetooth thermal: ESC/POS bytes + paired printer discovery/connection; test the exact 58/80mm model.
- Cloud/auth: Supabase Postgres + Auth + RLS. Publishable key in Flutter; service-role key only on backend.
- Nepali date: AD timestamps internally, Bikram Sambat display for business users.
- QR payments: configurable QR generator plus gateway integration point; dynamic gateway transactions must be created and verified server-side.
- WhatsApp: invoice PDF through the Android/iOS share sheet; text reminders via pre-filled WhatsApp message.
- FAT/SNF: configurable rate table; the app selects the matching rate instead of guessing a formula.
- AI: authenticated backend validates the user, rate-limits requests, sends a controlled business snapshot to OpenAI Responses API, and returns the answer. Never expose the AI secret key in the APK.
