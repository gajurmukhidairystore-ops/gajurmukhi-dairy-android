# Safe Android Update and Package Identity

The unified Gajurmukhi Android application uses the stable application ID `com.gajurmukhi.one.v2`. Android treats this ID as the identity of the installed app. A future APK can update the existing installation only when it keeps this same application ID and is signed by the same release key as the installed APK.

## Before installing an update

Open the current app while online and run **Cloud sync** until the dashboard reports that no local changes are waiting. Also create an offline backup from the app’s backup setting and keep the backup outside the app installation. Do not uninstall the existing app before these two steps are complete.

## Installing a compatible update

Download the new `app-release.apk` from the green GitHub Actions run. Install it over the existing app. Android should show an **Update** or **Install update** confirmation and preserve the local database. If the confirmation appears, accept it and reopen the app; then verify the app ID remains `com.gajurmukhi.one.v2`, sign in with the existing local account, and run a two-phone sync check.

## When Android reports a signature or package conflict

Do not uninstall immediately. A conflict means one of the following is different: the application ID, the signing certificate, or the APK variant. Keep the old app installed, export its offline backup, and use the new APK as a side-by-side test only if it has a deliberately different application ID. A side-by-side variant must be treated as a separate app and will not share its local database automatically; use the cloud account and an intentional import/restore process instead.

For this repository, the correct long-term solution is to restore the original release keystore in GitHub Actions using the four documented secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, and `ANDROID_STORE_PASSWORD`. Do not generate a replacement keystore for an app that is already distributed through the same package identity. If the original release key is permanently unavailable, the existing installed app cannot be updated cryptographically; retain it for data export and publish a new package identity as a separate migration application.

## Debug versus release APK

Install `app-debug.apk` only for testing on a separate test device or after confirming that the debug certificate matches the intended test installation. Use `app-release.apk` for direct installation of the production candidate and keep `app-release.aab` for Google Play. Never alternate debug and release APKs over one installation unless their signing keys are known to match.

## Current build source of truth

The reproducible Android workflow is `.github/workflows/flutter-android.yml`. It runs analysis and deterministic tests before creating the debug APK, release APK, and release AAB. A successful build proves package creation and source validation; physical installation, Bluetooth printing, QR/payment, WhatsApp, GPS permissions, and two-phone synchronization still require testing on actual Android devices.
