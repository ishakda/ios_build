# Flutter Marketplace Structure

This maps the missing marketplace pieces onto the current `lib/features` structure.

## 1. Existing Good Base

The project already has these feature groups:

- `auth`
- `cart`
- `checkout`
- `notifications`
- `product`
- `vendor`
- `admin`

Keep them. Extend them with payment, wallet, disputes, and shipping instead of reorganizing the entire app.

## 2. Recommended Feature Additions

### `lib/features/checkout`

Add:

- `data/datasources/payment_remote_data_source.dart`
- `data/models/payment_session_model.dart`
- `domain/entities/payment_session.dart`
- `domain/repositories/payment_repository.dart`
- `presentation/cubit/payment_cubit.dart`
- `presentation/pages/payment_redirect_page.dart`
- `presentation/widgets/payment_method_selector.dart`

Responsibilities:

- create Chargily checkout
- show payment method options
- poll or subscribe for payment confirmation

### `lib/features/orders`

Create a dedicated order feature if order volume grows. For now, the current `checkout` order pages can stay, but split these concerns:

- order history
- order details
- shipment timeline
- invoice view

### `lib/features/vendor`

Add:

- `presentation/pages/vendor_wallet_page.dart`
- `presentation/pages/vendor_withdrawals_page.dart`
- `presentation/pages/vendor_disputes_page.dart`
- `presentation/pages/vendor_shipping_updates_page.dart`
- `data/datasources/vendor_wallet_remote_data_source.dart`
- `data/datasources/vendor_withdrawal_remote_data_source.dart`

### `lib/features/admin`

Add:

- `presentation/pages/admin_payments_page.dart`
- `presentation/pages/admin_withdrawals_page.dart`
- `presentation/pages/admin_disputes_page.dart`
- `presentation/pages/admin_seller_payouts_page.dart`
- `presentation/pages/admin_webhook_logs_page.dart`

### `lib/features/profile`

Add buyer profile sub-pages:

- addresses
- payout methods if seller
- KYC documents if seller
- notification preferences

### `lib/features/disputes`

New feature:

- `data`
- `domain`
- `presentation`

Responsibilities:

- open dispute
- upload evidence
- seller response
- admin resolution

## 3. Core Services To Add

Inside `lib/core/services`:

- `payment_service.dart`
- `wallet_service.dart`
- `notification_service.dart`
- `deep_link_service.dart`

## 4. Realtime Streams To Use

Use Supabase realtime on:

- `orders`
- `payments`
- `notifications`
- `withdrawals`
- `disputes`

This avoids manual refresh on payment success and seller dashboard changes.

## 5. Navigation Additions

Buyer bottom or profile routes:

- `My Orders`
- `Saved Addresses`
- `Support / Disputes`

Seller routes:

- `Dashboard`
- `Orders`
- `Wallet`
- `Withdrawals`
- `Disputes`

Admin routes:

- `Payments`
- `Withdrawals`
- `Disputes`
- `Sellers`
- `Payout Releases`

## 6. Minimal Checkout Integration Path

1. Keep the existing order creation flow.
2. After `place_order`, call the new Edge Function for online payment when method is `chargily`.
3. Open returned `checkout_url`.
4. Listen for `payments.status = paid` and update the UI.
5. If payment expires, let the buyer retry from order details.

## 7. Data Contracts Needed In Flutter

Create app-side models for:

- `Payment`
- `PaymentSession`
- `SellerWallet`
- `WalletTransaction`
- `Withdrawal`
- `Dispute`
- `ShipmentTrackingEvent`
- `OrderStatusHistory`

## 8. Recommended Immediate Implementation Order

1. online payment session
2. webhook-backed payment confirmation UI
3. seller wallet page
4. withdrawal request flow
5. admin payments and withdrawals pages
6. dispute flow
