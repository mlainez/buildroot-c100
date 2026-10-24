#!/bin/sh
# Builds the boot partition's chain-loading script and the microSD card image.

set -e

BOARD_DIR=$(dirname "$0")

"$HOST_DIR/bin/mkimage" -A arm64 -T script -C none \
	-d "$BOARD_DIR/uboot/boot.cmd" "$BINARIES_DIR/boot.scr"

mkdir -p "$BINARIES_DIR/extlinux"
cp "$BOARD_DIR/extlinux.conf" "$BINARIES_DIR/extlinux/extlinux.conf"

support/scripts/genimage.sh -c "$BOARD_DIR/genimage.cfg"
