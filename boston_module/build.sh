#!/bin/bash
# build.sh - runs on YOUR machine, not in the sandbox that produced this kit.
#
# WHY THIS SCRIPT EXISTS / WHAT IT DOES NOT DO:
# Every file in overlays/*/AndroidManifest.xml and overlays/*/res/values/config.xml
# is verified: sourced from your uploaded firmware dump, cross-checked against
# each APK's own resource ID table, and successfully compiled with `aapt2 compile`
# (the .zip files in compiled_resources/ are that real, verified output).
#
# What could NOT be done in the sandbox that built this: the final `aapt2 link`
# step, which turns compiled resources into an actual installable overlay APK.
# That step requires a `-I <framework>` base to resolve android: references
# against. The sandbox's only copy of framework-res.apk (from your own dump)
# has a non-standard resource table - its ARSC header declares 6 separate
# package chunks all claiming package id=1 name='android' (one ~4.2MB, five
# 4-12KB), which is not valid per the standard AOSP resource table layout and
# both aapt2 builds tested in the sandbox rejected it with a hard parse error
# ("RES_TABLE_TYPE_TYPE entry offsets overlap actual entry data"). This is
# almost certainly a device-build-tooling artifact from how Motorola merges
# base + OEM resource patches - the Android runtime on your actual phone
# tolerates it, but a standalone aapt2 does not.
#
# CONSEQUENCE FOR THIS SCRIPT: it links against the framework-res.apk found
# on YOUR machine (from an installed Android SDK platform), NOT the one from
# the firmware dump. This should be a clean, standard single-package file and
# should not hit the same parser error. If it does, that would be new
# information (meaning the problem isn't specific to the sandbox's copy).
#
# REQUIREMENTS on your machine:
#   - Android SDK with build-tools installed (you're doing device-tree /
#     aospdtgen work already, so this is likely already present)
#   - $ANDROID_HOME (or $ANDROID_SDK_ROOT) set, OR pass build-tools path directly
#   - A debug or release keystore for apksigner. If you don't have one, this
#     script generates a throwaway debug keystore via keytool - fine for
#     personal use on your own device, NOT something to redistribute.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build_output"
OUT_DIR="$SCRIPT_DIR/dist"

# --- Locate build-tools ---
if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
  echo "ERROR: Neither \$ANDROID_HOME nor \$ANDROID_SDK_ROOT is set."
  echo "Set one to your Android SDK path, e.g.:"
  echo "  export ANDROID_HOME=\$HOME/Android/Sdk"
  exit 1
fi

SDK_ROOT="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
BUILD_TOOLS_DIR=$(find "$SDK_ROOT/build-tools" -maxdepth 1 -mindepth 1 -type d | sort -V | tail -1)

if [ -z "$BUILD_TOOLS_DIR" ]; then
  echo "ERROR: No build-tools found under $SDK_ROOT/build-tools"
  echo "Install one via: sdkmanager \"build-tools;35.0.0\" (or any recent version)"
  exit 1
fi

AAPT2="$BUILD_TOOLS_DIR/aapt2"
APKSIGNER="$BUILD_TOOLS_DIR/apksigner"
ZIPALIGN="$BUILD_TOOLS_DIR/zipalign"

for tool in "$AAPT2" "$APKSIGNER" "$ZIPALIGN"; do
  if [ ! -x "$tool" ]; then
    echo "ERROR: required tool not found or not executable: $tool"
    exit 1
  fi
done
echo "Using build-tools: $BUILD_TOOLS_DIR"

# --- Locate a framework base to link against ---
# Prefer an installed SDK platform's android.jar. Fall back to letting the
# user point at a device framework-res.apk explicitly via $FRAMEWORK_APK,
# but WARN clearly that using the device's own dump reproduces the exact
# parse failure this script exists to avoid.
if [ -n "$FRAMEWORK_APK" ]; then
  echo "Using explicitly-set FRAMEWORK_APK=$FRAMEWORK_APK"
  echo "NOTE: if this is the same framework-res.apk from the firmware dump,"
  echo "      this WILL likely fail with the same parse error documented"
  echo "      above - use an SDK platform android.jar instead if possible."
  LINK_BASE="$FRAMEWORK_APK"
else
  PLATFORM_DIR=$(find "$SDK_ROOT/platforms" -maxdepth 1 -mindepth 1 -type d -name "android-*" | sort -V | tail -1)
  if [ -z "$PLATFORM_DIR" ] || [ ! -f "$PLATFORM_DIR/android.jar" ]; then
    echo "ERROR: No SDK platform android.jar found under $SDK_ROOT/platforms"
    echo "Install one via: sdkmanager \"platforms;android-35\""
    echo "(or set \$FRAMEWORK_APK to point at your own framework-res.apk - not recommended, see note above)"
    exit 1
  fi
  LINK_BASE="$PLATFORM_DIR/android.jar"
  echo "Using SDK platform framework: $LINK_BASE"
fi

# --- Keystore for signing ---
KEYSTORE="$SCRIPT_DIR/boston_overlay_debug.keystore"
KEYSTORE_PASS="boston-overlay-debug"
if [ ! -f "$KEYSTORE" ]; then
  echo "No keystore found at $KEYSTORE - generating a throwaway debug keystore."
  echo "This is fine for flashing on your own device. Do NOT redistribute this"
  echo "keystore or APKs signed with it as if they were from a trusted source."
  keytool -genkeypair -v \
    -keystore "$KEYSTORE" \
    -alias boston-overlay \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$KEYSTORE_PASS" -keypass "$KEYSTORE_PASS" \
    -dname "CN=Boston Overlay Fix V1, OU=Personal, O=Personal, L=Unknown, ST=Unknown, C=US"
fi

# --- Link + align + sign each overlay ---
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

FAILED=0
for overlay_dir in "$SCRIPT_DIR"/overlays/*/; do
  name=$(basename "$overlay_dir")
  manifest="$overlay_dir/AndroidManifest.xml"
  compiled_zip="$SCRIPT_DIR/compiled_resources/${name}.zip"

  if [ ! -f "$compiled_zip" ]; then
    echo "SKIP $name: no compiled resource zip found at $compiled_zip"
    continue
  fi

  echo ""
  echo "=== Building $name ==="

  unsigned_apk="$BUILD_DIR/${name}.unsigned.apk"
  aligned_apk="$BUILD_DIR/${name}.aligned.apk"
  final_apk="$OUT_DIR/${name}.apk"

  "$AAPT2" link \
    -I "$LINK_BASE" \
    --manifest "$manifest" \
    -o "$unsigned_apk" \
    "$compiled_zip"

  if [ $? -ne 0 ]; then
    echo "!!! aapt2 link FAILED for $name - skipping sign/align"
    FAILED=1
    continue
  fi

  "$ZIPALIGN" -f 4 "$unsigned_apk" "$aligned_apk"

  "$APKSIGNER" sign \
    --ks "$KEYSTORE" \
    --ks-pass "pass:$KEYSTORE_PASS" \
    --ks-key-alias boston-overlay \
    --out "$final_apk" \
    "$aligned_apk"

  if [ $? -eq 0 ]; then
    echo "OK: $final_apk"
  else
    echo "!!! apksigner FAILED for $name"
    FAILED=1
  fi
done

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "One or more overlays failed to build. See errors above. The Magisk"
  echo "zip will NOT be assembled until every overlay builds successfully -"
  echo "a partial module would silently omit fixes without telling you."
  exit 1
fi

echo ""
echo "=== All overlays built and signed successfully ==="
ls -la "$OUT_DIR"/*.apk

# --- Assemble the flashable Magisk zip ---
MODULE_STAGING="$SCRIPT_DIR/module_staging"
rm -rf "$MODULE_STAGING"
mkdir -p "$MODULE_STAGING/META-INF/com/google/android"
mkdir -p "$MODULE_STAGING/common"
mkdir -p "$MODULE_STAGING/overlay/product/overlay"
mkdir -p "$MODULE_STAGING/overlay/vendor/etc"
mkdir -p "$MODULE_STAGING/overlay/product/etc/CarrierSettings"

cp "$SCRIPT_DIR/module.prop" "$MODULE_STAGING/"
if [ -f "$SCRIPT_DIR/system.prop" ]; then
  cp "$SCRIPT_DIR/system.prop" "$MODULE_STAGING/"
fi
cp "$SCRIPT_DIR/META-INF/com/google/android/update-binary" "$MODULE_STAGING/META-INF/com/google/android/"
cp "$SCRIPT_DIR/META-INF/com/google/android/updater-script" "$MODULE_STAGING/META-INF/com/google/android/"
cp "$SCRIPT_DIR/common/customize.sh" "$MODULE_STAGING/common/"
cp "$SCRIPT_DIR/common/post-fs-data.sh" "$MODULE_STAGING/common/"
cp "$SCRIPT_DIR/common/service.sh" "$MODULE_STAGING/common/"
cp "$OUT_DIR"/*.apk "$MODULE_STAGING/overlay/product/overlay/"
if [ -d "$SCRIPT_DIR/overlay/vendor/etc" ]; then
  cp -a "$SCRIPT_DIR"/overlay/vendor/etc/* "$MODULE_STAGING/overlay/vendor/etc/" 2>/dev/null
fi
if [ -d "$SCRIPT_DIR/overlay/product/etc/CarrierSettings" ]; then
  cp -a "$SCRIPT_DIR"/overlay/product/etc/CarrierSettings/* "$MODULE_STAGING/overlay/product/etc/CarrierSettings/" 2>/dev/null
fi

ZIP_NAME="boston_gsi_overlay_fix_v3.zip"
cd "$MODULE_STAGING"
rm -f "$SCRIPT_DIR/$ZIP_NAME"
zip -r -X "$SCRIPT_DIR/$ZIP_NAME" . -x ".*"
cd "$SCRIPT_DIR"

echo ""
echo "=== DONE ==="
echo "Flashable module: $SCRIPT_DIR/$ZIP_NAME"
echo "Flash via Magisk app > Modules > Install from storage, then reboot."
echo "After reboot, check /data/local/tmp/boston_overlay_fix_boot.log and"
echo "/data/local/tmp/boston_overlay_fix_service.log to confirm the module"
echo "ran and to see whether OverlayManagerService picked up the overlays."
