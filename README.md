# Boston GSI Overlay Fix - V1

## What this actually is

This is NOT a flashable Magisk zip yet. It is a verified **source + build
kit**. Every resource value in `overlays/*/res/values/config.xml` has been
decoded directly from your uploaded Boston stock firmware dump and
cross-checked against the source APK's own resource ID table - nothing in
those files is estimated, calculated, or guessed. Every one of those files
has been confirmed well-formed XML and has been confirmed to successfully
compile via `aapt2 compile` (the `.zip` files in `compiled_resources/` are
that real, verified compiler output, not placeholders).

**What could not be completed in the sandbox that built this:** the final
`aapt2 link` step (compiled resources -> installable APK) and signing.
`aapt2 link` needs a clean, standard Android framework resource base to
resolve `android:` references against. The only such file available in the
sandbox - the `framework-res.apk` from your own firmware dump - has a
non-standard resource table (its header declares 6 duplicate `android`
package chunks instead of the standard 1), which both aapt2 builds tested
in the sandbox rejected outright with a hard parse error. This is very
likely a Motorola build-tooling artifact, not a corrupted file - your phone
runs it fine - but a standalone `aapt2` will not load it. No clean
alternative framework file was obtainable through the sandbox's restricted
network access.

Run `build.sh` on your own machine (where you already have a working
Android SDK for your `aospdtgen` / device-tree work) to complete the link,
align, and sign steps, and produce the actual flashable
`boston_gsi_overlay_fix_v1.zip`. See the comments at the top of `build.sh`
for exact requirements.

## Building via GitHub Actions instead (no local Android SDK required)

`.github/workflows/build.yml` does the same link/align/sign/assemble
sequence as `build.sh`, but on GitHub's own runners, which come with a
clean, standard `android.jar` - avoiding this sandbox's specific problem
with your device's non-standard `framework-res.apk`. Every command's exit
code is checked explicitly (not relying on `set -e` mid-loop, since that
was verified by direct test to silently swallow per-overlay error
reporting - see comments in the workflow file).

To use it:
1. Push this whole `boston_module/` directory to a new GitHub repo (public
   or private, either works)
2. Go to the repo's **Actions** tab, select **Build Boston Overlay Fix**,
   click **Run workflow**
3. Wait for it to finish (a few minutes - it's installing an SDK from
   scratch each run)
4. Download the `boston_gsi_overlay_fix_v1` artifact from the completed
   run - that's your flashable zip
5. Flash via Magisk app > Modules > Install from storage > reboot

If the run fails, open the failed step's log - the "Link, align, and sign
each overlay" step prints exactly which overlay and which tool (aapt2 /
zipalign / apksigner) failed, with the real exit code, rather than just a
generic failure.

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

## What is explicitly NOT in V1, and why

**Telephony/IMS** - Per your original scope instruction. Several real,
verified values (`config_device_volte_available`, `config_carrier_volte_available`,
`config_volte_replacement_rat`, `networkAttributes`, `radioAttributes`,
`config_qualified_networks_service_package`, and related WLAN/network
service package strings) were found in the same source RROs as everything
above and were deliberately excluded, not missed.

**Vendor audio HAL routing / volume-step tuning** - No RRO-overridable
framework resource for this exists anywhere in the dump; volume tuning
lives in `vendor/audio/sku_parrot/audio_policy_configuration.xml`,
`mixer_paths_parrot_qrd_sku1.xml`, etc. Those are vendor HAL config files
consumed directly from `/vendor/etc`, not RRO targets - delivering them
would require a file-replacement module, which risks mismatching your
GSI's actual audio HAL expectations if built blind, without you being able
to pull and compare the GSI's own currently-active config. Deferred to V2.

**Fingerprint enrollment UI (colors, animation timing, wizard strings)** -
Found in `MotoSettingsFPSDisplayOverlay.apk` but this affects what the
Settings app *shows* during enrollment, not whether the UDFPS hardware
reads correctly. Not a gap in the hardware fix.

**Navigation bar height/width, gesture height, multi-window support,
screen width/height/density resources** - Checked for and NOT found
anywhere in the decoded resource tables of any overlay APK in the dump.
These AOSP/GSI defaults are apparently already correct on this device
(Motorola didn't need to patch them), so there was nothing to override.

## Known open questions for V2

- Whether `com.motorola.coresettingsext` is actually present on your GSI's
  running system (the overlay is harmless if not, but confirming would
  validate it's doing something)
- Real values for `MotoSettingsFPSDisplayOverlay`'s empty dimen entries
  (`ring_progress_bar_thickness`, `enrolling_animation_margin`,
  `fingerprint_pre_enroll_content_padding_top`) - these resolved to
  genuinely empty strings across every density config in the dump; unclear
  if that's intentional in stock or a resource-linking issue in Motorola's
  own build
- Whatever new files/dumps you're able to pull once you have a way to
  extract from the running GSI (per your note that you currently can't
  pull or check files from within it)

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
