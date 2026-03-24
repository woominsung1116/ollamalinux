#!/bin/bash
set -euo pipefail

PROJECT="${PROJECT:-ollamalinux}"
VERSION="${VERSION:-0.1.0}"
FLAVOR="${FLAVOR:-server}"

echo "============================================"
echo " Building ${PROJECT} v${VERSION} (${FLAVOR})"
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
    echo ">>> Server mode: removing desktop package list"
    rm -f config/package-lists/desktop.list.chroot
fi

# Use cached APT packages if available
if [ -d /build/cache/packages ]; then
    mkdir -p cache/packages.chroot
    cp /build/cache/packages/*.deb cache/packages.chroot/ 2>/dev/null || true
fi

# Run live-build
# auto/config is invoked by lb config, auto/build by lb build
lb config noauto \
    --distribution noble \
    --parent-distribution noble \
    --parent-archive-areas "main restricted universe multiverse" \
    --archive-areas "main restricted universe multiverse" \
    --mirror-bootstrap "http://archive.ubuntu.com/ubuntu/" \
    --mirror-chroot "http://archive.ubuntu.com/ubuntu/" \
    --mirror-binary "http://archive.ubuntu.com/ubuntu/" \
    --mirror-chroot-security "http://security.ubuntu.com/ubuntu/" \
    --mirror-binary-security "http://security.ubuntu.com/ubuntu/" \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --mode debian \
    --system live \
    --linux-flavours generic \
    --linux-packages "linux-image linux-headers" \
    --apt-recommends false \
    --memtest none \
    --bootappend-live "boot=live components quiet splash" \
    --iso-application "OllamaLinux" \
    --iso-publisher "OllamaLinux Project" \
    --iso-volume "OllamaLinux-${VERSION}" \
    --bootloader syslinux \
    --cache true \
    --cache-packages true \
    --apt-source-archives false \
    --firmware-binary false \
    --firmware-chroot false \
    --initramfs auto \
    --initsystem systemd

lb build noauto 2>&1 | tee /build/output/build.log

# Move output
mv *.iso /build/output/${PROJECT}-${VERSION}-${FLAVOR}-amd64.iso 2>/dev/null || true
mv *.zsync /build/output/ 2>/dev/null || true
mv *.contents /build/output/ 2>/dev/null || true
mv *.packages /build/output/ 2>/dev/null || true

# Cache APT packages for next build
if [ -d cache/packages.chroot ]; then
    mkdir -p /build/cache/packages
    cp cache/packages.chroot/*.deb /build/cache/packages/ 2>/dev/null || true
fi

echo "============================================"
echo " Build complete: ${PROJECT}-${VERSION}-${FLAVOR}-amd64.iso"
echo "============================================"
ls -lh /build/output/*.iso 2>/dev/null
