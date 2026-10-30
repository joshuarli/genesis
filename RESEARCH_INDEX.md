# Additional research index — audit revision 2

**Research date: October 30, 2026.** This index supplements S01–S24 in `RUST_BOOTSTRAP_ROADMAP.md`. R identifiers used elsewhere in this bundle refer here. URLs are implementation research references, not an already-resolved dependency lockfile. Branch heads must be pinned again when implementing. A recipe, an author-reported result, and a locally executed successful build are different evidence levels. No compiler build was executed for this audit.

## Distribution recipes and actual bootstrap handoffs

### R01 — Gentoo mrustc package

Source inspected: `dev-lang/mrustc/mrustc-0.12.0_p20261018.ebuild`. It identifies mrustc commit `d85e86b199e2522d74bee19efa6ebf3af596270f` and a GCC-based integration. File blob observed: `646c57628897456ff079e26d107178fb11d470a0`.

https://github.com/gentoo/gentoo/blob/master/dev-lang/mrustc/mrustc-0.12.0_p20261018.ebuild

**Reuse:** externally supplied Rust sources, exact patch inventory, native compiler choice, intermediate library installation, and local tests. Do not infer that the same source bundle works under unmodified Clang.

### R02 — Gentoo Rust package and `mrustc_bootstrap()`

Inspected `rust-1.90.0-r1.ebuild`; observed file blob `8cc8c6a8553f2593f44d736cb017e5fa613691bc`. The package declares `LLVM_COMPAT=(20)` and contains a dedicated mrustc normalization path referencing upstream `run_rustc/Makefile` and `TestRustcBootstrap.sh`.

https://github.com/gentoo/gentoo/blob/master/dev-lang/rust/rust-1.90.0-r1.ebuild

**Reuse:** stage-specific compiler/sysroot arrangements and cleanup of bootstrap-only environment variables. Read the whole function and its called helpers before extracting commands; an ebuild is not a standalone shell script.

### R03 — Gentoo feature description

https://packages.gentoo.org/useflags/mrustc-bootstrap

**Use:** confirms that `mrustc-bootstrap` is an explicit packaging feature, not a reconstruction inferred from package names. It is not by itself proof of every architecture or a particular complete rebuild.

### R04 — Guix Rust 1.90 bootstrap commit

Developer-authored commit diff published on the `rust-team` branch, commit `f2d57ed6ecc619b9ba09798b5c0e27778e86206e`, authored October 1 and posted October 26, 2026. It adds `rust-bootstrap-1.90`, pins mrustc `a822472b9ee744e58d8b1a79bdd8080f7a7b008f`, uses LLVM 21, and runs native sysroot normalization. Main-branch merge status and build success were not established by this audit.

https://mid.mail-archive.com/guix-commits@gnu.org/msg401755.html

**Reuse:** another explicit source-to-seed implementation to compare against, not a reason to adopt Guix as this project's runtime.

### R05 — StageX Rust recipe, detailed inspection

Rendered package page inspected: Rust 1.96.0. Its source link identifies snapshot `9bdf430d09ce2ba53932df0182faef00d4feecd1`. Direct Codeberg raw retrieval was unavailable in this research environment; use the package's source link and resolve the complete recipe/dependency pins on the builder.

https://stagex.tools/packages/core/rust/

**Reuse:** primary musl integration. Preserve a reference reproduction before changing distribution policy or extending releases. See the audit for the important distinction between bootstrap compatibility and final-package target policy.

### R06 — StageX development/reproduction workflow

https://docs.stagex.tools/project/contribute-to-stagex/

https://docs.stagex.tools/get-started/reproduce-stagex/

**Reuse:** upstream Make/container dependency orchestration, dependency imports for development, and the separate no-preseed reproduction path. Inspect the selected revision's cache/import controls rather than inventing their behavior.

### R07 — Alpine current Rust package

Inspected default-branch `main/rust/APKBUILD`: Rust **1.99.1**, LLVM **23**, bootstrap Rust **1.99.0**. This is a packaging configuration observation, not an independently reproduced source-only lineage.

https://github.com/alpinelinux/aports/blob/master/main/rust/APKBUILD

**Reuse:** late-ladder musl compatibility, native dependency selection, target-triplet handling, and LLVM-23 stack-size guidance. The recipe deliberately avoids arbitrary system libgit2; inspect this before “unbundling” Cargo dependencies. Its bootstrap packages already supply Rust, so this is not a replacement for mrustc.

### R08 — Chimera Linux Rust package

Inspected `main/rust/template.py`: Rust **1.99.0**, Clang/musl/libc++-oriented native configuration, separate bootstrap packaging, explicit runtime/library handling.

https://github.com/chimera-linux/cports/blob/master/main/rust/template.py

**Reuse:** adjacent musl/Clang packaging prior art, C++ runtime linkage, host/target environment separation, and preserving bootstrap compilers across LLVM changes. It consumes existing Rust/Cargo bootstrap packages; do not describe it as an independent seed.

## Generated-C alternatives — experiments, not replacements for the accepted lineage

### R09 — Rustic README

https://github.com/rustic-compiler/rustc_codegen_c

Observed README file blob: `f8f9980bd0325139487619b0068c384ba67a1539`. Documents a forked-rustc C backend and rebuilding a compiler from a generated-C release archive. Reports 99.2% of a rustc UI suite passing for the backend-built compiler. That percentage is an upstream claim, not an end-to-end result from this audit and not automatically the standalone archive's result.

**Important identity:** this is `rustic-compiler/rustc_codegen_c`, not `rust-lang/rustc_codegen_c`.

### R10 — Rustic release assets

Inspected release `release-1.94.1-2`, published May 28, 2026. The observed C-source and toolchain assets cover GNU/Linux x86-64 and AArch64 with GCC/Clang variants. The source asset is distinct from the binary toolchain asset. No musl source-archive result was established.

https://github.com/rustic-compiler/rustc_codegen_c/releases/tag/release-1.94.1-2

**Use:** a concrete candidate for the bounded C-snapshot experiment. Inspect archive contents and build them; do not infer completeness from asset naming.

### R11 — Rustic CI artifact construction

Inspected file blob `cf045a5305c375296173a818d24b0d22a153eb58`. The workflow uses fork branch `rustic-1.94.1`, runs backend tests, and constructs separate binary-toolchain and generated-C artifacts.

https://github.com/rustic-compiler/rustc_codegen_c/blob/6731c737826a04162acc5027089d2b54a321766c/.github/workflows/ci.yaml

**Reuse:** artifact-generation recipe. Inspect the compiler/standard-library C-file collection separately from the installed toolchain; Cargo, crate metadata, and all runtime inputs must be accounted for explicitly.

### R12 — Rustic standalone native fallbacks

https://github.com/rustic-compiler/rustc_codegen_c/blob/6731c737826a04162acc5027089d2b54a321766c/src/native_stubs.rs

https://github.com/rustic-compiler/rustc_codegen_c/blob/6731c737826a04162acc5027089d2b54a321766c/src/c/native_stubs.c

Observed C file blob: `ba875d9869bbb59489943f71f71d6f675e42a863`. The standalone build uses weak fallback implementations instead of some build-script-produced native code. In particular, the inspected PSM fallback does not actually switch to the supplied stack.

**Consequence:** separately test the standalone-generated compiler under recursion/stack pressure, procedural macros, unwinding, and self-compilation. This is a concrete test concern, not a blanket conclusion that all such builds fail.

### R13 — Rustic generated-C invocation and Makefile emission

https://github.com/rustic-compiler/rustc_codegen_c/blob/6731c737826a04162acc5027089d2b54a321766c/src/write.rs

Observed file blob: `c008d934a548a031c81be7cbc6fa5d1ef4fe667a`. The inspected backend invokes `CC` as a single executable, fixes important code-generation flags, and emits a standalone Makefile with native dependency handling.

**Consequence:** an executable ccache wrapper is appropriate when a consumer does not split `CC`; `CC="ccache gcc"` is not a universally valid interface. Do not override optimization/aliasing/unwinding flags casually in this experiment.

### R14 — Original Rust C backend project

https://github.com/rust-lang/rustc_codegen_c

**Reuse:** backend API and experimental C codegen prior art. Do not transfer Rustic's capabilities or release artifacts to this repository merely because the basename matches.

### R15 — FractalFir C/.NET backend

https://github.com/FractalFir/rustc_codegen_clr

**Reuse:** additional Rust-to-C lowering and testing prior art. A rustc codegen plugin is not an independent Rust frontend. No suitable full contemporary source-bootstrap recipe was established here.

## Backend alternatives and independent compiler boundaries

### R16 — GCC backend self-bootstrap results

https://blog.rust-lang.org/2025/11/18/gsoc-2025-results/

Official Rust project report describes successful stage-2 and stage-3 rustc builds using `rustc_codegen_gcc`.

**Reuse:** a concrete later LLVM-removal experiment. It still uses the rustc frontend and requires the matching backend/GCC integration; it is not `gccrs`, and it does not establish our current musl release ladder.

### R17 — gccrs status

https://rust-gcc.github.io/2026/09/08/2026-08-monthly-report.html

Inspected August 2026 report, published September 8: work was still progressing through `core` compilation. This report does not supply an alternative modern-rustc bootstrap entry point.

**Decision:** monitor independently; do not put completion of gccrs on this project's critical path.

### R18 — Cranelift backend

https://github.com/rust-lang/rustc_codegen_cranelift

**Reuse:** later codegen/performance experiments and its existing backend test infrastructure. Backend substitution is different from breaking the Rust frontend's seed dependency.

## Other distribution and lower-bootstrap precedents

### R19 — Nixpkgs source-bootstrap proposal, with actual status

https://github.com/NixOS/nixpkgs/pull/528074

At inspection: **closed, unmerged**, closed June 28, 2026. Head `71f9844a5a5e43e84f8b306c31efe7b1d327c4eb` in `poelzi/nixpkgs`. The proposal describes an mrustc-to-1.96 route and author-reported x86-64 Linux testing.

**Reuse:** reviewable derivation ideas and failure/maintenance discussion. Do not describe the proposal as Nixpkgs' accepted default bootstrap.

### R20 — Author's corrected Nix bootstrap account

https://voxel.esq/blog/the-compiler-you-didnt-build/

The July 24, 2026 post carries a July 26 correction retracting its original claim that an automated update had completed the 1.90-to-1.97 compiler chain.

**Use:** evidence-quality lesson only: workflow completion, artifact availability, and compiler success must be separate signals. The rhetoric of the article is not part of this plan's threat model.

### R21 — Freedesktop SDK

https://freedesktop-sdk.gitlab.io/documentation/wiki/Freedesktop-SDK-Binary-Seed.html

https://freedesktop-sdk.gitlab.io/documentation/reference/api-reference/fdsdk/elements/components/rust.html

**Reuse:** source-built native SDK ancestry, BuildStream dependency/artifact organization, Rust packaging. The inspected Rust component consumes `rust-stage1`; this audit did not resolve that entire predecessor's ancestry. Do not infer a no-binary-Rust guarantee from a small native-toolchain seed alone.

### R22 — Onramp

https://github.com/ludocode/onramp

https://github.com/ludocode/onramp/blob/develop/docs/bootstrap-path.md

**Reuse:** staged minimal C and VM bootstrap design. The inspected README explicitly marks the project unfinished, including missing floating-point/libc functionality. It is not a demonstrated C++/LLVM/mrustc bridge.

### R23 — boot2

https://ryansepassi.com/notes/boot2-c

https://git.ryansepassi.com/boot2/file/README.md.html

**Reuse:** small staged C/Scheme/TCC/musl bootstrap architecture and architecture-separated drivers. The documented C endpoint is not itself the C++ and LLVM environment needed by the selected Rust route. Keep kernel/VM modes separate from host-driven development.

### R24 — Nim generated-C bootstrap

https://github.com/nim-lang/Nim

https://github.com/nim-lang/csources_v3

**Reuse:** practical precedent for distributing generated C as a compiler bootstrap artifact. The relevant lesson is versioned regeneration and a clearly declared seed, not using Nim as another prerequisite. A generated-C snapshot does not independently prove its derivation.

### R25 — Zig historical WASM-to-C bootstrap

https://github.com/ziglang/zig/blob/master/bootstrap.c

https://github.com/ziglang/zig-bootstrap

https://github.com/ziglang/zig

**Scope:** the inspected GitHub material is historical/archive material; the repository explicitly says development moved to Codeberg and it is not mirrored. The historical bootstrap compiles a small wasm2c tool, translates `zig1.wasm`, and compiles resulting C.

**Reuse:** compact bootstrap drivers and portable seed packaging. A prebuilt WASM compiler remains a compiler seed; conversion to C does not remove that assumption. Do not cite this archive as the latest Zig implementation or as a Rust solution.

## Existing measurement and validation infrastructure

### R26 — Native Rust bootstrap metrics

https://github.com/rust-lang/rust/blob/92b5b8c87c61b20adc9001b41baf587634a74734/src/ci/run.sh

https://github.com/rust-lang/rust/blob/92b5b8c87c61b20adc9001b41baf587634a74734/bootstrap.example.toml

**Reuse:** existing step timing, resource usage, and metrics options. Check each selected release's configuration before enabling them; a default-branch example is not a promise that every old tag supports identical keys.

### R27 — Cargo timings

https://doc.rust-lang.org/cargo/reference/timings.html

**Reuse:** existing `--timings` reporting. Use native build-system output before creating a custom profiling dashboard.

### R28 — Rust compiler test infrastructure

https://rustc-dev-guide.rust-lang.org/tests/intro.html

**Reuse:** compiletest, targeted UI/run-make tests, standard-library tests, and tool tests. Select a useful subset before requiring the entire compiler suite.

### R29 — ABI Cafe

https://github.com/Gankra/abi-cafe

**Reuse:** later C/Rust ABI comparison instead of a homegrown ABI fuzzer. Its own documentation warns that generated experiments may contain undefined behavior; mismatches require interpretation and are not automatic miscompilation proofs.

### R30 — Rustlantis

https://github.com/cbeuw/rustlantis

**Reuse:** later MIR-level differential testing. It targets rustc internals and documented nightly tooling, not necessarily the valid source subset accepted by mrustc. Keep it outside the initial bootstrap dependency chain.

### R31 — Reproducible-build comparison tooling

https://diffoscope.org/

https://reproducible-builds.org/tools/

**Reuse:** compare and explain artifacts in later clean-replay work. Do not implement a new ELF/archive differ or make these optional audit tools part of the compiler-producing bootstrap prerequisites.

## Research limitations

This audit inspected documentation, package recipes, implementation code, release metadata, and proposal status. It did not download/extract Rustic's large release archive, reproduce CI, compile mrustc/rustc, test cache hits, or independently prove any upstream success claim. Some raw Codeberg/GitLab paths were inaccessible; rendered upstream pages and an authored commit diff are identified above. These limitations are converted into specific implementation gates in the audit and roadmap, rather than hidden behind a claim of exhaustive verification.
