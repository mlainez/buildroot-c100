# Installed as boot.scr in the microSD card's boot partition. It runs twice:
#
# 1. The U-Boot in the eMMC LNX partition (for example OKdo's) finds it
#    through distro boot. It starts this system's U-Boot from the same
#    partition rather than booting Linux itself: that U-Boot replaces the SD
#    card and memory controller nodes of the device tree with L4T overlays.
# 2. This system's U-Boot sets okdo_c100_uboot and runs it again to boot
#    Linux.

if test "${okdo_c100_uboot}" = "1"; then
	setenv bootargs console=tty1 console=ttyS0,115200n8 net.ifnames=0 root=PARTUUID=a57829cf-995e-43fc-86e3-591c78f62b06 rootfstype=ext4 rootwait rw
	fatload mmc 1:1 ${kernel_addr_r} Image
	fatload mmc 1:1 ${fdt_addr_r} tegra210-p3448-0002-okdo-c100.dtb
	booti ${kernel_addr_r} - ${fdt_addr_r}
else
	load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} u-boot.bin
	booti ${kernel_addr_r} - ${fdtcontroladdr}
fi
