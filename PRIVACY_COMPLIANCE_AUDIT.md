# Privacy & Compliance Audit — Travel Expenses Pro
**Stage:** 1.8.1.4  
**Date:** 2026-06-02  
**Auditor:** AI Audit (read-only, no code modified)  
**App ID:** `com.calmledger.android`

---

## 1. Android Permissions

### Production (`AndroidManifest.xml` — main)

| Permission | Found? | Notes |
|---|---|---|
| INTERNET | ❌ No | NOT declared in release manifest |
| CAMERA | ❌ No | Not requested |
| READ_EXTERNAL_STORAGE | ❌ No | Not requested |
| WRITE_EXTERNAL_STORAGE | ❌ No | Not requested |
| ACCESS_FINE_LOCATION | ❌ No | Not requested |
| ACCESS_COARSE_LOCATION | ❌ No | Not requested |
| READ_CONTACTS | ❌ No | Not requested |
| PHONE_STATE | ❌ No | Not requested |
| BLUETOOTH | ❌ No | Not requested |
| RECEIVE_BOOT_COMPLETED | ❌ No | No background boot service |
| BIOMETRIC | ❌ No | Not requested |

**Result: Zero runtime permissions declared in the production manifest. Excellent.**

### Debug & Profile Manifests

`INTERNET` is declared in **debug** and **profile** manifests only — standard Flutter development requirement for hot reload. This permission is **NOT** present in the release/production manifest and will NOT appear in the published APK/AAB.

### Android `<queries>` block

`android.intent.action.PROCESS_TEXT` — used by the Flutter engine's `ProcessTextPlugin` for text selection actions. Does not collect or share data.

---

## 2. External SDKs & Libraries

### Flutter Dependencies (`pubspec.yaml`)

| Package | Version | Category | Privacy Risk |
|---|---|---|---|
| `flutter_riverpod` | ^2.6.1 | State management | ✅ None — local only |
| `sqflite` | ^2.4.2 | Local database | ✅ None — on-device SQLite |
| `shared_preferences` | ^2.2.0 | Local key-value store | ✅ None — on-device only |
| `path_provider` | ^2.1.5 | File system paths | ✅ None — no network |
| `path` | ^1.9.1 | Path utilities | ✅ None |
| `intl` | ^0.20.2 | Localization/formatting | ✅ None — no network |
| `uuid` | ^4.5.1 | UUID generation | ✅ None — local IDs only |
| `pdf` | ^3.11.3 | PDF generation | ✅ None — local file creation |
| `file_picker` | ^8.3.7 | File selection UI | ⚠️ Low — triggers OS file picker; no data sent externally |
| `share_plus` | ^10.1.4 | OS share sheet | ⚠️ Low — user-initiated sharing via OS; no data sent by app |
| `cupertino_icons` | ^1.0.8 | UI icons | ✅ None |
| `flutter_localizations` | SDK | i18n | ✅ None |

### Analytics / Tracking / Advertising SDKs

| SDK Type | Found? |
|---|---|
| Firebase Analytics | ❌ Not present |
| Firebase Crashlytics | ❌ Not present |
| Google Analytics | ❌ Not present |
| Facebook SDK | ❌ Not present |
| Mixpanel | ❌ Not present |
| Amplitude | ❌ Not present |
| Segment | ❌ Not present |
| Sentry | ❌ Not present |
| Adjust / AppsFlyer | ❌ Not present |
| AdMob / Advertising | ❌ Not present |
| Any crash reporter | ❌ Not present |

**Result: Zero analytics, tracking, or advertising SDKs. Excellent.**

### Native Android Dependencies (build.gradle)

- `com.android.application` — standard Android build plugin
- `kotlin-android` — standard Kotlin plugin
- `dev.flutter.flutter-gradle-plugin` — official Flutter tooling

No third-party native SDKs added at the Gradle level.

---

## 3. Data Collected (On-Device Only)

All data is stored exclusively on-device in SQLite (`sqflite`) and `SharedPreferences`. No data leaves the device except via explicit user-initiated actions.

### SQLite Tables & Data Stored

| Table | Data Fields |
|---|---|
| `trips` | Trip name, destination, country code, dates, currency codes, budget amount |
| `expenses` | Title, amounts (multi-currency), transaction amounts, fees, category, payment method, date, notes, card reference |
| `settings` | Home currency code, locale code |
| `cards` | Card name/display name, bank name, card network, card tier |
| `user_financial_profile` | Home country code, home country name (EN/AR), home currency code, onboarding status |
| `trip_cash_balances` | Cash balance amounts per currency per trip |
| `cash_transactions` | Amount, currency, type, notes, timestamps |
| `manual_exchange_rates` | Currency pair, rate, trip reference |

### SharedPreferences Data

- `_hasEverHadTrips` — boolean flag for onboarding UI state
- `_prefsLastCategoryKeyForTrip` — last selected category (UX memory)
- `_prefsAmountMemoryKeyForTrip` — amount memory for Quick Add

### What Is NOT Collected

- No name, email, phone, or any PII of the user
- No device identifiers (IMEI, Android ID, Advertising ID)
- No IP address
- No location/GPS data
- No contacts
- No biometric data
- No crash reports or diagnostic data sent externally

---

## 4. Data Shared

| Sharing Mechanism | Trigger | Data Shared | Who Controls It |
|---|---|---|---|
| OS Share Sheet (PDF export) | User taps "Export → Share" | Trip expense PDF file | User — they choose destination app |
| OS Share Sheet (CSV export) | User taps "Export → Share" | Trip expense CSV file | User — they choose destination app |
| OS Share Sheet (backup) | User taps "Backup → Share" | `.clbackup` JSON file | User — they choose destination app |
| File Picker (restore) | User taps "Restore" | Reads a user-selected file | User-initiated read only |

**Key point:** The app never sends data to any server. All "sharing" goes through Android's OS share sheet — the app has no knowledge of where the file goes. The destination is 100% user-controlled.

---

## 5. Google Play Data Safety — Answers

Based on this audit, here are the correct answers for the **Data Safety** section on Google Play Console:

### Does your app collect or share any of the required data types?

**Answer: No** — with the following nuance:

The app does NOT collect data in the sense that Google defines (data transmitted off-device to developer/third-party servers). All data stays on-device. However, the user can *share* files via OS share sheet which Google may still ask about.

### Data Types Questionnaire

| Data Type | Collected? | Shared? | Notes |
|---|---|---|---|
| Name | No | No | |
| Email address | No | No | |
| User IDs | No | No | UUIDs are local record IDs only, not tied to a user account |
| Phone number | No | No | |
| Address | No | No | |
| Location (precise) | No | No | |
| Location (approximate) | No | No | Country selected by user is not GPS — it's a manual input |
| Web browsing | No | No | No WebView |
| App interactions | No | No | No analytics |
| Crash logs | No | No | |
| Device identifiers | No | No | |
| Financial info | No (on-device only) | No | Expense amounts stored locally; user can export/share themselves |
| Photos/videos | No | No | |
| Files | No | No (user-initiated only) | File picker reads user-selected file; no automatic access |

### Google Play Data Safety Declaration

**Recommended declaration:**
- **Data collected:** None transmitted to developer/servers
- **Data shared:** None transmitted to third parties
- **Security practices:** Data encrypted in transit — N/A (no transit); Data encrypted at rest — depends on device encryption (Android default)
- **Committed to follow Google Play's Families Policy:** If targeting children, declare so; otherwise N/A
- **Independent security review:** Not required for this scope

**Select: "No, I don't collect or share data"** — this is accurate because no data is transmitted to any server (yours or a third party's). The OS share sheet is user-driven, not app-driven collection.

---

## 6. Privacy Policy Implications

### What a Privacy Policy Must Cover (even for local-only apps)

Google Play **requires** a privacy policy link for all apps. Even though this app collects no server-side data, you need one because:
- The app stores financial and travel data locally
- It uses file sharing capabilities
- It targets potentially vulnerable users (financial data)

### Minimum Privacy Policy Content

Your policy should state:

1. **Data collected:** The app stores trip, expense, and card profile data **locally on your device only**. No data is transmitted to our servers.
2. **No accounts required:** The app does not require registration or login.
3. **Exports & sharing:** When you export or share data (PDF, CSV, backup), the file is shared via your device's OS share sheet. We have no visibility into or control over where you send it.
4. **Third-party SDKs:** The app uses no analytics, advertising, or tracking SDKs.
5. **Data deletion:** Uninstalling the app deletes all local data.
6. **Children:** State your minimum age / whether the app is for children.
7. **Contact:** Provide a contact method.

---

## 7. Compliance Risks

| Risk | Severity | Details |
|---|---|---|
| No Privacy Policy URL | 🔴 Critical | Google Play **will reject** the app without a privacy policy link. Required before submission. |
| Release signing uses debug keys | 🟡 Medium | `build.gradle` shows `signingConfig = signingConfigs.getByName("debug")`. Must use a real release keystore before publishing. |
| No crash reporting | 🟡 Medium | Not a privacy risk, but means production crashes are invisible. Consider adding Firebase Crashlytics or Sentry (both are GDPR-friendly with proper config) *after* launch. |
| `file_picker` on Android 13+ | 🟢 Low | On Android 13+, `file_picker` uses the system photo/file picker — no `READ_EXTERNAL_STORAGE` needed. Your manifest correctly omits it. Verify this works on API 33+ during QA. |
| Backup file contains full financial data | 🟢 Low | The `.clbackup` JSON contains all user data. Educate users in the UI that they should treat backup files as sensitive. No technical fix needed, just UX copy. |
| App label still `travel_expenses` | 🟢 Low | The `android:label` in AndroidManifest.xml says `travel_expenses` (snake_case, internal name). Should be the real product name for store listing. |

---

## 8. Recommended Actions Before Publishing

### Critical (must fix before submission)

- [ ] **Create a Privacy Policy** — host it on a public URL (e.g., GitHub Pages or a simple website). Link it in the Google Play Console under App Content → Privacy Policy.
- [ ] **Generate a release keystore** — replace the debug signing config with a proper release keystore and store the keystore securely.
- [ ] **Update `android:label`** — change from `travel_expenses` to the real product name (e.g., `"Travel Expenses Pro"`).

### Recommended (before or shortly after launch)

- [ ] **Add a backup sensitivity warning** in the UI — when the user initiates a backup share, show a one-line note: "This file contains your financial data. Share only with trusted destinations."
- [ ] **Decide on crash reporting** — even a simple non-PII crash reporter (Firebase Crashlytics with `setCrashlyticsCollectionEnabled(false)` by default + opt-in) will save significant debugging time in production.
- [ ] **Test file_picker on Android 13+** — ensure the restore flow works correctly on API 33 and API 34 devices without storage permissions.
- [ ] **App ID cleanup** — consider whether `com.calmledger.android` is the permanent package name. Changing it after publishing breaks app identity on Play Store.

### Not Needed (explicitly confirmed clean)

- ✅ No analytics SDK to configure
- ✅ No ad SDK to configure  
- ✅ No GDPR/consent dialog needed (no data collection)
- ✅ No network security config needed (no network calls)
- ✅ No `<uses-permission>` cleanup needed

---

## Summary

This app has an **exceptionally clean privacy profile** for a financial app. It is 100% local-first with no external data transmission, no tracking, no analytics, and no advertising. The Google Play Data Safety declaration will be one of the simplest possible: "no data collected or shared."

The only blocking issue before publishing is the **missing Privacy Policy URL** and **release signing configuration**. Everything else is either low-risk or post-launch optimization.
