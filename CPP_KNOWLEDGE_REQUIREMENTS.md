# Required C++ Knowledge for Working in This Codebase

This document outlines the C++ knowledge needed to contribute effectively to OpenFHE in this repository.

## 1. Baseline C++ Proficiency

You should be comfortable with modern C++ (C++17 in practice for this project), including:

- Declarations, definitions, namespaces, headers, and translation units
- Classes, inheritance, polymorphism, and virtual functions
- Templates (function templates, class templates, specialization basics)
- References, pointers, and object lifetimes
- Standard containers and algorithms
- Exception handling and error propagation
- Build workflow with CMake and compiler diagnostics

If these are unfamiliar, start with a modern C++ fundamentals resource before touching cryptographic internals.

## 2. Language Features You Will Use Frequently

### 2.1 Const Correctness

You will see const used pervasively in APIs and internal types:

- const objects and member functions
- const references to avoid copies
- immutable interfaces where mutation would break assumptions

Why it matters: cryptographic code depends on strict invariants and predictable object state.

### 2.2 RAII and Ownership

Resource management follows RAII patterns:

- Objects acquire resources during construction and release in destructors
- Prefer deterministic cleanup over manual lifecycle handling
- Understand ownership transfer and scope-based cleanup

### 2.3 Smart Pointers

The codebase uses shared ownership heavily:

- std::shared_ptr for shared crypto contexts and parameter objects
- std::unique_ptr for exclusive ownership
- Weak ownership concepts when avoiding ownership cycles

You should recognize when APIs return pointer-like handles and how long objects remain valid.

### 2.4 Move Semantics and Copy Costs

Large polynomial and ciphertext objects are expensive to copy.

Required concepts:

- lvalues, rvalues, move construction, move assignment
- std::move and when not to use it
- copy elision and pass-by-reference patterns

### 2.5 Templates and Generic Programming

OpenFHE APIs and internals rely on templated types such as ring elements and scheme components.

You should be comfortable reading and debugging:

- nested template types
- typedef and using aliases
- template-heavy compiler errors

## 3. Math and Numeric Programming in C++

You do not need deep number theory to begin, but you do need practical numeric programming skills:

- Fixed-width integer types and overflow awareness
- Precision tradeoffs for floating-point and approximate arithmetic
- Efficient vector/matrix style computation patterns
- Understanding algorithmic complexity and memory pressure

This is essential for CKKS workflows (approximate arithmetic) and performance-sensitive code paths.

## 4. Project-Specific C++ Patterns in OpenFHE

### 4.1 API-Centric Programming Through CryptoContext

Most user-facing logic runs through CryptoContext APIs and feature flags.

You should understand:

- how contexts are created and configured
- which features must be enabled for specific operations
- key generation and evaluation key requirements

Useful starting point:

- src/pke/examples/README.md
- src/pke/examples/simple-integers.cpp
- src/pke/examples/simple-real-numbers.cpp

### 4.2 Serialization and Interop Boundaries

Distributed or multi-process usage depends on serializing contexts, keys, and ciphertexts.

Required knowledge:

- binary vs text serialization tradeoffs
- API discipline around compatible parameter sets
- error handling for malformed or mismatched serialized data

Useful starting point:

- src/pke/examples/simple-integers-serial.cpp
- src/pke/examples/simple-real-numbers-serial.cpp

### 4.3 Performance-Aware Coding

This repository is performance-sensitive. C++ changes should avoid hidden costs.

You should be able to:

- identify unnecessary allocations/copies
- reserve container capacity when sizes are known
- reason about hot loops and branch behavior
- use profiling data rather than intuition when optimizing

Useful starting point:

- benchmark/src/

### 4.4 Parallel and Low-Level Runtime Awareness

Parallelism and backend selection are part of normal development:

- basic OpenMP awareness
- compiler and architecture flags
- effects of native integer width and backend selection

Useful starting point:

- src/core/include/utils/parallel.h
- docs/sphinx_rsts/intro/installation/cmake_in_openfhe.rst

## 5. Build, Tooling, and Debugging Skills

### 5.1 CMake Competence

You should be able to:

- configure out-of-source builds
- enable/disable options
- interpret CMake configure output
- link against OpenFHE in downstream projects

Useful starting point:

- CMakeLists.txt
- CMakeLists.User.txt

### 5.2 Compiler Diagnostics

Template-heavy code can produce long errors. You should know how to:

- locate the first meaningful error in a long trace
- reduce errors with smaller reproductions
- iterate quickly with targeted file builds when possible

### 5.3 Basic Test and Benchmark Workflow

Contributors should be able to run tests/benchmarks relevant to their changes.

Useful starting point:

- test/
- benchmark/

## 6. Security and Correctness Mindset

Cryptographic code has stricter standards than general application code.

Expected mindset:

- correctness first, optimization second
- preserve API contracts and parameter assumptions
- avoid introducing side effects in supposedly pure steps
- document assumptions clearly when changing numerical behavior

Small implementation changes can alter noise growth, precision, or security envelopes.

## 7. Suggested Learning Path for New Contributors

1. Build the project successfully from source.
2. Run simple examples for BFV/BGV/CKKS.
3. Read and modify one small example (for example, vector size or operation chain).
4. Add serialization to that example and verify round-trip behavior.
5. Inspect one benchmark and one unit test to learn expected coding style.
6. Only then start modifying core or scheme internals.

## 8. Practical Checklist Before Editing Core Crypto Code

- I can read templated code without guessing at types.
- I understand move/copy implications for large objects.
- I can run and interpret example outputs.
- I can build with CMake options relevant to my change.
- I know what tests/benchmarks validate my change.
- I can explain security or precision impact of the change.

If any item is missing, spend time filling that gap first. It will save debugging time and reduce risk.

## 9. Nice-to-Have Advanced Knowledge

Not mandatory for first contributions, but very useful over time:

- Advanced template metaprogramming
- Cache-aware optimization and vectorization basics
- Cross-platform compiler behavior differences (GCC/Clang)
- Familiarity with homomorphic encryption concepts and noise management

---

This document is intended as a contributor readiness guide. Pair it with CODEBASE_OVERVIEW.md and the examples under src/pke/examples for fastest onboarding.
