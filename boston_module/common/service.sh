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
