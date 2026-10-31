# Fresh replay report

- source commit: 01682108ae9ae398e0028ae2bb5870cafd5b98b5
- work dir: /home/josh/d/genesis/.work/fresh/work
- target stage: self-1.99.1
- started: 2026-10-31T09:00:16Z
- elapsed seconds: 6
- host: Linux x86_64, nproc=32
- ccache: /home/josh/d/genesis/.work/fresh/work/cache/ccache-replay

## Toolchain versions
- seed: rustc 1.29.100 (mrustc v0.12.0 master:db0c35d)
- seed-1.90: rustc 1.90.0-stable-mrustc / cargo 1.90.0 (840b83a10 2025-07-30)
- 1.91.1: rustc 1.91.1 (ed61e7d7e 2025-11-07) (built from a source tarball) / cargo 1.91.1 (ea2d97820 2025-10-10) (built from a source tarball)
- 1.92.0: rustc 1.92.0 (ded5c06cf 2025-12-08) (built from a source tarball) / cargo 1.92.0 (344c4567c 2025-10-21) (built from a source tarball)
- 1.93.1: rustc 1.93.1 (01f6ddf75 2026-02-11) (built from a source tarball) / cargo 1.93.1 (083ac5135 2025-12-15) (built from a source tarball)
- 1.94.1: rustc 1.94.1 (e408947bf 2026-03-25) (built from a source tarball) / cargo 1.94.1 (29ea6fb6a 2026-03-24) (built from a source tarball)
- 1.95.0: rustc 1.95.0 (59807616e 2026-04-14) (built from a source tarball) / cargo 1.95.0 (f2d3ce0bd 2026-03-21) (built from a source tarball)
- ref-1.96.0: rustc 1.96.0 (ac68faa20 2026-05-25) (built from a source tarball) / cargo 1.96.0 (30a34c682 2026-05-25) (built from a source tarball)
- ext-1.96.1: rustc 1.96.1 (31fca3adb 2026-06-26) (built from a source tarball) / cargo 1.96.1 (356927216 2026-06-26) (built from a source tarball)
- ext-1.97.1: rustc 1.97.1 (8bab26f4f 2026-07-14) (built from a source tarball) / cargo 1.97.1 (c980f4866 2026-06-30) (built from a source tarball)
- ext-1.98.1: rustc 1.98.1 (48a229cea 2026-09-01) (built from a source tarball) / cargo 1.98.1 (797e8a9bc 2026-08-05) (built from a source tarball)
- ext-1.99.1: rustc 1.99.1 (58cf8f9c3 2026-10-13) (built from a source tarball) / cargo 1.99.1 (5f94df478 2026-08-27) (built from a source tarball)
- self-1.99.1: rustc 1.99.1 (58cf8f9c3 2026-10-13) (built from a source tarball) / cargo 1.99.1 (5f94df478 2026-08-27) (built from a source tarball)

## Provenance
- built in this work dir: mrustc/minicargo, the 1.90 seed, every ladder rung, and the same-version rebuild
- shared sources: downloaded from sources.toml and verified by SHA-256
- borrowed runtime/tools: host cc/c++/clang/musl-dev, mold, python3, make, tar, curl, ccache
- no ambient rustc/cargo was visible on PATH

## Results
- smoke suite: pass, including static-pie output inspection (final and relocated prefixes)
- external rustfilt 0.2.1: pass
- same-version rebuild: pass
- relocation: pass (build/artifacts/downloads hidden)

## ccache
    Cacheable calls:   129 /  131 (98.47%)
      Hits:            128 /  129 (99.22%)
        Direct:        128 /  128 (100.0%)
        Preprocessed:    0 /  128 ( 0.00%)
      Misses:            1 /  129 ( 0.78%)
    Uncacheable calls:   2 /  131 ( 1.53%)
    Local storage:
      Cache size (GB): 0.1 / 30.0 ( 0.37%)
      Hits:            128 /  129 (99.22%)
      Misses:            1 /  129 ( 0.78%)

## Runtime contract
- RUST_MIN_STACK=16777216 is used for LLVM-23 compiler builds (1.99.1 and self-build).
- Functional smoke and external tests run without it; compiler-sized LTO builds should keep it.

> This raw report is the final verification rerun over completed stages; the
> chain build and interruption history are in `replay-fresh.md`.
