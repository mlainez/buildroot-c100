#!/bin/sh
# Builds the boot partition's script and the microSD card image.

set -e

BOARD_DIR=$(dirname "$0")

"$HOST_DIR/bin/mkimage" -A arm64 -T script -C none \
	-d "$BOARD_DIR/uboot/boot.cmd" "$BINARIES_DIR/boot.scr"

support/scripts/genimage.sh -c "$BOARD_DIR/genimage.cfg"
