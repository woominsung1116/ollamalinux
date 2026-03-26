#!/bin/bash
set -euo pipefail

PROJECT="${PROJECT:-ollamalinux}"
VERSION="${VERSION:-0.1.0}"
FLAVOR="${FLAVOR:-server}"
ARCH="${ARCH:-amd64}"

echo "============================================"
echo " Building ${PROJECT} v${VERSION} (${FLAVOR}) [${ARCH}]"
echo "============================================"

cd /build/live-build

# Copy scripts into chroot overlay
mkdir -p config/includes.chroot/usr/local/bin/lib
cp -r /build/scripts/*.sh config/includes.chroot/usr/local/bin/ 2>/dev/null || true
cp -r /build/scripts/lib/*.sh config/includes.chroot/usr/local/bin/lib/ 2>/dev/null || true
chmod +x config/includes.chroot/usr/local/bin/*.sh 2>/dev/null || true

# Rename scripts (remove .sh extension for cleaner CLI)
for f in config/includes.chroot/usr/local/bin/*.sh; do
    [ -f "$f" ] && mv "$f" "${f%.sh}"
done

# Copy branding assets
if [ -d /build/branding/grub ]; then
    mkdir -p config/includes.binary/boot/grub/themes/ollamalinux/
    cp /build/branding/grub/* config/includes.binary/boot/grub/themes/ollamalinux/ 2>/dev/null || true
fi

if [ -d /build/branding/plymouth ]; then
    mkdir -p config/includes.chroot/usr/share/plymouth/themes/ollamalinux/
    cp -r /build/branding/plymouth/* config/includes.chroot/usr/share/plymouth/themes/ollamalinux/ 2>/dev/null || true
fi

# Handle desktop flavor
if [ "$FLAVOR" = "desktop" ]; then
    echo ">>> Including desktop environment packages"
else
    echo ">>> Server mode: removing desktop/installer package lists"
    rm -f config/package-lists/desktop.list.chroot
    rm -f config/package-lists/installer.list.chroot
fi

# Use cached APT packages if available
if [ -d /build/cache/packages ]; then
    mkdir -p cache/packages.chroot
    cp /build/cache/packages/*.deb cache/packages.chroot/ 2>/dev/null || true
fi

# Create local syslinux bootloader template (fix broken symlinks in live-build)
mkdir -p config/bootloaders
cp -a /usr/share/live/build/bootloaders/isolinux config/bootloaders/
cp -fL /usr/lib/ISOLINUX/isolinux.bin config/bootloaders/isolinux/ 2>/dev/null || true
cp -fL /usr/lib/syslinux/modules/bios/vesamenu.c32 config/bootloaders/isolinux/ 2>/dev/null || true
cp -fL /usr/lib/syslinux/modules/bios/ldlinux.c32 config/bootloaders/isolinux/ 2>/dev/null || true
cp -fL /usr/lib/syslinux/modules/bios/libcom32.c32 config/bootloaders/isolinux/ 2>/dev/null || true
cp -fL /usr/lib/syslinux/modules/bios/libutil.c32 config/bootloaders/isolinux/ 2>/dev/null || true
find config/bootloaders/isolinux/ -xtype l -delete 2>/dev/null || true
rm -f config/bootloaders/isolinux/splash.svg.in
if [ ! -e config/bootloaders/isolinux/bootlogo ]; then
    (cd /tmp && ls -d . | cpio --quiet -o) > config/bootloaders/isolinux/bootlogo
fi

# Run live-build config (delegated to auto/config)
export ARCH VERSION
lb config

lb build noauto 2>&1 | tee /build/output/build.log

# Move output
mv *.iso /build/output/${PROJECT}-${VERSION}-${FLAVOR}-${ARCH}.iso 2>/dev/null || true
mv *.zsync /build/output/ 2>/dev/null || true
mv *.contents /build/output/ 2>/dev/null || true
mv *.packages /build/output/ 2>/dev/null || true

# Cache APT packages for next build
if [ -d cache/packages.chroot ]; then
    mkdir -p /build/cache/packages
    cp cache/packages.chroot/*.deb /build/cache/packages/ 2>/dev/null || true
fi

echo "============================================"
echo " Build complete: ${PROJECT}-${VERSION}-${FLAVOR}-${ARCH}.iso"
echo "============================================"
ls -lh /build/output/*.iso 2>/dev/null
