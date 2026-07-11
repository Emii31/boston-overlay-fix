#!/system/bin/sh
# customize.sh
# Runs ONCE during Magisk module installation (Magisk app / recovery).
# NOT run at every boot - that's post-fs-data.sh / service.sh.
#
# Responsibilities here:
#   1. Abort install on a device that clearly isn't Boston (parrot) - this
#      module writes overlays with hardware-specific pixel values (UDFPS at
#      540,2154 / cutout circle at 540,53 / etc extracted from a Boston-only
#      firmware dump) that would misplace UI elements on any other device.
#   2. Set correct permissions on the files this module ships.
#
# What this script does NOT do: enable overlays via `cmd overlay enable`.
# Every overlay in this module is isStatic="true" (matching the stock
# Motorola RROs they were sourced from), so OverlayManagerService picks
# them up automatically by partition-scan at boot once they are placed
# under /product/overlay - no explicit enable call needed. See service.sh
# for the one thing that IS handled at runtime (a verification/log step,
# not an enable call).

ui_print "-------------------------------------------"
ui_print " Boston GSI Overlay Fix (V1)"
ui_print "-------------------------------------------"

# --- Device identity check ---
# Boston's codename is 'parrot' (ro.product.board / ro.board.platform on
# stock; on a GSI, ro.product.vendor.device or ro.boot.product.hardware are
# the more reliable fields since ro.product.device may report the GSI's own
# generic name instead of the vendor codename). Check every field that
# could plausibly carry 'parrot' rather than trusting just one, since GSI
# + vendor-splits are exactly the situation where a single prop can lie.
DEVICE_MATCH=0
for propname in ro.product.board ro.board.platform ro.product.vendor.device \
                ro.boot.product.hardware ro.product.device ro.product.vendor.board; do
  val=$(getprop "$propname")
  case "$val" in
    *parrot*) DEVICE_MATCH=1 ;;
  esac
done

if [ "$DEVICE_MATCH" -ne 1 ]; then
  ui_print "!!! WARNING: could not confirm this is a Boston (parrot) device."
  ui_print "!!! None of the checked build props contain 'parrot'."
  ui_print "!!! This module contains hardware-specific pixel values (UDFPS"
  ui_print "!!! position, cutout geometry, corner radius) measured from a"
  ui_print "!!! Boston firmware dump. Installing on a different device WILL"
  ui_print "!!! misplace UI elements."
  ui_print "!!! Aborting install. If you are certain this IS a Boston device"
  ui_print "!!! and your GSI reports different build props, install manually"
  ui_print "!!! by extracting this zip and copying overlay/ into"
  ui_print "!!! /data/adb/modules/boston_gsi_overlay_fix/ yourself."
  abort "Device check failed - see log above."
fi

ui_print "- Device check passed (parrot detected in build props)"

# --- Copy overlay APKs into the module's mount tree ---
# $MODPATH is the Magisk-provided staging directory; anything placed here
# under system/... gets magic-mounted over the corresponding real partition
# path at boot, which is how Magisk delivers files without touching the
# actual partition. The overlay/ directory in this zip already mirrors
# that structure (overlay/product/overlay/*.apk -> mounted at
# /product/overlay/*.apk).
#
# $ZIPFILE is the path to this module's own zip archive (confirmed against
# Magisk's official developer guide - it is a zip PATH, not a pre-extracted
# staging directory, so it must be unzipped here, not cp'd from directly).
mkdir -p "$MODPATH/product/overlay"

unzip -o "$ZIPFILE" 'overlay/product/overlay/*.apk' -d "$TMPDIR/extracted" >&2

if [ -d "$TMPDIR/extracted/overlay/product/overlay" ]; then
  cp -af "$TMPDIR"/extracted/overlay/product/overlay/*.apk "$MODPATH/product/overlay/" 2>/dev/null
fi

APK_COUNT=$(ls -1 "$MODPATH/product/overlay/"*.apk 2>/dev/null | wc -l)
ui_print "- Copied $APK_COUNT overlay APK(s) into place"

if [ "$APK_COUNT" -eq 0 ]; then
  abort "No overlay APKs were found to install. The zip may be malformed - reinstall from a fresh download."
fi

set_perm_recursive "$MODPATH/product/overlay" 0 0 0755 0644

ui_print "- Permissions set"
ui_print "-------------------------------------------"
ui_print " Install complete. Reboot required."
ui_print " V1 scope: display/cutout/UDFPS/brightness/"
ui_print " refresh-rate/night-light/doze/WiFi-Display."
ui_print " NOT included: telephony (separate module),"
ui_print " vendor audio-HAL routing (see module README)."
ui_print "-------------------------------------------"
