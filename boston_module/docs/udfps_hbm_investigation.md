# UDFPS / HBM Investigation — Closed Finding (V2)

## Status: NOT FIXABLE with available tooling. Root cause identified and confirmed.

Do not re-attempt an RRO overlay or LSPosed hook for this without new evidence
(see "What would reopen this" at the bottom). Every avenue below was checked
against real evidence pulled from the device, not assumed.

## Symptom

UDFPS sensor detects touch (physical hardware works) but never illuminates /
never completes an enrollment or authentication scan. No HBM (High Brightness
Mode) flash occurs during a scan attempt.

## Root cause (confirmed)

**Anchor's proprietary userspace fingerprint HAL (`ANC_HAL`/`ANC_HIDL`,
process `android.hardware.biometrics.fingerprint@2.1-service-jv`) fails to
complete its extension-callback registration with the Android biometric
framework, on every GSI available for this device.**

Direct evidence, in the order it was gathered:

1. **Touch capture works.** `goodix_ts_report_finger` events fire correctly
   on every touch (confirmed in the first logcat pulled for this
   investigation). The Goodix touchscreen digitizer and its kernel driver
   (`drivers/input/touchscreen/goodix.c`, `goodix_berlin_driver/`) are not
   the problem.

2. **The illumination surface never initializes.** Every touch produces a
   `sendUdfpsPointerDown`/`Up` pair with `callback null`, and the
   `SurfaceView[UdfpsControllerOverlay]` BufferQueueProducer reports
   `disconnect: not connected` / `Surface failed to disconnect... Error -19
   (NO_INIT)` on every single attempt — meaning the surface connection was
   never successfully established in the first place, not that it failed
   after working.

3. **The vendor HAL fails enrollment internally with what is very likely
   `EINVAL`:**
   ```
   JV_FP   : [ANC_HAL][CustomManager][E]: fail to enroll, ret value:22
   ANC_HIDL: fingerprint extension callback is nullptr
   BiometricScheduler: [Finishing] ... FingerprintEnrollClient ... but
     current operation is null, success: false, possible lifecycle bug
     in clientMonitor implementation?
   ```
   Return value 22 matches POSIX `EINVAL` (invalid argument) on Linux/Android.
   The framework's own scheduler independently flags this as a lifecycle bug
   on its side, consistent with a HAL that never completes its handshake.

4. **Sensor geometry is read from the HAL at runtime, not from any RRO
   resource.** Decompiling `SystemUI.apk`'s `AuthController.updateUdfpsLocation()`
   confirmed the sensor `Rect` comes from
   `FingerprintSensorPropertiesInternal.getLocation().getRect()` — data the
   vendor HAL itself reports during registration — not from
   `config_udfps_sensor_props` or any other static overlay resource. This
   means no RRO coordinate value (V1's `540,2154,91`, or any alternative)
   is actually consulted by this code path. Realigning overlay coordinates
   was never going to fix scan failure, only (at most) cosmetic circle
   position if the HAL path were otherwise working.

5. **This GSI's SystemUI does not self-handle dimming.**
   `config_udfpsFrameworkDimming = false` (confirmed via direct binary
   resource decode of the GSI's own compiled `SystemUI.apk`, see Method
   below). SystemUI defers illumination entirely to the vendor HAL — which
   is the layer confirmed broken in points 3–4.

6. **No kernel-level Anchor code exists anywhere in Motorola's published
   kernel source for this device.** Checked two ways: (a) the scoped
   `drivers/input/` tree contains only Goodix touchscreen drivers, no
   fingerprint-specific code; (b) a full-tree case-insensitive recursive
   grep across all 73,187 files of the complete
   `kernel-msm-MMI-V1UBS35H.97-24-16` release for "anc_hal" / "anchor" /
   "anc_hidl" returned zero hits. The `techpack/` directory (where
   Qualcomm vendor modules sometimes live) is a deliberately empty stub in
   this public release — confirmed via its `.gitignore` and trivial
   `stub.c`, not just absence of a match. **This is expected, not a dead
   end**: Anchor's HAL is a userspace HIDL service
   (`@2.1-service-jv`, confirmed via `ps -A` on the live device), and
   userspace HAL binaries are architecturally never part of kernel source.

## Avenues ruled out, and why each is actually closed (not just untried)

- **RRO overlay (V1's original approach):** Cannot work — confirmed the
  live code path doesn't read the resource V1 sets (point 4 above), and
  even the resources that ARE read (`config_udfpsFrameworkDimming` etc.)
  are compiled into SystemUI.apk, not overridable in a way that changes
  which subsystem handles the failing handshake.
- **LSPosed hook on SystemUI:** Would only touch the Java/Kotlin layer.
  The actual failure (`ret value:22`, null extension callback) originates
  inside Anchor's closed-source vendor binary. A hook could suppress the
  visible Java-side error but cannot make the vendor HAL's internal state
  machine complete correctly — this would hide the symptom while leaving
  enrollment/auth genuinely broken underneath, which is worse than the
  current honest failure.
- **Base ROM Trick (borrow vendor partition from a working custom ROM):**
  No custom ROM exists for Boston (`parrot`) — Motorola never published a
  device tree, confirmed by the user. The `twrpdtgen/android_device_motorola_boston`
  repo is a recovery-only tree auto-generated from a boot image (confirmed
  via its own tool description) — it contains no vendor/HAL integration and
  does not enable this approach.
- **Different GSI build:** Every GSI available for this device is
  maintained by a single developer (Doze-off); the user has tried all of
  them and all exhibit the identical failure. Uniform failure across every
  available build, from every maintainer, is strong evidence the problem
  is in the shared stock vendor partition (Anchor's HAL) underneath all of
  them, not in any specific GSI's SystemUI build.
- **Kernel source fix:** See point 6. No Anchor code exists in the
  published kernel tree to fix.

## Method note: binary resource decoding

Standard tooling (androguard 4.1.4's `get_resolved_res_configs()` /
`get_value()`) was found to silently return incorrect values (unrelated
strings) when reading resources compiled with AAPT2's newer "compact entry"
format (`FLAG_COMPACT`, `0x0008` bit in `ARSCResTableEntry.flags`) — which
this GSI's APKs use throughout. This was caught by cross-checking decoded
brightness values against known AOSP upstream defaults
(`config_screenBrightnessSettingMaximum` decoded to exactly `255`, matching
AOSP source) before trusting the method, and separately catching a `-2.0`
sentinel value that turned out to be correct, documented AOSP behavior
("invalid, fall back to int value") rather than a decode bug, again verified
against source before accepting it.

The working method used throughout this investigation reads
`ARSCResTableEntry.datatype` / `.data` directly (bypassing the broken
resolver), with type-specific decoding: `TYPE_INT_BOOLEAN`/`TYPE_INT_DEC`
read directly, `TYPE_FLOAT` via IEEE 754 unpacking, `TYPE_STRING` via
`stringpool_main.getString(index)` (not `get_string()`, which expects a name
string, not an index — an earlier mismatch caught by testing method
signatures rather than assuming), and `TYPE_DIMENSION` via AOSP's actual
documented `COMPLEX_MANTISSA_SHIFT=8` / radix-shift table (verified against
AOSP source after an initial radix-shift error produced an impossible
negative-exponent result).

If this decode method is needed again for future work on this device's GSI
resources, the corrected reference implementation is preserved in this
conversation's tool-call history; ask for it to be re-extracted into a
standalone script rather than re-deriving it from scratch.

## What would reopen this

- A firmware update from Motorola that changes the Anchor HAL binary itself
- A newer or differently-sourced GSI build whose maintainer has specifically
  solved Anchor HAL registration (worth asking in GSI support channels with
  the exact evidence above — `ret value:22`, `ANC_HIDL` nullptr callback,
  `@2.1-service-jv` — since that's a precise, recognizable signature someone
  familiar with Anchor sensors elsewhere might identify immediately)
- Discovery of a working custom ROM or vendor dump for Boston or a
  closely-related device sharing the same Anchor HAL version
