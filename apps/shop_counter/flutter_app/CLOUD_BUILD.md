# Gajurmukhi Store — Phone-Only Cloud Android Build

The Flutter Android application is the primary mobile product. The repository includes a GitHub Actions workflow at `../.github/workflows/flutter-android.yml` that runs on a hosted Ubuntu runner, resolves dependencies, runs Flutter analysis and unit tests, and produces three downloadable artifacts in one run: a debug APK, a release APK, and a release AAB.

## What the cloud workflow produces

| Artifact    | Workflow path                                                  | Intended use                                       |
| ----------- | -------------------------------------------------------------- | -------------------------------------------------- |
| Debug APK   | `flutter_app/build/app/outputs/flutter-apk/app-debug.apk`      | Install on your phone for testing                  |
| Release APK | `flutter_app/build/app/outputs/apk/release/app-release.apk`    | Direct installation after a successful cloud build |
| Release AAB | `flutter_app/build/app/outputs/bundle/release/app-release.aab` | Google Play upload after proper release signing    |

The workflow runs `flutter analyze` and `flutter test` before packaging. It uses Flutter `3.47.0` stable, Java 17, and the validated Android Gradle stack. It does not require your phone to compile anything.

## The easiest phone-only route

You need an Android phone, a GitHub account, and access to the Manus project management screen. You do **not** need a PC, Android Studio, Flutter installation, or a local terminal.

### Step 1: Export the project to GitHub from your phone

Open the Gajurmukhi project in the Manus web interface using Chrome on your Android phone. Open the **Code** or **GitHub** panel, choose **Export code to a new repository**, sign in to GitHub if prompted, and create a private repository such as `gajurmukhi-dairy-store`. Keep the repository private because the source includes application configuration and business logic.

After export, open the repository in Chrome and confirm that these paths exist at the repository root: `flutter_app/`, `.github/workflows/flutter-android.yml`, `flutter_app/pubspec.yaml`, and `flutter_app/android/`.

### Step 2: Start the cloud build from GitHub on your phone

In Chrome, open the repository and tap **Actions**. Select **Flutter Android build** in the left-side workflow list. Tap **Run workflow**, keep the default branch selected, and tap the green **Run workflow** button. The workflow will run on GitHub’s hosted Linux machine; you can close the browser while it runs.

The first run may take several minutes while Flutter packages and Android dependencies are cached. Wait for the run to show a green check mark. If it fails, open the failed step and copy the red error text; do not repeatedly rerun the same failed job without checking the failing step.

### Step 3: Download all three files on your Android phone

When the run is green, open its details page and scroll to **Artifacts**. Tap the artifact named `gajurmukhi-dairy-android-<commit>`. GitHub downloads a ZIP file. Open the ZIP from your phone’s Downloads notification or Files app and extract it.

Install `app-debug.apk` first for testing. If Android blocks the installation, open **Settings → Security and privacy → More security settings → Install unknown apps**, allow Chrome or Files temporarily, and retry. The release APK can be installed the same way after testing.

Keep the AAB file in your phone’s Downloads folder until you are ready to upload it in Google Play Console. AAB files are for Play distribution and are not installed directly like APK files.

## Release signing requirement for Google Play

The workflow supports encrypted release signing through four GitHub repository secrets. Without these secrets, the release APK and AAB are built with the debug signing configuration so the cloud packaging path can be tested; those artifacts are **not suitable for Google Play production publishing**.

| GitHub secret             | Meaning                                    |
| ------------------------- | ------------------------------------------ |
| `ANDROID_KEYSTORE_BASE64` | Base64 text of the release `.jks` keystore |
| `ANDROID_KEY_ALIAS`       | Alias of the release key                   |
| `ANDROID_KEY_PASSWORD`    | Password for the release key               |
| `ANDROID_STORE_PASSWORD`  | Password for the keystore                  |

For a phone-only setup, first run the workflow without signing secrets, install the debug APK, and test the app. Before publishing to Google Play, create one permanent upload keystore on the Android phone and save its values as GitHub Actions secrets. The following procedure does not require a PC.

### Phone-only keystore creation with Termux

Install **Termux from F-Droid**, not an unofficial APK mirror. Open Termux and run these commands one at a time:

```bash
pkg update -y
pkg install openjdk-17 coreutils -y
mkdir -p ~/gajurmukhi-secrets
cd ~/gajurmukhi-secrets
keytool -genkeypair -v -keystore gajurmukhi-release.jks -alias gajurmukhi-upload -keyalg RSA -keysize 2048 -validity 10000
base64 -w 0 gajurmukhi-release.jks > gajurmukhi-release.jks.base64
cat gajurmukhi-release.jks.base64
```

When `keytool` asks questions, enter the store password and key password and keep them in a password manager. For the certificate name, your store name is sufficient. The final `cat` command prints one long base64 value. Copy that value directly from Termux; do not send it in chat. Your four values are: the copied base64 output, alias `gajurmukhi-upload`, the key password, and the store password.

### Enter the secrets from the phone browser

In Chrome, open the GitHub repository, tap **Settings**, tap **Secrets and variables**, tap **Actions**, and tap **New repository secret**. Create these four secrets exactly, one at a time: `ANDROID_KEYSTORE_BASE64` with the copied base64 output; `ANDROID_KEY_ALIAS` with `gajurmukhi-upload`; `ANDROID_KEY_PASSWORD` with the key password; and `ANDROID_STORE_PASSWORD` with the store password. GitHub masks secrets in workflow logs. Do not put the keystore, passwords, or base64 text into a repository file, issue, commit, or chat message.

After saving the four secrets, return to **Actions → Flutter Android build → Run workflow**. The workflow decodes the keystore into `flutter_app/android/app/upload-keystore.jks`, signs the release APK and AAB, and uploads all three artifacts. Keep the original `gajurmukhi-release.jks` file in Termux and back it up securely. Losing the keystore can prevent future updates to the same Play application identity.

The Android application ID currently lives in `flutter_app/android/app/build.gradle.kts`. Choose the final Play application identity before the first production release and do not change it afterward.

## Phone-only testing checklist

After installing the debug APK, test invoice creation while offline, app restart and local data retention, reconnect-and-sync, customer ledger balances, farmer morning/evening collection, configurable FAT/SNF payout calculation, stock reduction, reports, QR display, WhatsApp sharing, Bluetooth discovery and printing on both 58 mm and 80 mm printers, and AI assistant responses after cloud credentials are configured. Hardware and WhatsApp checks must be performed on the actual phone; a green GitHub build only proves source analysis, tests, and package creation.

## If GitHub Actions is unavailable

Do not attempt to build locally on the phone. Send the repository link and the failed workflow step to the project owner or use another hosted Flutter builder that accepts a GitHub repository. The checked-in workflow remains the reproducible source of truth for the three requested artifacts.
