# Telephony V3 Merge — SMS/USSD-over-IMS Bypass

## Status: Built correctly, real bug found and fixed along the way,
## NOT YET CONFIRMED WORKING on-device. Read this before assuming
## SMS/USSD no longer needs the airplane-mode trick.

## The wrong-module mixup

Earlier in this investigation, a module named `boston_telephony_fix.zip`
was supplied and merged as "the" telephony fix. On review, that module's
approach was a blunt `ro.telephony.ims.disabled=1`-style attempt to kill
the entire AOSP IMS framework, plus several properties that don't hold up
individually (`ro.boot.hardware.sku` can't be overridden by a
`system.prop` entry applied late in boot; several `persist.dbg.*` IMS
override flags with no confirmed effect on this device's actual RIL).
That module was merged, documented, and tested — the merge was later
found to be against the wrong reference module entirely. The correct one
is `moto-parrot-telephony-fix` (internally versioned "V3.0-BruteForce"),
which takes a materially different and better-targeted approach.

## What the real module actually does

Rather than trying to force IMS registration to succeed (which several
turns of this investigation spent real effort on via a CarrierSettings
`.pb` edit — see `docs/telephony_investigation.md` — targeting
`carrier_volte_available_bool` and `iwlan.epdg_static_address_string`),
this module sidesteps the problem for SMS/USSD specifically:

- `carrier_config_fix.xml` sets the real, standard AOSP CarrierConfig
  keys `support_sms_over_ims_bool` and `support_ussd_over_ims_bool` to
  `false`, correctly scoped to MCC 470 / MNC 01 (Grameenphone) and MNC 02
  (Airtel/Robi — the MNC confirmed correct after resolving three
  conflicting candidate values earlier in this investigation). This
  tells the framework to route SMS and USSD over the legacy
  circuit-switched (CS/GSM) domain instead of depending on IMS
  registration succeeding at all.
- `apns-conf.xml` ships real APN definitions for both carriers
  (`gpinternet` / `internet`), matching what was independently confirmed
  from this device's own live APN content-provider database earlier in
  this investigation.
- `post-fs-data.sh` wipes the telephony provider's database
  (`/data/user_de/0/com.android.providers.telephony/databases/telephony.db*`)
  on every boot, forcing these files to be freshly re-read rather than
  possibly conflicting with stale cached provisioning data.
- `service.sh` waits for boot completion, then a further 15 seconds,
  then issues `cmd phone restart-radio` — Android's own documented radio
  restart command, functionally similar in goal to the airplane-mode
  toggle this project had already automated, but via a cleaner,
  purpose-built mechanism.

## Real evidence this approach is architecturally sound

A logcat capture taken during this investigation (before the CRLF bug
below was found, so before the restart could have fired) showed, real
and unprompted, an IMS registration failure immediately followed by:
```
domain=CS transportType=WWAN registrationState=HOME
availableServices=[VOICE,SMS,VIDEO]
```
This confirms the CS/GSM fallback path this module relies on genuinely
exists and is available on this device — SMS being available over CS,
`registrationState=HOME`, at the same moment IMS reports
`CODE_REGISTRATION_ERROR` (the same wrapper 1000 / sub-code 4002 seen
consistently throughout this whole investigation). This is not a
theoretical fallback; it was observed actually working, just not yet
being used by default before this module set the CarrierConfig keys.

## The CRLF bug — a real, found-and-fixed problem, not speculation

The module as originally supplied had **CRLF (Windows) line endings on
all three shell scripts**. On `customize.sh` and `post-fs-data.sh`
(flat sequences of single-line commands) this happened to be tolerated.
On `service.sh`, which contains a multi-line `until...do...done` loop,
it was not: `sh -n` on the original file returned a real syntax error
(`Syntax error: end of file unexpected (expecting "do")`, exit code 2).

**This means the radio restart never actually executed in any test run
against the originally-supplied module.** Two separate test attempts
earlier in this investigation, both showing continued `MODEM_ERR`
(RIL error 40 — confirmed via AOSP's real `ril.h` definition:
"vendor RIL got unexpected/incorrect response from vendor RIL") on a USSD
attempt, were later found to not have been testing this module at all —
it had never been flashed standalone. Whether the radio restart itself
resolves `MODEM_ERR` remains genuinely untested; the two prior negative
results do not count as evidence against it, because the mechanism being
tested was never running.

Fixed via `sed -i 's/\r$//'` on all three scripts, re-verified with `sh -n`
after the fix (all three now parse correctly). This fix is what's shipped
in this module — not the original, silently-broken scripts.

## What is NOT yet confirmed

**Nothing about this module's actual real-world effectiveness has been
verified after the CRLF fix.** The only on-device evidence gathered so
far in this whole investigation was either (a) against the wrong module,
or (b) against this module before the CRLF bug was found, meaning the
restart script never ran. After flashing this merged version:

1. Confirm the restart actually fires:
   ```
   su -c "logcat -d | grep -iE 'restart-radio|RADIO_POWER'"
   ```
   Should show real output ~15+ seconds after boot completes. If this is
   empty, something beyond the CRLF issue is also blocking it and needs
   investigation before anything else here can be trusted.
2. Confirm the CarrierConfig keys took effect:
   ```
   su -c "dumpsys carrier_config | grep -iE 'support_sms_over_ims_bool|support_ussd_over_ims_bool'"
   ```
3. Attempt SMS and USSD on a fresh boot, without any manual airplane-mode
   toggle, and see if they succeed. This is the actual test that matters
   — everything above is necessary-but-not-sufficient supporting
   evidence, not proof of the end result.

If SMS/USSD still require the airplane-mode toggle after all of the
above checks out, the airplane-mode automation already in this module
(see the main `service.sh` telephony section) remains active as a
fallback — it only fires if `gsm.network.type` genuinely isn't
registered after a 60-second poll, so it won't conflict with or mask a
working fix from this module; it will simply do nothing if this module
alone is sufficient.
