# ATL Project 2

Flutter implementation of the synopsis project: a distributed campus event management client with AES-backed admin access, public-by-default behavior, and a modern animated UI.

## What It Does

- Boots in standard mode with a campus event feed.
- Shows public events immediately.
- Hides private events entirely until a valid admin passphrase is stored locally.
- Uses `AES` to protect private event payloads.
- Lets admins create and edit events after unlocking administrative access.
- Signs every event before persistence and verifies the signature on load to mimic backend integrity checks.
- Persists the event feed and stored keys locally with `flutter_secure_storage`.

## How To Access Features

1. Run the app with `flutter run`.
2. Tap the settings icon, or long-press the top bar title `Campus Events`, to open `Access settings`.
3. Use the demo admin passphrase:

### AES Demo Passphrase

```text
MIT-ZEROTRUST-AES-2026
```

## Feature Walkthrough

- `Feed` tab:
  - Browse public events in standard mode.
  - Browse both public and private events in admin mode.
  - Filter `All`, `Public`, and `Private` in admin mode.
  - Tap an event card for a fuller detail view.
  - In admin mode, use the floating action button to create events.
  - In admin mode, editable events show an edit icon.

## UI Notes

- Custom animated aurora/grid background
- Staggered feed-card reveal animations
- Non-default high-contrast palette for a security-focused visual identity
- Animated tab switcher, filter chips, and modal surfaces
