# Telephony (LTE/5G data, SMS/USSD, VoLTE) — V4

## Status: Mixed. Two pieces confirmed working, one piece real-but-unverified,
## one piece (Airtel/Robi VoLTE) still genuinely open. Read carefully before
## assuming "telephony is fixed" - it's fixed in parts, not as a whole.

## Piece 1: LTE/5G data stuck on EDGE — FIXED, confirmed by direct
## on-device testing

`system.prop` carries a set of properties (originally assembled by the
user as a standalone module, tested extensively over real-world use)
that reliably bring LTE/5G data up on both Grameenphone and Airtel/Robi
after a GSI flash. Confirmed directly: same GSI flash, same device,
data stuck on EDGE without these properties active, LTE/5G working
with them active.

**What's NOT yet known:** which individual propert(ies) in the set are
actually responsible. Isolation testing (four candidate groups,
documented in this module's git history / prior investigation) was
designed but not run, because it requires a clean GSI flash the user
didn't have available at the time. The full set is shipped together as
the verified-working unit. Two lines from the original set were
excluded on structural grounds regardless of any test outcome:
- `ro.boot.hardware.sku=xt2419` — a `system.prop` entry (applied via
  `resetprop`, late in boot) cannot override a `ro.boot.*` property,
  which is set by the bootloader before `init` runs at all.
- `telephony.lteOnCdmaDevice=1` — legacy CDMA-era property, not
  applicable to this device's GSM/LTE/5G-NR radio technology.

If a clean flash becomes available, isolation testing should still
happen — narrowing this to the actual load-bearing propert(ies) would
let this module drop whatever's inert, and would settle open questions
about *why* it works, which remain unanswered.

## Piece 2: SMS/USSD failing after boot — WORKED AROUND, not root-caused

Confirmed, repeatedly, across multiple independent logcat captures:
IMS registration fails with `CODE_REGISTRATION_ERROR` (wrapper code
`1000`, sub-code `4002`, undocumented anywhere publicly searchable) on
both SIM slots, every cold boot. Toggling airplane mode on then off
forces the modem/RIL to fully re-register, which resolves it — this is
a real, repeatable, user-confirmed workaround, not a guess.

`common/service.sh` automates this: polls `gsm.network.type` for up to
60s after boot, and only performs the airplane-mode toggle if the
device is still not on an LTE/NR-class network by then. If registration
comes up fine on its own, nothing is touched.

**This does not fix why registration fails in the first place.** That
remains unknown. See Piece 3 for the one specific, verified contributing
factor that was found and addressed (for Grameenphone only).

## Piece 3: VoLTE / IMS registration — PARTIALLY ADDRESSED (Grameenphone
## only), built on verified evidence, but not yet confirmed to resolve
## the actual registration failure

### What was found, and how it was verified

- Live `dumpsys carrier_config` on the GSI showed
  `carrier_volte_available_bool = false` and empty
  `iwlan.epdg_static_address_string` for both SIMs — matching AOSP's
  hardcoded platform fallback defaults exactly (confirmed against
  AOSP's real `CarrierConfigManager.java` source), meaning no
  carrier-specific config was loading for either carrier on the GSI.
- A separate `dumpsys carrier_config` capture, later confirmed to be
  from **stock**, showed `carrier_volte_available_bool = true` on both
  phone slots. Stock has `com.motorola.carrierconfig` installed (a
  Motorola-proprietary carrier-config package, confirmed present via a
  real file-path listing from a stock dump); the GSI does not have
  this package at all (confirmed via `pm path`, empty result). This is
  believed to be why VoLTE is offered on stock and not on the GSI —
  Motorola's own carrier-config layer sets the flag; AOSP's generic
  default does not.
- A genuine, AOSP-standard-format ePDG server hostname
  (`epdg.epc.mnc001.mcc470.pub.3gppnetwork.org`, per 3GPP FQDN
  convention using Grameenphone's confirmed MCC/MNC 470-01) resolves to
  two real, non-loopback IPs: `123.108.240.250` and `123.108.240.251`.
  The owning ASN (AS24389) was independently confirmed via a real
  APNIC WHOIS record to be genuinely registered to Grameenphone Ltd,
  Bangladesh. **This is circumstantial, not airtight** — DNS resolution
  landing in the right ASN is strong evidence, not proof the specific
  IP is the real, currently-operational ePDG endpoint.
- Grameenphone's real `CarrierSettings` protobuf
  (`product/etc/CarrierSettings/s47001.pb`, pulled from a stock dump)
  was decoded using AOSP's actual, real `carrier_settings.proto` /
  `carrier_list.proto` schema (fetched from
  `android.googlesource.com/platform/tools/carrier_settings`, verified
  as genuine AOSP source, not inferred). The real, correct APN data
  (`GP-INTERNET`/`gpinternet`, `GP-MMS`/`gpmms`) was confirmed present;
  the `configs {}` block was confirmed genuinely empty — no
  CarrierConfig overrides shipped in Grameenphone's actual file.

### What was built

`product/etc/CarrierSettings/s47001.pb` — Grameenphone's real file, with
two config entries added:
```
config { key: "carrier_volte_available_bool" bool_value: true }
config { key: "iwlan.epdg_static_address_string" text_value: "123.108.240.250" }
```
Built via a real `protoc --encode` against the actual schema (not a raw
binary edit), then verified via `protoc --decode` round-trip — the
decoded output was diffed against the intended edit and confirmed
byte-for-byte identical before this file was placed in the module.

### What is NOT yet confirmed

**This has not been tested on-device.** The mechanism is real and the
inputs are as well-sourced as this investigation could get them, but
"correctly encoded" and "actually resolves the registration failure"
are different claims. After installing this module, check:
```
su -c "dumpsys carrier_config | grep -iE 'carrier_volte_available_bool|carrier_name_string'"
```
should show `true` and `Grameenphone` respectively for the Grameenphone
SIM slot if the file is being read. Then attempt an SMS/USSD action on
a fresh boot, without the airplane-mode toggle, and check for the same
`CODE_REGISTRATION_ERROR 4002` signature via a fresh logcat capture. If
it's gone or changed, this genuinely helped. If it's identical, the
static ePDG address either isn't correct or isn't the actual blocker,
and this needs to be revisited with real post-install evidence rather
than more inference.

## Airtel/Robi Bangladesh VoLTE — NOT addressed, genuinely still open

- Airtel Bangladesh's real MNC was a genuine point of confusion across
  this investigation (candidate values `02`, `03`, `07` all appeared
  from different sources at different points) before being resolved:
  **`02`** is correct, confirmed independently by (a) this device's own
  live service-state logs showing `mMnc=02` consistently, (b) a BTRC
  reference table assigning MNC 02 to "Robi Axiata Bangladesh Ltd.",
  and (c) Robi's own Wikipedia article confirming Airtel Bangladesh Ltd
  as Robi's direct predecessor/acquisition. (`03` was mistakenly
  supplied at one point — that digit actually belongs to Banglalink, a
  separate, third carrier.)
- With the correct MNC confirmed, the same 3GPP-standard FQDN pattern
  (`epdg.epc.mnc002.mcc470.pub.3gppnetwork.org`) was attempted. It does
  not resolve — genuine `NXDOMAIN`-equivalent failure, not a loopback
  artifact like the wrong-MNC attempts earlier. Robi/Airtel does not
  appear to publish a standard-format 3GPP ePDG FQDN, or uses a
  different naming convention not yet identified.
- No `s47002.pb` (Robi/Airtel's real CarrierSettings file) has been
  pulled and decoded the way Grameenphone's was — this remains a real,
  concrete next step if a stock dump of that specific file becomes
  available, using the exact same verified schema and encode/decode
  process already built and proven for Grameenphone.

## What was deliberately NOT pursued further

- **`com.motorola.carrierconfig` APK repack** — confirmed absent from
  the GSI (`pm path` empty), confirmed present on stock (real file
  listing). A full priv-app repack (add asset, re-sign, magic-mount
  over `system_ext/priv-app/`) was scoped as technically possible using
  the same mechanism already proven for the Dolby settings app
  attempt, but was set aside in favor of the CarrierSettings `.pb`
  approach, which is lower-risk (a single data file vs. a repacked
  priv-app) and became viable once the real schema was obtained. Worth
  revisiting if the `.pb`-only approach proves insufficient.
- **`ims.apk` and its native libraries** — a real path
  (`.../ims/ims.apk`) was described but the actual file was never
  pulled or inspected. Unexplored.
