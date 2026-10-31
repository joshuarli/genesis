# Genesis — mrustc-derived Rust bootstrap

Genesis builds a Rust toolchain from the mrustc seed, starting with a pinned
1.90.0 seed and extending through the Rust 1.99.1 destination. It is a working
feasibility implementation, not a full-source lower bootstrap.

## Status

| Milestone | State |
|---|---|
| Rust feasibility PoC (mrustc → 1.90 → 1.91.1 → 1.96.0 → 1.99.1) | complete |
| Same-version 1.99.1 rebuild and functional tests | complete |
| Fresh-checkout replay to 1.99.1 | pass; see `records/reports/replay-fresh.md` |
| Hex0-derived lower toolchain | not complete; native toolchains remain borrowed |

The checked-in recipes now contain the seed build, TLS compatibility shim,
release ladder, native-package pins, compatibility patches, and test runners.
`.work/` is disposable output: downloads, build trees, logs, caches, and
installed toolchains.

## Quick start

```sh
./scripts/doctor.sh
./scripts/launch.sh --status
./scripts/launch.sh --until 1.99.1
./scripts/launch.sh --verify 1.99.1
./tests/smoke/run.sh --prefix .work/artifacts/ext-1.99.1/prefix
./tests/external/run.sh --prefix .work/artifacts/ext-1.99.1/prefix
```

`--until` builds missing prerequisites and resumes existing build directories.
It never treats an existing log as a completed stage. `--verify` only inspects
installed artifacts; it does not prove build ancestry. `--status` distinguishes
`not-attempted`, `incomplete`, `failed`, and `passed`.

A genuine same-version rebuild is a build, not a status check. `--until`
builds it only when missing; `--rebuild-same-version` always removes the
previous self-build tree and rebuilds it:

```sh
./scripts/launch.sh --until self-1.99.1
./scripts/launch.sh --rebuild-same-version 1.99.1
```

## Fresh replay

`recipes/replay.sh` builds the whole chain in an empty work directory, using
only this checkout and `sources.toml`. It downloads and hash-checks Rust
sources and Alpine native packages, builds the seed and every ladder rung,
runs the functional tests, relocates the final prefix, and hides the build and
artifact trees during the relocation test.

```sh
recipes/replay.sh --work-dir .work/replay-fresh
```

The 2026-10-31 fresh-checkout run built mrustc, the seed, every rung, and a
same-version 1.99.1 compiler in an empty work directory; interrupted stages
resumed without rebuilding earlier toolchains. It then passed 7/7 smoke cases
(including static PIE), the external rustfilt build, and relocation with the
build/artifact/download trees hidden. A subsequent forced mrustc C++ stage
rebuild scored 128/129 ccache hits. Details:
`records/reports/replay-fresh.md`.

The same result with the launcher:

```sh
GENESIS_WORK=/path/to/empty/work ./scripts/launch.sh --until ref-1.96.0
GENESIS_WORK=/path/to/empty/work ./scripts/launch.sh --until 1.99.1
GENESIS_WORK=/path/to/empty/work ./scripts/launch.sh --rebuild-same-version 1.99.1
```

## Lower chain

```sh
recipes/lower-chain.sh inventory
recipes/lower-chain.sh verify-rust-poc
recipes/lower-chain.sh replay-rust-chain --work-dir .work/replay-fresh
recipes/lower-chain.sh verify-lower-closure
```

`verify-lower-closure` fails until compiler-producing consumers are rebuilt
under the rebuilt lower lineage. Rebuilding libunwind and relinking a smoke
program does not change the ancestry of the Rust compiler.

## Layout

| Path | Purpose |
|---|---|
| `sources.toml` | pinned Rust sources, Alpine native packages, patches, and release ladder |
| `recipes/` | executable seed, release, replay, and lower-chain commands |
| `patches/` | mrustc and Rust compatibility patches |
| `support/` | bootstrap helper sources, including the TLS-key shim |
| `tests/smoke/` | proc-macro, build.rs, FFI, threads/TLS, unwind, and hello fixtures |
| `tests/external/` | pinned rustfilt 0.2.1 build from vendored crates |
| `tests/runner/` | fast regression tests for the launcher and runners |
| `tests/tls-shim/` | TLS-key shim regression test |
| `records/` | historical handoffs, StageX pin, and campaign reports |
| `.work/` | disposable downloads, builds, logs, caches, and prefixes |

## Declared build environment

Linux x86-64 with musl, `cc`/`c++` (GCC 15 works), clang 23, Python 3.11+,
GNU make, tar, curl, ccache, mold, and the musl development CRT/archive files
(`/usr/lib/{rcrt1.o,crt1.o,Scrt1.o,crti.o,crtn.o,libc.a}`). Docker is only
needed for the parked StageX lower-chain work. Network access is needed on the
first run to fetch pinned sources and native packages.

The native LLVM packages are borrowed build tools, not part of the claimed
Rust ancestry. `sources.toml` records their repositories and full SHA-256
hashes. The seed also uses a bootstrap-only TLS-key shim while mrustc-built
compilers lack native TLS; `1.91.1` and later do not need it at runtime.

## Runtime contract

The produced toolchain is relocatable and finds its driver and `libunwind`
through `$ORIGIN`-relative runpaths. The final prefix bundles the runtime
library it needs. `RUST_MIN_STACK=16777216` is used while building LLVM-23
compilers (1.99.1 and the same-version rebuild); functional smoke and external
tests do not need it. Keep it for compiler-sized LTO builds.

## What is not claimed

- No byte-for-byte reproducibility.
- No Hex0-derived C/C++/musl closure yet.
- No replacement for LLVM or GNU extensions.
- No additional architectures.
- No static-everything promise; dynamic output is the default, and `+crt-static`
  static PIE is tested separately.
