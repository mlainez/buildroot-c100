#!/bin/sh
# Adds a login prompt on the HDMI/DP console next to the serial one.

set -e

grep -q '^tty1::' "$TARGET_DIR/etc/inittab" ||
	sed -i '/GENERIC_SERIAL/a tty1::respawn:/sbin/getty -L tty1 0 linux # HDMI/DP' \
		"$TARGET_DIR/etc/inittab"
