# OAuth Verification — checklist + demo-video script

Required when the app moves from **Testing** → **In production** with any sensitive or restricted scope. `calendar.events` is **Sensitive** (not Restricted) so the third-party security assessment is NOT required; brand + domain + scope justification + demo video are.

Submit via: **Cloud Console → APIs &amp; Services → OAuth consent screen → Audience → Publish app → Prepare for verification**. There is no API for submission — every step is a manual click.

> ⚠️ **Blocker:** the demo video requires the Phase 4 consent flow to actually exist in the app (Google Sign-In button, calendar.events grant prompt, event-create round-trip visible in Google Calendar). **Do not record the video until the coding agent finishes Phase 4** and produces a release-mode debuggable build.

---

## Pre-submission checklist

- [ ] **Branding** complete and saved (`docs/oauth-consent.md` → Branding).
- [ ] **Authorized domain** verified for ownership in **Search Console** with the same Google Account that owns the Cloud project. Verification method: DNS TXT record OR HTML file upload. **Allow up to 24h after DNS change.**
- [ ] **Privacy policy URL** is live on the authorized domain, reachable over HTTPS, returns 200, and discloses the `calendar.events` scope use exactly as in `privacy-policy.html`.
- [ ] **Homepage URL** is live on the authorized domain, returns 200, and is on the same registrable domain as the privacy policy.
- [ ] **App logo** (120×120 PNG, square, opaque) uploaded in Branding.
- [ ] **Scopes** list contains `calendar.events` only (and any default OpenID Connect scopes the form pre-checks).
- [ ] **Scope-justification text** pasted from `docs/oauth-consent.md`.
- [ ] **Test users** include the reviewer's Gmail address Google asks you to add (the verification team will tell you).
- [ ] **YouTube demo video** uploaded (Unlisted), URL captured. Script below.
- [ ] **Production publishing** toggle set to "In production" *before* submitting verification (publishing-status mismatch is the #1 rejection reason).

---

## Demo video — script / storyboard

Target length: 60–120 seconds. Unlisted YouTube link. Show the literal OAuth flow with the **exact** OAuth client ID visible in the consent dialog URL bar (verifier checks it matches the project under review).

### Shot list

| # | Shot | What to say (voice or captions) |
|---|---|---|
| 1 | **Cloud Console OAuth client page**, mouse cursor over the client ID, then zoom on URL bar showing `taskflow-sync-499408`. | "This is OAuth client `…2hgq407fd6pp5elmov50kgqsi53a8jiu` in project `taskflow-sync-499408`, the project being verified." |
| 2 | App home screen on Android device. | "TaskFlow Sync, a task manager. The app works fully offline by default." |
| 3 | Tap **Settings → Sync with Google Calendar → Sign in**. | "The user chooses to enable Google Calendar sync. They tap Sign in." |
| 4 | Google account chooser, then consent screen. **Pause on consent screen.** Zoom on the requested-permission line ("See, edit, share, and permanently delete all the calendars you can access using Google Calendar" wording variant for `calendar.events`). | "The user grants the single scope `calendar.events`. No other scopes are requested." |
| 5 | Return to app; show the success state. | "Sign-in complete." |
| 6 | Create a new task with a due time 5 minutes in the future. Tap **Sync to Calendar** on the task. | "The user creates a task and chooses to sync it." |
| 7 | Switch to Google Calendar app on the same device. Show the new event appears at the correct time, with title matching the task. | "TaskFlow Sync uses `calendar.events` to create the event." |
| 8 | Edit the task title in TaskFlow Sync. Switch back to Calendar. Show the event title updated. | "Updates propagate. The app uses `events.patch` on the same event." |
| 9 | Delete the task in TaskFlow Sync. Switch to Calendar. Show the event is gone. | "Delete the task, the event is deleted. The app only touches events it created." |
| 10 | Open Google Calendar's other calendars list to make a point: TaskFlow Sync never reads them. | "The app never enumerates or reads events it did not create." |
| 11 | (Optional) Open Android Settings → Accounts → Google → permissions, show the user can revoke at `myaccount.google.com/permissions`. | "Revoking access is one tap away." |

### Recording mechanics

- Use `adb shell screenrecord /sdcard/demo.mp4 --bit-rate 8000000` then `adb pull` to host machine.
- Or use Android Studio's built-in screen recorder.
- Burn-in captions (no voice required, but voice helps).
- **Do not** show real user data — use a fresh Google account or one already on the test-users list.

---

## After submission

- Google's response SLA is "several business days" but in practice 2–6 weeks for first-time sensitive-scope verification.
- They will email questions. Reply on the same thread; do not start a new submission.
- Common rejections: privacy policy doesn't mention the exact scope by name; demo video doesn't show the consent screen; homepage and privacy URL are on different registrable domains; app logo too small or transparent.
