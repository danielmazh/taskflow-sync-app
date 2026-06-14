# TaskFlow Sync — Production Setup Runbook

A single ordered list of **every human click** the operator must perform. Each step links to a prep doc and flags its dependencies. This agent prepared the files; the operator owns the clicks.

> **Legend**
> · ⛔ **BLOCKED** — depends on something not yet done (flagged below the step)
> · 🟢 **READY** — prep doc exists, no upstream blocker
> · 🕒 **TIME-GATED** — Google enforces a wait
> · 👤 **HUMAN ONLY** — no API, console click required

---

## Phase R0 — Prerequisites you control (do these first, in any order)

### R0.1 🟢 👤 Decide and reserve a domain
- Pick a registrable domain for the homepage + privacy policy. Both URLs must share the same domain (Google verification requirement).
- Suggested: `taskflow-sync.app` or any `.com`/`.dev` you own.
- Output: replace `{{AUTHORIZED_DOMAIN}}`, `{{HOMEPAGE_URL}}`, `{{PRIVACY_URL}}` placeholders across `docs/`.

### R0.2 🟢 👤 Decide a support email
- A real inbox that can answer user mail. Recommended: a Google Workspace alias or a free `+taskflow` alias on an account you own.
- Output: replace `{{SUPPORT_EMAIL}}` everywhere in `docs/`.

### R0.3 🟢 👤 Host the two static files
- Files to host: `docs/index.html` and `docs/privacy-policy.html` (already generated).
- Hosting options that satisfy Google's reachability checks: GitHub Pages, Cloudflare Pages, Netlify, Firebase Hosting, S3+CloudFront, any plain HTTPS host.
- After hosting, verify both URLs return **HTTP 200** from a clean browser (no auth wall, no Cloudflare bot challenge, no robots block on the privacy URL).
- Output: the two live URLs.

### R0.4 🟢 👤 Verify domain ownership in Google Search Console
- https://search.google.com/search-console → Add property → choose **Domain** (DNS TXT, preferred) or **URL prefix** (HTML file).
- Use the **same Google Account** that owns the Cloud project `taskflow-sync-499408`.
- Wait until Search Console shows "Ownership verified" (DNS can take up to 24h).

---

## Phase R1 — Cloud project state fixes (operator console)

### R1.1 ⛔ 👤 Enable Calendar API
- **BLOCKER** — verified read-only that `calendar.googleapis.com` is **not enabled** in project `taskflow-sync-499408`. Phase 4 cannot work without this.
- Console: APIs &amp; Services → Library → search "Google Calendar API" → **Enable**.

### R1.2 ⛔ 👤 (Optional but recommended) Enable IAM API + Cloud Resource Manager API
- Verified read-only that neither is enabled. They're not required for end-user OAuth/Calendar, but enabling Resource Manager lets future read-only verification (`gcloud projects describe`) work.
- Skip if you want to stay minimal.

### R1.3 ⛔ 👤 Decide on OAuth client cleanup (see flag in `docs/oauth-consent.md`)
- Two OAuth clients exist locally:
  - **Web** client `…2hgq407fd6pp5elmov50kgqsi53a8jiu` — keep, use as `serverClientId`.
  - **Installed (Desktop)** client `…2fb6n2vh9pmans1fmcb315shmhas50bb` — likely unused; an Android client is what you need.
- Console: APIs &amp; Services → Credentials → check the **type** column of every OAuth client.
  - If an **Android** client already exists, you're fine — delete the Desktop client.
  - If not, click **Create credentials → OAuth client ID → Android**, set:
    - Package name: confirm from Phase 4 build's `applicationId` (likely `com.example.taskflow_sync`).
    - SHA-1: `B0:10:0F:60:A7:1A:DD:C3:8E:F7:B2:61:1E:1F:53:60:13:85:87:65` (debug).

---

## Phase R2 — OAuth consent screen (operator console)

### R2.1 ⛔ 👤 Fill Branding
- Path: APIs &amp; Services → OAuth consent screen → Branding.
- Inputs from: `docs/oauth-consent.md` → Branding.
- Depends on: R0.1, R0.2, R0.3, R0.4.

### R2.2 ⛔ 👤 Configure Audience
- External; status Testing; add yourself + a few seed test users.
- Inputs from: `docs/oauth-consent.md` → Audience.

### R2.3 ⛔ 👤 Add the scope
- Path: Data Access → Add or remove scopes → check `https://www.googleapis.com/auth/calendar.events`.
- Paste the scope-justification paragraph from `docs/oauth-consent.md`.
- Depends on: R1.1 (Calendar API must be enabled before the scope can be selected).

---

## Phase R3 — Coding-agent dependency: Phase 4 build

### R3.1 ⛔ Wait for Phase 4 to land
- **BLOCKER** — `docs/oauth-verification.md` demo video, all Play screenshots, and the App Signing SHA-1 cross-link all require a working Phase 4 build with:
  - Google Sign-In button wired to the Web OAuth client as `serverClientId`.
  - Consent flow that requests `calendar.events`.
  - Per-task "Sync to Calendar" creating an event via `events.insert`.
  - Edit/delete round-trip working.
- Coding agent is operating in parallel. **Do not start R4, R5, R6 until coding agent reports Phase 4 DONE.**

---

## Phase R4 — OAuth verification submission (operator console)

### R4.1 ⛔ 🕒 👤 Record demo video
- Follow the shot list in `docs/oauth-verification.md` → Demo video.
- Upload to YouTube as **Unlisted**.
- Depends on: R3.1.

### R4.2 ⛔ 🕒 👤 Submit for verification
- Path: OAuth consent screen → Publish app → Prepare for verification.
- Pre-submission checklist: `docs/oauth-verification.md` → Pre-submission checklist.
- Depends on: R2.*, R4.1.
- SLA: 2–6 weeks for first-time sensitive-scope verification.

---

## Phase R5 — Play Console setup (operator console)

### R5.1 ⛔ 🕒 👤 Create + identity-verify Play developer account
- One-time, $25 USD, requires government ID and a couple of business days for identity verification.
- Skip if already done.

### R5.2 ⛔ 👤 Create the app in Play Console
- App name: `TaskFlow Sync`. Default language: en-US. Free, App. Confirm Play policies.

### R5.3 ⛔ 👤 Enable Play App Signing &amp; upload first AAB
- Generate or import an upload key on your workstation:
  - `keytool -genkey -v -keystore taskflow-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`
  - Store the keystore + passwords in a password manager. **Do not commit.**
- Build a signed release AAB: `flutter build appbundle --release`.
- Upload to Play Console → Testing → Closed testing → Create track → upload AAB.
- **After upload:** Play Console → Setup → App signing → copy the **App Signing certificate SHA-1**.

### R5.4 ⛔ 👤 Cross-link Play App Signing SHA-1 to Android OAuth client
- Cloud Console → APIs &amp; Services → Credentials → Android OAuth client (the one created in R1.3) → add the **release** SHA-1 from R5.3.
- Without this, real Play-installed builds will fail Google Sign-In.

### R5.5 ⛔ 👤 Fill store listing + content rating + target audience
- Inputs from: `docs/play-listing.md`.
- Screenshots: capture from the Phase 4 release build per the suggested sequence in `docs/play-listing.md`.

### R5.6 ⛔ 👤 Fill Data Safety
- Inputs from: `docs/play-listing.md` → Data safety — copy-paste answers.

---

## Phase R6 — Closed testing (operator + testers)

### R6.1 ⛔ 🕒 👤 Recruit ≥12 testers and run for ≥14 continuous days
- Plan: `docs/play-testing.md`.
- Depends on: R5.3 (AAB live in the closed track).
- This is the wall-clock long pole **inside operator control**. Start as soon as Phase 4 is buildable; can overlap with R4 (OAuth verification).

### R6.2 ⛔ 🕒 👤 Apply for production access
- Path: Play Console → Apply for production access.
- Reviewer SLA: a few days to ~2 weeks.
- Depends on: R6.1, and OAuth verification approved if you want first launch to allow Calendar sync for non-test users.

---

## Phase R7 — Launch

### R7.1 ⛔ 👤 Promote AAB to Production
- Path: Play Console → Production → Create new release → "Choose from existing track" → pick the closed-12 build.
- Roll out at 20%, watch crash-free for a day, then 100%.
- Depends on: R6.2 approved **and** OAuth verification approved (R4.2).

### R7.2 🟢 👤 Flip OAuth consent to **In production**
- Path: OAuth consent screen → Audience → Publishing status → **In production**.
- Required so non-test users can sign in.

### R7.3 🟢 👤 Sanity-check the live build
- Fresh Google account on a fresh device → install from Play → sign in → sync one task → confirm event appears in Calendar.

---

## Critical-path summary (longest wall-clock chain)

```
R0.1–R0.4 (you, ~1 day)
  → R1.1, R2.* (you, ~30 min)
    → coding agent Phase 4 (parallel, gates R4 + R5.3 onward)
      → R4 OAuth verification (Google, 2–6 weeks)  ──┐
      → R5.3 closed track + R6.1 14 days (~2 weeks) ┤
      → R6.2 production access (Google, ~1 week)    ┤
                                                      → R7 launch
```

OAuth verification and Play closed-test can run in parallel — start both the moment Phase 4 is buildable. Don't wait for one to finish before starting the other.
