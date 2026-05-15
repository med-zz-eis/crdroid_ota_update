#!/bin/bash

# Utility script to fix fingerprint issues in the gale device tree
# Targets: Mayuri-Chan/android_device_xiaomi_gale

if [ ! -d "configs" ] || [ ! -f "device.mk" ]; then
    echo "Error: Run this script from the root of the gale device tree repository."
    exit 1
fi

echo "--- Fixing init.project.rc permissions ---"
RC_FILE="rootdir/etc/init.project.rc"
if [ -f "$RC_FILE" ]; then
    if ! grep -q "fpc1020" "$RC_FILE"; then
        sed -i '/chmod 0660 \/dev\/silead_fp/a \    chown system system /dev/fpc1020\n    chmod 0660 /dev/fpc1020' "$RC_FILE"
        echo "Added FPC device node permissions to $RC_FILE"
    else
        echo "FPC device node permissions already present in $RC_FILE"
    fi
fi

echo "--- Fixing VINTF manifest.xml ---"
MANIFEST_FILE="configs/vintf/manifest.xml"
if [ -f "$MANIFEST_FILE" ]; then
    if ! grep -q "android.hardware.biometrics.fingerprint" "$MANIFEST_FILE"; then
        # Insert AIDL HAL before the closing manifest tag
        sed -i '/<\/manifest>/i \    <hal format="aidl">\n        <name>android.hardware.biometrics.fingerprint</name>\n        <version>3</version>\n        <interface>\n            <name>IFingerprint</name>\n            <instance>default</instance>\n        </interface>\n    </hal>' "$MANIFEST_FILE"
        echo "Added AIDL Fingerprint HAL to $MANIFEST_FILE"
    else
        echo "AIDL Fingerprint HAL already present in $MANIFEST_FILE"
    fi
fi

echo "--- Fixing SEPolicy ---"
DEVICE_TE="sepolicy/vendor/device.te"
if [ -f "$DEVICE_TE" ]; then
    if ! grep -q "fingerprint_device" "$DEVICE_TE"; then
        echo "type fingerprint_device, dev_type;" >> "$DEVICE_TE"
        echo "type fpc_device, dev_type;" >> "$DEVICE_TE"
        echo "type goodix_device, dev_type;" >> "$DEVICE_TE"
        echo "Added fingerprint device types to $DEVICE_TE"
    fi
fi

FILE_CONTEXTS="sepolicy/vendor/file_contexts"
if [ -f "$FILE_CONTEXTS" ]; then
    if ! grep -q "fpc1020" "$FILE_CONTEXTS"; then
        echo "/dev/fpc1020              u:object_r:fpc_device:s0" >> "$FILE_CONTEXTS"
        echo "/dev/goodix_fp            u:object_r:goodix_device:s0" >> "$FILE_CONTEXTS"
        echo "Added device labels to $FILE_CONTEXTS"
    fi
fi

HAL_TE="sepolicy/vendor/hal_fingerprint_default.te"
if [ -f "$HAL_TE" ]; then
    if ! grep -q "fingerprint_device" "$HAL_TE"; then
        echo "allow hal_fingerprint_default fingerprint_device:chr_file rw_file_perms;" >> "$HAL_TE"
        echo "allow hal_fingerprint_default fpc_device:chr_file rw_file_perms;" >> "$HAL_TE"
        echo "allow hal_fingerprint_default goodix_device:chr_file rw_file_perms;" >> "$HAL_TE"
        echo "Added HAL permissions to $HAL_TE"
    fi
fi

echo "Done! Please rebuild the ROM and verify."
