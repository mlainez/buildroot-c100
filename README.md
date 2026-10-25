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
| Python         | Python 3 with NumPy (OpenBLAS), OpenCV, IREE runtime, pip |
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

## Compared with NVIDIA JetPack

NVIDIA's software for the Jetson Nano ends with JetPack 4.6 (L4T R32.7):
Ubuntu 18.04 on a 4.9 kernel, with a proprietary GPU stack built around CUDA.
This system uses no NVIDIA software except the boot firmware on the eMMC and
the GPU and USB controller firmware from linux-firmware, and replaces each
part with open source, mostly on Vulkan:

| JetPack 4.6                                  | This system                                                        |
| -------------------------------------------- | ------------------------------------------------------------------ |
| Ubuntu 18.04, Python 3.6                     | Buildroot 2026.08, Python 3.14                                     |
| L4T kernel 4.9                               | Mainline Linux 6.18                                                |
| cboot, then L4T U-Boot 2020.04 on the eMMC   | Unchanged on the eMMC; mainline U-Boot 2026.07 runs from the card  |
| `nvgpu` driver, proprietary OpenGL ES and Vulkan 1.2 | `nouveau` driver, Mesa OpenGL ES 3.2 and Vulkan 1.3 (NVK)  |
| CUDA 10.2                                    | Vulkan compute, through IREE, ggml and OpenCV `vkstereo`           |
| cuDNN 8.2, TensorRT 8.2                      | IREE: models compiled for the GPU, on the board or a computer, and run with `iree.runtime` |
| CUDA builds of PyTorch and TensorFlow        | PyTorch, JAX, ONNX Runtime and LiteRT from pip on the CPU; PyTorch, JAX and ONNX models compiled for the GPU with IREE |
| No LLM or speech runtime; users built llama.cpp or whisper.cpp against CUDA | llama.cpp and whisper.cpp on Vulkan               |
| OpenCV 4.1.1 on the CPU, VPI 1.2 for GPU stereo | OpenCV 4.13 with `cv2.vkstereo`, a GPU stereo matcher           |
| Ubuntu's NumPy                               | NumPy with OpenBLAS                                                |
| NVENC/NVDEC video codecs, DeepStream, GStreamer plugins | FFmpeg (with x264) on the CPU, also behind `cv2.VideoCapture` |
| CSI cameras through the ISP (libargus)       | CSI cameras (IMX219) through libcamera, its software ISP running on the GPU; USB cameras through V4L2 |
| `nvpmodel`, `jetson_clocks`, `tegrastats`    | Clock limits set in the device tree; `cpufreq` and `devfreq` in sysfs, `htop` |
| Docker and NVIDIA's L4T containers           | Not included                                                       |

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

USB cameras and video files work through `cv2.VideoCapture`.

### CSI cameras

Both camera connectors are set up for Raspberry Pi Camera v2 modules (IMX219).
The Tegra X1's ISP has no open driver, so libcamera processes the raw sensor
frames in its software ISP, on the GPU through OpenGL ES:

```sh
cam -l                                  # list cameras
cam -c 1 --capture=10 --file=frame#.ppm
libcamerify python3 my_opencv_app.py    # V4L2 applications, such as OpenCV
```

The `libcamera` Python module is installed, so `pip install picamera2` gives
the usual Raspberry Pi camera library.

### Python AI frameworks

PyTorch, JAX, ONNX Runtime, LiteRT (TensorFlow Lite) and ExecuTorch install
from pip, and run on the CPU:

```sh
pip install torch --extra-index-url https://download.pytorch.org/whl/cpu
pip install jax onnxruntime ai-edge-litert
```

To run on the GPU, models are compiled with [IREE](https://iree.dev) for
Vulkan, on the board itself, and run with the IREE runtime that this system
includes (with fixes for the Tegra X1). pip leaves that runtime in place.

PyTorch, with `iree-turbine`:

```sh
pip install iree-turbine
```

```python
import iree.runtime as rt
import iree.turbine.aot as aot

exported = aot.export(model, example_input)
exported.session.set_flags("--iree-vulkan-target-features=" + C100_FEATURES)
vmfb = exported.compile(save_to=None, target_backends=["vulkan-spirv"])

config = rt.Config("vulkan")
ctx = rt.SystemContext(config=config)
module = rt.VmModule.copy_buffer(config.vm_instance, vmfb.map_memory())
ctx.add_vm_module(module)
output = ctx.modules[module.name]["main"](example_input.numpy()).to_host()
```

JAX, the NumPy API with compilation, through StableHLO:

```python
import jax, jax.numpy as jnp
import iree.compiler as ireec

def f(a, b):
    return jnp.tanh(a @ b) * jnp.mean(a, axis=0)

mlir = jax.jit(f).lower(a, b).as_text(dialect="stablehlo")
vmfb = ireec.compile_str(mlir, input_type="stablehlo", target_backends=["vulkan-spirv"],
                         extra_args=["--iree-vulkan-target-features=" + C100_FEATURES])
# then load vmfb with iree.runtime as above
```

ONNX models, exported from any framework, compile with
`iree-import-onnx model.onnx -o model.mlir` (`pip install iree-base-compiler[onnx]`)
followed by `iree-compile`. TensorFlow has no wheels for Python 3.14: its
models run with LiteRT after conversion to TFLite, or through ONNX.

`C100_FEATURES` describes what NVK supports on this GPU:

```python
C100_FEATURES = ("spirv:v1.3,cap:Shader,cap:Float16,cap:Int8,cap:Int16,cap:Int64,"
                 "cap:StorageBuffer8BitAccess,cap:StorageBuffer16BitAccess,"
                 "ext:SPV_KHR_8bit_storage,ext:SPV_KHR_16bit_storage,cap:GroupNonUniform,"
                 "cap:GroupNonUniformArithmetic,cap:GroupNonUniformShuffle,cap:GroupNonUniformBallot")
```

### Compiling on a computer

Models can also be compiled ahead of time on a computer, with the same
compiler release (`iree-base-compiler` 3.13.0, matching `package/iree-runtime`):

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
module = rt.VmModule.mmap(config.vm_instance, "model.vmfb")
ctx.add_vm_module(module)
result = ctx.modules[module.name]["main"](input_array).to_host()
```

