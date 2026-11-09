# LinkPilot AI — Build Information

**Application Name:** LinkPilot AI  
**Package Identifier:** `com.linkpilot.ai.linkedin_ai_automation`  
**Flutter SDK:** 3.47.9 (channel stable)  
**Dart SDK:** 3.13.7  
**Build Target:** Android ARM64, ARMv7, x86_64 APK  
**Build Date:** November 9, 2026  
**Architecture:** Multi-Customer Mobile SaaS + FastAPI Backend  

---

## 1. Build Verification & Integrity

- **Artifact Name:** `app-release.apk`
- **Output Path:** `mobile/build/app/outputs/flutter-apk/app-release.apk`
- **Delivery Path:** `DELIVERY/app-release.apk`
- **Target OS:** Android 5.0+ (API Level 21 through 34+)
- **Target Architecture:** universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`)
- **Default Injected API Base:** `https://api.linkpilot.io` (overridable at runtime or via `--dart-define=API_BASE_URL=...`)

---

## 2. Cryptographic Checksum

| File | Algorithm | Hash Digest | Size |
| :--- | :--- | :--- | :--- |
| `app-release.apk` | SHA-256 | `329595cbc56c2c6e246cd9fb95e50eb9f153d25551c4322564e77f5f4ae9dfac` | 52.0 MB (54.5 MB uncompressed) |
| `LinkPilot_AI_Final_Delivery.zip` | SHA-256 | *Generated in delivery root* | — |

---

## 3. Real Device Verification

- **Connected Device:** Nothing Phone (2a) / Pacman (`model: A142`, `id: 65CICECYGEFQGY69`)
- **Android OS:** Android 16 (API Level 36)
- **Installation Command:** `adb -s 65CICECYGEFQGY69 install -r DELIVERY/app-release.apk`
- **Result:** `Performing Streamed Install` -> `Success`
- **Process Activity:** Launched `com.linkpilot.ai.linkedin_ai_automation/.MainActivity` successfully (PID 14280)

```bash
cd mobile
export JAVA_HOME="/home/resanul/jdk-21"
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="/home/resanul/android-sdk"
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://api.linkpilot.io
```
