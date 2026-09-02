#!/usr/bin/env bash
#
# Build leodec/openfhe-gpu-public.
#
# Key requirement: CMake 3.22.x. Newer CMake (3.27+) fails at configure time
# with "export called with target ... which requires target Thrust/rmm that is
# not in any export set". The project declares cmake_minimum_required(3.18)
# and predates the stricter export checks.
#
# Usage: ./build_openfhe_gpu.sh [-s SRC_DIR] [-a CUDA_ARCH] [-j JOBS] [-c]
#   -s  source directory   (default: ./openfhe-gpu-public)
#   -a  CUDA architecture  (default: autodetected; 75=T4, 80=A100, 86=A10/3090, 89=L4/4090)
#   -j  parallel jobs      (default: nproc)
#   -c  clean: remove the build directory before configuring

set -euo pipefail

SRC="${PWD}/openfhe-gpu-public"
ARCH=""
JOBS="$(nproc)"
CLEAN=0

while getopts ":s:a:j:c" opt; do
    case "$opt" in
        s) SRC="$(readlink -f "$OPTARG")" ;;
        a) ARCH="$OPTARG" ;;
        j) JOBS="$OPTARG" ;;
        c) CLEAN=1 ;;
        \?) echo "unknown option -$OPTARG" >&2; exit 1 ;;
    esac
done

BUILD="$SRC/build"

[ -f "$SRC/CMakeLists.txt" ] || { echo "ERROR: no CMakeLists.txt in $SRC"; exit 1; }

# --- CUDA toolkit -----------------------------------------------------------
CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
[ -x "$CUDA_HOME/bin/nvcc" ] || {
    echo "ERROR: nvcc not found at $CUDA_HOME/bin/nvcc. Set CUDA_HOME."; exit 1;
}
export PATH="$CUDA_HOME/bin:$PATH"
echo "cuda:   $($CUDA_HOME/bin/nvcc --version | tail -1)"

# --- NVIDIA driver library --------------------------------------------------
# ld needs an unversioned libcuda.so to resolve -lcuda. Containers commonly
# bind-mount only libcuda.so.1, so create the dev symlink if it's missing.
# Note: /usr/local/cuda*/compat/ is deliberately excluded -- linking against a
# forward-compat driver older than the running one causes runtime init failures.
DRIVER_DIR=""
for d in /usr/local/nvidia/lib64 /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib; do
    [ -e "$d/libcuda.so.1" ] && { DRIVER_DIR="$d"; break; }
done
[ -n "$DRIVER_DIR" ] || {
    echo "ERROR: libcuda.so.1 not found. Is the NVIDIA driver installed / GPU visible?"
    nvidia-smi || true
    exit 1
}
echo "driver: $DRIVER_DIR"

if [ ! -e "$DRIVER_DIR/libcuda.so" ]; then
    if [ -w "$DRIVER_DIR" ]; then
        ln -sf "$DRIVER_DIR/libcuda.so.1" "$DRIVER_DIR/libcuda.so"
        ldconfig 2>/dev/null || true
    else
        echo "note: no libcuda.so in $DRIVER_DIR and it isn't writable;"
        echo "      relying on LIBRARY_PATH below (run as root if the link fails)"
    fi
fi
export LIBRARY_PATH="$DRIVER_DIR:$CUDA_HOME/lib64:${LIBRARY_PATH:-}"

# --- CMake version ----------------------------------------------------------
CMAKE_BIN="$(command -v cmake || true)"
CMAKE_VER="$($CMAKE_BIN --version 2>/dev/null | head -1 | awk '{print $3}' || echo none)"
case "$CMAKE_VER" in
    3.1[89].*|3.2[0-6].*) : ;;    # in range
    *)
        echo "cmake $CMAKE_VER is out of range; installing 3.22.6 via pip"
        pip install -q "cmake==3.22.6"
        hash -r
        CMAKE_BIN="$(command -v cmake)"
        ;;
esac
echo "cmake:  $($CMAKE_BIN --version | head -1)"

# --- GPU architecture -------------------------------------------------------
if [ -z "$ARCH" ]; then
    ARCH="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null \
            | head -1 | tr -d '.')"
    [ -n "$ARCH" ] || { echo "ERROR: could not detect compute capability; pass -a"; exit 1; }
fi
echo "arch:   sm_$ARCH"

# --- configure + build ------------------------------------------------------
[ "$CLEAN" -eq 1 ] && rm -rf "$BUILD"

"$CMAKE_BIN" -B "$BUILD" -S "$SRC" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="$ARCH"

"$CMAKE_BIN" --build "$BUILD" -j "$JOBS"

echo
echo "done. binaries under $BUILD/bin/"
find "$BUILD/bin" -name "*gpu*" -type f 2>/dev/null || true
