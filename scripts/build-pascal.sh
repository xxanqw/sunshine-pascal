#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
source_dir=$PWD
build_dir=$(realpath -m "${BUILD_DIR:-cmake-build-pascal}")
cuda_root=$(realpath -m "${CUDA12_ROOT:-$build_dir/cuda-12.9}")
cuda_host_cxx=${CUDA_HOST_CXX:-g++-14}
cuda_architectures=${CUDA_ARCHITECTURES:-61}

if [[ $(uname -sm) != "Linux x86_64" ]]; then
  echo "This build setup supports Linux x86_64." >&2
  exit 1
fi

if ! cuda_host_cxx=$(command -v "$cuda_host_cxx"); then
  echo "Install GCC 14 or set CUDA_HOST_CXX to a CUDA 12-compatible C++ compiler." >&2
  exit 1
fi

git submodule update --init --depth 1 --jobs 4
# Build Sunshine with the pinned Vulkan headers and Moonlight protocol libraries.
git submodule update --init --recursive --depth 1 --jobs 4 -- third-party/moonlight-common-c
git -C third-party/build-deps submodule update --init --depth 1 -- third-party/FFmpeg/Vulkan-Headers
mkdir -p "$build_dir"

# Install only the compiler, runtime headers/libraries, and CCCL in the build tree.
# Filenames and hashes come from NVIDIA's redistrib_12.9.2.json.
if [[ -z ${CUDA12_ROOT:-} && ! -x "$cuda_root/bin/nvcc" ]]; then
  cuda_stage=$(mktemp -d "$build_dir/cuda-stage.XXXXXX")
  trap 'rm -rf -- "$cuda_stage"' EXIT
  mkdir "$cuda_stage/toolkit"
  while read -r component version hash; do
    archive=${component}-linux-x86_64-${version}-archive.tar.xz
    curl --fail --location --retry 3 --output "$cuda_stage/$archive" \
      "https://developer.download.nvidia.com/compute/cuda/redist/$component/linux-x86_64/$archive"
    printf '%s  %s\n' "$hash" "$cuda_stage/$archive" | sha256sum --check
    tar -xJf "$cuda_stage/$archive" -C "$cuda_stage/toolkit" --strip-components=1
  done <<'CUDA_ARCHIVES'
cuda_nvcc 12.9.86 7a1a5b652e5ef85c82b721d10672fc9a2dbaab44e9bd3c65a69517bf53998c35
cuda_cudart 12.9.79 1f6ad42d4f530b24bfa35894ccf6b7209d2354f59101fd62ec4a6192a184ce99
cuda_cccl 12.9.27 8b1a5095669e94f2f9afd7715533314d418179e9452be61e2fde4c82a3e542aa
CUDA_ARCHIVES

  # Match the declarations in newer glibc headers in our private toolkit.
  glibc_version=$(getconf GNU_LIBC_VERSION | cut -d ' ' -f 2)
  if [[ $(printf '%s\n' 2.41 "$glibc_version" | sort -V | head -n 1) == 2.41 ]]; then
    patch -d "$cuda_stage/toolkit" -p4 -i \
      "$source_dir/packaging/linux/patches/x86_64/cuda-12-math_functions.patch"
  fi
  # CMake also looks in lib64 when detecting the CUDA toolkit.
  ln -s lib "$cuda_stage/toolkit/lib64"
  mv -T "$cuda_stage/toolkit" "$cuda_root"
fi

if [[ ! -x "$cuda_root/bin/nvcc" ]] ||
   ! "$cuda_root/bin/nvcc" --version | grep -Eq 'release 12\.'; then
  echo "CUDA12_ROOT must point to a CUDA 12 toolkit. Pascal kernels require CUDA 12." >&2
  exit 1
fi

BRANCH=main BUILD_VERSION=2026.914.233613 cmake -S "$source_dir" -B "$build_dir" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CUDA_COMPILER="$cuda_root/bin/nvcc" \
  -DCMAKE_CUDA_HOST_COMPILER="$cuda_host_cxx" \
  -DSUNSHINE_CUDA_ARCHITECTURES="$cuda_architectures" \
  -DSUNSHINE_ENABLE_CUDA=ON -DSUNSHINE_ENABLE_X11=ON \
  -DSUNSHINE_ENABLE_TRAY=OFF -DBUILD_DOCS=OFF -DBUILD_TESTS=OFF

cmake --build "$build_dir" --parallel "${JOBS:-4}" --target sunshine web-ui
printf '\nRun from your target X11 or Xwayland session:\n  cd %q\n  ./sunshine\n' "$build_dir"
