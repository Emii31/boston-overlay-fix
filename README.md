# Boston Overlay Fix (v1.0.0)

[![Release](https://img.shields.io/github/v/release/Emii31/boston-overlay-fix?include_prereleases)](https://github.com/Emii31/boston-overlay-fix/releases)
[![License](https://img.shields.io/github/license/Emii31/boston-overlay-fix)](LICENSE)

A clean, lightweight, and pre-built fix designed to resolve overlay rendering and framework conflict issues on **Motorola "boston" (Moto G Stylus 5G 2024)** devices when running custom ROMs or GSIs. 

This v1.0.0 release provides a permanent fix for broken UI elements, hardware overlays, and systemic overlay glitches, restoring seamless visual stability.

---

## 🚀 Features & Fixes (v1.0.0)
* **Hardware Overlay Correction:** Fixes broken rendering pipelines and glitchy UI layers.
* **GSI Compatibility:** Tailored specifically to integrate smoothly with modern Generic System Images (Android 14/15/16).
* **Pre-compiled & Ready:** No building required. Flash/install and go.

## 📦 Installation Guide

### Prerequisites
* A Motorola Moto G Stylus 5G 2024 (`boston`) with an unlocked bootloader.
* Custom Recovery (OrangeFox/TWRP) or root access (Magisk/KernelSU) depending on your implementation method.
* A complete backup of your current setup.

### Step-by-Step Installation
1. Head over to the **[Releases](https://github.com/Emii31/boston-overlay-fix/releases)** tab and download the `v1.0.0` package.
2. Transfer the file to your device's internal storage.
3. Depending on how you packaged your build:
   * **For Magisk/KSU Modules:** Open your root manager, navigate to the Modules section, select *Install from storage*, choose the zip, and reboot.
   * **For Recovery Flashables:** Boot into recovery, flash the zip, wipe caches, and reboot.

---

## 🛠️ Troubleshooting

* **Bootloop or Soft Lock:** If your device experiences a bootloop after flashing, boot into recovery and remove the module/overlay manually via the file manager or terminal (`adb wait-for-device shell magisk --remove-modules`).
* **Overlay Not Applying:** Ensure you are running a compatible vendor base. This fix is targeted at the `boston` board layout.

---

## 🤝 Contributing

Found a bug or want to optimize the overlay structure further?
1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/Optimization`).
3. Commit your changes (`git commit -m 'Optimize overlay matrix'`).
4. Push to the branch (`git push origin feature/Optimization`).
5. Open a **Pull Request**.

---


## What V1 covers

Eight RRO overlays, each targeting the specific package the original stock
value came from:

| Overlay | Target package | Covers |
|---|---|---|
| BostonFrameworkOverlay | android | Rounded corners, refresh rate defaults not covered by Display overlay, auto-brightness curve (13-step lux/nits/backlight arrays), brightness debounce timing, doze brightness |
| BostonCutoutOverlay | android | `config_mainBuiltInDisplayCutout` (100x105px rect), status bar height (105px) |
| BostonUDFPSOverlay | android | UDFPS sensor position (540, 2154, radius 91px), biometric sensor type, LHBM support + 120Hz fix-refresh-rate requirement during scan |
| BostonSystemUIOverlay | com.android.systemui | Visual cutout protection circle (center 540,53 radius 33px - different from the WM-level rect above, both are real and serve different purposes), rounded corner radius for SystemUI decorations, nav bar deadzone |
| BostonDisplayOverlay | android | Refresh rate policy (60-120Hz range, 90Hz "in zone" rate, ambient thresholds), color modes, night light availability, doze/AOD flags, double-tap-to-wake |
| BostonAudioOverlay | android | Safe media volume flag, speed-up-audio-on-MT-calls flag |
| BostonWFDOverlay | android | WiFi Display (Miracast) enable flag |
| BostonCoreSettingsExtOverlay | com.motorola.coresettingsext | Supported refresh rate list for Motorola's own settings UI (may be inert on a GSI if this proprietary package isn't present - harmless either way) |


## Priority values (for your own reference / future edits)

All overlays targeting `android` have distinct RRO priorities to avoid any
dependency on tie-break behavior: BostonFrameworkOverlay=10,
BostonDisplayOverlay=11, BostonCutoutOverlay=12, BostonAudioOverlay=13,
BostonWFDOverlay=14, BostonUDFPSOverlay=16. (Verified: zero actual
resource-key overlap exists between any of these overlays regardless of
priority value - the distinct numbering is precautionary, not required by
a real conflict.) BostonSystemUIOverlay=10 on its own target
(com.android.systemui). BostonCoreSettingsExtOverlay=15 on its own target
(com.motorola.coresettingsext), matching the stock value exactly.


## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
