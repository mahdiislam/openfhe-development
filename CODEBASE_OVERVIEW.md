# OpenFHE Codebase Overview

> Version 1.2.1 — this is the **openfhe-gpu-public** fork, which adds GPU-accelerated bootstrapping on top of the upstream OpenFHE library.

---

## Table of Contents

1. [What the project does](#1-what-the-project-does)
2. [Repository layout](#2-repository-layout)
3. [Layer architecture](#3-layer-architecture)
4. [Module: `core`](#4-module-core)
   - 4.1 Math backends
   - 4.2 Hardware Abstraction Layer (HAL)
   - 4.3 Lattice algebra
   - 4.4 Random distributions
   - 4.5 Utilities
5. [Module: `pke`](#5-module-pke)
   - 5.1 CryptoContext and the scheme-feature model
   - 5.2 Plaintext encoding
   - 5.3 BFVrns scheme
   - 5.4 BGVrns scheme
   - 5.5 CKKSrns scheme
   - 5.6 Key switching (BV and Hybrid)
   - 5.7 Proxy Re-Encryption (PRE)
   - 5.8 Threshold / Multiparty FHE
   - 5.9 Scheme Switching (CKKS ↔ FHEW/TFHE)
   - 5.10 Serialization
6. [Module: `binfhe`](#6-module-binfhe)
   - 6.1 LWE primitives
   - 6.2 Ring GSW (RGSW) and bootstrapping
   - 6.3 Supported gate families
7. [Key data types](#7-key-data-types)
8. [Build system](#8-build-system)
9. [Third-party dependencies](#9-third-party-dependencies)
10. [Tests, benchmarks, and examples](#10-tests-benchmarks-and-examples)
11. [Data-flow walkthrough: BFV integer example](#11-data-flow-walkthrough-bfv-integer-example)
12. [Data-flow walkthrough: CKKS real-number example](#12-data-flow-walkthrough-ckks-real-number-example)
13. [Data-flow walkthrough: Boolean gate example (BinFHE)](#13-data-flow-walkthrough-boolean-gate-example-binfhe)
14. [GPU extension (this fork)](#14-gpu-extension-this-fork)
15. [Security considerations](#15-security-considerations)

---

## 1. What the project does

OpenFHE is a C++17 library for **Fully Homomorphic Encryption (FHE)** — a family of cryptographic techniques that allow arbitrary computations to be performed directly on encrypted data, without ever decrypting it. The output, when decrypted, is identical to what would have been obtained by running the same computation on the plaintext.

The library provides three independent but interoperable FHE "worlds":

| World | Schemes | Plaintext space | Key feature |
|-------|---------|----------------|-------------|
| **Integer arithmetic** | BFVrns, BGVrns | Packed integer vectors (mod `t`) | Exact arithmetic, no accumulated noise |
| **Real-number arithmetic** | CKKSrns | Packed complex/real vectors | Approximate; supports deep circuits via bootstrapping |
| **Boolean / small plaintext** | FHEW/TFHE (DM, CGGI, LMKCDEY) | Single bits or small integers | Ultra-fast bootstrapping for arbitrary functions |

On top of these, the library supports **Threshold FHE** (secret-shared keys across multiple parties), **Proxy Re-Encryption**, and **Scheme Switching** between CKKS and FHEW/TFHE.

---

## 2. Repository layout

```
openfhe-development/
├── CMakeLists.txt            # Top-level build configuration
├── CMakeLists.User.txt       # Template for downstream applications
├── src/
│   ├── core/                 # Math/lattice foundation (no crypto logic)
│   │   ├── include/
│   │   │   ├── math/         # Big integers, polynomial transforms, distributions
│   │   │   ├── lattice/      # Polynomial ring elements (Poly, DCRTPoly)
│   │   │   └── utils/        # Serialization, memory, parallelism helpers
│   │   └── lib/              # Implementations
│   ├── pke/                  # Public-key FHE schemes (BGV, BFV, CKKS)
│   │   ├── include/
│   │   │   ├── scheme/       # Per-scheme headers (bfvrns/, bgvrns/, ckksrns/)
│   │   │   ├── schemebase/   # Abstract base classes for every crypto operation
│   │   │   ├── schemerns/    # RNS-specific shared implementations
│   │   │   ├── keyswitch/    # BV and Hybrid key-switching
│   │   │   ├── key/          # PublicKey, PrivateKey, EvalKey types
│   │   │   ├── encoding/     # Plaintext encoding/decoding
│   │   │   └── cryptocontext.h  # Main user-facing API entry point
│   │   ├── lib/              # Implementations
│   │   └── examples/         # Runnable demo programs
│   └── binfhe/               # Boolean/TFHE FHE schemes
│       ├── include/          # LWE + RGSW + bootstrapping headers
│       ├── lib/              # Implementations
│       └── examples/         # Boolean gate demos
├── benchmark/                # Google Benchmark programs
├── test/                     # Google Test harness (Main_TestAll.cpp)
├── third-party/
│   ├── cereal/               # Header-only serialization library
│   ├── google-benchmark/
│   ├── google-test/
│   └── gperftools/           # tcmalloc (optional)
└── docs/                     # Sphinx + RST documentation
```

---

## 3. Layer architecture

```
┌──────────────────────────────────────────────────────────┐
│              User application / examples                 │
│         (include openfhe.h or binfhecontext.h)           │
└──────────┬───────────────────────────────────────────────┘
           │  GenCryptoContext() / BinFHEContext()
┌──────────▼───────────────────────────────────────────────┐
│                  CryptoContextImpl<DCRTPoly>              │
│         pke module – scheme-agnostic API surface         │
│  KeyGen · Encrypt · EvalAdd · EvalMult · EvalRotate      │
│  EvalBootstrap · MultiPartyDecrypt · EvalSchemeSwitching │
└──────────┬───────────────────────────────────────────────┘
           │  virtual dispatch via SchemeBase<DCRTPoly>
┌──────────▼─────────────────────────────────────────────────────────────────┐
│  Per-scheme implementations  (all in pke/lib/scheme/)                      │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────────────────┐   │
│  │  BFVrns     │  │  BGVrns     │  │  CKKSrns                         │   │
│  │  -pke       │  │  -pke       │  │  -pke / -leveledshe / -fhe       │   │
│  │  -leveledshe│  │  -leveledshe│  │  -advancedshe / -multiparty      │   │
│  │  -multiparty│  │  -multiparty│  │  -schemeswitching                │   │
│  └─────────────┘  └─────────────┘  └──────────────────────────────────┘   │
└──────────┬─────────────────────────────────────────────────────────────────┘
           │  operates on ring elements
┌──────────▼───────────────────────────────────────────────┐
│                  core module                             │
│  DCRTPoly  (Doubly-CRT polynomial)                       │
│  Poly (single-modulus polynomial)                        │
│  NTT / FFT transforms                                    │
│  Big-integer arithmetic (backends 2, 4, 6 / native)      │
└──────────────────────────────────────────────────────────┘
```

---

## 4. Module: `core`

The `core` library contains no cryptographic logic. It is purely mathematical infrastructure.

### 4.1 Math backends

Three selectable "backends" implement big-integer arithmetic and polynomial-vector operations:

| Backend | CMake flag | Type alias | Description |
|---------|-----------|------------|-------------|
| **Backend 2** (default) | `WITH_BE2=ON` | `BigInteger` (fixed-size) | Fixed-width multi-limb integers; fast for typical parameter sizes |
| **Backend 4** | `WITH_BE4=ON` | `BigInteger` (dynamic) | Variable-length integers; handles larger moduli |
| **Backend 6** | `WITH_NTL=ON` | `NTL::ZZ` | Uses external NTL/GMP libraries for arbitrary precision |
| **Native** | always present | `uint64_t` / `uint128_t` | Single machine-word modular arithmetic used in RNS (most operations) |

The active backend is selected at compile time via `src/core/include/math/hal/math-hal.h` which includes the appropriate backend header.

`basicint.h` selects the native integer width (`NATIVEINT` = 32, 64, or 128 bits) and defines `BasicInteger`, `DoubleNativeInt`, `uint128_t`, and `MAX_MODULUS_SIZE`.

### 4.2 Hardware Abstraction Layer (HAL)

Located in `src/core/include/lattice/hal/` and `src/core/include/math/hal/`.

The lattice HAL defines `DCRTPolyInterface<>` — an abstract base class for all polynomial ring element operations. The default backend (`lattice/hal/default/`) provides a CPU implementation. The architecture allows plugging in accelerated backends (e.g., Intel HEXL for AVX-512 NTT acceleration) by providing a new class that inherits `DCRTPolyInterface`.

The current GPU fork uses CUDA kernels that are hooked in below this layer for bootstrapping operations.

### 4.3 Lattice algebra

The core ring type is **`DCRTPoly`** (Doubly-CRT Polynomial), defined under `src/core/include/lattice/hal/default/`. This is the ring element used by all PKE scheme operations.

- **`Poly`** — A single-modulus polynomial in $\mathbb{Z}_q[x]/(x^N + 1)$. Used for intermediate computations and as a building block.
- **`NativePoly`** — A `Poly` with a native-integer coefficient type; used in RNS decompositions.
- **`DCRTPoly`** — A vector of `NativePoly` objects, one per prime in the RNS chain. This is the main ciphertext element type. The RNS representation allows all per-limb arithmetic to stay within `uint64_t`, making it very fast.

The lattice module also provides:
- Trapdoor sampling (`trapdoor.h`) — for lattice-based sampling algorithms
- Field2n (`field2n.h`) — for field arithmetic over degree-$2^n$ extensions
- `stdlatticeparms.h` — lookup tables for the HE Standard parameter sets (STD128, STD192, STD256)

### 4.4 Random distributions

`src/core/include/math/` houses samplers for the noise distributions required by lattice crypto:

| File | Distribution | Used for |
|------|-------------|----------|
| `discretegaussiangenerator.h` | Discrete Gaussian $\mathcal{D}_{\sigma}$ | LWE / RLWE error terms |
| `ternaryuniformgenerator.h` | Ternary uniform $\{-1, 0, 1\}$ | Secret key polynomials |
| `binaryuniformgenerator.h` | Binary uniform $\{0, 1\}$ | Some secret key modes |
| `discreteuniformgenerator.h` | Uniform mod $q$ | Public randomness |
| `discretegaussiangeneratorgeneric.h` | Generic Gaussian sampler | Higher-precision sampling |

All samplers inherit from `DistributionGenerator` and operate in a thread-safe manner (supporting OpenMP parallel evaluation).

### 4.5 Utilities

- `serial.h` / `serializable.h` — Cereal-based JSON and binary serialization for all library objects
- `parallel.h` — OpenMP wrappers (`ParallelFor`, `ParallelReduce`, etc.)
- `exception.h` — `OPENFHE_THROW` macro
- `prng/` — ChaCha20-based PRNG for reproducible random generation
- `memory.h` / `blockAllocator/` — custom allocators for performance

---

## 5. Module: `pke`

This is the largest module and provides the user-facing API for all public-key FHE operations. The central entry point is `src/pke/include/openfhe.h`.

### 5.1 CryptoContext and the scheme-feature model

**`CryptoContextImpl<DCRTPoly>`** (typedef'd as `CryptoContext<DCRTPoly>`) is the single object through which all operations are accessed. It is created via `GenCryptoContext(params)` and holds:

- A `SchemeBase<DCRTPoly>` pointer (the actual scheme implementation)
- The cryptographic parameters (`RLWECryptoParams`)
- A registry of evaluation keys (`EvalMultKey`, rotation keys, etc.)

Before use, individual feature modules must be explicitly enabled:

```cpp
cc->Enable(PKE);          // key generation, encrypt, decrypt
cc->Enable(KEYSWITCH);    // key-switching infrastructure
cc->Enable(LEVELEDSHE);   // add, multiply, rotate, rescale
cc->Enable(ADVANCEDSHE);  // inner product, linear weighted sum
cc->Enable(MULTIPARTY);   // threshold FHE
cc->Enable(FHE);          // bootstrapping
cc->Enable(SCHEMESWITCH);  // CKKS ↔ FHEW switching
```

This feature-flag model (bitmask `PKESchemeFeature`) allows the compiler to omit unused virtual dispatch paths and clearly documents which capabilities are active.

**`CryptoContextFactory<DCRTPoly>`** maintains a global registry of all live contexts, enabling operations across different contexts to be validated.

### 5.2 Plaintext encoding

Before encryption, data must be encoded into polynomial ring elements. The `encoding/` subdirectory provides:

| Encoding | Type | Used by |
|----------|------|---------|
| `PackedEncoding` | Integer SIMD packing via CRT/NTT | BFVrns, BGVrns |
| `CoefPackedEncoding` | Coefficients of a polynomial | Simple integer embedding |
| `CKKSPackedEncoding` | Complex/real values scaled and packed via FFT | CKKSrns |
| `StringEncoding` | ASCII text mapped to integers | Demos only |

`PlaintextFactory::MakePlaintext()` dispatches to the correct encoding class based on the active scheme.

### 5.3 BFVrns scheme

**Files:** `src/pke/include/scheme/bfvrns/`

BFV (Brakerski–Fan–Vercauteren) provides **exact** integer arithmetic modulo a plaintext modulus `t`. Ciphertexts live in $\mathbb{Z}_q^N$ (RNS form).

Key operations:
- **Encryption:** $ct = (b + \Delta m + e,\ a)$ where $\Delta = q/t$, $e$ is Gaussian noise
- **EvalAdd:** coefficient-wise addition mod $q$
- **EvalMult:** tensored polynomial multiplication followed by relinearization (key switching)
- **Rescaling:** BFVrns does not use CKKS-style rescaling; instead uses the HPS or BEHZ multiplication method for noise management

Three multiplication variants are supported:
- `BEHZ` (Bajard–Eynard–Hasan–Zucca)
- `HPS` (Harvey–Peikert–Shoup)
- `HPSPOVERQ` / `HPSPOVERQLEVELED` (leveled variants)

The choice is controlled by `CCParams<CryptoContextBFVRNS>::SetMultiplicationTechnique()`.

### 5.4 BGVrns scheme

**Files:** `src/pke/include/scheme/bgvrns/`

BGV (Brakerski–Gentry–Vaikuntanathan) is similar to BFV but uses a **modulus-switching** (rather than scaling) strategy for noise management. After each multiplication, the ciphertext modulus `q` is reduced by one RNS prime (one "level" is consumed). This makes BGV ideal for circuits with a known depth where precision is critical.

Distinctive features compared to BFV:
- Plaintext is in the "top" of the modulus chain; no $\Delta$ scaling
- `ModReduce()` (modulus switching) is how noise is managed
- Supports both `FIXEDMANUAL` and `FLEXIBLEAUTO` modulus-switch scheduling

### 5.5 CKKSrns scheme

**Files:** `src/pke/include/scheme/ckksrns/`

CKKS (Cheon–Kim–Kim–Song) is the most complex scheme and enables **approximate floating-point arithmetic** over packed vectors of complex numbers.

**Encoding:** Values are scaled by $\Delta = 2^{\texttt{scaleModSize}}$ before embedding as integer polynomial coefficients. After each multiplication, the ciphertext scale grows by $\Delta$, so a **rescaling** step divides by $\Delta$, consuming one level.

**Scaling techniques** (set via `CCParams::SetScalingTechnique()`):

| Mode | Description |
|------|-------------|
| `FIXEDMANUAL` | User calls `Rescale()` explicitly |
| `FIXEDAUTO` | Library inserts rescaling automatically |
| `FLEXIBLEAUTO` | Moduli are adjusted per-level for best precision |
| `FLEXIBLEAUTOEXT` | Extended variant for better bootstrapping |

**Bootstrapping** is implemented in `ckksrns-fhe.h/cpp`:
- `EvalBootstrapSetup()` — precomputes the rotation/linear-transform keys
- `EvalBootstrap()` — refreshes the ciphertext to restore all levels
- The core steps are: ModRaise → CoeffToSlot → EvalMod → SlotToCoeff
- Chebyshev approximation of $\sin(2\pi x)$ is used for `EvalMod`
- `CKKSBootstrapPrecom` stores precomputed constants for the linear transformations

**Advanced operations** in `ckksrns-advancedshe.h`:
- `EvalLinearWSumMutable()` — weighted linear combination of ciphertexts
- `EvalChebyshevSeries()` — arbitrary function evaluation via Chebyshev expansion
- `EvalChebyshevFunction()` — convenience wrapper taking a lambda

### 5.6 Key switching (BV and Hybrid)

Key switching is the fundamental operation that makes relinearization and rotation possible. Two methods are provided:

**BV key switching** (`keyswitch-bv.h`):  
Decomposes the ciphertext into small pieces (digit decomposition) and multiplies by the evaluation key. Higher noise growth, but no dimension doubling.

**Hybrid key switching** (`keyswitch-hybrid.h`):  
Based on the GHS scheme (Gentry–Halevi–Smart 2012, RNS version 2019). Partitions the key into a hybrid structure that mixes BV and GHS approaches. Pros: lower noise than BV with only a linear number of NTTs. The method is the default for CKKSrns.

The abstraction layer `KeySwitchBase` → `KeySwitchRNS` → `KeySwitchBV` / `KeySwitchHYBRID` allows schemes to select the appropriate method.

### 5.7 Proxy Re-Encryption (PRE)

Implemented in `base-pre.h` and per-scheme `*-pre.h` files. PRE allows a ciphertext encrypted under key $A$ to be transformed to be decryptable by key $B$, without exposing either key or the plaintext. The library supports:
- `INDCPA` — IND-CPA secure
- `FIXED_NOISE_HRA` — Honest re-encryptor model
- `NOISE_FLOODING_HRA` — Highest security for PRE

### 5.8 Threshold / Multiparty FHE

Implemented in `base-multiparty.h` and per-scheme `*-multiparty.h` files.

Supports $n$-of-$n$ threshold decryption across multiple parties:
1. Each party generates a partial key pair; parties combine public keys
2. Encryption uses the combined public key
3. Each party computes a **partial decryption** using their secret key share
4. A **fusion** step combines all partial decryptions into the plaintext

`MultipartyMode` controls noise injection during decryption:
- `FIXED_NOISE_MULTIPARTY` — adds fixed noise for security
- `NOISE_FLOODING_MULTIPARTY` — adds larger noise for statistical hiding (most secure)

Interactive bootstrapping for Threshold CKKS (`tckks-interactive-mp-bootstrapping.cpp`) allows refreshing ciphertexts collaboratively without any party learning the secret.

### 5.9 Scheme Switching (CKKS ↔ FHEW/TFHE)

**Files:** `src/pke/include/scheme/ckksrns/ckksrns-schemeswitching.h`

This unique feature lets a computation start in CKKS (for real-number arithmetic), switch to FHEW/TFHE (to evaluate non-smooth functions like comparisons or floor), and switch back to CKKS.

Key methods:
- `EvalCKKStoFHEWSetup/KeyGen/Precompute` — sets up the bridge keys
- `EvalCKKStoFHEW()` — extracts individual slots from a CKKS ciphertext as LWE ciphertexts
- `EvalFHEWtoCKKSSetup/KeyGen` — reverse direction setup
- `EvalFHEWtoCKKS()` — packs LWE ciphertexts back into a CKKS ciphertext

Enables operations like:
- Comparison / sign / floor via FHEW functional bootstrapping
- Argmin over encrypted vectors
- General piecewise-polynomial functions

### 5.10 Serialization

All crypto objects (`CryptoContext`, ciphertexts, keys) implement the `Serializable` interface. The `serial.h` utility provides:
- `Serial::Serialize(obj, stream, SerType::JSON)` — human-readable
- `Serial::Serialize(obj, stream, SerType::BINARY)` — compact

The underlying engine is the **Cereal** library (header-only, in `third-party/cereal/`).

---

## 6. Module: `binfhe`

The `binfhe` module implements Boolean-circuit FHE based on the Learning With Errors (LWE) problem over small rings.

### 6.1 LWE primitives

Located in `src/binfhe/include/lwe-*.h`:

- **`LWECiphertextImpl`** — An LWE ciphertext $(b, \mathbf{a}) \in \mathbb{Z}_q \times \mathbb{Z}_q^n$. Represents a single encrypted bit (or small integer).
- **`LWEPrivateKey`** / **`LWEPublicKey`** / **`LWEKeyPair`** — Key types for LWE encryption
- **`LWEKeySwitchKey`** — Key material for dimension/modulus switching between LWE instances
- **`LWECryptoParams`** — Parameter set: lattice dimension $n$, modulus $q$, standard deviation $\sigma$, key distribution

The `BinFHEContext` wraps all LWE operations in a single user-facing API that parallels `CryptoContextImpl`.

### 6.2 Ring GSW (RGSW) and bootstrapping

Bootstrapping in BinFHE works by evaluating a programmable lookup table (gate) using ring-based operations.

Three bootstrapping methods are supported:

| Method | Reference | Key type |
|--------|-----------|----------|
| **DM** (Ducas–Micciancio) | FHEW 2015 | RGSW accumulation keys |
| **CGGI** (Chillotti–Gama–Georgieva–Izabachène) | TFHE 2016 | Same, with better constants |
| **LMKCDEY** (Lee–Micciancio–Kim–Choi–Deryabin–Eom–Yoo 2022) | Improved TFHE | Automorphism keys |

Files:
- `rgsw-acc.h` — abstract accumulator interface
- `rgsw-acc-cggi.h` / `rgsw-acc-dm.h` / `rgsw-acc-lmkcdey.h` — concrete implementations
- `rgsw-cryptoparameters.h` — parameters for the ring-GSW component (ring dimension $N$, bootstrapping modulus $Q$, gadget base $B$)
- `rgsw-evalkey.h` / `rgsw-acckey.h` — evaluation keys for the accumulator

The bootstrapping flow:
1. **Key switching**: reduce the LWE ciphertext from dimension $N$ down to $n$
2. **Blind rotation** (accumulator step): apply RGSW products to rotate a test polynomial by the secret key; this is where the lookup table is evaluated
3. **Sample extraction**: extract one LWE coefficient from the RLWE ciphertext to get the output bit

### 6.3 Supported gate families

Via `BinFHEContext::EvalBinGate()`:
- Standard 2-input: `AND`, `OR`, `NAND`, `NOR`, `XOR`, `XNOR`
- Standard 1-input: `NOT` (free, no bootstrapping needed)
- 3-input gates (MUX, MAJORITY, etc.) when using LMKCDEY

`EvalFunc()` allows evaluation of an arbitrary function via a lookup table.

---

## 7. Key data types

| Type | Defined in | Description |
|------|-----------|-------------|
| `DCRTPoly` | `lattice/hal/default/` | Main ring element; vector of NTT-domain NativePolys |
| `NativePoly` | `math/hal/intnat/` | Single-modulus polynomial with `uint64_t` coefficients |
| `Poly` | `lattice/hal/poly-interface.h` | Generic polynomial (used for big-integer backends) |
| `CiphertextImpl<DCRTPoly>` | `pke/include/ciphertext.h` | Pair (or triple) of `DCRTPoly` values + metadata |
| `PlaintextImpl` | `pke/include/encoding/` | Encoded plaintext; holds the raw `DCRTPoly` |
| `KeyPair<DCRTPoly>` | `pke/include/key/keypair.h` | `{publicKey, secretKey}` pair |
| `EvalKey<DCRTPoly>` | `pke/include/key/evalkey.h` | Relinearization / rotation key |
| `LWECiphertextImpl` | `binfhe/include/lwe-ciphertext.h` | $(b, \mathbf{a})$ LWE ciphertext |
| `RLWECiphertextImpl` | `binfhe/include/rlwe-ciphertext.h` | $(b, a)$ with polynomial components; used in bootstrapping |

---

## 8. Build system

The project uses CMake (≥ 3.5.1) and requires a C++17 compiler (GCC ≥ 9 or Clang ≥ 10).

### Key CMake options

| Option | Default | Effect |
|--------|---------|--------|
| `CMAKE_BUILD_TYPE` | `Release` | `Debug` adds `-g`, disables optimizations |
| `BUILD_UNITTESTS` | `ON` | Compiles Google Test suites |
| `BUILD_EXAMPLES` | `ON` | Compiles example programs into `bin/examples/` |
| `BUILD_BENCHMARKS` | `ON` | Compiles Google Benchmark suites into `bin/benchmark/` |
| `BUILD_STATIC` | `OFF` | Build `_static.a` archives alongside shared libs |
| `WITH_BE2` / `WITH_BE4` | `OFF` | Enable multi-precision backends |
| `WITH_NTL` | `OFF` | Enable NTL/GMP backend (requires external install) |
| `WITH_TCM` | `OFF` | Enable tcmalloc for multithreaded performance |
| `WITH_OPENMP` | `ON` | Parallelise polynomial operations with OpenMP |
| `NATIVE_SIZE` | `64` | Native integer word size (64 or 128 bits) |
| `WITH_NATIVEOPT` | `OFF` | Machine-specific SIMD optimisations (big speedup on Clang) |

### Output layout after `make`

```
build/
├── lib/               # OPENFHEcore, OPENFHEpke, OPENFHEbinfhe (shared/static)
├── bin/
│   ├── examples/pke/  # BFV, BGV, CKKS, threshold, scheme-switching demos
│   ├── examples/binfhe/ # Boolean gate demos
│   └── benchmark/     # Performance benchmarks
├── unittest/          # Unit test binaries (run via `make testall`)
└── third-party/lib/   # cereal, google-test, google-benchmark built artifacts
```

---

## 9. Third-party dependencies

| Library | Location | Purpose |
|---------|----------|---------|
| **Cereal** | `third-party/cereal/` | Header-only C++11 serialization |
| **Google Test** | `third-party/google-test/` | Unit testing framework |
| **Google Benchmark** | `third-party/google-benchmark/` | Microbenchmark framework |
| **gperftools (tcmalloc)** | `third-party/gperftools/` | Optional thread-caching allocator |
| **NTL / GMP** | System install | Optional multi-precision arithmetic (backend 6) |
| **Intel HEXL** | Optional system install | AVX-512 accelerated NTT operations |
| **OpenMP** | System compiler | Multi-threaded polynomial arithmetic |

All git-submodule dependencies are auto-initialised when `GIT_SUBMOD_AUTO=ON` (default).

---

## 10. Tests, benchmarks, and examples

### Unit tests
Run with `make testall` or `ctest` from the build directory. The test runner is `test/Main_TestAll.cpp`. Tests are organized per module:
- `src/core/unittest/` — math and lattice tests
- `src/pke/unittest/` — PKE scheme correctness tests
- `src/binfhe/unittest/` — Boolean gate tests

### Benchmarks
`benchmark/src/` contains Google Benchmark programs for:
- NTT and lattice operations (`Lattice.cpp`, `poly-benchmark-*.cpp`)
- BFV multiplication methods (`bfv-mult-method-benchmark.cpp`)
- BFV vs BGV comparison (`compare-bfvrns-vs-bgvrns.cpp`)
- BinFHE parameter sets (`binfhe-paramsets.cpp`)
- CKKS serialization (`serialize-ckks.cpp`)

### Examples
`src/pke/examples/` and `src/binfhe/examples/` provide annotated, runnable programs covering all major API surface areas. These are the recommended starting point for new users.

---

## 11. Data-flow walkthrough: BFV integer example

```
[User code: simple-integers.cpp]

1. CCParams<CryptoContextBFVRNS> params;
   params.SetPlaintextModulus(65537);   // t
   params.SetMultiplicativeDepth(2);    // → selects RNS modulus chain with 3 primes

2. CryptoContext<DCRTPoly> cc = GenCryptoContext(params);
   // Internally: BFVrnsParameterGeneration::ParamsGen() selects q_0,q_1,q_2
   // such that q = q_0·q_1·q_2 is large enough for 2 multiplications

3. cc->Enable(PKE | KEYSWITCH | LEVELEDSHE);

4. KeyPair<DCRTPoly> kp = cc->KeyGen();
   // Generates s ← TernaryUniform, a ← UniformModQ
   // pk = (b = -(a·s + e), a)

5. cc->EvalMultKeyGen(kp.secretKey);
   // Generates relinearization key: encrypts s² under s with special modulus

6. Plaintext pt1 = cc->MakePackedPlaintext({1,2,3,...});
   // CRT-packs the vector using Shoup's packing into a polynomial mod t

7. auto ct1 = cc->Encrypt(kp.publicKey, pt1);
   // ct = pk·u + (Δ·m + e₁, e₂)  where Δ = round(q/t)

8. auto ctAdd = cc->EvalAdd(ct1, ct2);
   // Coefficient-wise addition mod q (no key switching needed)

9. auto ctMul = cc->EvalMult(ct1, ct2);
   // 1. Tensor product: 3-component ciphertext
   // 2. Relinearization (key switch) back to 2 components
   // 3. Rescaling / rounding via BFV multiplication technique

10. Plaintext result;
    cc->Decrypt(kp.secretKey, ctMul, &result);
    // Computes ⌊ct[0] + ct[1]·s⌋ mod t
```

---

## 12. Data-flow walkthrough: CKKS real-number example

```
[User code: simple-real-numbers.cpp]

1. CCParams<CryptoContextCKKSRNS> params;
   params.SetMultiplicativeDepth(1);    // 1 multiplication before noise blows up
   params.SetScalingModSize(50);         // Δ = 2^50 ≈ 10^15 scale factor
   params.SetBatchSize(8);              // pack 8 complex values

2. CryptoContext<DCRTPoly> cc = GenCryptoContext(params);
   // Selects ring dimension N (e.g., 4096) and 2-3 RNS primes

3. Plaintext pt = cc->MakeCKKSPackedPlaintext({0.1, 0.2, ...});
   // FFT-encodes values: m(x) = IFFT(values) scaled by Δ, stored as poly coefficients

4. auto ct = cc->Encrypt(kp.publicKey, pt);
   // Standard RLWE encryption

5. auto ctSq = cc->EvalMult(ct, ct);
   // Polynomial multiplication in the ring
   // Scale: Δ² after mult

6. ctSq = cc->Rescale(ctSq);      // (or automatic with FLEXIBLEAUTO)
   // Drops one RNS level (one prime), divides coefficients by ~Δ
   // Scale returns to ~Δ; one level consumed

7. Plaintext result;
   cc->Decrypt(kp.secretKey, ctSq, &result);
   // Decrypts, removes scale Δ via FFT, returns approximate float vector
   result->SetLength(8);
   std::cout << result;  // ≈ [0.01, 0.04, ...]
```

---

## 13. Data-flow walkthrough: Boolean gate example (BinFHE)

```
[User code: boolean.cpp]

1. BinFHEContext cc;
   cc.GenerateBinFHEContext(STD128);
   // Looks up STD128 in stdlatticeparms.h:
   //   n=512 (LWE dim), N=1024 (RLWE dim for bootstrapping),
   //   q=512, Q=2^27+1, σ=3.19

2. LWEPrivateKey sk = cc.KeyGen();
   // sk ← {-1,0,1}^n (ternary, uniform)

3. cc.BTKeyGen(sk);
   // Generates:
   //   - Bootstrapping key BK: RGSW encryptions of each sk[i]
   //   - Key-switching key KSK: for dimension reduction N→n after blind rotation

4. auto ct1 = cc.Encrypt(sk, 1);
   // LWE encryption: b = a·sk + e + q/4 (encoding 1 as q/4)
   // bootstrapped immediately by default

5. auto ctAND = cc.EvalBinGate(AND, ct1, ct2);
   // 1. Homomorphic XOR of the two ciphertexts (sum their (b,a) components)
   // 2. Blind rotation: multiplies accumulator polynomial by X^{-b} · ∏ X^{a_i·sk_i}
   //    This rotates a test polynomial to position encoding AND(bit1, bit2)
   // 3. Sample extraction: pull out one LWE coefficient
   // 4. Key switching back to original key/dimension
   // Output: a fresh LWE ciphertext encoding the result bit

6. LWEPlaintext result;
   cc.Decrypt(sk, ctAND, &result);
   // result = 1 (true)
```

---

## 14. GPU extension (this fork)

This repository (`openfhe-gpu-public`) adds CUDA-accelerated computation primarily for CKKS bootstrapping, the most computationally intensive operation. The key addition is:

```
./bin/examples/pke/advanced-ckks-bootstrapping-gpu
```

The GPU path hooks in at the polynomial-multiplication and NTT level, replacing CPU implementations with CUDA kernels for:
- Number Theoretic Transforms (NTT/INTT) over RNS primes
- Element-wise arithmetic (coefficient addition, multiplication, Barrett reduction)
- The linear transformations (matrix–ciphertext products) in CoeffToSlot/SlotToCoeff

The rest of the library (key generation, encoding, non-bootstrapping operations) still runs on CPU. The GPU backend follows the same HAL interface pattern as the Intel HEXL backend.

> **Note:** This fork is described as a benchmarking tool and is not intended for production use. Bugs and security issues are the responsibility of the fork's authors.

---

## 15. Security considerations

- **IND-CPA security** is provided by all schemes under the Ring Learning With Errors (RLWE) hardness assumption.
- **Parameter selection** follows the HomomorphicEncryption.org standard. When a `SecurityLevel` (STD128, STD192, STD256) is selected, the library automatically consults `stdlatticeparms.h` to ensure parameters meet the standard.
- **Noise flooding** modes (`NOISE_FLOODING_MULTIPARTY`, `NOISE_FLOODING_HRA`) add extra Gaussian noise to partially-decrypted values before sharing them, providing protection against malicious parties.
- **CKKS approximate decryption** exposes some information about the plaintext through the decryption noise. `CKKS_M_FACTOR` (default 1) strengthens the adversarial model when decryption results are shared; set it higher in multi-party CKKS deployments.
- **Serialized secrets** (private keys, evaluation keys) must be protected by the application; the library provides no built-in access-control layer.
- **`WITH_NOISE_DEBUG`** must never be enabled in production; it weakens the noise flooding by exposing internal noise values.
