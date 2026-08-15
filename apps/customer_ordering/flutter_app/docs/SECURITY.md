# Security
- Never ship OpenAI, Supabase service-role, payment secret, or signing keys in the APK.
- Use RLS for every cloud business table.
- Recalculate financial totals on the trusted backend before cloud commit.
- Use idempotency IDs for invoice/payment/sync operations.
- Audit refunds, voids, stock adjustments, rate changes and role changes.
- Minimize customer/farmer data sent to AI and use HTTPS in production.
