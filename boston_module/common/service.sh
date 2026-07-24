#!/system/bin/sh
# service.sh
# Runs in the late_start service boot stage, once the system and its
# services (including OverlayManagerService) are up. As with
# post-fs-data.sh, $MODPATH is not guaranteed available here.
#
# This script does NOT call `cmd overlay enable` on anything. Every overlay
# in this module is android:isStatic="true", and static overlays with a
# priority value are enabled automatically by OverlayManagerService based
# on partition scan + manifest declaration - explicit enable calls are for
# non-static (mutable, runtime-toggleable) overlays, which none of these
# are. Calling `cmd overlay enable` on a static overlay is a no-op at best
# and is not needed here.
#
# What this script DOES do: wait for OMS to be queryable, then log the
# actual overlay state for each package this module ships, so that if
# something isn't applying correctly, the boot log shows definitively
# whether OMS sees the overlay as [x] enabled or not - rather than the user
# having to guess blind.

LOGFILE="/data/local/tmp/boston_overlay_fix_service.log"

# Wait briefly for the overlay service to be queryable. `cmd overlay list`
# will fail with a non-zero exit and empty/error output if OMS isn't up yet;
# this is a bounded wait (max ~30s), not an infinite loop, so a genuinely
# broken OMS doesn't hang this script forever and delay boot.
i=0
while [ "$i" -lt 30 ]; do
  if cmd overlay list >/dev/null 2>&1; then
    break
  fi
  sleep 1
  i=$((i + 1))
done

{
  echo "===================================================="
  echo "Boston GSI Overlay Fix - service.sh executed"
  echo "Timestamp: $(date 2>/dev/null || echo 'date command unavailable')"
  echo "Waited ${i}s for OverlayManagerService to become queryable."
  echo ""
  echo "Overlay state as reported by 'cmd overlay list':"
  echo "(a leading [x] means enabled, [ ] means present but not enabled -"
  echo "the latter would indicate a problem worth investigating, since"
  echo "these overlays are static and should self-enable)"
  echo ""
  cmd overlay list 2>&1 | grep -iE "boston|com\.boston\.overlay" || \
    echo "No entries matching 'com.boston.overlay.*' found in overlay list."
  echo "===================================================="
} >> "$LOGFILE" 2>&1

# ====================================================================
# Boston Telephony Auto-Recovery (merged in from a standalone module)
#
# WHAT THIS DOES: automates the airplane-mode-toggle workaround for
# SMS/USSD failing after a cold boot on this GSI (confirmed real,
# repeating IMS registration failure: CODE_REGISTRATION_ERROR wrapper
# 1000, sub-code 4002, on both SIM slots, across multiple independent
# logcat captures). Toggling airplane mode forces the modem/RIL to
# fully re-register, which resolves it.
#
# WHAT THIS DOES NOT DO: does not fix VoLTE registration itself (the
# CarrierSettings config entries placed by this module at
# product/etc/CarrierSettings/s47001.pb address that, for Grameenphone
# specifically - see that file's own documentation for what's verified
# vs. still open). This script is purely the SMS/USSD workaround
# automation.
#
# CORRECTION TO AN EARLIER NOTE IN THIS SCRIPT'S HISTORY: an earlier
# version of these comments stated the telephony_fix module's ~16
# system.prop properties "don't hold up under review" and implied they
# were inert. That was wrong, and was corrected after the module's
# actual effect was tested directly on-device: with those properties
# active, LTE/5G data registration is confirmed to come up reliably,
# which does not happen without them. Several of the properties remain
# individually unverified as to WHICH one is responsible (isolation
# testing was deferred pending a clean GSI flash), and two lines from
# the original set are excluded here on structural grounds regardless
# of outcome (ro.boot.hardware.sku - a resetprop write cannot override
# a bootloader-set ro.boot.* property; telephony.lteOnCdmaDevice - not
# applicable to this GSM/LTE radio). The rest of the confirmed-working
# bundle is preserved in this module's system.prop file.
#
# METHOD: settings put global airplane_mode_on + an explicit broadcast
# of android.intent.action.AIRPLANE_MODE (both needed - the setting
# write alone is not reliably sufficient to force the radio to react).
#
# TIMING: polls gsm.network.type every 5s for up to 60s rather than a
# blind fixed sleep. Only toggles if still not on an LTE/NR-class type
# after the full window - if registration comes up fine on its own,
# nothing is touched.

TELEPHONY_LOGFILE="/data/local/tmp/boston_telephony_autorecovery.log"

telephony_log() {
  echo "$(date 2>/dev/null || echo '?') $1" >> "$TELEPHONY_LOGFILE"
}

telephony_log "=== telephony auto-recovery started ==="

TEL_REGISTERED=0
ti=0
while [ "$ti" -lt 12 ]; do
  NET_TYPE=$(getprop gsm.network.type)
  telephony_log "poll $ti: gsm.network.type=$NET_TYPE"
  # NOTE: gsm.network.type reports one comma-joined value per SIM slot
  # (e.g. "LTE,IWLAN" for a dual-SIM device), not a single exact string -
  # confirmed via a real device log where this exact value caused the
  # original exact-match pattern to miss an already-registered state and
  # trigger an unneeded toggle. Wildcards match substring presence
  # anywhere in the joined value, correctly handling any slot combination.
  # IWLAN is included as a valid registered state - VoWiFi/data-over-WiFi
  # is a legitimate working connection, not something to toggle away from.
  case "$NET_TYPE" in
    *LTE*|*NR*|*5G*|*IWLAN*)
      TEL_REGISTERED=1
      telephony_log "Registered on LTE/NR-class network - no action needed."
      break
      ;;
  esac
  sleep 5
  ti=$((ti + 1))
done

if [ "$TEL_REGISTERED" -eq 1 ]; then
  telephony_log "=== telephony auto-recovery finished: no toggle performed ==="
else
  telephony_log "Still not on LTE/NR after ${ti}x5s poll (last seen: $NET_TYPE) - performing airplane mode toggle."

  settings put global airplane_mode_on 1
  am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true
  telephony_log "Airplane mode ON issued."

  sleep 3

  settings put global airplane_mode_on 0
  am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false
  telephony_log "Airplane mode OFF issued."

  telephony_log "=== telephony auto-recovery finished: toggle performed ==="
fi
