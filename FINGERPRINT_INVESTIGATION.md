# Investigation: Lack of Fingerprint Support on Redmi 13C (gale)

## Summary of Findings

The investigation into the lack of fingerprint support on the Redmi 13C (gale) reveals significant discrepancies in the device tree configuration that likely prevent the fingerprint sensor from functioning correctly.

### 1. Missing Device Node Permissions (FPC)
A review of `init.project.rc` shows that while directories for FPC are created, the actual device node `/dev/fpc1020` is **not** assigned the necessary permissions or ownership in the `on boot` section.
- **Problem**: The fingerprint HAL cannot open the FPC sensor device node.
- **Recommended Fix**: Add the following to `init.project.rc`:
  ```rc
  chown system system /dev/fpc1020
  chmod 0660 /dev/fpc1020
  ```

### 2. VINTF Manifest Mismatch (AIDL HAL)
The `device.mk` file includes the AIDL fingerprint service:
`PRODUCT_PACKAGES += android.hardware.biometrics.fingerprint-service.xiaomi`

However, the `configs/vintf/manifest.xml` **only** lists the older HIDL interfaces for Goodix and FPC. It is missing the AIDL declaration required for Android 13+.
- **Problem**: The system does not "see" the running AIDL fingerprint service because it's not declared in the device manifest.
- **Recommended Fix**: Add the following to `manifest.xml`:
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

### 3. HAL & Service Configuration
The current device tree uses:
- **Service**: `android.hardware.biometrics.fingerprint-service.xiaomi` (AIDL)
- **Blobs**: Goodix, FPC, Silead, and Chipone (mostly HIDL-based legacy blobs).

There is a potential conflict between the modern AIDL service wrapper and the legacy HIDL blobs if the `android.hardware.biometrics.fingerprint@2.1-service` is not also present or if the AIDL service fails to wrap them correctly.

---

## Troubleshooting Guide for Users

If your fingerprint sensor is not working on crDroid for Redmi 13C, please follow these steps to help developers debug the issue:

### 1. Collect Logs (Crucial)
Run the following command via ADB to see why the HAL is failing:
```bash
adb shell logcat | grep -E "fingerprint|biometrics|goodix|fpc|silead"
```
Look for:
- `E/FingerprintHal: Failed to open /dev/fpc1020: Permission denied`
- `W/ServiceManager: Permission failure: android.permission.HAL_FINGERPRINT`
- `E/hwservicemanager: getTransport: Cannot find entry android.hardware.biometrics.fingerprint@2.1 in either framework or device manifest.`

### 2. Check SELinux Status
Test if a missing policy is the cause:
```bash
adb shell setenforce 0
```
If biometrics work after this, the ROM needs updated SELinux rules for the fingerprint HAL.

### 3. Hardware Detection
Verify the kernel sees the sensor:
```bash
adb shell dmesg | grep -E "goodix|fpc|silead"
```

### 4. Firmware Requirements
Ensure you are using the latest stable HyperOS/MIUI firmware. The fingerprint sensor relies on the TrustZone (TEE), which is part of the firmware.
- [Xiaomi Firmware Updater](https://xiaomifirmwareupdater.com/firmware/gale/)
