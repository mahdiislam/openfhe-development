#!/usr/bin/env bash
#
# details_build.sh — build and install leodec/openfhe-gpu-public.
#
# Two workarounds are baked in, both discovered the hard way:
#
#   1. CMake must be 3.22.x. Newer CMake (3.27+) fails at configure time with
#      "export called with target ... which requires target Thrust/rmm that is
#      not in any export set". The project declares cmake_minimum_required(3.18)
#      and predates the stricter export checks.
#
#   2. Thrust/RMM include dirs do not propagate from the project's CMake to all
#      targets, so they are supplied via CPATH below.
#
# Usage: ./details_build.sh [-s SRC_DIR] [-p PREFIX] [-a CUDA_ARCH] [-j JOBS] [-t TARGET] [-c]
#   -s  source directory   (default: ./openfhe-gpu-public)
#   -p  install prefix     (default: $HOME/openfhe-install)
#   -a  CUDA architecture  (default: autodetected; 75=T4, 80=A100, 86=A10/3090, 89=L4/4090)
#   -j  parallel jobs      (default: nproc)
#   -t  build only this target (repeatable); default builds everything
#   -c  clean: remove the build directory before configuring

set -euo pipefail

SRC="${PWD}/openfhe-gpu-public"
PREFIX="${HOME}/openfhe-install"
ARCH=""
JOBS="$(nproc)"
CLEAN=0
TARGETS=()

while getopts ":s:p:a:j:t:c" opt; do
    case "$opt" in
        s) SRC="$(readlink -f "$OPTARG")" ;;
        p) PREFIX="$(readlink -f "$OPTARG")" ;;
        a) ARCH="$OPTARG" ;;
        j) JOBS="$OPTARG" ;;
        t) TARGETS+=("$OPTARG") ;;
        c) CLEAN=1 ;;
        \?) echo "unknown option -$OPTARG" >&2; exit 1 ;;
    esac
done

BUILD="$SRC/build"

[ -f "$SRC/CMakeLists.txt" ] || { echo "ERROR: no CMakeLists.txt in $SRC"; exit 1; }

# --- CUDA toolkit -----------------------------------------------------------
# Prefer $CUDA_HOME, then /usr/local/cuda, then the newest /usr/local/cuda-*.
if [ -z "${CUDA_HOME:-}" ]; then
    if [ -x /usr/local/cuda/bin/nvcc ]; then
        CUDA_HOME=/usr/local/cuda
    else
        CUDA_HOME="$(ls -d /usr/local/cuda-* 2>/dev/null | sort -V | tail -1 || true)"
    fi
fi
[ -n "$CUDA_HOME" ] && [ -x "$CUDA_HOME/bin/nvcc" ] || {
    echo "ERROR: nvcc not found. Set CUDA_HOME to your CUDA toolkit."; exit 1;
}
export PATH="$CUDA_HOME/bin:$PATH"
echo "cuda:   $CUDA_HOME  ($($CUDA_HOME/bin/nvcc --version | tail -1))"

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

# --- include paths ----------------------------------------------------------
# Thrust ships with the toolkit; CUDA 13 moved it under include/cccl.
export CPATH="$CUDA_HOME/include:${CPATH:-}"
[ -d "$CUDA_HOME/include/cccl" ] && export CPATH="$CUDA_HOME/include/cccl:$CPATH"

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
echo "prefix: $PREFIX"

# --- configure --------------------------------------------------------------
[ "$CLEAN" -eq 1 ] && rm -rf "$BUILD"

"$CMAKE_BIN" -B "$BUILD" -S "$SRC" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="$ARCH" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX"

# RMM headers land in the build tree, so this must come after configure.
[ -d "$BUILD/_deps/rmm-src/include" ] && export CPATH="$BUILD/_deps/rmm-src/include:$CPATH"
echo "cpath:  $CPATH"

# --- build ------------------------------------------------------------------
if [ "${#TARGETS[@]}" -gt 0 ]; then
    for t in "${TARGETS[@]}"; do
        echo "building target: $t"
        "$CMAKE_BIN" --build "$BUILD" -j "$JOBS" --target "$t"
    done
else
    "$CMAKE_BIN" --build "$BUILD" -j "$JOBS"
fi

# --- install ----------------------------------------------------------------
"$CMAKE_BIN" --install "$BUILD"

echo
echo "installed to $PREFIX"
ls "$PREFIX/lib" 2>/dev/null || true
echo
echo "example binaries stay in the build tree (not installed):"
find "$BUILD/bin" -name "*gpu*" -type f 2>/dev/null || true
echo
echo "to use the installed library:"
echo "  cmake -DOpenFHE_DIR=$PREFIX/lib/OpenFHE .."
echo "  export LD_LIBRARY_PATH=$PREFIX/lib:\$LD_LIBRARY_PATH"
