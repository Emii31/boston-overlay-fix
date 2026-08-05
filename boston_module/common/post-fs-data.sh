#!/system/bin/sh
# post-fs-data.sh
# Runs very early at boot (post-fs-data stage), before most of the Android
# framework has started. $MODPATH is NOT guaranteed available here (confirmed
# against a real Magisk GitHub issue discussion - MODPATH is a
# customize.sh-time-only variable), so this script does not attempt to
# reference it.
#
# This module's actual fix mechanism is static RRO placement: every overlay
# APK shipped here is android:isStatic="true" (matching the stock Motorola
# RROs they were sourced from) and was copied into /product/overlay/ by
# customize.sh at install time via Magisk's normal magic-mount mechanism.
# OverlayManagerService scans that partition path and picks up static
# overlays automatically during boot - no action is required from this
# script for the overlays themselves to take effect.
#
# This script exists to write a boot-time log line only, so that if a user
# reports the overlays aren't applying, there's a timestamped confirmation
# that Magisk did run this module's boot scripts at all (ruling out a
# module-not-loading problem vs an overlay-not-picked-up problem).

MODDIR="/data/adb/modules/boston_gsi_overlay_fix"
LOGFILE="/data/local/tmp/boston_overlay_fix_boot.log"

{
  echo "===================================================="
  echo "Boston GSI Overlay Fix - post-fs-data.sh executed"
  echo "Timestamp: $(date 2>/dev/null || echo 'date command unavailable')"
  echo "Expected overlay location: /product/overlay/"
  if [ -d "$MODDIR/product/overlay" ]; then
    echo "Module directory found at: $MODDIR"
    echo "APKs present in module:"
    ls -la "$MODDIR/product/overlay/" 2>/dev/null
  else
    echo "WARNING: module directory not found at expected path $MODDIR"
    echo "This may indicate the module did not install correctly."
  fi
  echo "===================================================="
} >> "$LOGFILE" 2>&1
