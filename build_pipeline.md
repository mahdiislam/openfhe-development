Created CODEBASE_OVERVIEW.md at the repository root. Here is a summary of what it covers:

**Structure of the document (15 sections):**

1. **What the project does** — OpenFHE is an FHE library supporting three worlds: integer arithmetic (BFV/BGV), real-number arithmetic (CKKS), and Boolean circuits (FHEW/TFHE).

2. **Repository layout** — annotated directory tree.

3. **Layer architecture** — ASCII diagram showing the user API → `CryptoContextImpl` → per-scheme dispatch → `core` ring elements.

4. **`core` module** — explains the three math backends (2/4/6 + native), the HAL abstraction for DCRTPoly, lattice types (`Poly`, `NativePoly`, `DCRTPoly`), random distribution samplers, and utility helpers.

5. **`pke` module** — the largest section; covers `CryptoContextImpl`, the feature-flag model, plaintext encoding, each scheme (BFVrns, BGVrns, CKKSrns with bootstrapping), BV vs Hybrid key switching, PRE, Threshold/Multiparty FHE, Scheme Switching (CKKS↔FHEW), and serialization.

6. **`binfhe` module** — LWE primitives, the three bootstrapping methods (DM, CGGI/TFHE, LMKCDEY), and supported gate families.

7. **Key data types** — table of all major types with their locations.

8. **Build system** — CMake options table and output directory layout.

9. **Third-party dependencies** — Cereal, Google Test/Benchmark, tcmalloc, NTL/GMP, HEXL.

10. **Tests, benchmarks, examples** — what's in each.

11–13. **Three step-by-step data-flow walkthroughs** — BFV integer arithmetic, CKKS real-number arithmetic, and BinFHE boolean gates.

14. **GPU extension** — what this fork adds and where it hooks in.

15. **Security considerations** — RLWE security, noise flooding modes, CKKS approximate decryption caveats, `CKKS_M_FACTOR`.


The build pipeline is CMake-driven and is organized as a staged dependency chain, not a single flat compile. The top-level logic in CMakeLists.txt configures the environment first, then builds the three library layers in order: core, binfhe, and pke.

At a high level, the flow is:

- Configure in a separate build directory with CMake.
- CMake detects compiler support, native integer width, math backend, OpenMP, and optional features like NTL or tcmalloc.
- Core is built first as an object library, then packaged as `OPENFHEcore` or `OPENFHEcore_static`.
- BinFHE is built next on top of core, producing `OPENFHEbinfhe`.
- PKE is built last on top of core and binfhe, producing `OPENFHEpke`.
- Examples, unit tests, and benchmarks are generated as separate executables if the corresponding build flags are enabled.

The important implementation detail is that each module has its own CMakeLists.txt and its own target graph. For example, CMakeLists.txt compiles all core math and lattice sources into an object target first, then wraps that into the final shared or static library. CMakeLists.txt and CMakeLists.txt do the same, but link against the libraries below them. That is how OpenFHE enforces the layering: PKE depends on core and binfhe, binfhe depends on core, and core is the foundation.

The pipeline also branches into build products by type:

- Libraries go into the build tree under `lib/`.
- Examples go into `bin/examples/...`.
- Benchmarks go into `bin/benchmark/`.
- Unit tests go into `unittest/`.

Installation is a separate final stage. `make install` exports headers to `include/openfhe/...`, libraries to `lib/`, and CMake package files for downstream applications. The build docs and flags are described in cmake_in_openfhe.rst.
