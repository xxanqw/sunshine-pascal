# Sunshine on NVIDIA Pascal

Build Sunshine with NVENC support for NVIDIA Pascal GPUs on Linux. This guide covers the latest stable Sunshine release as of November 25, 2026, `v2026.914.233613`. [Upstream release](https://github.com/SunshineStream/Sunshine/releases/tag/v2026.914.233613)

## Why the stock build can fall back to software

Sunshine's X11 capture path uses CUDA to convert captured frames to NV12 before NVENC encodes them. CUDA 13 ended offline compilation for Pascal, so a build using that toolkit can fail conversion with `cudaErrorNoKernelImageForDevice` on a Pascal card. CUDA 12 can build the converter for Pascal. [Sunshine issue #5725](https://github.com/SunshineStream/Sunshine/issues/5725) · [NVIDIA CUDA 13 release notes](https://docs.nvidia.com/cuda/archive/13.0.0/cuda-toolkit-release-notes/index.html)

Some FFmpeg builds require a newer NVENC API than NVIDIA's 580 driver exposes. The build below uses the FFmpeg libraries pinned by Sunshine. [FFmpeg compatibility report](https://github.com/CachyOS/distribution/issues/542) · [Sunshine's FFmpeg build configuration](https://github.com/SunshineStream/Sunshine/blob/v2026.914.233613/cmake/dependencies/ffmpeg.cmake)

## Build for Pascal

Install Sunshine's Linux build dependencies, CUDA Toolkit 12.9, and a compatible host compiler such as GCC 14. Set the paths below to the CUDA and GCC installations on your system. The example uses the matching web and shader assets from an existing Sunshine installation at `/usr/share/sunshine`. [Upstream build instructions](https://github.com/SunshineStream/Sunshine/blob/v2026.914.233613/docs/building.md#linux) · [NVIDIA CUDA 12.9 downloads](https://developer.nvidia.com/cuda-12-9-2-download-archive)

```sh
git clone --branch v2026.914.233613 --recurse-submodules \
  https://github.com/SunshineStream/Sunshine.git
cd Sunshine

# Target the GTX 1060 and other CUDA-capable cards with compute capability 6.1.
cat > pascal-target.cmake <<'EOF'
cmake_language(DEFER CALL set_property TARGET sunshine PROPERTY CUDA_ARCHITECTURES 61)
EOF

CUDA12_ROOT=/usr/local/cuda-12.9
CUDA_HOST_CXX=/usr/bin/g++-14

cmake -S . -B cmake-build-pascal -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CUDA_COMPILER="$CUDA12_ROOT/bin/nvcc" \
  -DCMAKE_CUDA_HOST_COMPILER="$CUDA_HOST_CXX" \
  -DCMAKE_PROJECT_Sunshine_INCLUDE="$PWD/pascal-target.cmake" \
  -DSUNSHINE_ENABLE_CUDA=ON \
  -DSUNSHINE_ASSETS_DIR=/usr/share/sunshine \
  -DBUILD_DOCS=OFF -DBUILD_TESTS=OFF

cmake --build cmake-build-pascal --target sunshine
```

- Use the compute capability of your exact GPU when choosing the architecture value. [NVIDIA's legacy CUDA GPU list](https://developer.nvidia.com/cuda-legacy-gpus)
- On Arch, newer glibc can require the upstream CUDA 12 math-header patch. Apply it to the local CUDA 12 toolkit if nvcc reports mismatched exception specifications for `sinpi`, `cospi`, or `rsqrt`. [Sunshine's CUDA 12 patch](https://github.com/SunshineStream/Sunshine/blob/v2026.914.233613/packaging/linux/patches/x86_64/cuda-12-math_functions.patch)
- Rolling distributions with OpenSSL 4.1 or CMake 4.5 may need upstream compatibility fixes. [OpenSSL fix](https://github.com/SunshineStream/Sunshine/commit/dac66dfdd200c5f1bb4b31b4e34227690ca8c565) · [Boost.Locale CMake fixes](https://github.com/boostorg/locale/commit/1d070743d98469809a92c5bb3fca4720bd2bd782)

## Verify NVENC

Run the build from the X11 or Xwayland session you intend to capture. Use a separate local test configuration and port if Sunshine is already running. Set `capture = x11` and `encoder = nvenc`, then confirm the startup log reports an NVENC encoder for the intended display.

```text
Found H.264 encoder: h264_nvenc [nvenc]
Found HEVC encoder: hevc_nvenc [nvenc]
```

Sunshine is developed by the upstream Sunshine project and licensed under GPL-3.0. [Source and license](https://github.com/SunshineStream/Sunshine/tree/v2026.914.233613)
