# Architecture and implementation plan

## Known device and environment

The initial target is USB device `138a:003d` (Validity VFS491) on an HP
ProBook 6570b running Ubuntu 24.04. The system fprintd/libfprint stack is
1.94.x. The device enumerates on USB, but fprintd currently reports that no
fingerprint devices are available.

## Historical vendor stack

The HP SoftPaq SP84530 package contains, among other files:

- `vcsFPService`
- `libvfsFprintWrapper.so`
- `100-Validity_FingerPrint_Sensor.rules`
- VFS491 firmware and helper scripts

The extracted wrapper has unresolved runtime dependencies on
`libcrypto.so.0.9.8` and `libssl.so.0.9.8` on the target Ubuntu system.
These are old OpenSSL SONAMEs. Do not fake them with symlinks to OpenSSL 3
(or any other ABI) and do not install the vendor RPM blindly.

## Candidate integration approach

The historical
[rindeal/libfprint-vfs_proprietary-driver](https://github.com/rindeal/libfprint-vfs_proprietary-driver)
repository documents an architecture in which proprietary capture components
run in a helper process and exchange captured image data with libfprint.
This avoids loading the proprietary wrapper directly into the libfprint
process, but does not by itself establish compatibility with current
libfprint.

## Staged plan

1. Record exact hardware, OS, kernel, fprintd, and libfprint versions.
2. Inspect vendor binaries and their dependencies without executing them.
3. Reproduce the historical helper build in a disposable workspace.
4. Check compile-time compatibility and runtime dependencies.
5. Only after a successful isolated test, design integration for the current
   libfprint API.
6. Test enrollment and verification without changing the login stack.
7. Consider PAM integration only after repeatable successful tests.

## Explicit non-goals for early stages

- No replacing or shadowing Ubuntu's system libfprint.
- No modifying PAM configuration.
- No enabling an unverified vendor daemon at boot.
- No distributing HP firmware or proprietary binaries.
