# Boston Overlay Fix (v1.3.0)

[![Release](https://img.shields.io/github/v/release/Emii31/BostonOverlayExtractor?include_prereleases)](https://github.com/Emii31/BostonOverlayExtractor/releases)
[![License](https://img.shields.io/github/license/Emii31/BostonOverlayExtractor)](LICENSE)

A clean, lightweight fix designed to resolve overlay rendering, biometrics, and framework conflict issues on **Motorola "boston" (Moto G Stylus 5G 2024)** devices when running custom ROMs or GSIs. 

This framework provides a permanent fix for broken UI elements, hardware overlays, and systemic overlay glitches, restoring seamless visual stability.

---

## 📄 Changelog (v1.3.0 - V3-Kit Upgrade)

Version 1.3 replaces the static pre-compiled structure of V1 with a completely rebuilt development workspace, introducing deeper hardware calibrations and automated cloud compilation.

* **Rebuilt Source Architecture (V3-Kit):** Converted all pre-compiled overlay APKs into raw, human-readable Android source files (`AndroidManifest.xml` and `res/values/config.xml`), making future automated tweaks seamless.
* **Under-Display Fingerprint (UDFPS) Fix:** Added absolute coordinate mapping (centerX: 540px, centerY: 2154px, radius: 91px) to align the optical scanner perfectly under GSIs. 
* **High-Brightness Mode (LHBM) & 120Hz Rule:** Implemented Local High-Brightness Mode and forced a mandatory 120Hz display lock during fingerprint scans to prevent illumination and read failures.
* **Display & Brightness Calibration:** Added 13-step stock auto-brightness curves (lux/nits/backlight), explicit peak refresh rate ambient thresholds, and calibrated display corner radii (75.0px).
* **Audio & Connectivity Injections:** Added low-level latency reductions for incoming calls (`config_speed_up_audio_on_mt_calls`), enforced safe media volume warning caps, and enabled native Wireless Display (Miracast) support.
* **Low-Level System Properties:** Introduced a dedicated `system.prop` layer to actively inject Android system configurations straight into the GSI environment alongside resource changes.
* **Automated CI/CD Workflows:** Integrated a built-in GitHub Actions pipeline (`build.yml`) to automatically compile flashable Magisk binaries directly on the cloud upon pushing changes.

---

## 📦 Installation Guide

### Prerequisites
* A Motorola Moto G Stylus 5G 2024 (`boston`) with an unlocked bootloader.
* Root access via Magisk or KernelSU to mount the module framework.
* A complete backup of your current setup.

### Step-by-Step Installation
1. Head over to the **[Releases](https://github.com/Emii31/BostonOverlayExtractor/releases)** tab and download the compiled `v1.3.0` package.
2. Transfer the zip file to your device's internal storage.
3. Open your root manager (Magisk/KernelSU), navigate to the Modules section, select *Install from storage*, choose the zip, and reboot your device.

---

## 🛠️ Troubleshooting

* **Bootloop or Soft Lock:** If your device experiences a bootloop after flashing, boot into a custom recovery and remove the module manually via the integrated file manager or terminal (`adb wait-for-device shell magisk --remove-modules`).
* **Overlay Not Applying:** Ensure you are running a compatible vendor base. This fix is strictly targeted at the `boston` board layout.

---

## 🤝 Contributing

Found a bug or want to optimize the overlay structure further?
1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/Optimization`).
3. Commit your changes (`git commit -m 'Optimize overlay matrix'`).
4. Push to the branch (`git push origin feature/Optimization`).
5. Open a **Pull Request**.

---

## 🔍 What v1.3.0 Covers

Eight RRO overlays, each targeting the specific package the original stock value came from:

| Overlay | Target package | Covers |
|---|---|---|
| BostonFrameworkOverlay | android | Rounded corners (75.0px), refresh rate defaults, 13-step auto-brightness curves (lux/nits/backlight arrays), brightness debounce timing, doze brightness. |
| BostonCutoutOverlay | android | `config_mainBuiltInDisplayCutout` (100x105px rect), portrait status bar height scaling (105px). |
| BostonUDFPSOverlay | android | UDFPS sensor absolute positioning (540, 2154, radius 91px), biometric sensor type mapping (0:2:15), LHBM support + 120Hz fixed refresh rate constraint during illumination scans. |
| BostonSystemUIOverlay | com.android.systemui | Visual cutout protection circle geometry (`M 507,53 a 33,33...` centered at 540,53), rounded corner radius for SystemUI decorations, navigation bar deadzones. |
| BostonDisplayOverlay | android | Refresh rate policies (60-120Hz range, 90Hz comfort-zone bounds, ambient lux thresholds), color modes, night light availability, doze/AOD flags, double-tap-to-wake. |
| BostonAudioOverlay | android | Safe media volume flags, speed-up-audio-on-MT-calls latency mitigations. |
| BostonWFDOverlay | android | WiFi Display (Miracast) hardware enable rules matching underlying HAL execution states. |
| BostonCoreSettingsExtOverlay | com.motorola.coresettingsext | Supported refresh rate selection list (`["0", "60", "120"]`) mapped safely to preserve original Motorola settings UI functionality. |

### Priority Scaling (For Reference)
All overlays targeting `android` have distinct RRO priorities to avoid any dependency on tie-break behavior: BostonFrameworkOverlay=10, BostonDisplayOverlay=11, BostonCutoutOverlay=12, BostonAudioOverlay=13, BostonWFDOverlay=14, BostonUDFPSOverlay=16. BostonSystemUIOverlay=10 on its own target (`com.android.systemui`). BostonCoreSettingsExtOverlay=15 on its own target (`com.motorola.coresettingsext`).

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
