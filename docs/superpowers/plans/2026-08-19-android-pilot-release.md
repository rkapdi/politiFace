# Android Pilot Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A signed, Play-Store-ready Android release build (AAB) of Politiface with working notifications, correct branding, and a reproducible build script, per the spec at `docs/superpowers/specs/2026-08-19-android-pilot-release-design.md`.

**Architecture:** No Dart architecture changes. The work is: local Android toolchain setup, a Gradle/AGP upgrade to reach SDK 35, manifest and signing configuration, adaptive launcher icons, one small platform-branching change in `NotificationService`, a build script, and an emulator QA pass. iOS behavior must be byte-for-byte untouched.

**Tech Stack:** Flutter 3.22.0 (via fvm at `/Users/rkapdi/fvm/versions/3.22.0`, on PATH as `flutter`), AGP 8.3.2, Gradle 8.6, Kotlin 1.9.24, JDK 17 (Temurin), flutter_local_notifications 17.x, flutter_launcher_icons 0.13.1.

## Global Constraints

- Repo root: `/Users/rkapdi/Developer/politiFace/politiface`. Flutter app lives in `app/`. All `flutter` commands run from `app/`.
- `compileSdk 35`, `targetSdk 35` (Play floor for new apps). `minSdk` stays `flutter.minSdkVersion` (21).
- applicationId / namespace: `io.politiface.politiface` (already set; do not change).
- Version stays the shared line in `app/pubspec.yaml` (`1.3.0+31`); do not bump in this plan.
- iOS untouched: no diffs under `app/ios/` except identical regenerated icon files (verify with `git status`; if flutter_launcher_icons rewrites identical iOS icons, the diff must be empty).
- No em-dashes in any user-visible copy, comments, or docs written during this plan.
- Never commit: `key.properties`, `*.jks`, `*.keystore`, `local.properties` (all already in `app/android/.gitignore`; verify before every commit with `git status`).
- Every commit message ends with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Commit on the current branch `v2-planning`.
- Data rule: nothing in this plan may add data collection of any kind.

---

### Task 1: Local Android toolchain (JDK 17, cmdline-tools, SDK 35, emulator)

The machine has Flutter 3.22 + an Android SDK at `~/Library/Android/sdk` but only platform 33, no cmdline-tools, unaccepted licenses, no JDK 17 (system Java is 1.8), no Android Studio, no emulator image. AGP 8.3 requires JDK 17.

**Files:** none in repo (machine setup only).

**Interfaces:**
- Produces: a working `flutter doctor` Android toolchain, an AVD named `politiface_api35` used by Tasks 2 and 8, and JDK 17 configured for Flutter's Gradle invocations.

- [ ] **Step 1: Install JDK 17 (Temurin) via Homebrew**

```bash
brew install --cask temurin@17
/usr/libexec/java_home -v 17
```

Expected: prints a path like `/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home`.

- [ ] **Step 2: Point Flutter at JDK 17**

```bash
flutter config --jdk-dir "$(/usr/libexec/java_home -v 17)"
```

- [ ] **Step 3: Install Android cmdline-tools into the existing SDK**

```bash
cd /private/tmp/claude-501/-Users-rkapdi-Developer-politiFace-politiface/95732295-3501-4805-92a1-ae613d05b20c/scratchpad
curl -L -o cmdline-tools.zip "https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
unzip -q cmdline-tools.zip
mkdir -p ~/Library/Android/sdk/cmdline-tools
rm -rf ~/Library/Android/sdk/cmdline-tools/latest
mv cmdline-tools ~/Library/Android/sdk/cmdline-tools/latest
```

- [ ] **Step 4: Accept licenses and install SDK 35 + emulator packages**

```bash
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
SDKMANAGER=~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager
yes | "$SDKMANAGER" --licenses
"$SDKMANAGER" "platform-tools" "platforms;android-35" "build-tools;35.0.0" "emulator" "system-images;android-35;google_apis;arm64-v8a"
```

Expected: packages download without error. (This machine is arm64; the arm64-v8a image is correct.)

- [ ] **Step 5: Create the QA emulator**

```bash
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
echo "no" | ~/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager create avd -n politiface_api35 -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_7
```

- [ ] **Step 6: Verify toolchain**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface/app && flutter doctor -v
```

Expected: Android toolchain section shows a checkmark (SDK 35, licenses accepted). Nothing to commit.

---

### Task 2: Gradle toolchain upgrade + SDK 35 + desugaring

AGP 7.3.0 / Gradle 7.6.3 / Kotlin 1.7.10 cannot compile SDK 35. flutter_local_notifications 17.x additionally requires core library desugaring. Do this as one task because the pieces only build together.

**Files:**
- Modify: `app/android/settings.gradle` (plugin versions)
- Modify: `app/android/gradle/wrapper/gradle-wrapper.properties` (distribution)
- Modify: `app/android/app/build.gradle` (SDK levels, Java 17, desugaring)

**Interfaces:**
- Produces: a debug APK build that Tasks 3 to 8 rely on. Compile settings: `compileSdk 35`, `targetSdk 35`, Java/Kotlin toolchain 17, `coreLibraryDesugaringEnabled true`.

- [ ] **Step 1: Bump plugin versions in `app/android/settings.gradle`**

Replace the `plugins` block:

```groovy
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.3.2" apply false
    id "org.jetbrains.kotlin.android" version "1.9.24" apply false
}
```

- [ ] **Step 2: Bump Gradle wrapper in `app/android/gradle/wrapper/gradle-wrapper.properties`**

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.6-all.zip
```

- [ ] **Step 3: Update `app/android/app/build.gradle`**

In the `android { }` block, change `compileSdk`, `compileOptions`, add `kotlinOptions`, and change `defaultConfig.targetSdk`; add the desugaring dependency at file end:

```groovy
android {
    namespace = "io.politiface.politiface"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "io.politiface.politiface"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutterVersionCode.toInteger()
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            // TODO(release-signing): replaced in the signing task.
            signingConfig = signingConfigs.debug
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"
}
```

(Keep the existing `localProperties` / `flutterVersionCode` / `flutterVersionName` preamble above `android { }` unchanged. Remove the two scaffold TODO comment lines that reference developer.android.com; the signing TODO above is intentional and dies in Task 6.)

- [ ] **Step 4: Build a debug APK to verify the toolchain**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface/app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --debug
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`. If Gradle fails, fix within AGP 8.3.x / Gradle 8.x first; upgrading Flutter is last resort per spec.

- [ ] **Step 5: Commit**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface
git add app/android/settings.gradle app/android/gradle/wrapper/gradle-wrapper.properties app/android/app/build.gradle
git commit -m "Android: AGP 8.3.2 / Gradle 8.6 / SDK 35 toolchain with desugaring

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Manifest — app label, permissions, notification receivers

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Produces: manifest entries the notification code path (Task 5) and QA (Task 8) depend on: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, and the flutter_local_notifications scheduled/boot receivers.

- [ ] **Step 1: Edit the manifest**

Add the three permissions directly after the opening `<manifest ...>` tag, change the label, and add the receivers inside `<application>` after the `flutterEmbedding` meta-data:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <application
        android:label="Politiface"
        ...>
        ...
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>
    ...
</manifest>
```

(`...` marks existing content that stays exactly as is: the activity block, the PROCESS_TEXT queries block.)

- [ ] **Step 2: Build and verify the merged manifest**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface/app
flutter build apk --debug
grep -o 'POST_NOTIFICATIONS\|RECEIVE_BOOT_COMPLETED\|SCHEDULE_EXACT_ALARM\|ScheduledNotificationBootReceiver\|android:label="Politiface"' \
  build/app/intermediates/merged_manifests/debug/*/AndroidManifest.xml | sort -u
```

Expected: all five strings print. (The merged manifest path may be `.../debug/AndroidManifest.xml` on some AGP versions; check both.)

- [ ] **Step 3: Commit**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface
git add app/android/app/src/main/AndroidManifest.xml
git commit -m "Android: app label, notification permissions, scheduled/boot receivers

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Adaptive launcher icons

The shipped artwork is `app/assets/icon/app_icon.png` (1024x1024, solid navy background with the P-profile mark). Adaptive icons need a separate foreground layer (mark on transparency, content inside the safe zone) plus a background color. Because the artwork's background is solid, scaling the whole square icon down onto a transparent canvas and using the sampled corner color as the background layer blends seamlessly.

**Files:**
- Create: `scripts/generate_android_adaptive_icon.py`
- Create (generated): `app/assets/icon/app_icon_android_fg.png`
- Modify: `app/pubspec.yaml` (`flutter_launcher_icons` block)
- Generated: `app/android/app/src/main/res/mipmap-*` files

**Interfaces:**
- Consumes: `app/assets/icon/app_icon.png` (existing artwork; do not modify it).
- Produces: launcher icons referenced by the manifest's existing `@mipmap/ic_launcher` and by `AndroidInitializationSettings('@mipmap/ic_launcher')` in the notification service. No code change needed for either.

- [ ] **Step 1: Write the foreground generator script**

Create `scripts/generate_android_adaptive_icon.py`:

```python
"""Generates the Android adaptive-icon foreground layer from app_icon.png.

The adaptive foreground is the full square icon scaled down onto a
transparent 1024x1024 canvas so the mark lands inside the adaptive safe
zone (center 66/108 of the layer). The background layer is a solid color
sampled from the icon's corner, so the scaled square blends invisibly.
Assumes the icon background is a solid color; if the artwork ever gains a
gradient background, this script needs a real foreground asset instead.

Usage: python3 scripts/generate_android_adaptive_icon.py
Prints the background hex to paste into pubspec.yaml.
"""

from pathlib import Path

from PIL import Image

SCALE = 0.72  # icon square as fraction of the 1024 canvas; tune if QA
              # shows the mark clipped by the round mask or too small.


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    src_path = root / "app" / "assets" / "icon" / "app_icon.png"
    out_path = root / "app" / "assets" / "icon" / "app_icon_android_fg.png"

    src = Image.open(src_path).convert("RGBA")
    r, g, b, _ = src.getpixel((0, 0))
    bg_hex = f"#{r:02X}{g:02X}{b:02X}"

    size = 1024
    inner = int(size * SCALE)
    fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    scaled = src.resize((inner, inner), Image.LANCZOS)
    offset = (size - inner) // 2
    fg.paste(scaled, (offset, offset))
    fg.save(out_path, "PNG")

    print(f"wrote {out_path}")
    print(f"adaptive_icon_background: \"{bg_hex}\"")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface
python3 scripts/generate_android_adaptive_icon.py
```

Expected: prints the generated path and a hex color like `adaptive_icon_background: "#1B2A4A"`. If PIL is missing: `python3 -m pip install pillow`.

- [ ] **Step 3: Update the `flutter_launcher_icons` block in `app/pubspec.yaml`**

Replace the existing block, substituting the hex printed in Step 2:

```yaml
flutter_launcher_icons:
  ios: true
  android: true
  remove_alpha_ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#HEX_FROM_STEP_2"
  adaptive_icon_foreground: "assets/icon/app_icon_android_fg.png"
```

- [ ] **Step 4: Generate icons and verify**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface/app
dart run flutter_launcher_icons
ls android/app/src/main/res/mipmap-anydpi-v26/
git status --short
```

Expected: `ic_launcher.xml` exists in `mipmap-anydpi-v26`; new files only under `app/android/.../res/` and `app/assets/icon/`; zero modified files under `app/ios/` (identical rewrites show no diff). If iOS icon files show as modified, inspect: content-identical rewrites can be checked out (`git checkout -- app/ios`), real changes are a stop-and-investigate.

- [ ] **Step 5: Commit**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface
git add scripts/generate_android_adaptive_icon.py app/assets/icon/app_icon_android_fg.png app/pubspec.yaml app/android/app/src/main/res
git commit -m "Android: adaptive launcher icons from the navy P mark

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: NotificationService Android support (permission, status, exact-alarm fallback)

Three gaps in `app/lib/features/notifications/data/notification_service.dart`, which is iOS-only today:
1. `requestPermission()` only calls the iOS implementation; Android 13+ needs `requestNotificationsPermission()`.
2. `isAuthorized()` only checks iOS; Android has `areNotificationsEnabled()`.
3. Both `zonedSchedule` calls hardcode `AndroidScheduleMode.exactAllowWhileIdle`; on Android 14+ the `SCHEDULE_EXACT_ALARM` permission is denied by default, and exact scheduling then throws `PlatformException(exact_alarms_not_permitted)`. Fall back to inexact scheduling (a daily 7 PM reminder tolerates inexact delivery windows).

Callers (`settings_screen.dart` x3, `push_service.dart`) already route through `requestPermission()`, so no call-site changes.

**Files:**
- Modify: `app/lib/features/notifications/data/notification_service.dart`
- Test: `app/test/features/notifications/schedule_mode_test.dart` (new)

**Interfaces:**
- Consumes: manifest permissions from Task 3.
- Produces: `pickAndroidScheduleMode({required bool canScheduleExact}) -> AndroidScheduleMode`, a top-level pure function exported from `notification_service.dart`. Existing public API (`requestPermission()`, `isAuthorized()`, `scheduleDailyReminder()`, `scheduleAt(...)`) keeps its signatures.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/notifications/schedule_mode_test.dart`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/notifications/data/notification_service.dart';

void main() {
  test('exact scheduling when the OS permits exact alarms', () {
    expect(
      pickAndroidScheduleMode(canScheduleExact: true),
      AndroidScheduleMode.exactAllowWhileIdle,
    );
  });

  test('falls back to inexact when exact alarms are not permitted', () {
    expect(
      pickAndroidScheduleMode(canScheduleExact: false),
      AndroidScheduleMode.inexactAllowWhileIdle,
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface/app
flutter test test/features/notifications/schedule_mode_test.dart
```

Expected: FAIL (compile error, `pickAndroidScheduleMode` undefined).

- [ ] **Step 3: Implement in `notification_service.dart`**

Add the pure function at top level (after imports, before the class):

```dart
/// Exact alarms fire on the second but need a permission Android 14+
/// denies by default; inexact still delivers within an OS-chosen window,
/// which is fine for a daily reminder. Pure so it is unit-testable.
AndroidScheduleMode pickAndroidScheduleMode({required bool canScheduleExact}) =>
    canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
```

Replace the body of `requestPermission()`:

```dart
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? false;
  }
```

Replace the body of `isAuthorized()` (keep its doc comment):

```dart
  Future<bool> isAuthorized() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final opts = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.checkPermissions();
    return opts?.isEnabled ?? false;
  }
```

Add a private helper inside the class:

```dart
  /// iOS ignores androidScheduleMode, so the exact default is safe there.
  Future<AndroidScheduleMode> _scheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return AndroidScheduleMode.exactAllowWhileIdle;
    final canExact = await android.canScheduleExactNotifications() ?? false;
    return pickAndroidScheduleMode(canScheduleExact: canExact);
  }
```

In `scheduleDailyReminder()` and `scheduleAt(...)` (the only two `zonedSchedule` calls), replace:

```dart
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
```

with:

```dart
      androidScheduleMode: await _scheduleMode(),
```

- [ ] **Step 4: Run the new test, the analyzer, and the full suite**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface/app
flutter test test/features/notifications/schedule_mode_test.dart
flutter analyze
flutter test
```

Expected: new test PASSES, analyzer clean, full suite green.

- [ ] **Step 5: Commit**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface
git add app/lib/features/notifications/data/notification_service.dart app/test/features/notifications/schedule_mode_test.dart
git commit -m "Notifications: Android permission, status, and exact-alarm fallback

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Release signing (upload keystore + key.properties)

**Files:**
- Create (outside repo): `~/politiface-keys/upload-keystore.jks`, `~/politiface-keys/README.txt`
- Create (gitignored): `app/android/key.properties`
- Modify: `app/android/app/build.gradle` (signing config)

**Interfaces:**
- Produces: a release-signed build used by Task 7's script. `key.properties` keys: `storePassword`, `keyPassword`, `keyAlias` (value `upload`), `storeFile` (absolute path).

- [ ] **Step 1: Generate the keystore with a random password**

```bash
mkdir -p ~/politiface-keys
KS_PASS="$(openssl rand -base64 24)"
keytool -genkeypair -v \
  -keystore ~/politiface-keys/upload-keystore.jks \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$KS_PASS" -keypass "$KS_PASS" \
  -dname "CN=Politiface, O=Politiface, L=Mississauga, ST=Ontario, C=CA"
cat > ~/politiface-keys/README.txt <<EOF
Politiface Android upload keystore. Generated $(date +%Y-%m-%d).
Back up this whole folder (keystore + password) in the founders'
password manager NOW. Play App Signing holds the real app key, so a
lost upload key is recoverable via Google support, but treat this
backup as mandatory anyway.
Password: $KS_PASS
EOF
chmod 600 ~/politiface-keys/*
```

- [ ] **Step 2: Write `app/android/key.properties`**

```bash
KS_PASS="$(grep '^Password: ' ~/politiface-keys/README.txt | cut -d' ' -f2-)"
cat > /Users/rkapdi/Developer/politiFace/politiface/app/android/key.properties <<EOF
storePassword=$KS_PASS
keyPassword=$KS_PASS
keyAlias=upload
storeFile=$HOME/politiface-keys/upload-keystore.jks
EOF
```

- [ ] **Step 3: Verify it is ignored**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface
git check-ignore app/android/key.properties && echo IGNORED
```

Expected: `IGNORED`. If not, STOP and fix `.gitignore` before proceeding.

- [ ] **Step 4: Wire signing into `app/android/app/build.gradle`**

Above the `android { }` block (after the existing `flutterVersionName` preamble), add:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.withReader("UTF-8") { reader ->
        keystoreProperties.load(reader)
    }
}
```

Inside `android { }`, replace the `buildTypes` block (and its signing TODO) with:

```groovy
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"]
                keyPassword = keystoreProperties["keyPassword"]
                storeFile = file(keystoreProperties["storeFile"])
                storePassword = keystoreProperties["storePassword"]
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug signing when key.properties is absent so
            // contributors can still `flutter run --release` from the open
            // source repo without the private keystore.
            signingConfig = keystorePropertiesFile.exists()
                ? signingConfigs.release
                : signingConfigs.debug
        }
    }
```

- [ ] **Step 5: Build a signed release AAB and verify the signature**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface/app
flutter build appbundle --release
KS_PASS="$(grep '^Password: ' ~/politiface-keys/README.txt | cut -d' ' -f2-)"
jarsigner -verify -keystore ~/politiface-keys/upload-keystore.jks \
  -storepass "$KS_PASS" build/app/outputs/bundle/release/app-release.aab
```

Expected: build succeeds; `jarsigner` prints `jar verified.`

- [ ] **Step 6: Commit (build.gradle only; confirm no secrets staged)**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface
git status --short
git add app/android/app/build.gradle
git commit -m "Android: release signing from gitignored key.properties

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Reproducible build script

**Files:**
- Create: `scripts/build_android.sh`

**Interfaces:**
- Consumes: signing from Task 6; env vars `SENTRY_DSN`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` (all optional; empty legally disables the feature, matching codemagic.yaml).
- Produces: `app/build/app/outputs/bundle/release/app-release.aab`; this script later becomes the body of the Codemagic `android-release` workflow (week two, out of scope).

- [ ] **Step 1: Write `scripts/build_android.sh`**

```bash
#!/usr/bin/env bash
# Politiface Android release build. Mirrors the codemagic.yaml iOS steps.
# Empty dart-defines are legal (they disable the feature); the report below
# makes a degraded binary a visible choice rather than a silent accident.
set -euo pipefail

cd "$(dirname "$0")/../app"

echo "dart-define report:"
for v in SENTRY_DSN SUPABASE_URL SUPABASE_ANON_KEY; do
  if [ -n "${!v:-}" ]; then
    echo "  $v: set"
  else
    echo "  $v: EMPTY (feature disabled in this build)"
  fi
done

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter build appbundle --release \
  --dart-define=SENTRY_DSN="${SENTRY_DSN:-}" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

echo "AAB: $(pwd)/build/app/outputs/bundle/release/app-release.aab"
```

- [ ] **Step 2: Make it executable and run it**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface
chmod +x scripts/build_android.sh
./scripts/build_android.sh
```

Expected: define report prints (all three EMPTY is fine locally), tests pass, AAB path prints. The real Play upload build runs this with the production env vars exported first.

- [ ] **Step 3: Commit**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface
git add scripts/build_android.sh
git commit -m "Android: reproducible release build script

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Emulator QA pass

Manual verification on the API 35 AVD from Task 1. Findings that are quick fixes get fixed and committed individually; anything structural gets reported, not silently patched.

**Files:**
- Possibly modify: whatever QA findings require (each its own commit).

**Interfaces:**
- Consumes: everything above.
- Produces: a go/no-go on the build plus the edge-to-edge decision (see decision rule below).

- [ ] **Step 1: Boot the emulator and install the app**

```bash
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
~/Library/Android/sdk/emulator/emulator -avd politiface_api35 &
cd /Users/rkapdi/Developer/politiFace/politiface/app
flutter devices   # wait until the emulator appears
flutter run --release
```

- [ ] **Step 2: Functional checklist (from the spec)**

Walk each item; record pass/fail with notes:

1. Fresh install: content seeding completes, decks and chapter journey render.
2. FSRS session flow end to end; Mock FCLE; readiness indicator.
3. Notifications: toggling the reminder in Settings triggers the Android 13+ permission prompt; a scheduled reminder fires (set device clock forward past 7 PM local, or temporarily schedule near-term via `scheduleAt` path by arming a chapter nudge); notification tap routes correctly.
4. Reboot persistence: `adb reboot`, wait for boot, confirm the scheduled reminder still fires.
5. Workmanager: with Washington notifications enabled, `adb shell dumpsys jobscheduler | grep -i politiface` shows a registered job.
6. Share sheet opens (score challenge share); sounds play; Supabase auth sign-in and sync work (needs `SUPABASE_URL`/`SUPABASE_ANON_KEY` defines exported before `flutter run` for this item; if unavailable locally, mark deferred to the internal-track build).
7. Edge-to-edge: check every main screen for content hidden under the status bar or gesture nav bar.

- [ ] **Step 3: Apply the edge-to-edge decision rule**

If inset issues exist and are fixable in under an hour, fix them (own commit). Otherwise add to `app/android/app/src/main/res/values/styles.xml` in BOTH `values/` and `values-night/`, inside each `<style>` currently there:

```xml
<item name="android:windowOptOutEdgeToEdgeEnforcement">true</item>
```

and commit with a note that this is the sanctioned temporary opt-out, plus a follow-up entry in the week-two list of the spec.

- [ ] **Step 4: Re-run the full test suite and the build script one final time**

```bash
cd /Users/rkapdi/Developer/politiFace/politiface
./scripts/build_android.sh
```

Expected: green tests, fresh signed AAB. This AAB is the artifact for the Play internal track upload (Play Console work is founder-facing per the spec, not part of this plan).

- [ ] **Step 5: Commit any remaining QA fixes and report**

Summarize checklist results, including anything deferred (for example Supabase auth if defines were unavailable), in the final report to the user.
