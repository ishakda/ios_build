# Sahla

Sahla shopping app.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase Chat Media Migration

If you have older chat attachments stored under the legacy path layout
`chats/<userId>/<filename>`, migrate them before enforcing private chat-media
storage policies.

Run a dry run first:

```powershell
$env:SUPABASE_URL="https://your-project.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
dart run tool/migrate_chat_media.dart --dry-run
```

Then run the real migration:

```powershell
dart run tool/migrate_chat_media.dart
```

This utility moves storage objects to the new layout
`chats/<chatRoomId>/<senderId>/<filename>` and updates `public.messages.imageUrl`
to the new storage path.

## Runtime Config

The app currently expects these runtime values for production:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://xshodrfurizuvsabbbbs.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key `
  --dart-define=GOOGLE_WEB_CLIENT_ID=your-google-web-client-id `
  --dart-define=GOOGLE_IOS_CLIENT_ID=your-google-ios-client-id `
  --dart-define=ONESIGNAL_APP_ID=your-onesignal-app-id
```

If `ONESIGNAL_APP_ID` is not set, push initialization is skipped safely.

## Bootstrap First Admin

Create the future admin account normally first, either from the app or from the
Supabase dashboard. Then apply the latest database migrations and run the
bootstrap tool with a service role key.

Apply pending migrations:

```powershell
$env:SUPABASE_DB_PASSWORD="your-db-password"
supabase db push
```

Set the required env vars for the bootstrap tool:

```powershell
$env:SUPABASE_URL="https://your-project.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
```

Run a dry run:

```powershell
dart run tool/bootstrap_first_admin.dart --email=admin@example.com --dry-run
```

Promote the account:

```powershell
dart run tool/bootstrap_first_admin.dart --email=admin@example.com
```

You can also target a specific auth user directly:

```powershell
dart run tool/bootstrap_first_admin.dart --user-id=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Safety rules:

- the SQL function only executes for `service_role`
- the bootstrap refuses to run if any `public.users.role = 'admin'` already exists
- the target account is promoted in both `public.users` and `auth.users` metadata

## Google Sign-In

Android Google sign-in uses the Firebase OAuth setup for package
`com.sahla.algeria`. The current Firebase config contains:

- Android SHA-1: `6D:5C:5C:00:1C:37:9A:A4:29:57:E5:C7:67:51:32:E3:3D:3C:4D:57`
- Web client ID:
  `531932731672-p22vujs7il43unuock2p5uc6t6h4601n.apps.googleusercontent.com`

For Supabase Google auth to work, this same web client ID must be configured in:

- Supabase Dashboard -> Authentication -> Providers -> Google
- app runtime via `GOOGLE_WEB_CLIENT_ID`

If Android still shows `Google Sign-In Error (10)`, check:

- the installed app package is `com.sahla.algeria`
- the Firebase Android OAuth client includes the SHA-1 above
- the Supabase Google provider uses the same Google project and web client ID

## Firebase Migration Toolkit

These scripts help migrate Firebase data into Supabase using exports and a
Supabase service role key.

Required env vars:

```powershell
$env:SUPABASE_URL="https://your-project.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
```

### 1. Export Firebase Auth Users

```powershell
firebase auth:export firebase_auth_users.json --format=json
dart run tool/import_firebase_auth_users.dart --input=firebase_auth_users.json --dry-run
dart run tool/import_firebase_auth_users.dart --input=firebase_auth_users.json
```

This writes `firebase_uid_map.json`, which maps Firebase UIDs to new Supabase
auth user IDs. Because Supabase auth IDs are different, import auth users
before relational data.

### 2. Export Firebase Realtime Database

Export your RTDB JSON however you prefer, then import it:

```powershell
dart run tool/import_firebase_rtdb.dart --input=firebase_rtdb_export.json --uid-map=firebase_uid_map.json --dry-run
dart run tool/import_firebase_rtdb.dart --input=firebase_rtdb_export.json --uid-map=firebase_uid_map.json
```

The importer rewrites user references using `firebase_uid_map.json` for these
tables:

- `users`
- `products`
- `reviews`
- `chats`
- `messages`
- `orders`
- `notifications`
- `addresses`
- `paymentMethods`
- `storeFollowers`

### 3. Export Firebase Storage Files

If you already have a local export, upload the directory into the target
Supabase bucket:

```powershell
dart run tool/upload_directory_to_supabase_storage.dart --dir=firebase_storage_export --bucket=product-media --dry-run
dart run tool/upload_directory_to_supabase_storage.dart --dir=firebase_storage_export --bucket=product-media
```

Optional:

- use `--prefix=...` to upload under a subfolder in the Supabase bucket

### 4. Copy Firebase Storage Bucket Directly

If `firebase login` is already completed on this machine, you can copy the live
Firebase Storage bucket directly into the app's Supabase buckets:

```powershell
$env:SUPABASE_URL="https://your-project.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
dart run tool/migrate_firebase_storage_to_supabase.dart --dry-run
dart run tool/migrate_firebase_storage_to_supabase.dart
```

This script:

- reads the Firebase CLI access token from the local machine
- lists the live Firebase Storage bucket
- copies `profiles/` into `user-profiles`
- copies `stores/` into `store-media`
- copies `products/` into `product-media`
- copies `chats/` into `chat-media`
- writes `firebase_storage_map.json` so later database imports can rewrite old
  Firebase URLs to Supabase storage values automatically

If you import RTDB data after that, pass the generated map file so image fields
are rewritten during import:

```powershell
dart run tool/import_firebase_rtdb.dart --input=firebase_rtdb_export.json --uid-map=firebase_uid_map.json --storage-map=firebase_storage_map.json
```

Notes:

- Auth passwords are not copied from Firebase into Supabase by these scripts.
  Imported users get new temporary passwords, and the generated
  `firebase_uid_map.json` includes them.
- For Google users, once the Google provider is configured correctly in
  Supabase, they can sign in again with Google after import.
