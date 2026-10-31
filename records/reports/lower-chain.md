# S9 lower-closure report (2026-10-31, bounded scope)
## Correction (2026-10-31)
The old `--verify` command only checked that recorded paths existed; its
`VERIFY_OK` did not establish a lower-chain closure. The current
`recipes/lower-chain.sh verify-lower-closure` fails explicitly because no
compiler-producing consumer was rebuilt under the new lineage. `inventory`
only lists artifacts.
## Provenance of every lower input
Borrowed (declared, S10-excluded): host cc/gcc 15.2.0, clang 23.1.3, musl libc/loader,
apk LLVM 21.1.8 triple (llvm21/-dev/-static, test-utils), apk compiler-rt 23.1.4,
apk llvm-libunwind 23.1.4, host libz/zstd/ssl/curl (cargo), make/cmake/ninja/python.
In-lineage (rebuilt here or in S2/S3): mrustc+minicargo (S2), seed rustc chain (S3+),
TLS-keys shim (own C source), libunwind below (rebuilt from llvm-project source).
## Rebuilt this slice
llvm-project-23.1.4 source (sha256 819ecf73…, 179 MB) → cmake runtimes build →
.work/lower/rebuilt/{lib/libunwind.a,.so.1.0,include/*}. Consumers relinked and rerun:
static-pie smoke-unwind (standalone OK) and dynamic smoke-unwind-dyn with ONLY the
rebuilt lib on the loader path (DT_NEEDED satisfied by rebuilt artifact — identity proven).
## Parked: full Hex0-derived C++/musl closure
Cause: rebuilding the complete lower toolchain (Hex0 seed through C++ compiler,
musl, and all native deps) is a multi-day, ~500 GB full-distro reproduction;
StageX documents that scope and this campaign declares it out of scope for local
completion. Retry condition: dedicated builder + storage, or a narrowed closure
definition (e.g. musl+libunwind+compiler-rt+C++ only) with days of compute.
## Mechanism status
`recipes/lower-chain.sh inventory` lists the recorded path; it does not verify
ancestry. `verify-lower-closure` fails because the Rust compiler chain was not
rebuilt under the rebuilt lower lineage. S10 partial replay covered S2-S4 only.
