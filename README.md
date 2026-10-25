# Buildroot for the OKdo Nano C100

A Buildroot external tree for the [OKdo Nano C100](https://www.okdo.com/), a
carrier board with the NVIDIA Jetson Nano production module (P3448-0002,
Tegra X1). It builds a plain Linux system on a microSD card with the GPU
driven by mainline nouveau and Mesa's NVK Vulkan driver.

| Feature        | Description                                          |
| -------------- | ---------------------------------------------------- |
| Linux kernel   | 6.18 (mainline) with nouveau patches for the GM20B   |
| Bootloader     | U-Boot 2026.07 (mainline), chain-loaded from the card |
| GPU            | OpenGL ES 3.2 and EGL/GBM (Mesa), Vulkan 1.3 (NVK)   |
| Python         | Python 3 with NumPy                                  |
| Console        | UART `ttyS0` (115200 8N1) and HDMI                   |
| Network        | Ethernet over DHCP, SSH (Dropbear)                   |

## Building

This tree targets Buildroot 2026.08.

```sh
git clone https://gitlab.com/buildroot.org/buildroot.git -b 2026.08
make -C buildroot BR2_EXTERNAL=$PWD/buildroot-c100 O=$PWD/buildroot-c100/output okdo_c100_defconfig
make -C buildroot-c100/output
```

The card image is `output/images/sdcard.img`. Write it with
`sudo dd if=output/images/sdcard.img of=/dev/sdX bs=4M conv=fsync`.

## Booting

NVIDIA's boot firmware on the module always starts the U-Boot in the eMMC
`LNX` partition, as shipped by OKdo or installed with
[c100-bootupd](https://github.com/LetsOKdo/c100-bootupd); nothing on the eMMC
is modified. Its distro boot finds `boot.scr` in the card's boot partition,
which starts this system's U-Boot from the same partition. That U-Boot runs
`boot.scr` again, which then loads the kernel and device tree and boots the
ext4 root filesystem. The kernel command line is in `board/okdo_c100/uboot/boot.cmd`.

Log in as `root` on the serial console; there is no password. For SSH, set a
root password or add a key to `/root/.ssh/authorized_keys`.

## GPU

NVK only exposes the GM20B when `NVK_I_WANT_A_BROKEN_VULKAN_DRIVER=1` is set;
`/etc/profile.d/nvk.sh` sets it for login shells. `vulkaninfo --summary`
checks Vulkan; `kmscube` checks OpenGL ES on HDMI.

The CPU runs up to 1479 MHz and the GPU between 76.8 and 921.6 MHz (devfreq),
the module's validated maxima; the DRAM runs at 1600 MHz.
