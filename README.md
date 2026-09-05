# Boston GSI Overlay Fix

A verified Magisk module for the Motorola "Boston" GSI. This project extracts and applies device-specific configuration values from the stock firmware to fix display, audio, UI, and biometric issues on a Generic System Image (GSI).

## 📦 What This Module Does

This module replaces incorrect GSI defaults with verified values extracted directly from the official Motorola "Boston" stock firmware. It ensures your GSI behaves exactly like the stock ROM for critical system features.

### ✅ What is Fixed (V5)

| Feature | Description |
| :--- | :--- |
| **Display** | Correct refresh rate policy (60-120Hz), brightness curves, ambient thresholds, and color modes. |
| **SystemUI** | Fixes lock screen notification overlap, status bar height, navigation bar deadzone, and rounded corners. |
| **Audio** | Enables safe media volume flags and integrates **Dolby Audio (DAP, GameDAP, DVL)** effects. |
| **UDFPS** | Correctly positions the under-display fingerprint sensor (540, 2154, radius 91px) and enables LHBM support. |
| **Device Identity** | Fixes "Unknown" values in the About Phone section (Model, Manufacturer, Brand, Platform). |
| **WiFi Display** | Enables Miracast support. |

### ⚠️ Known Limitations (Not Fixed)

- **Telephony (VoLTE/SMS/USSD)**: Not included in this release (deferred to future versions).
- **Vendor Audio Tuning**: Volume steps and mixer paths are not overridden.
- **Fingerprint Enrollment UI**: Cosmetic changes to the enrollment wizard are excluded.
- **Speaker Calibration**: Known issue with Awinic calibration parsing; not resolved in V5.
- **Battery/Camera Specs**: Cannot be fixed via overlays (requires HAL support).

## 📍 Where These Values Came From

Every resource value in this module is **verified and decoded**, not guessed or estimated.

1.  **Source**: Extracted directly from the official Motorola "Boston" stock firmware dump.
2.  **Verification**: Cross-checked against the source APK's resource ID table.
3.  **Compilation**: Confirmed to successfully compile via `aapt2` to ensure compatibility.
4.  **Testing**: Values were tested on-device via `dumpsys` and `logcat` to confirm they take effect.

*See `docs/` for detailed technical logs and investigation notes.*

## 🚀 Installation

This module is pre-built and released automatically via GitHub Actions.

1.  **Download**: Go to the **Releases** section on the right sidebar and download `boston_gsi_overlay_fix_v5.zip`.
2.  **Flash**:
    - Open **Magisk** (or KernelSU).
    - Go to **Modules** > **Install from Storage**.
    - Select the downloaded zip file.
3.  **Reboot**: Reboot your device.

## 🛠️ Build Process (For Developers)

For those who want to rebuild the module:

- **GitHub Actions**: The `.github/workflows/build.yml` file automates the entire process (compile, link, align, sign, and release) on every push to `main`.
- **Local Build**: Run `build.sh` on your machine with a working Android SDK to generate the zip locally.

## 📄 License & Credits

- **Author**: Emii31
- **Source Firmware**: Motorola "Boston" Stock ROM
- **Tools**: aapt2, apksigner, zipalign, Magisk

---

*For detailed technical documentation, investigation logs, and known open questions, please refer to the `docs/` folder.*
