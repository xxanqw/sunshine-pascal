# Sunshine Pascal

Sunshine game-streaming host with a Linux x86_64 build setup for NVIDIA Pascal GPUs. The source is based on Sunshine v2026.914.233613, the latest stable release as of November 25, 2026. [Upstream release](https://github.com/SunshineStream/Sunshine/releases/tag/v2026.914.233613) · [Upstream README](README.upstream.md)

CUDA 13 dropped offline compilation for Pascal. Sunshine uses CUDA kernels for pixel conversion on its X11 NVENC path, so a newer-toolkit build can fail with `cudaErrorNoKernelImageForDevice` even when the driver still supports NVENC. This build uses CUDA 12 and targets compute capability 6.1 by default, including the GeForce GTX 1060. [CUDA 13 release notes](https://docs.nvidia.com/cuda/archive/13.0.0/cuda-toolkit-release-notes/index.html) · [Sunshine issue #5725](https://github.com/SunshineStream/Sunshine/issues/5725) · [NVIDIA's legacy GPU list](https://developer.nvidia.com/cuda-legacy-gpus)

## Build

Install Sunshine's Linux build dependencies, including a C++23 host compiler, GCC 14 for CUDA, CMake 3.24 or later, Ninja, Node.js 22.12 or later, npm, Git, curl, xz, and patch. Use an NVIDIA proprietary driver that supports your card. See [upstream Linux dependency installation](docs/building.md#linux) and skip any CUDA 13 installation.

On Arch Linux, install the following packages on an up-to-date system. Install `gcc14` and `gcc14-libs` if your package mirror has them. The [Arch Linux Archive](https://archive.archlinux.org/packages/g/gcc14/) also provides the signed GCC 14 packages, or you can set `CUDA_HOST_CXX` to another CUDA 12-compatible compiler.

```sh
sudo pacman -S --needed base-devel cmake ninja git curl xz patch \
  nodejs npm python-jinja avahi libcap libdrm libevdev libpulse libva \
  libx11 libxcb libxfixes libxrandr libxtst libxi mesa miniupnpc \
  numactl openssl opus pipewire shaderc systemd vulkan-icd-loader wayland
```

```sh
git clone https://github.com/xxanqw/sunshine-pascal.git
cd sunshine-pascal
./scripts/build-pascal.sh
```

The script initializes the pinned build submodules, downloads and verifies the NVIDIA CUDA 12.9 build components, and builds Sunshine and its web UI. It runs without root and keeps its CUDA toolkit and output in `cmake-build-pascal/`. The upstream workflow files are preserved under `.github/upstream-workflows/`.

| Optional environment variable | Purpose |
| --- | --- |
| `CUDA12_ROOT` | Use an existing CUDA 12 toolkit. |
| `CUDA_HOST_CXX` | Select the CUDA host C++ compiler. Defaults to `g++-14`. |
| `CUDA_ARCHITECTURES` | Set the CUDA architecture list, such as `61` or `60;61;62`. Check NVENC support on your exact GPU. |
| `BUILD_DIR` | Select another build directory. Use a fresh directory when changing compilers. |
| `JOBS` | Set parallel build jobs. Defaults to four. |

## Run and verify

Run from the desktop session you want to capture. The default build uses its own assets in the build directory.

```sh
cd cmake-build-pascal
./sunshine
```

To verify the X11 or Xwayland capture path, set `capture = x11` and `encoder = nvenc` in the Sunshine configuration. If you're targeting Xwayland from a Wayland session, launch with `env -u WAYLAND_DISPLAY ./sunshine` and set `DISPLAY` to the target Xwayland display. The log should show the encoders available for the selected GPU and display.

```text
Found H.264 encoder: h264_nvenc [nvenc]
Found HEVC encoder: hevc_nvenc [nvenc]
```

If another Sunshine instance is already running, use a separate configuration and port for the test. [Upstream configuration docs](https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2configuration.html)

## Source and license

This independent modification was made on November 25, 2026. It adds a CUDA architecture override and build script, and backports build compatibility fixes for [OpenSSL 4.1](https://github.com/SunshineStream/Sunshine/commit/dac66dfdd200c5f1bb4b31b4e34227690ca8c565) and [Boost.Locale on CMake 4.5](https://github.com/boostorg/locale/commit/1d070743d98469809a92c5bb3fca4720bd2bd782). Sunshine source is available under [GPL-3.0](LICENSE). See [NOTICE](NOTICE) for attribution and third-party information.
