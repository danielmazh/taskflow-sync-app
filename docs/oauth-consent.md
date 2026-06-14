# OAuth Consent Screen — copy-paste sheet

Console path: **Google Cloud Console → APIs &amp; Services → OAuth consent screen** (project `taskflow-sync-499408`, number `552734224992`).

> Note: the Cloud Console UI was reorganized in 2025 into **Branding**, **Audience**, **Data Access**, **Clients**. The OAuth consent screen content is now split across the first three. There is no public API for any of this — every step below is a manual click.

---

## Branding

| Field | Value |
|---|---|
| App name | `TaskFlow Sync` |
| User support email | `daniel.mazhbits@gmail.com` |
| App logo | 120×120 PNG, square, non-transparent (BLOCKED — operator to supply) |
| Application home page | `https://taskflowsync.xyz/` — e.g. `https://taskflow-sync.example.com/` |
| Application privacy policy link | `https://taskflowsync.xyz/privacy-policy.html` — e.g. `https://taskflow-sync.example.com/privacy-policy.html` |
| Application terms of service link | *(optional — leave blank for v1)* |
| Authorized domains | `github.io` — e.g. `taskflow-sync.example.com` (top-level only, no scheme, no path) |
| Developer contact email(s) | `daniel.mazhbits@gmail.com` |

---

## Audience

| Field | Value |
|---|---|
| User type | **External** |
| Publishing status | **Testing** → submit for **In production** once verification is approved |
| Test users (while in Testing) | Add yourself + every closed-test tester email (max 100 during Testing) |

---

## Data Access — scopes

Add **exactly one** non-sensitive scope. Do **not** add `.../auth/calendar` (full read/write of all calendars) — only the scoped variant.

| Scope | Why we need it |
|---|---|
| `https://www.googleapis.com/auth/calendar.events` | Create, update, and delete calendar events for tasks the user has explicitly chosen to sync. No access to other calendars, contacts, Drive, or Gmail. |

> `calendar.events` is classified by Google as a **Sensitive** scope (not Restricted). It still requires verification before production but does not require an annual third-party security assessment.

### Scope-justification paragraph (paste verbatim)

> TaskFlow Sync is an offline-first Android task manager. When a user opts in to "Sync with Google Calendar," the app uses the `calendar.events` scope to create one calendar event per synced task, update that event if the task's title or due time changes, and delete it if the task is deleted or unsynced. The app never reads events it did not create, never modifies events owned by other apps, and never accesses other Google services. All event writes are initiated by an explicit user action in the app; there is no background sync of unselected tasks. The narrower `calendar.events` scope (vs. full `calendar`) is sufficient because the app only manages its own events.

---

## Clients

Two OAuth 2.0 Client IDs already exist in the project (verified read-only from local client-secret JSONs):

| Client ID | Type | Use |
|---|---|---|
| `552734224992-2hgq407fd6pp5elmov50kgqsi53a8jiu.apps.googleusercontent.com` | **Web application** (has `client_secret`) | Server-side / exchange of `serverAuthCode`; pass as `serverClientId` to `google_sign_in` so the ID token's `aud` matches |
| `552734224992-2fb6n2vh9pmans1fmcb315shmhas50bb.apps.googleusercontent.com` | **Installed** (Desktop) — flagged below | ⚠️ Not the right type for Android |

> ⚠️ **Flag for operator:** the second client's JSON has the `"installed"` key with no `client_secret` and no `redirect_uris` — that is Google's **Desktop app** client shape, not Android. **Android OAuth clients are identified by package name + SHA-1 only and produce no downloadable JSON.** Two possibilities:
> 1. The Android OAuth client exists separately in the console (correct configuration) and the "installed" file is an unused/leftover Desktop client → confirm in console and consider deleting the Desktop client.
> 2. The Android OAuth client was never created → create it in console (package `com.example.taskflow_sync` — confirm the actual `applicationId` once Phase 4 ships — with debug SHA-1 below; later add release SHA-1 from Play App Signing).

### Android OAuth client — fingerprints to register

| Fingerprint | Value | When |
|---|---|---|
| Debug SHA-1 (local builds) | `B0:10:0F:60:A7:1A:DD:C3:8E:F7:B2:61:1E:1F:53:60:13:85:87:65` | Add now; needed for testing the Phase 4 consent flow on debug builds |
| Release SHA-1 (Play App Signing) | *unknown until first upload* | Add **after** uploading the first AAB; Google generates this in Play Console → Setup → App signing |

Re-verify the debug SHA-1 anytime with: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`.
