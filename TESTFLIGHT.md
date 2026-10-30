# Getting Ember Grove onto your iPhone (no Mac needed)

GitHub builds the app on one of its Macs and uploads it to Apple's **TestFlight** app. You can do every step below from your iPhone in Safari. Most of it is one-time setup.

## 1. Join the Apple Developer Program ($99/year)
- Install the **Apple Developer** app from the App Store, then go to **Account → Enroll Now**.
- Approval usually takes from a few hours to 2 days. You can do steps 2–3 while you wait.

## 2. GitHub
- Create a free account at github.com.
- Create a new **private** repository named `EmberGrove` (leave it empty).
- Send Claude the name, for example `yourname/EmberGrove`. Claude will upload the code.

## 3. Choose your app ID
Pick a unique bundle ID, for example `com.yourname.embergrove` (lowercase, no spaces).

## 4. Register the app with Apple (after enrollment is approved)
1. **developer.apple.com → Account → Certificates, IDs & Profiles → Identifiers → +**
   - Choose **App IDs → App**. Description: `Ember Grove`. Bundle ID: **Explicit**, then type your bundle ID.
   - Tap **Continue → Register**.
2. **appstoreconnect.apple.com → Apps → + → New App**
   - Platform **iOS**, name **Ember Grove** (if it's taken, add something like "Ember Grove Focus"), any language, your bundle ID, and any SKU (for example `embergrove`).
3. Find your **Team ID**: developer.apple.com → Account → **Membership details** (10 characters, like `ABCDE12345`).

## 5. Create an API key so GitHub can sign the app
1. **appstoreconnect.apple.com → Users and Access → Integrations → App Store Connect API → +**
   - Name: `GitHub`. Access: **Admin**.
2. Write down the **Issuer ID** (shown above the list) and the key's **Key ID**.
3. Tap **Download** to get the `.p8` file. You can only download it once.
   - To copy its text on iPhone: open the **Files** app → Downloads, long-press the file → **Rename**, and change `.p8` to `.txt`. Open it, then select all and copy.

## 6. Give the keys to GitHub
In your repository: **Settings → Secrets and variables → Actions**.

**Variables** tab → **New repository variable**:
| Name | Value |
|---|---|
| `APPLE_TEAM_ID` | your Team ID |
| `BUNDLE_ID` | your bundle ID |

**Secrets** tab → **New repository secret**:
| Name | Value |
|---|---|
| `ASC_KEY_ID` | the Key ID |
| `ASC_ISSUER_ID` | the Issuer ID |
| `ASC_PRIVATE_KEY` | the whole text of the key file, including the `-----BEGIN…` and `-----END…` lines |

## 7. Build
Go to **Actions → Build & TestFlight → Run workflow**. It takes about 15–25 minutes. A green check means the build was uploaded.

## 8. Install
1. **appstoreconnect.apple.com → your app → TestFlight → Internal Testing → +**. Create a group and add yourself.
2. Install **TestFlight** from the App Store and sign in with the same Apple ID.
3. Ember Grove appears there. Tap **Install**.

From then on, every update builds automatically and shows up in TestFlight. Each TestFlight build works for 90 days, and a new build replaces it.

### If something fails
Open the failed run in **Actions**, copy the red error text, and send it to Claude.
