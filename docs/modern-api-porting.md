# Porting the VFS491 driver to modern libfprint

## Current finding

The historical VFS proprietary driver is an image driver written against the pre-0.9 libfprint API. It cannot be copied unchanged into Ubuntu 24.04's libfprint 1.94.x tree.

The historical implementation uses these removed interfaces and types:

- `struct fp_img_dev`
- `struct fp_img_driver`
- `struct usb_id`
- `fpi_imgdev_open_complete()`, `fpi_imgdev_close_complete()`
- `fpi_imgdev_activate_complete()`, `fpi_imgdev_deactivate_complete()`
- `fpi_imgdev_image_captured()`
- `fpi_imgdev_report_finger_status()`
- `fpi_img_new()` and the old `struct fp_img` representation

Modern libfprint uses the `FpImageDevice` GObject base class and `FpImageDeviceClass` vfuncs, with `FpIdEntry` USB IDs. The modern image-driver lifecycle includes `img_open`, `img_close`, `activate`, `change_state`, and `deactivate`. The internal driver API is explicitly not API/ABI stable, so the port must target and test the exact Ubuntu package line.

## Proposed port architecture

Keep the vendor protocol isolated in the existing capture-helper process. Do not load `libvfsFprintWrapper.so` into fprintd or the libfprint process.

The new libfprint adapter should:

1. Subclass `FpImageDevice` and register USB ID `138a:003d` through an `FpIdEntry`.
2. Implement `img_open` / `img_close` using the current `fpi_image_device_*` completion APIs.
3. Start and supervise the capture helper asynchronously from `activate`; never block the libfprint main context while waiting for a swipe.
4. Convert the helper's image metadata and pixel buffer into the current `FpImage` representation and submit it through the current image-device reporting API.
5. Handle `deactivate` and cancellation at every point in helper startup/capture, terminate and reap the child process, and close every IPC descriptor.
6. Validate image dimensions, buffer length, and pixel format before handing data to libfprint.
7. Keep enrollment/matching in libfprint's host-side image pipeline unless protocol testing proves otherwise.

## Required gates before hardware testing

- [ ] Compile against the exact Ubuntu 24.04 libfprint source/API version.
- [ ] Add unit tests for IPC framing, malformed metadata, short reads/writes, child exit, timeout, and cancellation.
- [ ] Confirm helper executable path and runtime library search path without installing vendor files system-wide.
- [ ] Resolve the vendor wrapper's OpenSSL 0.9.8 dependency safely. Do not symlink modern OpenSSL libraries to old SONAMEs.
- [ ] Verify vendor service lifecycle and permissions in a disposable test environment.
- [ ] Test sensor open, capture, finger removal, repeated capture, suspend/resume, and cleanup.
- [ ] Only after all above pass, test enrollment and verification through a private test build of fprintd.
- [ ] Do not modify PAM or replace the distribution libfprint until a complete end-to-end test passes.

## Current status

The legacy reference build passes in CI. A compile-only probe against libfprint 1.94.7 is being developed. That probe is not evidence of a working modern driver; the port itself remains pending. The sensor has not yet been tested with a modern adapter.
