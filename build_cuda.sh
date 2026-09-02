set -e

echo "Installing CMake 3.22.6 (newer CMake fails on the Thrust/rmm export set)"
pip install -q cmake==3.22.6
hash -r
cmake --version | head -1

echo "Creating libcuda.so symlink for -lcuda"
ln -sf /usr/local/nvidia/lib64/libcuda.so.1 /usr/lib/x86_64-linux-gnu/libcuda.so
ldconfig 2>/dev/null || true
export LIBRARY_PATH=/usr/local/nvidia/lib64:$LIBRARY_PATH

echo "Removing previous build folder"
rm -rf build/
mkdir build && cd build
echo $PWD

echo "Starting new build"
cmake -DCMAKE_CROSSCOMPILING=1 -DRUN_HAVE_STD_REGEX=0 -DRUN_HAVE_POSIX_REGEX=0 -DCMAKE_CUDA_ARCHITECTURES=75 -DCMAKE_INSTALL_PREFIX=$HOME/openfhe-install ..
make -j8
make install
