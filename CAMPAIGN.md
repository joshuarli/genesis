# Rust bootstrap campaign — paused after cleanup

## Status

paused 2026-11-02 with `.work/` at zero, pending a host with at least 512 GB
free. `master` is green (doctor, runner tests, closure resolver, and the Rust
1.99.1 smoke/external acceptance). The StageX lower build driver is merged
(`158d0d1`), but the full source closure was never completed: it is parked at
`bootstrap-stage1`, so S9 remains incomplete and
`recipes/lower-chain.sh verify-lower-closure` fails by design. The removed
`.work/` held only downloads, builds, logs, caches, and prefixes; they are
disposable and reproducible from `sources.toml` and the committed recipes.

Last accepted code revision: `1e903f9`; the Rust 1.99.1 PoC, same-version
rebuild, and fresh-checkout replay remain accepted. Closure measurement is
committed: 35 packages and 308 source archives
(`records/reports/lower-closure.md`). No campaign process remains.

Resume prompt: "Continue the Genesis campaign; finish the StageX lower
closure." First command: `recipes/lower-chain.sh build` (recreates `.work/`;
the driver refuses to start below 512 GB free).

Retry condition for S9: run `recipes/lower-chain.sh build` on a builder with
at least 512 GB free on the work and Docker filesystems, then finish the pinned
StageX `bootstrap` and `core-rust` targets and the driver's 1.96.0-1.99.1
stages and functional tests. The previous builder needed a local
`sitecustomize` shim that filtered `socket.getaddrinfo` to IPv4 for StageX
fetches; recreate it only if fetches stall on IPv6.

## Post-campaign repairs (2026-10-31)

The earlier completion wording is corrected. The checked-in repository now
contains the seed and ladder recipes, the TLS shim source and test, native APK
pins with SHA-256 hashes, both Rust compatibility patches, and a fresh replay
driver. `scripts/launch.sh` now builds missing stages; `--verify` only checks
artifacts, and `--status` distinguishes not-attempted, incomplete, failed, and
passed. The smoke and external runners preserve compiler exit status, use the
selected toolchain, and keep target/output directories under a test-owned work
directory. `recipes/lower-chain.sh verify-lower-closure` fails while the lower
lineage has no compiler-producing consumers.

## Charter

- Decide and keep going. Record a decision only when a later slice depends on it.
- Within the granted authority proceed without approval. A plan grants no extra permission. Park items needing more authority.
- Hard stops (park the item): irreversible/destructive act, outside-repo write, pushing, deleting a promoted prefix, or a loop with no checkable proof. Pushing is always forbidden.
- Fix egregious breakage met on the way in its own commit when cheap and measurable: build removes >1 GB shared cache, log hides exit status, retry turns failure into success, wrapper re-enables a disabled codegen path. Otherwise record and leave.
- Parity before optimization. No S8 tuning gates S2–S7 except a repair that unblocks delivery with an exit test.
- One writer by default. Parallel only for pairs named in Sequence, in worktrees at `.work/wt/<lane>` per orchestrate lifecycle, never an OS temporary directory. Repo scratch is `.work/`.
- Every commit is Conventional Commit with workstream scope; item ID in body. Code never cites this doc.

## Decisions

Owner (2026-10-30): doc lives in new `CAMPAIGN.md`; existing docs stay as reference.
Owner: executor may use network fetches and docker on the builder, up to available disk (~344 GB free).
Owner: executor resolves and pins the exact StageX bundle on the builder; records hashes.
Owner: Rustic generated-C runs as a parallel lane now, not deferred (owns only `.work/rustic/*`).
Prescribed: canonical target is native Linux x86-64/musl via StageX workflow; GNU/glibc control is a separate workdir, never a substitute. Reason: only musl recipe is the integration reference; mixing bundles caused the earlier plan's risk.
Prescribed: reference endpoint 1.96.0 and extension 1.96.1 are distinct checkpoints; branch extension from the retained predecessor (1.95.0 or recipe-specified), never overwrite 1.96.0. Reason: audit found they are different artifacts.
Prescribed: S8 optimization moves after S7 functional gates. Reason: parity-first; tuning a broken chain is slow.
Prescribed: no new DAG/controller/test framework before S5 needs one; thin launch/resume/test scripts only. Reason: P0 audit finding.
Prescribed: ccache mandatory for three consumers (mrustc C++, generated C via `MRUSTC_CCACHE`, source-built LLVM); sccache optional after S5 with separate namespace and `CARGO_INCREMENTAL=0`. Reason: measured loop needs C++ hits first; sccache has documented exclusions.
Prescribed: `MINICARGO_DEFER_CODEGEN=0` does not disable the path (presence test); unset the variable or apply narrow explicit-control patch. Reason: inspected minicargo source.
Prescribed: each promoted prefix keeps its native runtime closure side by side across LLVM upgrades. Reason: Chimera evidence on predecessor survival.
Prescribed: `RUST_MIN_STACK=16777216` and Alpine/Chimera late fixes are version-specific triage, not global flags. Reason: tied to LLVM-23 late ladder.
Delegated (bound): patch classification (compatibility/policy/performance) with one-line why per deviation; smallest reversible assumption, logged. Reversed if 1.96.0 reproduction needs the unmodified series.
Delegated (bound): job counts starting at 12 C++/8 Rust/2 minicargo/1 large link; reduce on cgroup/OOM first, never multiply schedulers to `nproc`. Reversed by measured OOM or sustained idle CPUs.
Delegated (bound): Rustic stop/continue past X2; stop at first concrete blocker with gate report. Bound: no backend rewrite, no musl inference from GNU success.

## Baseline

Known red: none established; first build has no green ancestor. Executor must not mistake an imported final image for a local build (check leaf-build logs per S2/S5).
Host verified 2026-10-30: Alpine x86_64, 32 CPU, 60 GB RAM, 344 GB free (below 500 GB full-distro reference; narrow PoC only, measure high-water). `cc`/`gcc` 15.2.0, `clang` 23.1.3, `ccache` 4.13.6, docker 29.9.0 all present; C probe compiles and runs; `docker run alpine:3.21` works; stagex.tools and mrustc GitHub return HTTP 200.
Loop timings (this host): doc-integrity check ~0.01 s; C probe 0.01–0.03 s; `docker info` 0.04 s; `curl -I` stagex 0.96 s, GitHub 0.59 s; `docker run` with pull 1.7 s. Fences balanced in all docs; R01–R31 defined (one `R2` hit is S3/R2 object-store prose, not an ID). No compiler-build timing exists yet; S1 establishes it.

## Sequence

Serial except where `parallel` is stated. Each item owns its files; sharing items run serially. Attempt limit 3 per item, then park on its branch with cause + retry condition.

- S1 pin + doctor. Owns `.work/pins/*`, `scripts/doctor.sh`, `scripts/launch.sh`. Prereq: none. Acceptance: `./scripts/doctor.sh` passes in <2 min (native C/C++ run, LLVM load, disk/cgroup report, StageX pin record with hashes).
- S2 seed build (mrustc/minicargo compile and run). Owns `.work/build/seed/*`, `.work/logs/seed/*`. Prereq: S1. Acceptance: binaries execute; log shows local compilation commands and native identity; `scripts/launch.sh --until seed` resumable.
- S3 normalize + 1.90 seed validation. Owns `.work/artifacts/seed-1.90/*`. Prereq: S2. Acceptance: smoke workspace builds and runs outside the build tree; handoff record (rustc/cargo/sysroot/triple/LLVM/native root) written.
- S4 first handoff 1.90→1.91.1. Owns `.work/build/1.91.1/*`, `.work/artifacts/1.91.1/*`. Prereq: S3. Acceptance: 1.91.1 rustc/cargo/sysroot serve as next predecessor; smoke passes; seed + 1.91.1 retained.
- S5 reference endpoint 1.96.0. Owns `.work/artifacts/ref-1.96.0/*`, per-release prepared trees. Prereq: S4. Acceptance: declared functional checks pass; log proves local Rust compilation, not final-layer import; required runtime files present.
- S6 extension ladder to 1.99.1 (1.92.0→…→1.99.1, 1.96.1 separate from 1.96.0). Owns `.work/build/ext-*`, `.work/artifacts/ext-*`. Prereq: S5. Acceptance per release: predecessor pins explicit, `download-rustc=false`, smoke passes; failure resumes at its release.
- S7 usability + same-version rebuild. Owns `tests/smoke/*`, `tests/external/*`. Prereq: S6. Acceptance: proc-macro/build.rs/FFI/threads-TLS/unwind fixture passes; one pinned external CLI builds offline; fresh-workdir same-version rebuild executes compilation and yields working tools outside the original tree.
- S8 loop optimization. Owns `scripts/*cache*`, configs only. Prereq: S7 (may repair S2–S6 loop earlier with exit test). Acceptance: no-op rerun skips completed stages; README-only touch rebuilds nothing; eligible C object shows ccache hit; timings explain result.
- S9 Hex0 lower closure. Owns `recipes/lower-chain.sh`, `.work/lower/*`. Prereq: S7. Acceptance: recorded compiler-producing path seed→final Rust reruns consumers under new identity; same functional tests pass.
- S10 clean replay. Owns `.work/replay/*` (fresh output/cache namespace; sources may be shared). Prereq: S9 (S7 minimum for partial replay). Acceptance: replay finishes with scope statement and match/difference report; no imported compiler objects or foreign cache entries.
- X1 Rustic C-snapshot, bounded (parallel-eligible with S2–S6 only; owns `.work/rustic/*` and nothing else). Prereq: S1. Acceptance ladder X0 archive inventory → X1 rebuild without installed Rust → X2 ordinary programs on declared sysroot → X3 cargo/proc-macro/build.rs/FFI/unwind → X4 compiler-sized workload → X5 next-release handoff → X6 musl separately. Stop at first blocker; record highest gate.
- CLOSE. Owns removals + report. Prereq: S10, X1 parked or complete. Acceptance: dead code/trees removed with liveness proof, `ultrareview` P1/P2 fixed, final report with pins, stages, and replay scope.

## Acceptance

- A: source-Rust PoC (S1–S7): 1.99.1 rustc+cargo+matching libraries build and run fixture programs outside the build tree; no ambient Rust supplied the lineage. Command: `tests/smoke/run.sh --prefix .work/artifacts/ext-1.99.1/prefix && tests/external/run.sh --prefix .work/artifacts/ext-1.99.1/prefix`.
- Reference fidelity (S5): 1.96.0 matches selected recipe behavior; log shows local leaf build. Command: `./scripts/launch.sh --verify ref-1.96.0` (artifact check) and `recipes/replay.sh --until ref-1.96.0` (build evidence).
- Same-version rebuild (S7): fresh-workdir self-build executes compilation, not uplift/copy. Command: `./scripts/launch.sh --rebuild-same-version 1.99.1 && tests/smoke/run.sh --prefix .work/artifacts/self-1.99.1/prefix`.
- Loop (S8): `scripts/cache-stats.sh` shows eligible hit; `time ./scripts/launch.sh --until ext-1.99.1` no-ops fast; `git status` of prepared trees explains invalidation.
- B: lower closure (S9): `recipes/lower-chain.sh verify-lower-closure` fails until the rebuilt lineage has compiler-producing consumers; `inventory` only reports present artifacts.
- C: replay (S10): `recipes/replay.sh --work-dir .work/replay-fresh` executes the build and writes `REPLAY.md`; `recipes/lower-chain.sh show-report` only displays reports.
- Rustic (X1): per-gate evidence recorded; `tests/smoke/run.sh --prefix .work/rustic/<gate>` or blocker log with exact command and first error. No Rustic artifact enters the canonical chain silently.
- Negative/compat: invalid programs fail under native rustc (type/lifetime/malformed); musl default-linking and any promised static mode tested by inspecting output, not triple name.

## Needs environment

The StageX lower build requires at least 512 GB free on the work and Docker filesystems. This host has about 200 GB, so S9 stays parked until the checkout moves to a larger machine. The driver enforces the floor before creating work state. This is a conservative floor for the narrow Rust closure with headroom; the full StageX distribution remains out of scope. If cgroup/memory blocks the late ladder or LLVM source build, record the exact command, limit, and high-water mark here and park only that item.

## Execution boundary and non-goals

Allowed: network fetches of pinned sources; docker/StageX workflow; writes under `.work/`; ccache/sccache local caches; reading Gentoo/Guix/Alpine/Chimera/Rustic recipes for comparison.
Forbidden: `git push`; `docker system prune` / wiping shared caches; reapplying patches onto dirty trees; `find | head` Cargo selection; `--bless`/new skips to green; silent official-Rust fallback (`download-rustc` must stay false); mounting home directory or secrets; deleting a promoted prefix another stage needs.
Non-goals (no work, no proof): new C dialect/frontend, LLVM replacement, libc/TLS/shell/kernel builds, AArch64/macOS/Windows, static-everything, PGO/LTO/BOLT, byte-identity with official binaries, provenance/DDC, remote caches, package manager, larger controller CLI beyond thin scripts.
Contract changes for owner: musl host-vs-output linking policy chosen at S3 and frozen in handoff records; any advertised static output must retain CRT/archives and tests.

## Reference

Docs: `CODING_AGENT_PROMPT.md` (handoff, 120 lines), `RUST_BOOTSTRAP_ROADMAP.md` (work packages M0–M8, sections 6–11), `AUDIT_AND_PRIOR_ART.md` (P0–P2 findings, Rustic gates X0–X7), `RESEARCH_INDEX.md` (R01–R31). Verified: stagex.tools Rust page HTTP 200, mrustc GitHub HTTP 200, native toolchain runs. Pins resolve on builder into `.work/pins/`; research URLs are not a lockfile.
