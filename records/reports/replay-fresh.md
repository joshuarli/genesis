# Fresh-checkout replay to Rust 1.99.1

Date: 2026-10-31. Host: Linux x86-64/musl, AMD Ryzen 9 9950X, 32 CPUs, 60 GB RAM,
Alpine edge. Build environment: GCC 15.2.0, clang 23.1.3, musl-dev 1.2.6-r5,
mold, ccache 4.13.6, Python 3.15.1.

## Scope

A fresh `git clone` of this repository (no untracked files, no prior `.work/`)
built the complete chain in an empty external work directory:

```text
mrustc 0.12.0
  -> 1.90.0 seed (mrustc/minicargo)
  -> 1.91.1 -> 1.92.0 -> 1.93.1 -> 1.94.1 -> 1.95.0
  -> 1.96.0 reference endpoint
  -> separate 1.96.1 -> 1.97.1 -> 1.98.1 -> 1.99.1 extension
  -> same-version 1.99.1 rebuild
```

Sources and Alpine APKs were downloaded from `sources.toml` and checked by
SHA-256. The replay PATH contained no ambient `rustc` or `cargo`; the work
directory had its own `CARGO_HOME` and `CCACHE_DIR`.

## Checkout commits

- Chain build: `db0c35d` (the final ladder fix, 1.98.1 on LLVM 21).
- Final test/report rerun: `0168210` (static-pie included in replay tests).
- The work directory was reused across interruptions and resumed; each
  completed stage was verified before the next stage started.

## Interruptions and resume

The first empty-work-dir run stopped at three repository bugs, all fixed and
then resumed without rebuilding earlier stages:

1. `llvm21` packages were pinned to v3.24 bytes; the recorded hashes are the
   edge build. Switching the mirror made the existing download verification
   pass.
2. `verify_sha256` reused the caller's `file` variable, so native APK
   downloads renamed each `.part` onto itself. Renamed the functions' locals.
3. `extract_native_group`'s destination was overwritten by the nested
   download helper, extracting APKs into the download directory. Isolated the
   helper variables.
4. The first 1.98.1 attempt used LLVM 23; the recorded rung uses LLVM 21. The
   partial build tree was discarded and the rung rebuilt with LLVM 21.

These were genuine interruptions, not stage skips: earlier artifacts survived
and `--status` reported the failed stage as failed. The final rerun of the
replay script was a 6-second no-op plus tests because every stage verified.

## Results

| Check | Result |
|---|---|
| 1.90 seed builds and runs | pass: `rustc 1.90.0-stable-mrustc`, `cargo 1.90.0` |
| 1.96.0 reference endpoint | pass: `rustc 1.96.0`, `cargo 1.96.0` |
| 1.99.1 destination | pass: `rustc 1.99.1`, `cargo 1.99.1`, LLVM 23.1.4 |
| same-version 1.99.1 rebuild | pass: stage2 compiler artifacts, 25:37 |
| smoke fixtures | 7/7: proc-macro, build.rs, FFI, threads/TLS, unwind, hello, static PIE |
| external rustfilt 0.2.1 | pass, offline from vendored crates |
| relocation | pass with `build/`, `artifacts/`, and `downloads/` hidden |
| static PIE inspection | no `PT_INTERP`, no dynamic `NEEDED` entries |
| ambient toolchain | no `rustc`/`cargo` visible on PATH |

The self-build log contains `Building stage2 compiler artifacts`, compilation
of `rustc_driver_impl`/`rustc-main`, `install: installing component 'rustc'`,
and completed in 25:37. That is a compiler-producing rebuild, not an uplift.

## ccache

The seed C++ tree was rebuilt with `make -B` against the replay's ccache
namespace. The actual stage rebuild produced:

```text
Cacheable calls:   129 / 131 (98.47%)
Hits:              128 / 129 (99.22%)
Direct:            128 / 128 (100.0%)
Misses:              1 / 129 (0.78%)
Uncacheable calls:   2 / 131 (1.53%)
```

The one miss is the version-stamped translation unit; the link/strip steps are
uncacheable. mrustc-generated C uses `MRUSTC_CCACHE=1`; vendored OpenSSL built
by cargo is not ccached.

## Runtime contract

`RUST_MIN_STACK=16777216` is set for LLVM-23 compiler builds (1.99.1 and the
self-build). The smoke and external suites run without it. Keep it for
compiler-sized LTO builds.

## Borrowed and excluded

Borrowed, declared inputs: host cc/c++/clang/musl-dev, the Alpine LLVM 21 and
LLVM 23 packages, mold, Python, make/tar/curl, ccache, and host runtime
libraries (`libz`, `libzstd`, `libstdc++`, `libgcc_s`, OpenSSL/curl for cargo).
No StageX container was used for the Rust chain. The lower Hex0-derived
C/C++/musl closure remains incomplete; this replay changes no lower ancestry.

## Artifact location

Reproduction work directory: `.work/fresh/work` on the builder. Durable
records are in `records/`; compiler prefixes and build trees are intentionally
not committed.
