#!/usr/bin/env bash
# Build the historical VFS proprietary driver against its pinned historical
# libfprint API. This is a compatibility baseline only, not an install script.
set -Eeuo pipefail

readonly UPSTREAM_REPO="https://github.com/rindeal/libfprint-vfs_proprietary-driver.git"
readonly UPSTREAM_COMMIT="4f26cc8c51bd61fda9fcac27c9fa37c9ae54bad2"
readonly LIBFPRINT_COMMIT="1abe213844b28fd8afc28eb072fd569f0f72d7f1"
readonly SOFTPAQ_URL="https://ftp.hp.com/pub/softpaq/sp84501-85000/sp84530.tar"

WORK_DIR="${WORK_DIR:-$PWD/.work/vfs491-legacy-build}"
mkdir -p "$WORK_DIR"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"

for command in git curl tar rpm2cpio cpio meson ninja gcc g++ pkg-config; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Missing build prerequisite: $command" >&2
    exit 2
  }
done

echo "==> Fetching pinned historical driver source"
if [[ ! -d "$WORK_DIR/upstream/.git" ]]; then
  git clone "$UPSTREAM_REPO" "$WORK_DIR/upstream"
fi
git -C "$WORK_DIR/upstream" fetch --quiet origin "$UPSTREAM_COMMIT"
git -C "$WORK_DIR/upstream" checkout --quiet --detach "$UPSTREAM_COMMIT"

echo "==> Checking out the exact libfprint submodule revision"
git -C "$WORK_DIR/upstream" submodule update --init --recursive
test "$(git -C "$WORK_DIR/upstream/libfprint" rev-parse HEAD)" = "$LIBFPRINT_COMMIT"

echo "==> Downloading and extracting the HP SoftPaq locally (not into Git)"
mkdir -p "$WORK_DIR/softpaq" "$WORK_DIR/vendor"
if [[ ! -f "$WORK_DIR/softpaq/sp84530.tar" ]]; then
  curl --fail --location --retry 3 "$SOFTPAQ_URL" -o "$WORK_DIR/softpaq/sp84530.tar"
fi
tar -xf "$WORK_DIR/softpaq/sp84530.tar" -C "$WORK_DIR/softpaq"
rpm_file="$(find "$WORK_DIR/softpaq" -type f -name '*.rpm' -print -quit)"
test -n "$rpm_file"
(
  cd "$WORK_DIR/vendor"
  rpm2cpio "$rpm_file" | cpio --quiet -idm
)
wrapper_dir="$WORK_DIR/vendor/usr/lib64"
test -f "$wrapper_dir/libvfsFprintWrapper.so"

echo "==> Applying the upstream driver's documented Meson integration"
cd "$WORK_DIR/upstream/libfprint"
cp -a "$WORK_DIR/upstream/vfs_proprietary" libfprint/drivers/vfs_proprietary

grep -q "^all_drivers = " meson.build
grep -q "^libfprint = " libfprint/meson.build
sed -i "/^all_drivers =/a all_drivers += [ 'vfs_proprietary' ]" meson.build
sed -i "/^libfprint =/i libvfsFprintWrapper_dir='$wrapper_dir'\nsubdir('drivers/vfs_proprietary')" libfprint/meson.build

echo "==> Configuring and compiling (no installation, no device access)"
meson setup build -D drivers=vfs_proprietary -D x11-examples=false -D gtk-examples=false -D doc=false
ninja -C build -v

echo "==> Legacy reference build completed"
echo "This does not establish compatibility with Ubuntu 24.04's libfprint 1.94.x."
