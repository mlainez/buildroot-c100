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
| Python         | Python 3 with NumPy (OpenBLAS), OpenCV, IREE runtime |
| AI             | llama.cpp, whisper.cpp and IREE on Vulkan           |
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

Log in as `root` on the serial console, or on HDMI/DP with a USB keyboard;
there is no password. For SSH, set a root password with `passwd` or add a key
to `/root/.ssh/authorized_keys`.

On the first boot the root partition grows to the end of the card, so models
can be stored on it.

## GPU

NVK only exposes the GM20B when `NVK_I_WANT_A_BROKEN_VULKAN_DRIVER=1` is set;
`/etc/profile.d/nvk.sh` sets it for login shells. `vulkaninfo --summary`
checks Vulkan; `kmscube` checks OpenGL ES on HDMI.

The CPU runs up to 1479 MHz and the GPU between 76.8 and 921.6 MHz (devfreq),
the module's validated maxima; the DRAM runs at 1600 MHz.

## Using the GPU

Models are not included; download them with `curl`. The examples assume a
login shell, where `NVK_I_WANT_A_BROKEN_VULKAN_DRIVER` is set.

### LLMs with llama.cpp

```sh
curl -LO https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf
llama-cli -m tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf -ngl 99
llama-server -m tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf -ngl 99 --host 0.0.0.0
```

`-ngl 99` puts every layer on the GPU (TinyLlama: about 4.5 tokens/s).

### Speech to text with whisper.cpp

```sh
curl -LO https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin
arecord -f S16_LE -r 16000 -c 1 -d 10 speech.wav   # USB microphone
whisper-cli -m ggml-tiny.en.bin -f speech.wav
```

The first run of each model compiles the GPU shaders, which takes about half
a minute; Mesa caches them in `~/.cache`.

### Stereo depth with OpenCV

`cv2.vkstereo` is OpenCV with a semi-global stereo matcher running on the GPU
(43 FPS at 640x480, against 14 FPS for `cv2.StereoSGBM` on the CPU):

```python
import cv2
matcher = cv2.vkstereo.StereoSGM.create(64, 8, 64, 0.95)
disparity = matcher.compute(left_gray, right_gray)  # float32, -1 where rejected
```

USB cameras work through `cv2.VideoCapture`.

### Arrays and ML models with NumPy and IREE

NumPy runs on the CPU with OpenBLAS. For the GPU, models and array functions
are compiled ahead of time on a computer with the
[IREE compiler](https://iree.dev) (from JAX, PyTorch, ONNX or TFLite), then run
on the board with the `iree.runtime` Python package, which takes and returns
NumPy arrays:

```sh
iree-compile model.mlir -o model.vmfb --iree-hal-target-backends=vulkan-spirv \
  --iree-vulkan-target-features=spirv:v1.3,cap:Shader,cap:Float16,cap:Int8,cap:Int16,cap:Int64,cap:StorageBuffer8BitAccess,cap:StorageBuffer16BitAccess,ext:SPV_KHR_8bit_storage,ext:SPV_KHR_16bit_storage,cap:GroupNonUniform,cap:GroupNonUniformArithmetic,cap:GroupNonUniformShuffle,cap:GroupNonUniformBallot
```

```python
import iree.runtime as rt
config = rt.Config("vulkan")
ctx = rt.SystemContext(config=config)
ctx.add_vm_module(rt.VmModule.mmap(config.vm_instance, "model.vmfb"))
result = ctx.modules.module["main"](input_array).to_host()
```

The compiler must match the runtime's IREE revision (`package/iree-runtime`).

