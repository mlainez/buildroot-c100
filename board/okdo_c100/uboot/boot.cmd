# Installed as boot.scr in the microSD card's boot partition next to this
# system's u-boot.bin. The U-Boot in the eMMC LNX partition (for example
# OKdo's) runs this script through distro boot, and it starts this system's
# U-Boot, which boots the card through extlinux.conf.

load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} u-boot.bin
booti ${kernel_addr_r} - ${fdtcontroladdr}
