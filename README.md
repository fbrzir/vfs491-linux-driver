# Validity VFS491 Linux Driver

Experimental work to enable the **Validity Sensors VFS491** fingerprint reader
(USB ID `138a:003d`) on modern Linux systems, initially targeting Ubuntu 24.04.

> **Status: research / compatibility testing.** This repository does not yet
> provide a working installable driver. Do not change PAM or replace the system
> libfprint until the isolated driver build and device tests pass.

## Current target

- Laptop tested: HP ProBook 6570b
- Reader: Validity Sensors VFS491
- USB ID: `138a:003d`
- OS target: Ubuntu 24.04 LTS
- System stack observed: fprintd 1.94.x / libfprint 1.94.x
- Vendor package investigated: HP SoftPaq SP84530

## Why this is not a simple package install

The historical proprietary implementation depends on HP/Validity components,
including `vcsFPService` and `libvfsFprintWrapper.so`. The extracted wrapper
currently reports dependencies on the obsolete `libcrypto.so.0.9.8` and
`libssl.so.0.9.8` ABI, which are not provided by a normal Ubuntu 24.04
installation.

Do **not** create symlinks from modern OpenSSL libraries to those old SONAMEs:
matching filenames do not guarantee ABI compatibility.

The historical
[`rindeal/libfprint-vfs_proprietary-driver`](https://github.com/rindeal/libfprint-vfs_proprietary-driver)
project explored isolating the proprietary capture helper in a separate
process. Its README notes that its driver targets an older libfprint API;
compatibility with Ubuntu 24.04's libfprint 1.94.x must be established before
integration.

## Repository layout

- `scripts/diagnose-vfs491.sh` — read-only collection of device, service,
  package, and vendor-library diagnostics.
- `docs/architecture.md` — implementation strategy and safety constraints.

## First diagnostic

Run:

```bash
bash scripts/diagnose-vfs491.sh
```

The script only reads system state and writes a report under
`~/vfs491-recovery/reports/`. It does not install packages, start vendor
services, change permissions, alter PAM, or replace system libraries.

## Vendor files and licensing

HP/Validity binaries and firmware are proprietary. Do not commit extracted
vendor binaries, firmware images, RPMs, or SoftPaq archives to this repository.
Obtain them from HP under the applicable terms and keep them local.

## Safety policy

- No PAM/login changes until enrollment and verification work reliably.
- No replacing Ubuntu's system libfprint during development.
- No running the proprietary daemon as a system service until its dependencies
  and behavior are understood.
- Test in an isolated build/runtime environment first.
