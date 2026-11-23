#!/usr/bin/env bash
# Compile-only API compatibility probe against Ubuntu 24.04's libfprint line.
# It uses a dummy wrapper shared object and NEVER executes or installs the driver.
set -Eeuo pipefail

readonly LIBFPRINT_REPO="https://gitlab.freedesktop.org/libfprint/libfprint.git"
readonly LIBFPRINT_TAG="${LIBFPRINT_TAG:-v1.94.7}"
readonly DRIVER_REPO="https://github.com/rindeal/libfprint-vfs_proprietary-driver.git"
readonly DRIVER_COMMIT="4f26cc8c51bd61fda9fcac27c9fa37c9ae54bad2"

WORK_DIR="${WORK_DIR:-$PWD/.work/vfs491-modern-probe}"
mkdir -p "$WORK_DIR"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"

for command in git meson ninja gcc g++ pkg-config; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Missing build prerequisite: $command" >&2
    exit 2
  }
done

echo "==> Fetching libfprint $LIBFPRINT_TAG"
if [[ ! -d "$WORK_DIR/libfprint/.git" ]]; then
  git clone --filter=blob:none "$LIBFPRINT_REPO" "$WORK_DIR/libfprint"
fi
git -C "$WORK_DIR/libfprint" fetch --quiet --tags origin
git -C "$WORK_DIR/libfprint" checkout --quiet --detach "$LIBFPRINT_TAG"

echo "==> Fetching pinned historical VFS driver"
if [[ ! -d "$WORK_DIR/driver/.git" ]]; then
  git clone "$DRIVER_REPO" "$WORK_DIR/driver"
fi
git -C "$WORK_DIR/driver" fetch --quiet origin "$DRIVER_COMMIT"
git -C "$WORK_DIR/driver" checkout --quiet --detach "$DRIVER_COMMIT"

echo "==> Preparing a link-only stub for the proprietary wrapper"
mkdir -p "$WORK_DIR/stub"
printf 'void vfs491_link_probe(void) {}\n' > "$WORK_DIR/stub/stub.c"
gcc -shared -fPIC "$WORK_DIR/stub/stub.c" -o "$WORK_DIR/stub/libvfsFprintWrapper.so"

echo "==> Injecting driver into the modern libfprint source tree"
cd "$WORK_DIR/libfprint"
cp -a "$WORK_DIR/driver/vfs_proprietary" libfprint/drivers/vfs_proprietary

grep -q "^all_drivers = " meson.build || {
  echo "Could not locate all_drivers declaration in libfprint $LIBFPRINT_TAG" >&2
  exit 3
}
grep -q "^libfprint = " libfprint/meson.build || {
  echo "Could not locate libfprint target in libfprint/meson.build" >&2
  exit 3
}

sed -i "/^all_drivers =/a all_drivers += [ 'vfs_proprietary' ]" meson.build
sed -i "/^libfprint =/i libvfsFprintWrapper_dir='$WORK_DIR/stub'\nsubdir('drivers/vfs_proprietary')" libfprint/meson.build

echo "==> Showing upstream driver registration context"
sed -n '115,190p' libfprint/meson.build
echo "==> Showing injected driver Meson integration"
sed -n '1,180p' libfprint/drivers/vfs_proprietary/meson.build

echo "==> Configuring modern API probe with only the driver selection override"
meson setup build -D drivers=vfs_proprietary

echo "==> Compiling only; no hardware, daemon, PAM, or installation is touched"
ninja -C build -v
echo "Modern libfprint API compatibility probe completed."
