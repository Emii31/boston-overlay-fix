# Awinic Speaker Calibration (audio.cal) — Documented, Not Resolved

## Status: Root cause fully identified. NOT fixable without proprietary vendor
## tooling this investigation does not have access to. Do not attempt to
## hand-write or reformat audio.cal without that tooling — see risk section.

## Symptom (original report)

Video stutter and BT earbud audio "getting stuck" during playback (Facebook
and other apps). This investigation covers ONE of several threads opened to
explain that report — see "Relationship to other findings" at the bottom for
why this is not confirmed to be the actual cause of the reported symptom.

## Root cause (confirmed)

**The device's factory-provisioned speaker calibration file exists, at the
correct path, with real factory data — but the currently-running Awinic
`aw882xx` driver (v1.13.0.1) cannot parse its format, so calibration is
never loaded into either speaker amplifier's DSP.**

Evidence, in the order gathered:

1. **Recurring driver error, every ~7-9 seconds, for the full duration of
   every log capture taken:**
   ```
   android.hardware.audio.service_64: [Awinic] [ERR] aw_ar_cali_dev_get_re_from_file:
     can not open: /mnt/vendor/persist/factory/audio/audio.cal
   android.hardware.audio.service_64: [Awinic] [ERR] aw_ar_cali_devs_get_re_from_file:
     dev[0]get re failed
   ACDB: AcdbCmdGetProcSubgraphCalDataPersist:8416 Error[19]: No calibration found
   ```
   Error 19 (ENODEV) is consistent with "no calibration data available for
   this device configuration" at the ACDB layer — not a corrupted-read error.

2. **Live sysfs query on-device confirms the calibration was never loaded
   into either amplifier's DSP:**
   ```
   $ cat /sys/bus/i2c/devices/0-0034/dsp_re /sys/bus/i2c/devices/0-0035/dsp_re
   0
   0
   ```
   `dsp_re` is this driver's own live readback of the DC resistance value
   currently loaded into each amp's DSP. Zero on both channels means no
   valid Re (resistance) value has been programmed into the DSP — the
   protection algorithm is running without per-unit calibration data,
   falling back to whatever generic/default behavior the driver uses in
   this case (kernel log confirms this is a handled, non-fatal fallback:
   `aw882xx_dev_init_cali_re: no cali, needn't init cali re`, printed on
   every stream start).

3. **The file itself was recovered directly from a `persist.img` pulled off
   the device (via `dd` from `/dev/block/by-name/persist`) and mounted
   read-only (`mount -o loop,ro,noload` — `noload` needed because the image
   had unreplayed journal entries from being dd'd live; read-only mount
   with journal replay skipped, image never modified). Confirmed present at
   the exact expected path:**
   ```
   factory/audio/audio.cal
   Size: 20 bytes, mode 0600, uid/gid 5104, mtime 2025-02-11
   Content: "      6337      6769" (two whitespace-padded ASCII integers,
            no other structure, no header, no delimiter beyond whitespace)
   ```
   The mtime (Feb 2025) predates any GSI installation on this device,
   confirming this is the genuine factory-written file, not something
   corrupted or overwritten during later GSI work. The `persist` partition
   is untouched by GSI system-partition flashing by design (this is why
   pulling it was worthwhile at all — Motorola's original factory
   calibration should still be intact underneath any GSI, and it is).

4. **This 20-byte content does not resemble any documented Awinic/AudioReach
   `audio.cal` binary format found via public search.** The two numbers
   (6337, 6769) are plausible as milliohm-scale impedance values for two
   speaker channels (6.337Ω / 6.769Ω would be unremarkable for phone
   speakers) — but this is informed speculation about *meaning*, not a
   confirmed parser spec. No public source (searched: general "audio.cal
   format", the specific failing function name
   `aw_ar_cali_dev_get_re_from_file`, the AudioReach/Linaro open-source
   audio topology projects) documents this exact file's expected binary/text
   layout. This is almost certainly because the real parser lives inside
   Awinic's proprietary code compiled into the closed-source
   `android.hardware.audio.service_64` PAL/AGM binary — not published
   anywhere, consistent with the pattern already seen elsewhere in this
   device's stack (Anchor's fingerprint HAL, the empty `techpack/` kernel
   stub) of vendor-proprietary components with zero public source access.

## Why this was NOT hand-fixed, and should not be attempted casually

This file's content directly feeds a smart-PA (speaker protection)
algorithm's excursion/thermal limiting calculations. Writing a
reformatted or guessed-at replacement carries real risk:
- If the guessed format still fails to parse: no change, safe, but
  pointless.
- If the guessed format parses "successfully" but the values are wrong
  (wrong byte order, wrong scale, wrong number of channels, wrong
  structure entirely): the protection algorithm operates on false
  resistance data, which could mean under-protection (real risk of
  driving the speaker coil harder than its actual electrical
  characteristics safely allow) — worse than the current state, where the
  amp runs on a conservative fallback rather than false calibration.

This is a case where "I don't know the format" is a stopping condition,
not a puzzle to guess through, given what's on the other end of a wrong
guess.

## What would actually resolve this

- **Qualcomm's Audio Calibration Tool** (referenced in AudioReach's own
  public documentation as the standard tool for this class of calibration
  data) or Motorola's own factory service/repair software — both would
  know this format because they define it. Neither is available to this
  investigation.
- **A working (non-GSI, or GSI-with-correctly-matched-driver) reference
  device of the same model**, where `dsp_re` reads a real non-zero value
  and the corresponding live driver's expected file format could be
  observed/compared against this device's stored bytes.
- **Contacting Awinic or Motorola directly** with the exact failing
  function name and file path — this is a precise, recognizable signature
  for anyone with real access to this driver's source.

## Relationship to other findings — what this does and does NOT explain

This recurring error is confirmed real and confirmed uncorrected, but is
**not confirmed to be the cause of the originally reported video/BT audio
stutter.** Three other threads were opened investigating that same report:

- `BTAudioHalStream` stuck in `DISABLED` state after a stop event (Bluetooth
  output specifically) — confirmed real, separate mechanism, cause of the
  DISABLED-state entry still unresolved as of this writing.
- `DefaultAudioSink: Spurious audio timestamp` in `com.vivi.vivimusic` — a
  local music player, confirmed isolated to that app in the one capture it
  appeared in, not yet connected to any other symptom.
- Facebook video stutter specifically — zero direct log evidence connecting
  anything found (in this doc or the two above) to that specific symptom,
  as of this writing.

The recurring "no cali" cycle logs loudly every ~7-9 seconds throughout
normal use (correlating with ordinary stream open/close activity, not
specifically with reported glitch moments), but no capture taken so far
has timestamp-correlated this cycle with a user-confirmed moment of
audible stutter. It may be contributing background noise, a red herring
that happens to be noisy, or a real factor — undetermined.
