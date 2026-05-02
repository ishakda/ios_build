# UI + Localization Audit Baseline

This document records the UI consistency and localization hardening pass completed for the current Sahla codebase.

## Scope

- Unify page shell style across features.
- Remove duplicate UI implementations.
- Replace user-facing hardcoded strings with localization keys.
- Improve operational status labels in admin workflows.
- Keep behavior stable while improving visual and language consistency.

## Completed Work

### 1. Page Shell Consistency

- Standardized most previously plain pages to `AppGradientScaffold`.
- Preserved custom gradient containers where already intentional (`home`, `profile`).

Representative updated pages:

- `checkout`, `order tracking`, `vendor orders`
- `notifications`
- product pages: listing, recently viewed, wishlist, write review
- profile pages: about, addresses, contact support, edit profile, order history, payment methods, store setup

### 2. Checkout + Payment UX

- Added payment method choice (`cod` / `chargily`) in checkout.
- Added retry payment from orders list.
- Added online payment flow messaging via localization keys.
- Added robust handling when payment page open fails (order remains created).

### 3. Order Model Hardening

- Added `paymentStatus` to `Order` entity and Hive adapter.
- Updated retry-payment eligibility logic to use payment status (not only order status).

### 4. Duplicate Page Cleanup

- Removed duplicate wishlist page implementation:
  - deleted `lib/features/wishlist/presentation/pages/wishlist_page.dart`
- Kept canonical wishlist page under product feature.

### 5. Localization Pass (Profile + Cross-Feature)

- Fully localized `About Us` content (all visible text).
- Localized legal pages content:
  - privacy policy sections
  - terms and conditions sections
  - effective date and section labels
- Localized remaining user-facing hardcoded strings in:
  - `home` drawer admin label
  - `vendor orders` delivered-confirmation dialog and button
  - `admin` status chips and status action labels
  - `admin` reporter/seller labels

## New / Expanded Localization Keys

Added/expanded in `en`, `ar`, `fr` (representative groups):

- payment flow:
  - `pay_now`
  - `chargily_online`
  - `chargily_online_desc`
  - `order_placed_payment_open`
  - `order_payment_open_failed`
- vendor delivery:
  - `mark_as_delivered`
  - `mark_order_delivered_title`
  - `mark_order_delivered_msg`
- admin status chips:
  - `status_pending_approval`
  - `status_approved`
  - `status_verified`
  - `status_cod_blocked`
  - `status_suspended`
- admin lifecycle status labels:
  - `status_open`
  - `status_in_progress`
  - `status_reviewing`
  - `status_resolved`
  - `status_closed`
  - `status_dismissed`
  - `status_rejected`
  - `status_refunded`
  - `reporter_label`
  - `seller_label`
- legal pages:
  - `legal_effective_date`
  - `privacy_intro`
  - `privacy_section_1..8_title/body`
  - `terms_intro`
  - `terms_section_1..8_title/body`
- about page:
  - `about_us_title`
  - `about_app_name`
  - `about_app_version`
  - `about_mission_title`
  - `about_mission_body`
  - `about_why_title`
  - `about_feature_auth_title/desc`
  - `about_feature_delivery_title/desc`
  - `about_feature_support_title/desc`

## Backend / Deployment Status

- Supabase migrations for marketplace payments and payment reuse were applied.
- Edge functions deployed:
  - `create-chargily-checkout`
  - `chargily-webhook`
  - `release-seller-payout`
  - `request-withdrawal`
- Chargily live secrets set:
  - `CHARGILY_SECRET_KEY`
  - `CHARGILY_PUBLIC_KEY`
- Remaining production secret to add later:
  - `CHARGILY_WEBHOOK_SECRET`

## Verification

- Static check run after each pass:
  - `dart analyze lib`
- Current result:
  - `No issues found`

## Remaining Optional Improvements

- Add localization keys for any future admin/vendor raw status values introduced later.
- Add a translation QA checklist before releases.
- Add lightweight widget golden tests for visual consistency across core page shells.
