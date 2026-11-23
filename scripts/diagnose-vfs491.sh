#!/usr/bin/env bash
# Read-only VFS491 diagnostics. Does not install, start, or modify anything.
set -u

OUT_DIR="${HOME}/vfs491-recovery/reports"
mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/vfs491-diagnostic-$STAMP.txt"

exec > >(tee "$REPORT") 2>&1

section() { printf '\n\n===== %s =====\n' "$1"; }
run() {
  printf '\n$'
  printf ' %q' "$@"
  printf '\n'
  "$@" 2>&1 || true
}

echo "Validity VFS491 diagnostic report"
echo "Date: $(date -Is)"
echo "User: $USER"
echo "Report: $REPORT"

section "Operating system"
run uname -a
if [[ -r /etc/os-release ]]; then cat /etc/os-release; fi

section "USB device"
if command -v lsusb >/dev/null 2>&1; then
  run lsusb -d 138a:003d
  run lsusb -nn
else
  echo "lsusb is not installed"
fi

section "Fingerprint packages"
if command -v dpkg-query >/dev/null 2>&1; then
  dpkg-query -W -f='${binary:Package}\t${Version}\n' \
    'fprintd' 'libfprint*' 'libpam-fprintd' 2>&1 || true
fi

section "Fingerprint service"
if command -v systemctl >/dev/null 2>&1; then
  run systemctl --no-pager --full status fprintd.service
fi
if command -v fprintd-list >/dev/null 2>&1; then
  run fprintd-list "$USER"
fi

section "Relevant kernel messages"
if command -v journalctl >/dev/null 2>&1; then
  journalctl -k -b --no-pager 2>/dev/null | grep -Ei '138a|validity|fingerprint|usb' | tail -n 100 || true
fi

section "Previously extracted HP package"
EXTRACT_ROOT="${HOME}/vfs491-recovery/extracted"
if [[ -d "$EXTRACT_ROOT" ]]; then
  find "$EXTRACT_ROOT" -type f \( \
    -name 'libvfsFprintWrapper.so' -o \
    -name 'vcsFPService' -o \
    -name 'HPUsbVFS491.img' -o \
    -name 'Validity-Sensor-Setup*.rpm' \
  \) -print
  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    echo
    echo "--- ldd: $file"
    if command -v ldd >/dev/null 2>&1 && [[ "$file" == *.so* || "$file" == */vcsFPService ]]; then
      ldd "$file" 2>&1 || true
    fi
  done < <(find "$EXTRACT_ROOT" -type f \( -name 'libvfsFprintWrapper.so' -o -name 'vcsFPService' \))
else
  echo "No extracted HP package found at $EXTRACT_ROOT"
fi

section "Existing custom source/build directories"
for path in "$HOME/libfprint" "$HOME/vfs491-modern-test"; do
  if [[ -d "$path" ]]; then
    echo "Found: $path"
    find "$path" -maxdepth 2 -type f \( -name meson.build -o -name configure -o -name Makefile \) -print | head -n 30
  else
    echo "Not found: $path"
  fi
done

section "End"
echo "This report is read-only diagnostic output."
echo "Saved to: $REPORT"
