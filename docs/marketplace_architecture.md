# Sahla Marketplace Architecture

This document consolidates the production payment architecture for `Sahla` on top of the current `Flutter + Supabase` app and adds the marketplace pieces required for `Chargily`, seller settlement, withdrawals, disputes, and admin operations.

## 1. System Boundaries

- `Flutter app`: buyer flows, seller center, admin screens, realtime order state, push notifications.
- `Supabase Postgres`: source of truth for products, orders, payments, wallets, disputes, withdrawals, and audit history.
- `Supabase Auth`: buyer, seller, and admin identities.
- `Supabase Storage`: product images, KYC files, dispute evidence, invoices.
- `Supabase Edge Functions`: sensitive operations only.
- `Chargily Pay`: checkout page and card payment confirmation via webhook.
- `OneSignal` or `FCM`: push delivery.

## 2. Core Marketplace Model

The current app already has:

- `users`
- `products`
- `orders`
- `reviews`
- `notifications`
- seller/admin moderation helpers

The additive payment architecture introduces:

- `payments`
- `payment_webhook_logs`
- `seller_wallets`
- `wallet_transactions`
- `withdrawals`
- `disputes`
- `shipment_tracking`
- `order_status_history`

## 3. Updated Order Lifecycle

Recommended order states:

- `Pending`
- `AwaitingPayment`
- `Paid`
- `Processing`
- `ReadyToShip`
- `Shipped`
- `Delivered`
- `Completed`
- `Cancelled`
- `Refunded`
- `Disputed`

Recommended payment states:

- `pending`
- `checkout_created`
- `processing`
- `paid`
- `failed`
- `expired`
- `cancelled`
- `refunded`

Recommended withdrawal states:

- `pending`
- `approved`
- `rejected`
- `paid`

## 4. Money Flow

Example:

- Product subtotal: `8000 DZD`
- Commission rate: `10%`
- Platform commission: `800 DZD`
- Seller receivable: `7200 DZD`

Flow:

1. Buyer creates order in Supabase.
2. Buyer clicks pay.
3. Flutter calls `create-chargily-checkout`.
4. Edge Function creates a `payments` row and requests a Chargily checkout session.
5. Buyer is redirected to Chargily.
6. Chargily calls `chargily-webhook`.
7. Webhook verifies signature, stores event log, marks `payments.status = paid`, and updates the order.
8. Seller amount moves into `seller_wallets.pending_balance`.
9. After delivery plus dispute hold, admin or scheduled automation calls `release-seller-payout`.
10. Seller amount moves from `pending_balance` to `available_balance`.
11. Seller requests `withdrawal`.
12. Admin marks withdrawal as paid after CCP or bank transfer.

## 5. Security Rules

- Buyer sees only their own orders, payments, disputes, and addresses.
- Seller sees only rows linked to their orders or wallet.
- Admin sees all operational tables.
- Frontend never marks payment as successful.
- Only webhook or privileged backend logic updates `payments.status = paid`.
- Wallet balances are ledger-backed by `wallet_transactions`.
- Every status change is appended to `order_status_history`.

## 6. Edge Functions

### `create-chargily-checkout`

Responsibility:

- validate authenticated buyer
- validate order ownership
- prevent duplicate successful payment attempts
- create or reuse a `payments` row
- call Chargily API
- return hosted checkout URL

### `chargily-webhook`

Responsibility:

- verify webhook signature
- store raw payload in `payment_webhook_logs`
- resolve the internal `payment` by metadata
- idempotently apply success or failure
- credit seller wallet pending balance only once
- create notifications

### `release-seller-payout`

Responsibility:

- ensure order is delivered or completed
- ensure payment is paid
- ensure no open dispute
- move seller funds from pending to available
- create wallet ledger entries

### `request-withdrawal`

Responsibility:

- validate seller balance
- create `withdrawals` row
- hold requested amount in ledger
- notify admin

## 7. Notification Events

- payment created
- payment confirmed
- payment failed
- seller received new paid order
- order shipped
- order delivered
- payout released
- withdrawal requested
- withdrawal approved
- withdrawal paid
- dispute opened
- dispute resolved

## 8. Algeria-Specific Operational Notes

- keep all amounts in integer or exact numeric DZD values
- store `wilaya`, `commune`, and delivery notes
- keep CCP and bank transfer account fields on withdrawal requests
- support Arabic and French labels in app content
- add `phoneNumber` validation for Algerian formats
- if COD remains available, keep COD and Chargily as separate payment methods

## 9. App Surfaces Required

Buyer:

- checkout payment selector
- payment waiting screen
- order tracking
- receipts
- disputes

Seller:

- paid orders queue
- shipment update actions
- wallet summary
- withdrawals
- dispute response

Admin:

- payment monitoring
- webhook failures
- withdrawal review
- dispute resolution
- seller payout release

## 10. Deployment Sequence

1. Apply the new SQL migration.
2. Set Edge Function secrets:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `CHARGILY_SECRET_KEY`
   - `CHARGILY_WEBHOOK_SECRET`
   - `CHARGILY_API_BASE_URL`
   - `APP_BASE_URL`
3. Deploy Edge Functions.
4. Update Flutter checkout flow to use the payment function instead of direct COD-only RPC.
5. Enable push events for payment and shipment updates.
