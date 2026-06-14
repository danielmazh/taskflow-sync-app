# Google Play Store Listing — copy-paste sheet

Console path: **Play Console → All apps → TaskFlow Sync → Grow → Store presence → Main store listing**.

> Play account creation, identity verification, and the 12-tester / 14-continuous-day closed-test requirement are **human + time-gated** — see `docs/play-testing.md`. There is no API for the store listing or data-safety form.

---

## App identity

| Field | Value |
|---|---|
| App name (max 30 chars) | `TaskFlow Sync` |
| Short description (max 80 chars) | `Fast, offline task manager with reliable reminders and optional Calendar sync.` |
| Default language | `English (United States) – en-US` |
| Package name (Android) | `com.example.taskflow_sync` *(confirm actual `applicationId` from Phase 4 build before publishing — Play does not let you change it later)* |

## Full description (max 4000 chars — ~720 chars used)

```
TaskFlow Sync is a simple, offline-first task manager built for people who want
their reminders to fire on time and their tasks to stay on their device.

• Capture fast — type a task or use voice input.
• Reliable reminders — exact-time alarms that survive reboot, Doze, and aggressive
  OEM battery savers.
• Snooze, complete, archive — one tap each.
• Weekly stats — see your on-time completion rate at a glance.
• Optional Google Calendar sync — choose per-task whether to mirror to your
  calendar. Nothing else syncs anywhere.
• No accounts required. No backend. Tasks live on your device by default.

We never sell your data. We never share it. We do not use your data to train AI.
Read the full privacy policy at https://danielmazh.github.io/taskflow-sync-app/privacy-policy.html.
```

## What's new (max 500 chars — for first release)

```
First release. Offline task manager, reliable reminders, optional Google Calendar sync.
```

---

## Content rating (IARC questionnaire)

Answer **No** to every category except where noted. The expected rating is **Everyone / PEGI 3 / ESRB E**.

| Question category | Answer |
|---|---|
| Violence | No |
| Sexuality | No |
| Profanity | No |
| Controlled substances | No |
| Gambling, simulated gambling | No |
| User-generated content shared with other users | No |
| Personal info shared with other users | No |
| Location shared with other users | No |
| Digital purchases | No |
| Unrestricted internet (the app loads arbitrary web content) | No |
| Miscellaneous (e.g. horror, fear) | No |

---

## Target audience and content

| Field | Value |
|---|---|
| Target age group | `18+` *(simplest path; if you must target younger ages, add the Families program compliance which is a separate review)* |
| Appeals to children? | **No** |
| Ads in the app? | **No** |

---

## Data safety — copy-paste answers

Console path: **Play Console → App content → Data safety**. The form must be re-saved any time you change scopes or behavior.

### Section 1 — Data collection &amp; security

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** (we access Google account email + Calendar via OAuth — Google treats OAuth-scoped data as "collected" for this form even though we don't store it server-side) |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS to Google APIs) |
| Do you provide a way for users to request that their data is deleted? | **Yes** — uninstall + revoke at `myaccount.google.com/permissions` |

### Section 2 — Data types

| Data type | Collected? | Shared? | Optional? | Purpose | Notes |
|---|---|---|---|---|---|
| Personal info → Email address | **Yes** | No | Yes (only if user signs in) | App functionality | Used as the OAuth principal; not stored on any server we operate |
| Calendar → Calendar events | **Yes** | No | Yes (only if user enables Calendar sync) | App functionality | Scope `calendar.events`; app only manages events it created |
| Photos and videos | No | – | – | – | – |
| Audio → Voice or sound recordings | **No** | – | – | – | `speech_to_text` returns text on-device; we do not retain audio |
| App activity → App interactions | No | – | – | – | – |
| Device or other IDs | No | – | – | – | – |
| Files and docs | No | – | – | – | – |

> Important phrasing: under "Used for app functionality" — **not** "Analytics", **not** "Advertising or marketing", **not** "Fraud prevention, security, and compliance" beyond what is implicit in OAuth, **not** "Personalization", **not** "Account management" (Google manages the account, not us).

### Section 3 — Security practices

| Question | Answer |
|---|---|
| Is your data encrypted in transit? | **Yes** |
| Can users request their data be deleted? | **Yes** (see above) |
| Have you committed to following the Play Families Policy? | **No** (we do not target children) |
| Have you been independently validated against a security standard? | **No** |

---

## Screenshots &amp; graphics (BLOCKED on Phase 4 build)

| Asset | Spec | Status |
|---|---|---|
| App icon | 512×512 PNG, 32-bit, opaque | BLOCKED — operator to supply |
| Feature graphic | 1024×500 JPG/PNG, no transparency | BLOCKED — operator to supply |
| Phone screenshots | min 2, max 8, 16:9 or 9:16, 1080×1920 typical | Capture from Phase 4 release build |
| 7-inch tablet screenshots | Optional (we target phones first) | Skip for v1 |
| 10-inch tablet screenshots | Optional | Skip for v1 |
| Promo video | Optional YouTube URL | Skip for v1; demo video is for OAuth verification, not Play |

Suggested phone screenshot sequence:
1. Home — list with a few tasks, one with a due-time chip.
2. Add-task sheet open, with the quick-time chips visible.
3. Task being created via voice (mic indicator visible).
4. Weekly stats screen.
5. A reminder notification on the lock screen.
6. Settings → "Sync with Google Calendar" toggle on.
