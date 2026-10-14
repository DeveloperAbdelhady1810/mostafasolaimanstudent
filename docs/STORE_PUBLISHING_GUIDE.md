# Publishing the Mostafa Solaiman student app on the App Store and Google Play

Everything here was checked against Apple's and Google's current documentation (links at the end) and against what the app and server do today.
Ready-to-use files live in `store_assets/`:

| Folder | What is in it |
|---|---|
| `store_assets/metadata/en`, `ar` | Every listing text (name, subtitle, descriptions, keywords, what's new) - limits already checked |
| `store_assets/screenshots/` | Store-ready screenshots (English + Arabic) for Google Play, iPhone and iPad, plus Play feature graphic and icons |
| `store_assets/legal/` | Draft privacy policy and account-deletion page (English + Arabic) |
| `store_assets/build_metadata.py` | Re-generates the text files and re-checks the character/byte limits |

---

## 0. Read this first - what blocks approval today

These are not optional; each one is a common rejection reason.

| # | Blocker | Status | What to do |
|---|---|---|---|
| 1 | **Privacy policy URL** (both stores) | Missing. `https://mostafa-solaiman.online/privacy` returns 404 (only `/terms` exists) | Publish `store_assets/legal/privacy_policy.md` after filling the [BRACKETS] |
| 2 | **Account deletion** - Apple 5.1.1(v) and Google Play both require it for any app that lets people create an account (ours does: sign-up through Google/Apple) | Missing in the app and on the site | Add Settings > Delete account in the app **and** a public web page (`/delete-account`, draft in `store_assets/legal/`). Google also wants that URL in the Data safety form |
| 3 | **Support URL** (Apple requires real contact information) | Missing (`/support`, `/contact` are 404) | A page with an email / WhatsApp, or reuse the privacy page's contact section |
| 4 | **Demo account for the reviewers** (Apple "Review sign-in", Google "App access") | Not created | Create a normal student account on the website with a password that never expires, e.g. `appreview@mostafa-solaiman.online`, and keep it free of real student data |
| 5 | **Android release signing key** | The release build is still signed with the debug key | Section 5.1 (done in code; you create the key) |
| 6 | **Target age / children** | Registration allows ages 10-30 | Decide: Google treats a target group that includes under-13s as "Families" (extra rules). Simplest honest choice is target age **13+** and say so in the policy; get a lawyer's view because students are minors and a parent's phone number is collected |

The account-deletion pieces (1-3) are code and site work, not paperwork. Ask and they can be built and tested.

---

## 1. Accounts and costs

| | Apple | Google Play |
|---|---|---|
| Program | Apple Developer Program, **US$99 / year** (you already have a team: `6X8AX94P84`) | Play Console, **US$25 one time** |
| Who owns the app | The account holder's legal name is shown as the seller. Use the teacher's / company's name, not a personal one, if that is how it should appear | Same: the developer name appears under the app title |
| Extra rule for new accounts | none | **Personal accounts created after 13 Nov 2023 must run a closed test with at least 12 testers opted in for 14 continuous days before they can apply for production.** Organisation accounts (need a D-U-N-S number) are exempt. Plan for ~3 weeks, or use an organisation account |
| Identity checks | D-U-N-S for organisations | Identity + phone verification; organisation also D-U-N-S |

## 2. App facts

| Item | Value |
|---|---|
| Display name under the icon | `Mr. Mostafa Solaiman` (set in Info.plist on the Mac). Store name below is `Mostafa Solaiman`; keep them consistent |
| Bundle ID / package | `online.mostafasolaiman.student` (same on both) |
| Version | `1.0.0+1` in `pubspec.yaml` (`1.0.0` = shown to users, `+1` = build number; **increase the build number for every upload**) |
| Languages | English + Arabic. Add Arabic as a second localisation in both consoles |
| Primary market | Egypt. Choose Arabic or English as the primary language - Arabic recommended |
| Price | Free, no in-app purchases, no ads |
| Minimum OS | Android 7.0 (API 24), iOS 15 (as set on the Mac) |
| Target API | Android 16 / API 36 (what Flutter 3.35 sets) - meets Google's August 2026 requirement |
| Category | Apple: **Education** (secondary: Productivity). Google: **Education** |

## 3. Listing metadata (copy from `store_assets/metadata/`)

### Apple (App Store Connect > your app > App Information / the version page)
| Field | Limit | English | Arabic (add localisation "Arabic") |
|---|---|---|---|
| Name | 30 | `Mostafa Solaiman` | `مصطفى سليمان` |
| Subtitle | 30 | `Attendance & class updates` | `الحضور وتنبيهات الحصص` |
| Promotional text (editable any time) | 170 | see file | see file |
| Description | 4000 | see file | see file |
| Keywords | 100 **bytes**, comma separated, no spaces, each >2 characters | `attendance,student,math,qr code,bluetooth,class,teacher,school,egypt,notifications,tutor` | `حضور,طالب,رياضيات,كود,بلوتوث,حصة,مدرس,مدرسة,إشعارات` |
| What's new (not shown on a first version) | 4000 | see file | see file |
| Support URL | - | `https://mostafa-solaiman.online/support` (to create) | same |
| Marketing URL (optional) | - | `https://mostafa-solaiman.online` | same |
| Privacy Policy URL (App Information) | - | `https://mostafa-solaiman.online/privacy` (to create) | same |
| Copyright | - | `2026 [LEGAL NAME]` | same |
| Category | - | Education (primary) | |

### Google Play (Play Console > Grow > Store presence > Main store listing)
| Field | Limit | English | Arabic |
|---|---|---|---|
| App name | 30 | `Mostafa Solaiman` | `مصطفى سليمان` |
| Short description | 80 | `Your student ID, live QR code, attendance and class updates - works offline.` | `رقم الطالب وكود QR والحضور وتنبيهات الحصص - يعمل بدون إنترنت.` |
| Full description | 4000 | `description.txt` | `description.txt` |
| App icon | 512x512 PNG | `screenshots/google-play/icon/play_icon_512.png` | same |
| Feature graphic | 1024x500 JPG/PNG, no alpha | `feature_graphic_en_1024x500.png` | `feature_graphic_ar_1024x500.png` |
| Email / website / phone | | [SUPPORT EMAIL], https://mostafa-solaiman.online | |

Accuracy rule (Apple 2.3, Google "Metadata"): the text and screenshots must describe what the app really does. Nothing in these files claims
live classes, payments or features the app does not have. Bluetooth check-in only works where the center enables it - the description says so.

## 4. Screenshots

All generated from the real app (English and Arabic) with demo data, composed with a headline and device frame. They live under
`store_assets/screenshots/`.

| Store | Folder | Size (px) | Count | Notes |
|---|---|---|---|---|
| Google Play phone | `google-play/phone/{en,ar}` | 1080 x 1920 | 6 per language (2 min, 8 max) | JPEG / 24-bit PNG, no alpha; longer side must be at most 2x the shorter |
| Google Play feature graphic | `google-play/feature-graphic` | 1024 x 500 | 1 per language | Required |
| Google Play icon | `google-play/icon` | 512 x 512 | 1 | 32-bit PNG |
| App Store iPhone **required** size | `app-store/iphone-6.3in-1206x2622/{en,ar}` | 1206 x 2622 | 6 (1 min, 10 max) | "Dynamic Island, medium" = the mandatory iPhone size |
| App Store iPhone large | `app-store/iphone-6.9in-1320x2868/{en,ar}` | 1320 x 2868 | 6 | Optional; used for the biggest iPhones. App Store Connect scales the required one down for smaller devices |
| App Store iPad 13" | `app-store/ipad-13in-2064x2752/{en,ar}` | 2064 x 2752 | 6 | **Only required because the project currently supports iPad** (`TARGETED_DEVICE_FAMILY = "1,2"`). Alternative: in Xcode set Targeted Device Families to iPhone only and skip iPad screenshots |
| App Store icon | `app-store/icon/app_store_icon_1024.png` | 1024 x 1024 | 1 | No alpha. The same icon is already inside the Xcode asset catalog |

Screens shown (in order): 1 Sign in (email / Google / Apple), 2 Student ID + live code (works offline), 3 Bluetooth check-in,
4 Attendance history, 5 Notifications, 6 English / Arabic settings. Upload the `en` set to the English localisation and the `ar` set to the Arabic one.
Re-generate them any time with the scripts on the PC in the folder `mostafa_ble_testkit` next to the projects (`capture_store.py` takes the raw captures from an emulator, `compose_store.py` builds the store images). 52 files, all verified to the exact pixel sizes above with no alpha channel (except the Play icon, which Google wants as 32-bit PNG).

File names inside each language folder: `01_login.png`, `02_home.png`, `03_home_bluetooth.png`, `04_attendance.png`, `05_notifications.png`, `06_settings.png` - upload them in that order. The iPhone/iPad sign-in screenshot shows the Apple button (it only exists on iOS); the Google Play one does not.

## 5. Android - Google Play

### 5.1 Make the release key (once, keep it safe)
```
keytool -genkey -v -keystore %USERPROFILE%\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Create `android/key.properties` (already git-ignored; **never commit it or the .jks**):
```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=C:\\Users\\<you>\\upload-keystore.jks
```
The Gradle file already reads it and falls back to the debug key when the file is missing. Back the `.jks` and passwords up in two places: if the upload key
is lost you must ask Google to reset it.

### 5.2 Build
```
flutter pub get
flutter build appbundle --release        # upload this: build/app/outputs/bundle/release/app-release.aab
```
Google Play requires an Android App Bundle (.aab), not an .apk. Increase `+1` in `pubspec.yaml` for every new upload.

### 5.3 Google sign-in for the release build
Add the **SHA-1 of the upload key** (`keytool -list -v -keystore upload-keystore.jks -alias upload`) **and later the SHA-1 of the Play App Signing key**
(Play Console > Test and release > App integrity) to the Firebase Android app. Without them "Continue with Google" fails on the Play Store version.

### 5.4 Play Console steps, in order
1. **Create app**: name, default language, App, Free, accept policies.
2. **Dashboard > Set up your app** - complete every task:
   - *App access*: "All or some functionality is restricted" - give the demo account from blocker 4 and explain that Google/Apple sign-in also works.
   - *Ads*: **No ads**.
   - *Content rating*: IARC questionnaire (Education). No violence, sex, gambling, user-generated content, or location sharing -> expect "Everyone".
   - *Target audience and content*: pick the age groups (see blocker 6). Do not tick "appeals to children" unless you accept the Families policy.
   - *Data safety*: use the table in section 7. Data is encrypted in transit; **users can request deletion** - enter the `/delete-account` URL.
   - *Government apps / Financial features / Health*: No.
   - *Privacy policy*: the URL.
3. **Main store listing**: text + graphics from section 3/4 (add Arabic under Manage translations).
4. **Test and release > Testing > Closed testing**: upload the `.aab`, add testers (an email list or Google Group). **Personal account: 12+ testers must stay opted in 14 days.** Fix anything they report.
5. **Production**: after the closed test (or immediately for an organisation account), create a release, upload the same `.aab`, add release notes (`whats_new.txt`), set countries (Egypt + any others), **Send for review**. First review usually takes a few days.
6. Turn on **Play App Signing** (default) and add its SHA-1 to Firebase (5.3).

Permissions the app declares (explain them if asked): Internet, network state, Notifications (POST_NOTIFICATIONS, push), Vibrate, Bluetooth scan/connect/advertise (Nearby devices - the check-in feature; scanning is flagged "never for location").

## 6. iOS - App Store (needs the Mac)

### 6.1 Project settings (Xcode > Runner)
- Signing & Capabilities: Team `6X8AX94P84`, bundle `online.mostafasolaiman.student`, automatic signing.
- Capabilities present: **Push Notifications**, **Sign In with Apple**. (`aps-environment` is switched to production automatically by distribution signing.)
- `ios/Flutter/Secrets.xcconfig` (git-ignored) must contain `GOOGLE_IOS_CLIENT_ID` and `GOOGLE_REVERSED_CLIENT_ID` or Google sign-in breaks.
- `lib/firebase_options.dart` must exist locally (git-ignored) - copy it from the PC.
- Export compliance: `ITSAppUsesNonExemptEncryption = NO` is already in Info.plist (the app only uses HTTPS / OS encryption), so Apple will not ask on every build.
- Bluetooth usage descriptions are already in Info.plist (required, or the app is rejected / crashes on first Bluetooth use).
- Optional: set Targeted Device Families to iPhone only to avoid iPad screenshots.

### 6.2 Build and upload
```
flutter build ipa --release              # or: Xcode > Product > Archive
```
Upload through Xcode Organizer (Distribute App > App Store Connect) or the Transporter app. The build appears in App Store Connect after processing (10-30 min).

### 6.3 App Store Connect steps, in order
1. **My Apps > + > New App**: platform iOS, name, primary language, bundle ID `online.mostafasolaiman.student`, SKU e.g. `mostafa-student-ios`.
2. **App Information**: subtitle, category, **Privacy Policy URL**, content rights (no third-party content), age rating (below).
3. **Pricing and Availability**: Free; Egypt (+ others).
4. **App Privacy**: answer from section 7 (data linked to the user, **not** used for tracking). Add the privacy policy URL.
5. **Version page**: screenshots (section 4), promotional text, description, keywords, support URL, copyright; for Arabic add the localisation.
6. **Age rating** (Apple's questionnaire, updated for iOS 26: asks about in-app controls, capabilities, medical/wellness and violent themes): answer **no / none** to everything - expected **4+**. Answer the new questions too or updates get blocked.
7. **App Review Information**: contact name/phone/email, **demo account** (blocker 4), and the notes below.
8. **TestFlight**: add yourself / a few testers (internal testing needs no review), test on real iPhones (login, Apple/Google sign-in, push, Bluetooth).
9. **Submit for Review**. Typical review: 1-2 days. Choose "manual release" for the first version.

**Review notes to paste (English):**
> Mostafa Solaiman is the student app of a private maths teacher in Egypt. Sign in with the demo account in the review fields (email + password), or with Google / Apple.
> The home screen shows the student ID and a QR code that renews every 30 seconds; it works offline. "Bluetooth check-in" broadcasts that code for 60 seconds so the
> teacher's assistant can detect nearby students; it only appears when the feature is enabled for the account's center. Bluetooth is used only for this proximity check-in
> (no tracking, no location). Push notifications confirm attendance. Account deletion: Settings > Delete account. The app contains no ads, purchases or user-generated content.

## 7. Data inventory (use it for Apple "App Privacy" and Google "Data safety")

| Data | Collected? | Linked to the user | Used for | Shared with | Optional? |
|---|---|---|---|---|---|
| Name | Yes | Yes | App functionality, account | Teacher/assistants | No |
| Email address | Yes | Yes | Account, sign-in | - | No |
| Phone number (student) | Yes | Yes | Account, contact | Teacher/assistants | No |
| Phone number (parent/guardian, about another person) | Yes | Yes | Contact about attendance | Teacher | No |
| Photo URL (from Google) | If Google sign-in | Yes | Profile picture | - | Yes |
| Other profile info (grade, school, gender, age, study mode) | Yes | Yes | App functionality | Teacher | No |
| User ID (student number) | Yes | Yes | Identification, attendance | Teacher/assistants | No |
| App activity: attendance records, scan audit log (method, Bluetooth signal strength) | Yes | Yes | App functionality, fraud prevention | Teacher/assistants | No |
| Device or other IDs: push (FCM) token | Yes | Yes | Push notifications | Google (Firebase) | Yes (can refuse notifications) |
| Precise/approximate location | **No** (Bluetooth is not used to locate you) | - | - | - | - |
| Contacts, photos, audio, health, financial, browsing history | No | - | - | - | - |
| Advertising / analytics / tracking | **None** | - | - | - | - |

- Apple: "Data Used to Track You" = none. Data types to tick as linked to the user: Name, Email, Phone number, Other user contact info (parent's number), User ID, Other user content/usage (attendance), Device ID (push token) - purpose "App Functionality".
- Google Data safety: collects the types above; **data is encrypted in transit: Yes**; **users can request that data is deleted: Yes** (URL); **not shared with third parties** except service providers (Firebase for push), which Google does not count as "sharing" when it is processing on your behalf - declare Firebase if unsure.

## 8. Final checklist

- [ ] Privacy policy, support and account-deletion pages live (blocker 1-3) and linked in both consoles
- [ ] In-app Delete account works and is tested (blocker 2)
- [ ] Demo student account created, working with email + password; its details pasted in both consoles
- [ ] Android: release key created, `.aab` built, SHA-1 values added to Firebase
- [ ] iOS: Secrets.xcconfig + firebase_options.dart present on the Mac, archive uploaded, TestFlight run on a real iPhone
- [ ] Real-device test of: login (email, Google, Apple), offline ID/QR, push, Bluetooth check-in with an assistant phone, Arabic layout
- [ ] Screenshots uploaded for English and Arabic; icon 1024 (Apple) and 512 (Google)
- [ ] Age rating / content rating / Data safety / App Privacy completed with the answers above
- [ ] Closed test running 14 days with 12+ testers (Google personal account only)
- [ ] Release notes added; countries selected; submit

## 9. Common rejection reasons for this kind of app

1. Missing/non-working privacy policy or account deletion (5.1.1) - blockers 1-2.
2. Reviewer cannot sign in - the demo account must work and must not expire; mention that Google/Apple sign-in exists too.
3. Crash on first launch from a missing configuration (Secrets.xcconfig / firebase_options.dart not on the build machine).
4. Permission prompts without a clear reason - the Bluetooth/notification texts are already written; keep the review notes explaining them.
5. Screenshots that do not match the app (2.3) - these were taken from the real UI; refresh them whenever the UI changes.
6. Google: Data safety form disagreeing with the actual app, or missing deletion URL.

## Sources (checked October 2026)

- Apple - screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- Apple - platform version information (field limits): https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Apple - account deletion, guideline 5.1.1(v): https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion
- Apple - updated age ratings (13+/16+/18+): https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/
- Google - preview assets (icon, feature graphic, screenshots): https://support.google.com/googleplay/android-developer/answer/9866151
- Google - account deletion requirements: https://support.google.com/googleplay/android-developer/answer/13327111
- Google - target API level: https://support.google.com/googleplay/android-developer/answer/11926878
- Google - target audience and content settings: https://support.google.com/googleplay/android-developer/answer/9867159
- Google - closed testing for new personal accounts: https://support.google.com/googleplay/android-developer/answer/14151465
