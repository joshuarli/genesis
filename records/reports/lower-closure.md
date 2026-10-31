# Narrow StageX closure for the Rust/native path

Date: 2026-10-31. Pin: `9bdf430d09ce2ba53932df0182faef00d4feecd1`
(`stagex/core-rust` image digest
`sha256:def2df15b5bcc5271453fc940b06f5f1cbdec91b72c37855f6777c7e9acf9584`).

## What was measured

`recipes/lower-chain.sh closure` resolves the build-time package graph from the
pinned StageX source, starting at `core-rust`. The resolver follows the same
`COPY --from=stagex/...` and `FROM stagex/...` edges that `src/targets.py` turns
into build dependencies, expands subpackages, and rejects missing packages.

Result: **35 packages**, of which 17 are direct dependencies of `core-rust`,
and **308 distinct pinned source archives**. The archived source tree hashes and
mirrors are recorded in the per-package `package.toml` files.

| Package | Version | Direct deps |
|---|---|---|
| `bootstrap-stage0` | - | 0 |
| `bootstrap-stage1` | fc6eeb6bd75ea0d0025a79ea9fe45614bd60ba14 | 1 |
| `bootstrap-stage2` | - | 1 |
| `bootstrap-stage3` | - | 1 |
| `core-filesystem` | - | 1 |
| `core-busybox` | 1.38.0 | 2 |
| `core-libzstd` | 1.5.7 | 2 |
| `core-mimalloc` | 2.3.2 | 2 |
| `core-musl` | 1.2.6 | 3 |
| `core-llvm` | 22.1.5 | 3 |
| `core-make` | 4.4.1 | 2 |
| `core-linux-headers` | 7.0 | 2 |
| `core-zlib` | 1.3.2 | 7 |
| `core-perl` | 5.42.2 | 7 |
| `core-openssl` | 3.6.3 | 9 |
| `core-pkgconf` | 2.5.1 | 7 |
| `core-samurai` | 1.3 | 8 |
| `core-cmake` | 4.3.3 | 10 |
| `core-attr` | 2.5.2 | 8 |
| `core-libucontext` | 1.5 | 8 |
| `core-onetbb` | 2023.0.0 | 12 |
| `core-mold` | 2.41.0 | 12 |
| `core-ca-certificates` | 089afe88dd219cf4b1516fd04f3b1c1fda3b7b61 | 11 |
| `core-curl` | 8.20.0 | 12 |
| `core-libatomic-stub` | 0.0.1 | 6 |
| `core-llvm-libgcc` | 22.1.5 | 3 |
| `core-bzip2` | 1.0.8 | 9 |
| `core-libffi` | 3.5.2 | 9 |
| `core-ncurses` | 6.6 | 10 |
| `core-bsd-compat-headers` | 0.7.2 | 2 |
| `core-tcl` | 9.0.3 | 11 |
| `core-sqlite3` | 3.53.2 | 10 |
| `core-python` | 3.14.5 | 14 |
| `core-llvm21` | 21.1.8 | 13 |
| `core-rust` | 1.96.0 | 17 |

The closure starts at `bootstrap-stage0` (the 181-byte x86 seed) and reaches the
Rust package through the full source-built native toolchain. It does not include
`pallet/` or `user/` packages, and it does not include the later Genesis release
rungs. The published image layers for the closure total about 2.1 GB compressed;
the local build's intermediate and cache high-water mark is not yet measured.

## Why this is the right boundary

`core-rust`'s direct dependencies are the native tools and libraries its recipe
actually imports: filesystem, busybox, LLVM 22, LLVM 21, LLVM libgcc, make,
pkgconf, Python, oneTBB, mold, zlib, libzstd, musl, CA certificates, curl,
OpenSSL, and the libatomic stub. Everything else in the closure is a
transitive build dependency of those packages. This is the narrow Rust/native
path, not the full-distribution reproduction that StageX documents at about
500 GB.

## Next gate

Build this closure locally from the pinned source, with no preseed, then use its
StageX-built toolchain and seed to rerun the compiler-producing consumers. The
closure measurement alone does not establish lower ancestry; `verify-lower-closure`
must keep failing until a recorded build and consumer rebuild exist.
