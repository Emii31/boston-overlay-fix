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

## V3 findings

- **Lock screen: keyguard clock/notification overlap — FIXED, shipped.**
  `keyguard_status_view_bottom_margin` increased from the GSI SystemUI's
  default 16dip to 40dip (in `BostonSystemUIOverlay`). Confirmed via user
  screenshot that at 16dip the lock screen notification stack visually
  overlapped the clock/date/weather block. No stock Motorola override
  exists for this key to source a factory value from (confirmed absent in
  both stock RROs), so this is a visual tuning adjustment, not a decoded
  factory value like the rest of this module's overlay content — flagged
  as such in the file's own comments. Confirmed this device's screen
  computes to ~sw410dp, meaning the GSI SystemUI's only unqualified
  (default) config bucket applies here; the sw600dp+/sw720dp+ qualified
  variants present in the same resource do not apply and were correctly
  not used.

- **Dolby audio (DAP/GameDAP/DVL) — NOT shipped, held back pending
  on-device test.** Real progress made, but the last verification step
  hasn't happened yet, so this is deliberately excluded from V3:
  - Stock Boston's `audio_effects.xml` has Dolby fully wired into live
    stream postprocessing (music/ring/alarm/system/notification streams
    all apply `dlb_*` effects).
  - Confirmed via on-device search that the real Dolby DSP libraries
    (`libswdap.so`, `libswgamedap.so`, `libdlbvol.so`) ARE present on this
    device's vendor partition, both 32 and 64-bit. `libswspatializer.so`
    and `libswvqe.so` are confirmed ABSENT — a corrected config with those
    two removed has been drafted (neither was referenced in postprocess
    routing in the original, so removal doesn't change any active
    behavior, only removes two now-dangling declarations).
  - Confirmed via `lshal` and `dumpsys media.audio_flinger` that the
    backing Dolby HIDL service (`vendor.dolby.hardware.dms@2.0` and
    `@2.1`) is genuinely live and registered on this GSI right now,
    independent of any GSI/module changes - this is a vendor-partition
    service, unaffected by which system image sits on top.
  - **What's blocking shipment:** two different `audio_effects.xml` files
    exist on this device (`/vendor/etc/audio_effects.xml`, no Dolby, has
    an unrelated `mmieffects` library not accounted for anywhere; and
    `/vendor/etc/audio/sku_parrot/audio_effects.xml`, has Dolby, matches
    the corrected draft). Which one the live audio HAL actually reads at
    boot is unconfirmed - no property exposes this (checked, genuinely
    empty), and guessing which path to place the corrected file at risks
    shipping something that installs cleanly and does nothing, the exact
    failure mode this module has tried to avoid throughout. The corrected
    draft file exists (kept outside this module's tree, not packaged) and
    is ready to install and test the moment there's a way to confirm which
    path is live - e.g. installing it and checking `dumpsys
    media.audio_policy` or logcat during a music stream open for
    `dap`/`dlbvol` effect-creation lines.

- **Device-identity cosmetics** (`system.prop`, module root): sets
  `ro.sf.lcd_density`, `ro.board.platform`, `ro.product.model`,
  `ro.product.manufacturer`, `ro.product.brand` via Magisk's standard
  `system.prop` mechanism (auto-loaded via `resetprop` at boot, confirmed
  against Magisk's official developer guide — no custom script needed).
  Fixes "Unknown" About-phone fields that read from these specific
  properties. **Does NOT and cannot fix the battery capacity (mAh) or
  camera megapixel fields** — those have no standard AOSP build.prop
  equivalent; they're read from live hardware APIs
  (BatteryManager/Camera2 characteristics) that a prop value has no path
  into. If those still show "Unknown" after this update, the cause is
  elsewhere (likely the GSI's battery/camera HAL not reporting properly),
  not something `system.prop` addresses.
  `ro.product.model`/`manufacturer`/`brand` values are user-supplied
  device specs, not independently re-verified against a firmware dump.
  `ro.sf.lcd_density=400` and `ro.board.platform=parrot` ARE independently
  confirmed elsewhere in this investigation. Note: `ro.sf.lcd_density`
  re-asserts the value already active on this device (a no-op in
  practice) — density changes in general can require app icon
  resize/reboot and aren't purely cosmetic if ever changed to a
  *different* value later.
- **UDFPS/HBM: investigated in depth, confirmed not fixable with available
  tooling.** Root cause is a closed-source vendor fingerprint HAL (Anchor)
  failing its own internal handshake with the Android biometric framework —
  not something an RRO, an LSPosed hook, or kernel-level changes can reach.
  Full evidence chain, method notes, and what would be needed to reopen
  this: see `docs/udfps_hbm_investigation.md`.
- `com.motorola.coresettingsext` is confirmed present and active on the
  running GSI (`cmd overlay list` showed both
  `com.motorola.android.coresettingsext.overlay.doubletap` and `.genevn`
  enabled) — `BostonCoreSettingsExtOverlay` is confirmed doing real work,
  not inert.
- Every V1 overlay is confirmed `STATE_ENABLED`/active on-device via direct
  `dumpsys overlay` inspection, including full idmap resolution detail
  (which V1-shipped resource keys actually mapped onto this GSI's compiled
  resources vs. which were silently unresolved — see idmap debug output
  captured during this investigation if that detail is needed again).

- **Awinic speaker calibration (`audio.cal`): root cause identified,
  documented, NOT resolved.** The real factory calibration file was
  recovered from a `persist.img` pull and confirmed genuinely present with
  real factory data (mtime predates any GSI work) — but the running driver
  (v1.13.0.1) cannot parse its 20-byte format, confirmed via live sysfs
  (`dsp_re` reads 0 on both amps, meaning calibration never loads into the
  DSP despite the file existing). No public documentation of this exact
  binary format was found; the parser lives in closed-source vendor code.
  Deliberately NOT hand-fixed — a wrong guess at the file format risks
  feeding false resistance data into a speaker protection circuit, which is
  worse than the current safe fallback behavior. Full evidence chain and
  what would actually resolve it: see
  `docs/awinic_audio_cal_investigation.md`. **Not confirmed to be the cause
  of the originally reported stutter** — see that doc's relationship
  section.

## Known open questions

- Real values for `MotoSettingsFPSDisplayOverlay`'s empty dimen entries
  (`ring_progress_bar_thickness`, `enrolling_animation_margin`,
  `fingerprint_pre_enroll_content_padding_top`) — still unresolved, but
  low priority: this affects enrollment-wizard cosmetics only, not
  hardware function, and is unrelated to the UDFPS root cause above.
- **Bluetooth audio stutter** — `BTAudioHalStream` confirmed entering
  `state=DISABLED` after a stream stop event, then failing every
  `out_write`/`out_resume` call for ~3.2 seconds (137 consecutive failures
  logged) until `AudioFlinger` restarts and routes around the wedge. Cause
  of *why* the stream enters and stays in `DISABLED` is still open — this
  is the strongest-evidenced lead of the three video/audio threads and the
  most promising next target.
- **`com.vivi.vivimusic` playback glitch** — `DefaultAudioSink: Spurious
  audio timestamp (frame position mismatch)` confirmed firing repeatedly
  during local music playback in that one app, in one capture. Not yet
  connected to the Bluetooth or Facebook threads — treated as a separate
  symptom until evidence says otherwise.
- **Facebook video stutter** — zero direct log evidence found connecting
  anything discovered so far (Awinic, Bluetooth, or vivimusic) to this
  specific symptom. Needs its own targeted capture, ideally with a noted
  timestamp of when the stutter is observed.

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
