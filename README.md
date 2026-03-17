# ATL Project 2

Flutter implementation of the synopsis project: a distributed campus event management client with cryptographic access control, read-only default behavior, hidden key-custodian activation, and a modern animated UI.

## What It Does

- Boots in read-only mode with a campus event feed.
- Shows public events immediately.
- Keeps protected event payloads unreadable until a valid key is stored locally.
- Supports two protected routes:
  - `AES` passphrase protected events
  - `RSA` envelope protected events
- Lets custodians create and edit events after unlocking administrative access.
- Signs every event before persistence and verifies the signature on load to mimic backend integrity checks.
- Persists the event feed and stored keys locally with `flutter_secure_storage`.

## How To Access Features

1. Run the app with `flutter run`.
2. Long-press the top bar title `Campus Grid` to open the hidden `Key Custodian Console`.
3. Use either or both demo credentials:

### AES Demo Passphrase

```text
MIT-ZEROTRUST-AES-2026
```

### RSA Demo Private Key

```text
-----BEGIN PRIVATE KEY-----
MIICdgIBADANBgkqhkiG9w0BAQEFAASCAmAwggJcAgEAAoGBANWUAi39L13/pGnM
lsD0XCmNaE0vN7e14JftCriU3DKnqbNnCdBiS63wwEcgLeBAFyDuyR9dG8sUrxyI
8LxGzqtTtI+LFo4Cj5i9JrmGe+461qTLyKXhajZJxKDhu3do7LuByLlPpfKWLZv1
nioGawiRNsq8zWfzz3IuakaY2dvXAgMBAAECgYBfoDBFpQmzPYXAtRB+fipRlHWx
sUVyJKXVgBV/xW6942HQ6H51Zb1auONuNRM1R5zTavZz631JNQ6eaRXYRp+7NnNC
JfmuhkTWA3JqyJ1tTiiQ/phS4QfvvB/JmHGeG50y5RmbgyhX+z93jSINY0Df2E+v
JgcCvyvwMJTg7I/jSQJBAPG1mznuZlirfLMOtSIU8vqtIGD7inwR4sqPvVnGpOFX
HiMswC/Fh1U/cMHY5khSrHK9zbm5qVnBGfJTtNt9+sMCQQDiNJ8jgOmf9+BloF5m
ynmlBG/uT1uu0JXWMWkDKRFngsh07j0mlAbkSDTPsA9OZzOMiPVsn521jt6NDwbp
yQFdAkBAZvkjKGhQu/CP7R1KJXbQYAy+iodNo55gBoiXQRxxhjrbeHMEx4bVqf+r
RtWk85JLSFNmZxe+eHsnXDJWQWztAkBz68WV2y1eZhff3KQkByT5lOGLfa2dU5VF
tAJ9tSEPK61whtpdl8REXmB6Al6FrktzfIhRByc58KJKJWZEjladAkEAijJrr/ld
Wp36z6uWeADyqyJ8KzK3ox3ExbKuOEkwFXJmM0O4p3O8asTAShOPIDU4wHKL4eHB
QP9x5nDYscBD6A==
-----END PRIVATE KEY-----
```

## Feature Walkthrough

- `Feed` tab:
  - Browse all events.
  - Filter `All`, `Public`, and `Encrypted`.
  - Tap an event card for a fuller detail view.
  - In admin mode, use the floating action button to create events.
  - In admin mode, editable events show an edit icon.
- `Protocol` tab:
  - Review architecture mapping to the synopsis.
  - Copy the demo AES key or RSA private key.
  - Reset the seeded demo feed.

## UI Notes

- Custom animated aurora/grid background
- Staggered feed-card reveal animations
- Non-default high-contrast palette for a security-focused visual identity
- Animated tab switcher, filter chips, and modal surfaces
