# Contributing

Thanks for helping investigate the Validity VFS491 on Linux.

## Before submitting changes

- Keep experiments reproducible and document the exact Ubuntu, kernel,
  libfprint, and fprintd versions.
- Never commit HP SoftPaq archives, RPM files, firmware images, or proprietary
  Validity binaries.
- Never add scripts that silently modify PAM, replace system libraries, or
  enable vendor services at boot.
- Prefer isolated build directories and explicit opt-in for any privileged
  operation.
- Include complete build logs for failures, with usernames, serial numbers,
  and other private details removed.

## Scope

The initial goal is to determine whether a maintained integration for the
VFS491 can work with Ubuntu 24.04's libfprint API. A successful compile alone
is not proof of working enrollment or verification.
