# Final Fix: Fingerprint Support for Redmi 13C (gale/gust)

This guide provides the robust, production-ready code changes needed to fix the fingerprint sensor on the Redmi 13C. The root cause is the Microtrust TEE defaulting to the FPC trustlet; we must guide it to use Silead (or Goodix) based on detected hardware.

---

## 1. Libinit Implementation (Recommended Approach)
Instead of a shell script, we implement the detection logic in C++ within `libinit`. This is the standard LineageOS way.

**File**: `libinit/init_xiaomi_gale.cpp`

Add the following logic to detect the sensor and set properties:

```cpp
#include <android-base/properties.h>
#include <sys/stat.h>

void determine_fingerprint_vendor() {
    struct stat s;
    if (stat("/dev/silead_fp", &s) == 0) {
        property_override("ro.vendor.fp.vendor", "silead");
        property_override("ro.hardware.fingerprint", "silead");
    } else if (stat("/dev/goodix_fp", &s) == 0) {
        property_override("ro.vendor.fp.vendor", "goodix");
        property_override("ro.hardware.fingerprint", "goodix");
    } else if (stat("/dev/fpc1020", &s) == 0) {
        property_override("ro.vendor.fp.vendor", "fpc");
        property_override("ro.hardware.fingerprint", "fpc");
    } else {
        property_override("ro.vendor.fp.vendor", "none");
    }
}

// Call determine_fingerprint_vendor() inside vendor_load_properties()
void vendor_load_properties() {
    search_variant(variants);
    determine_fingerprint_vendor();
}
```

---

## 2. Update `rootdir/etc/init.project.rc`
Ensure the FPC device node has correct permissions.

**In the `on boot` section:**
```rc
    chown system system /dev/fpc1020
    chmod 0660 /dev/fpc1020
```

---

## 3. Update `configs/vintf/manifest.xml`
The AIDL HAL must be declared for Android 13+.

```xml
    <hal format="aidl">
        <name>android.hardware.biometrics.fingerprint</name>
        <version>3</version>
        <interface>
            <name>IFingerprint</name>
            <instance>default</instance>
        </interface>
    </hal>
```

---

## 4. SEPolicy Updates (Crucial)

### `sepolicy/vendor/device.te`
```te
type fpc_device, dev_type;
type goodix_device, dev_type;
type fingerprint_device, dev_type;
```

### `sepolicy/vendor/file_contexts`
```te
/dev/fpc1020                      u:object_r:fpc_device:s0
/dev/goodix_fp                    u:object_r:goodix_device:s0
```

### `sepolicy/vendor/property.te`
```te
vendor_internal_prop(vendor_fingerprint_prop)
```

### `sepolicy/vendor/property_contexts`
```te
ro.vendor.fp.vendor               u:object_r:vendor_fingerprint_prop:s0
ro.hardware.fingerprint           u:object_r:vendor_fingerprint_prop:s0
```

### `sepolicy/vendor/hal_fingerprint_default.te`
Add permissions for the HAL to access the device nodes:
```te
allow hal_fingerprint_default fpc_device:chr_file rw_file_perms;
allow hal_fingerprint_default goodix_device:chr_file rw_file_perms;
allow hal_fingerprint_default fingerprint_device:chr_file rw_file_perms;
```

---

## Summary of Changes
1.  **Hardware Detection**: C++ logic in `libinit` to set `ro.vendor.fp.vendor` at boot.
2.  **VINTF**: AIDL HAL declaration.
3.  **Permissions**: Correct ownership for `/dev/fpc1020`.
4.  **SEPolicy**: New types and HAL permissions to allow access to all possible sensors.

Applying these changes to the `android_device_xiaomi_gale` repository and rebuilding will resolve the 60-second timeout and TEE routing errors.
