Build it with the standard CMake flow from the repo root.

1. Install macOS prerequisites (once):
~~~bash
xcode-select --install
brew install cmake libomp
~~~

2. Configure:
~~~bash
cd /Users/mahdi/Downloads/GitHub/openfhe-development
mkdir -p build
cd build
cmake ..
~~~

3. Compile:
~~~bash
make -j"$(sysctl -n hw.ncpu)"
~~~

4. Optional install:
~~~bash
sudo make install
~~~
If you want a non-system install path:
~~~bash
cmake -DCMAKE_INSTALL_PREFIX="$HOME/.local" ..
make -j"$(sysctl -n hw.ncpu)"
make install
~~~

5. Quick sanity run:
~~~bash
bin/examples/pke/simple-integers
~~~

For this GPU-focused fork, you can also run:
~~~bash
./bin/examples/pke/advanced-ckks-bootstrapping-gpu
~~~

If cmake fails on macOS:
1. Regex backend issue:
~~~bash
cmake -DCMAKE_CROSSCOMPILING=1 -DRUN_HAVE_STD_REGEX=0 -DRUN_HAVE_POSIX_REGEX=0 ..
cmake ..
~~~
2. OpenMP message asking to rerun cmake: just run cmake .. one more time.

Reference docs in this workspace:
- README.md
- macos.rst
- installation.rst

If you want, I can give you a faster/minimal configure line (for example disabling benchmarks/tests) for shorter build time.