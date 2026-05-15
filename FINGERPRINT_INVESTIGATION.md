# Investigation: Lack of Fingerprint Support on Redmi 13C (gale)

## Summary of Findings

The investigation into the lack of fingerprint support on the Redmi 13C (gale) reveals significant discrepancies in the device tree configuration that likely prevent the fingerprint sensor from functioning correctly.

### 1. Missing Device Node Permissions (FPC)
A review of `init.project.rc` shows that while directories for FPC are created, the actual device node `/dev/fpc1020` is **not** assigned the necessary permissions or ownership in the `on boot` section.
- **Problem**: The fingerprint HAL cannot open the FPC sensor device node.

### 2. VINTF Manifest Mismatch (AIDL HAL)
The `device.mk` file includes the AIDL fingerprint service:
`PRODUCT_PACKAGES += android.hardware.biometrics.fingerprint-service.xiaomi`

However, the `configs/vintf/manifest.xml` **only** lists the older HIDL interfaces for Goodix and FPC. It is missing the AIDL declaration required for Android 13+.
- **Problem**: The system does not "see" the running AIDL fingerprint service because it's not declared in the device manifest.

### 3. Missing SEPolicy Rules
The vendor SEPolicy is missing definitions and permissions for the primary fingerprint device nodes (`/dev/fpc1020` and `/dev/goodix_fp`).

### 4. TEE/TrustZone Errors
Dmesg analysis shows that the Microtrust TEE (`teei`) is reporting "unsupported target" and "unknown command" when `fp_ta` (Fingerprint TrustZone App) is called.
```
[TZ_LOG] fp_ta | [fpc_log.c:79/fpc_tee_error]<err>error : fpc_ta_route_command unsupported target 4099
[TZ_LOG] fp_ta | [fpc_log.c:79/fpc_tee_error]<err>error : fpc_ta_hw_auth_handler unknown command 0
```
This typically happens when there is a mismatch between the HAL and the Fingerprint TA, or when the hardware is not properly powered/initialized by the kernel regulator before the TEE is invoked.

---

## Solutions

### For Developers: Fix Script
To automate the fixes in the `gale` device tree repository, I have provided a `fix_gale_device_tree.sh` script in this repository.

**How to use:**
1. Download `fix_gale_device_tree.sh`.
2. Move it to the root of your `android_device_xiaomi_gale` repository.
3. Run the script:
   ```bash
   chmod +x fix_gale_device_tree.sh
   ./fix_gale_device_tree.sh
   ```
4. Rebuild the ROM.

### For Users: Troubleshooting Guide
If you are using a build where these fixes have not yet been applied, please follow these steps:

#### 1. Collect Logs (Crucial)
Run the following command via ADB to see why the HAL is failing:
```bash
adb shell logcat | grep -E "fingerprint|biometrics|goodix|fpc|silead"
```
Look for:
- `E/FingerprintHal: Failed to open /dev/fpc1020: Permission denied`
- `E/hwservicemanager: getTransport: Cannot find entry android.hardware.biometrics.fingerprint@2.1 in either framework or device manifest.`

#### 2. Check SELinux Status
Test if a missing policy is the cause:
```bash
adb shell setenforce 0
```
If biometrics work after this, it is an SEPolicy issue.

#### 3. Firmware Requirements
Ensure you are using the latest stable HyperOS/MIUI firmware. The fingerprint sensor relies on the TrustZone (TEE), which is part of the firmware.
- [Xiaomi Firmware Updater](https://xiaomifirmwareupdater.com/firmware/gale/)
