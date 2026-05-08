# App Store Submission Checklist

Step-by-step from current state (everything code-side is ready; nothing has been uploaded) to "Submitted for Review".

## Phase 1: Apple Developer enrollment ($99/year)

- [ ] Visit https://developer.apple.com/programs/enroll/
- [ ] Sign in with the Apple ID you want to use as the developer
- [ ] Complete enrollment (individual is fine; company requires DUNS lookup)
- [ ] Pay the $99 fee
- [ ] Wait for confirmation email (usually 24–48 hours)

## Phase 2: GitHub repo + Pages

The privacy policy needs a public URL. Hosting on GitHub Pages is free and version-controlled.

- [ ] Create a public repo at https://github.com/new (suggested name: `shadowing-app`)
- [ ] In the local repo:
  ```bash
  cd /Users/samyu/Downloads/code/playground/shadowing-app
  git remote add origin https://github.com/<your-username>/shadowing-app.git
  git push -u origin feat/initial-build
  # Optionally merge to main:
  git checkout main 2>/dev/null || git checkout -b main
  git merge feat/initial-build
  git push -u origin main
  ```
- [ ] In GitHub → Settings → Pages: Source = "Deploy from a branch", Branch = `main`, Folder = `/docs`
- [ ] Wait ~1 minute, then verify the policy renders at:
  ```
  https://<your-username>.github.io/shadowing-app/privacy-policy
  ```

## Phase 3: Update placeholders in committed files

Two files have `<your-username>` and `<Your Name>` placeholders that need real values before paste:

- [ ] Edit `docs/app-store/marketing.md` — replace 3 occurrences of `<your-username>` and `<Your Name>`.
- [ ] Edit `docs/privacy-policy.md` — the contact section is generic; if you want a specific contact (email or GitHub Issues link), update it now.
- [ ] Commit & push:
  ```bash
  git add docs/app-store/marketing.md docs/privacy-policy.md
  git commit -m "docs: fill in App Store placeholder values"
  git push
  ```

## Phase 4: Create the App Store Connect app record

- [ ] Sign in to https://appstoreconnect.apple.com
- [ ] Apps → My Apps → "+" → New App
- [ ] Platform: iOS. Name: **Shadowing**. Primary language: English (U.S.).
- [ ] Bundle ID: `com.yudataguy.ShadowingApp` (must match `project.yml`).
- [ ] SKU: any unique string, e.g., `SHADOWING-001`.
- [ ] User Access: Full Access.
- [ ] Save.

If the Bundle ID doesn't appear in the dropdown, you may need to register it first at https://developer.apple.com/account/resources/identifiers/list — Add Identifiers → App ID → enter `com.yudataguy.ShadowingApp` and `com.yudataguy.ShadowingApp.Widget`.

## Phase 5: Build the archive

- [ ] In Xcode → Settings → Accounts, confirm your Apple ID is signed in and your developer team is selected.
- [ ] In the project's Signing & Capabilities tab for both targets (`ShadowingApp` and `ShadowingWidget`), confirm the Team is set.
- [ ] Run from terminal:
  ```bash
  ./scripts/archive.sh
  ```
- [ ] On success, the archive is at `build/Shadowing.xcarchive`.

If the script fails, common causes:
- "No matching profiles" → in Xcode, click the target → Signing & Capabilities → confirm "Automatically manage signing" is on and your team is selected.
- "App Group not authorized" → after enrolling, the App Group `group.com.yudataguy.shadowingapp` is created automatically by Xcode the first time it builds with that team. If it persists, register it manually at https://developer.apple.com/account/resources/identifiers/list (App Groups).

## Phase 6: Validate + upload via Xcode Organizer

- [ ] Open Xcode → Window → Organizer → Archives.
- [ ] Select the new archive.
- [ ] Click **"Validate App"** first — catches signing/entitlement errors before the slow upload.
- [ ] Choose "App Store Connect" as the destination, accept defaults, walk through.
- [ ] If validation reports errors, address them, re-run `./scripts/archive.sh`, re-validate.
- [ ] Once validation passes, click **"Distribute App"** → App Store Connect → Upload.
- [ ] Xcode prompts for signing identity and 2FA. Approve the 2FA prompt on another Apple device (iPhone, Mac).
- [ ] Wait 5–30 minutes for ASC to process the upload. You'll receive an email when processing finishes.

## Phase 7: Take screenshots

Apple requires at least one screenshot for the largest iPhone size (6.9" iPhone 17 Pro Max). Three different sizes are recommended for best presentation.

- [ ] Boot the iPhone 17 simulator:
  ```bash
  xcrun simctl boot 'iPhone 17' || true
  open -a Simulator
  ```
- [ ] Build & install:
  ```bash
  xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp \
    -destination 'platform=iOS Simulator,name=iPhone 17' build
  xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/ShadowingApp-*/Build/Products/Debug-iphonesimulator/ShadowingApp.app
  ```
- [ ] To capture the onboarding screenshot, uninstall first:
  ```bash
  xcrun simctl uninstall booted com.yudataguy.ShadowingApp
  xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/ShadowingApp-*/Build/Products/Debug-iphonesimulator/ShadowingApp.app
  ```
- [ ] Run `./scripts/take_screenshots.sh` and follow its prompts. The script captures 6 screens.
- [ ] Inspect the PNGs in `docs/app-store/screenshots/`. Re-run individual captures if any look bad.

## Phase 8: Fill ASC metadata

- [ ] In ASC → your app → 1.0 Prepare for Submission, fill in each section using `docs/app-store/marketing.md`:
  - **App Information**: subtitle, primary/secondary categories, content rights ("Yes — contains third-party content"), age rating (4+).
  - **Pricing & Availability**: Free, all territories.
  - **App Privacy**: declare "Data Not Collected" — the privacy manifest backs this up. Apple may ask follow-up questions; answer based on the privacy policy.
  - **1.0 Version Information**: paste promotional text, description, keywords, support URL, marketing URL, privacy policy URL.
  - **Screenshots**: drag PNGs from `docs/app-store/screenshots/` into the 6.9" / 6.7" iPhone slot.
  - **Build**: select the build that finished processing in Phase 6.
  - **Copyright**: e.g., "© 2026 <Your Name>".

## Phase 9: Submit

- [ ] Click **Save** in each section as you fill it in.
- [ ] When all sections show green checkmarks, click **"Add for Review"**.
- [ ] On the review form, answer the export-compliance question:
  - Does your app use encryption? → No (the app uses no custom cryptography; only standard iOS APIs that are exempt).
- [ ] Click **"Submit for Review"**.
- [ ] Wait. App Review typically takes 24h–7 days.

## What to do if rejected

App Review will email you with the rejection reason. Common issues for an app like this:

- **"App lacks demonstrable functionality"** → mitigated by bundled LibriVox samples.
- **"Crashes during review"** → check the crash log they attach. Reproduce locally, fix, increment `CURRENT_PROJECT_VERSION` (1 → 2), re-run `./scripts/archive.sh`, re-upload, re-submit.
- **"Misleading metadata"** → adjust marketing copy to match what the app actually does.
- **"Privacy policy URL not accessible"** → confirm GitHub Pages is published.

For each iteration after rejection:
1. Address the specific feedback.
2. Bump `CURRENT_PROJECT_VERSION` in `project.yml`.
3. `./scripts/archive.sh`
4. Validate + upload via Organizer.
5. In ASC, the new build will be available; select it and re-submit.

## Already-mitigated rejection risks

| Risk | Mitigation |
|------|------------|
| App lacks usable content | Three LibriVox samples bundled; Library shows them on first launch. |
| Missing privacy manifest | `ShadowingApp/PrivacyInfo.xcprivacy` and `ShadowingWidget/PrivacyInfo.xcprivacy` declare no tracking, two API access reasons. |
| Missing privacy policy URL | Hosted on GitHub Pages once Phase 2 is done. |
| Encryption export compliance unclear | Set "Does your app use encryption?" to No. |
| Bundle ID conflict | We use the unique `com.yudataguy.ShadowingApp`. |
| Onboarding confusion | First-launch sheet explains the app's purpose. |
