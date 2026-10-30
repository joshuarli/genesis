# Rust bootstrap: feasibility-first implementation roadmap — revision 2

**Research cut:** October 30, 2026  
**Revision:** 2 — sanity/completeness and prior-art audit incorporated  
**Initial target:** Linux x86-64, musl, native execution  
**Frozen initial Rust destination:** 1.99.1  
**Working project name:** `rust-bootstrap` — a suggested name, not an existing repository claim  
**Status:** Researched implementation plan. No bootstrap build was executed while preparing either revision.

**Companion documents:** `AUDIT_AND_PRIOR_ART.md` explains the findings and changes; `RESEARCH_INDEX.md` contains additional references R01–R31; `CODING_AGENT_PROMPT.md` is the execution handoff. References S01–S24 remain in section 18. This revision supersedes the earlier roadmap, but deliberately retains its useful engineering work packages.

## 0. The mandate

Build a working, resumable path from an independently implemented Rust compiler to modern `rustc` and Cargo. Then replace its borrowed C/C++ toolchain with a Hex0-derived toolchain. Only after those paths work should the project pursue language restrictions, smaller implementations, stronger provenance, reproducibility, or formal verification.

The ordering is deliberate:

> First make Rust compile Rust. Then make the complete compiler ancestry rebuildable. Then make the ancestry smaller and easier to trust.

GNU/Clang extensions, C++, LLVM, compiler-specific flags, upstream patches, dynamic linking, Bash, Python, ordinary build utilities, prebuilt **native-toolchain and build dependencies**, and local compiler caches are acceptable in the first proof of concept. Do not turn eventual aesthetic or verification goals into prerequisites for obtaining the first functioning compiler.

A prebuilt official Rust toolchain may be used in an isolated diagnostic/control experiment. It must not silently supply a compiler, Cargo, standard library, procedural-macro library, or bootstrap executable to the accepted mrustc-derived Rust lineage. That distinction is the experiment, not an early security certification exercise.

Do not begin by writing a new C compiler, defining Core C, replacing LLVM, porting mrustc out of C++, building a kernel, or inventing a general-purpose package manager.

### 0.1 Revision-2 implementation priority: reproduce before extracting

Start by executing one pinned upstream recipe in its intended native environment. For the canonical musl route, use the selected StageX workflow and reproduce its inspected 1.96.0 endpoint. Keep the mrustc seed and first-release handoff as early observable checkpoints. Only then extend the release ladder or extract more standalone glue.

Do not combine Gentoo's GCC integration, StageX's Clang patches, Tolnay's GNU configuration, and an arbitrary mrustc head into a new recipe before obtaining a reference result. Treat source, patches, C++ runtime, native libraries, LLVM, and seed-normalization logic as one compatibility bundle.

A small wrapper can retain artifacts, expose existing stages, or record commands. A new general runner, test harness, cache service, or dependency resolver is not the first deliverable. Existing Make/BuildKit/Ninja/Cargo/bootstrap tools should do the work they already implement. [R01–R06]

## 1. Define success precisely, without making it burdensome

There are three principal deliverables and one later assurance level.

| Level | What must work | What remains borrowed or unproven |
|---|---|---|
| **A: source-Rust PoC** | C++-built mrustc/minicargo produce a usable Rust seed; that seed reaches the frozen target; the final rustc, Cargo, and matching libraries build and run programs | Host OS, C/C++ compiler, LLVM, libraries, build tools, and caches may be imported |
| **B: Hex0-derived toolchain** | The compiler-producing dependency closure is rebuilt through the selected StageX/Stage0 route and feeds the same Rust pipeline | Kernel, hardware/VM, container engine, and orchestration remain explicitly outside the claim |
| **C: clean replay** | A separate run reconstructs the claimed closure without imported compiler objects or prebuilt toolchain layers; outputs and differences are recorded | This is still not a proof of compiler correctness or absence of malicious source |
| **D: stronger assurance** | Independent reproduction, reduced dependencies, carefully designed diverse compilation, and selected semantic verification | Each assertion needs its own evidence; none follows merely from reaching C |

Local cache reuse is normal in A and ordinary B development. A cache entry is an input, not evidence of lineage. The stronger C run gets separate output/cache state and either rebuilds or explicitly accounts for every admitted artifact.

The first end-to-end milestone is A, not a cold rebuild of an entire distribution. Keep this written at the top of the issue tracker.

## 2. Research conclusions that determine the design

### 2.1 The independent Rust entry point exists

mrustc is implemented in C++, emits C, and is intentionally oriented toward compiling existing valid Rust rather than replacing rustc's full validation machinery. Upstream reports a tested Rust 1.90.0 bootstrap and a binary-equal 1.91.1 result in its tested setup. Its README also retains historical defaults that are not the current bootstrap goal. Set the intended Rust version explicitly. [S01]

The version-specific 1.90 helper enables `MRUSTC_CCACHE` when ccache is present. It warns about races in deferred code generation. The currently inspected minicargo implementation checks the **presence** of `MINICARGO_DEFER_CODEGEN`, not whether its string value is `1`; setting it to `0` therefore does not disable that path. Its convenience wrapper also reinstates the default. Inspect these details at the actual pinned revision. [S02, S03]

**Consequence:** reuse the compiler and scripts, but expose the real stages and recovery controls instead of treating one opaque shell invocation as the whole project.

### 2.2 The release ladder already exists

The inspected `dtolnay/bootstrap` version manifest selects mrustc 0.12.0 and this sequence:

```text
1.90.0 → 1.91.1 → 1.92.0 → 1.93.1 → 1.94.1
       → 1.95.0 → 1.96.1 → 1.97.1 → 1.98.1 → 1.99.1
```

Its orchestration builds the mrustc seed, runs `run_rustc`, and then invokes each Rust source tree using explicit predecessor toolchains. Its setup is GNU/Linux-oriented; it is a recipe and release-ladder reference, **not a demonstration that these same configurations have already passed on musl**. [S04–S07]

**Consequence:** use the existing ladder. Do not start with Rust 1.19 and replay the entire language history. Do not skip releases until the adjacent-release route is green.

### 2.3 StageX is the primary musl integration reference

The inspected StageX package page publishes Rust 1.96.0. Its recipe enters through Rust 1.90, uses musl and Clang/LLVM, and handles several compatibility patches. It has a historical LLVM 21 dependency, later switches LLVM selection, and uses dynamic linking for the bootstrap. These are useful compatibility evidence, not a locally reproduced result. [S08]

StageX separately documents a tiny x86 seed stage and a live-bootstrap-derived stage. The latter explicitly turns off kernel bootstrapping in the inspected recipe. Do not describe this containerized route as reconstructing the host kernel or hardware. [S09, S10]

**Consequence:** reproduce the pinned musl integration before assembling a new adapter; bring the lower ancestry in later. A separate GNU/glibc control build is permissible for diagnosing a blocker, but does not replace the musl target. Keep the exact reference endpoint distinct from the later extension.

### 2.4 Rust's internal staging is not the same as the release ladder

Rust's bootstrap redesign retains previous-release-to-next-release support, but standard-library staging changed. A compiler executable without its appropriate sysroot is not a usable predecessor toolchain. Commands that only build stage-0 libraries can be inappropriate or no-ops in the redesigned sequence. [S11]

The inspected 1.99.1 configuration supports explicit `build.rustc`, `build.cargo`, and `build.ccache`. It also documents source-vs-CI LLVM selection and compiler-download controls. Always inspect each tagged source tree rather than projecting today's configuration onto older releases. [S12]

**Consequence:** model each handoff as a complete toolchain, not a path to `rustc` alone.

### 2.5 Caching is useful, but different layers solve different problems

ccache handles C/C++ compilation; it does not cache Rust compilation. Its content-based compiler check is specifically useful when compiler binaries change during bootstrap. [S13]

sccache supports eligible Rust compilations but requires incremental compilation to be disabled for that mode; its documented limitations include link-producing crates and some procedural-macro dependencies. It is optional for the first pass. [S14]

Persistent build directories and complete installed toolchain checkpoints avoid work that object caches cannot eliminate. Container cache mounts also differ from final image contents. [S15, S16]

**Consequence:** implement checkpointing and C/C++ caching first. Add measured Rust object caching later, without building a second bootstrap problem around the cache helper.

### 2.6 Distribution integration deserves first-class reuse

Gentoo has both an mrustc package and a dedicated `mrustc_bootstrap()` procedure in its Rust package. Guix has a separately organized Rust 1.90 bootstrap branch change. These are concrete normalization references, not merely background reading. Compare them when diagnosing a handoff; do not wholesale merge their environment and patch choices. [R01–R04]

Alpine's inspected Rust 1.99.1 recipe and Chimera's 1.99.0 template are useful late-ladder musl packaging references. They consume existing Rust bootstrap packages and therefore do not replace the independent seed. [R07, R08]

### 2.7 An optional C-snapshot experiment is now justified

Rustic documents generated-C compiler snapshots. This deserves a separate bounded experiment, with acceptance gates in section 20, rather than exclusion from the research. It is not the same lineage as an independently implemented frontend, and the standalone C artifact must be tested separately from a compiler built normally using the backend. Preserve the canonical mrustc path. [R09–R15]

### 2.8 Do not equate alternative backends with independent frontends

The official Rust report on `rustc_codegen_gcc` supplies stronger self-bootstrap prior art than the earlier discussion acknowledged. Evaluate it in the later reduction phase, rather than implementing a new backend. gccrs and Cranelift have different roles and must not be treated as interchangeable seed solutions. [R16–R18]

## 3. Scope and architectural decisions

### 3.1 Initial execution target

Use native Linux x86-64 with musl. Prefer a headless native Linux builder; the user's 9950X/64 GB machine is an appropriate candidate if it is available for this work. A Mac can be the control/editor machine. Do not make x86 emulation on Apple Silicon, macOS-native Rust bootstrapping, or an AArch64 port the first gate.

Use the existing StageX-compatible container workflow for the musl reference. Borrow the build environment and dependency images in development. An Alpine-based development environment is an acceptable adapter if needed, but avoid changing libc, C++ runtime, linker, LLVM revision, and mrustc revision simultaneously.

Do not rely on systemd, desktop services, or D-Bus. None is a project feature.

### 3.2 Freeze the destination

Rust 1.99.1 was announced on October 15, 2026. Freeze it for the initial implementation rather than following a floating `stable` target. A future update is a separate change after the baseline works. [S17]

An exact StageX 1.96.0 reproduction is the reference milestone before extension. Keep it distinct from the chosen ladder's 1.96.1 step; these are not interchangeable artifacts. Branch the extension from the last appropriate retained predecessor, using the selected per-release adapter. Do not invent a same-release edge simply to avoid showing two branches in the plan.

### 3.3 Borrowed dependencies are a feature of the PoC

In development, allow prebuilt musl-native C/C++ compilers, compatible LLVM, linkers, Python, CMake, Ninja, Make, Bash, pkg-config, compression libraries, Cargo native dependencies, ccache, and optionally sccache.

Record their identities once, in a short generated report. Do not spend the first implementation cycle writing an attestation service.

Use the exact known recipe's dependency set before reducing it. OpenSSL or libgit2 in Cargo's bootstrap dependency graph is not a reason to redesign TLS or networking. These are build dependencies to replace or constrain later, not an invitation to integrate the user's other experimental runtimes.

### 3.4 One canonical successful path

Maintain one canonical musl configuration. Alternative GCC-on-musl, different LLVM versions, and official-Rust control builds should be separate experiments with separate work directories.

Do not let every environment variable become an undocumented configuration dimension. A small number of named profiles is sufficient:

| Profile | Purpose |
|---|---|
| `dev` | Fast normal iteration with caches and borrowed dependencies |
| `debug-seed` | Lower parallelism, diagnostic logs, controlled codegen settings |
| `seed-derived` | Rust builds using the lower toolchain rebuilt by the project |
| `replay` | Fresh output/cache boundary for the later lineage/reproduction check |

### 3.5 Keep the build logic unsurprising

Use upstream orchestration first. A pinned checkout plus a small overlay, a launch script, a test script, and a short manifest can be the whole initial repository. Use the recipe's existing language and shell behavior rather than porting it to POSIX shell while diagnosing the compiler.

After a reference build exposes a specific usability gap, a small Python standard-library supervisor or POSIX-shell wrapper is acceptable. Its job is subprocess handling and reuse of known stage commands, not reimplementing Make/Cargo/BuildKit dependency tracking. The larger layout/CLI in section 11 is an optional later shape, not an initial checklist.

### 3.6 Specify host versus produced-program policy

Document the compiler's host libc, host triple, loader, C++ runtime, LLVM linkage, default output target, and produced-program static/dynamic policy separately. Dynamic intermediate compilers are acceptable. They do not by themselves determine how user programs link.

Preserve the reference package's policy for its reproduction, then choose this project's advertised target behavior deliberately. Test any separately promised static output and retain its required startup objects, builtins, unwind libraries, and native archives. See the policy audit before copying final-package pruning into an install step. [R05, R07, R08]

## 4. Target architecture and interfaces

```text
DEVELOPMENT ENTRY
  imported musl C/C++ toolchain + compatible LLVM + build utilities
                               │
                               ▼
                     mrustc + minicargo
                               │
                               ▼
                 Rust 1.90 seed compiler/Cargo
                               │
                    normalize native sysroot
                               │
                               ▼
                  Rust 1.91.1 → ... → 1.99.1
                               │
                               ▼
            complete installed toolchain + execution tests

LATER REPLACEMENT OF THE ENTRY
  Hex0 → Stage0 / live-bootstrap / StageX compiler prerequisites
                               │
                               └── same Rust pipeline, new dependency identity
```

Every promoted toolchain must have an explicit interface:

```text
prefix/
  bin/rustc
  bin/cargo
  bin/rustdoc                 # when built/required by selected tests
  lib/                       # required driver/runtime/shared libraries
  lib/rustlib/<host>/lib/     # matching native libraries and metadata
  lib/rustlib/<host>/codegen-backends/  # location where applicable
```

Actual layout is determined by the pinned build, not forced to match this sketch. The upstream recipe or a thin wrapper records resolved paths and verifies them.

A handoff record includes the rustc path, Cargo path, sysroot, host triple, LLVM selection, native dependency root, and required runtime-loader environment. Never propagate only a `rustc --version` string.

Keep successful prefixes immutable. A convenient `latest` symlink may exist for humans, but downstream stage inputs must resolve to a concrete installed prefix and identity.

## 5. Milestones and acceptance gates

### M0 — Select the reference and start real compilation

**Goal:** execute the known recipe rather than build a framework for it.

Inspect and pin the selected StageX snapshot, dependency imports, mrustc/seed sources, patches, and existing target commands. Read the relevant Gentoo/Guix normalization material as comparison references, not as extra runtime dependencies. Make a small record of the selected compatibility bundle.

Use the upstream package workflow and borrowed native prerequisites. Verify that the Rust leaf will actually execute locally instead of being satisfied by a preseeded final image. Keep effective commands and exit statuses in logs. A `doctor` command is optional; a reliable preflight shell script or existing upstream checks are sufficient.

Verify native C/C++ execution, LLVM/runtime loading, disk capacity, and cgroup limits. Establish persistent paths without rewriting the container/dependency engine. In the later lower-chain phase, verify execution of the early seed and any 32-bit stages explicitly.

**Acceptance:** mrustc and minicargo compile from source and run; commands and native identities are recorded; rerunning preserves useful work.

**Do not require:** a CLI suite, new DAG/state engine, remote caches, signed artifacts, or an entire distribution rebuild.

### M1 — Produce a functioning Rust 1.90 seed

**Goal:** make mrustc generate and compile the selected Rust seed using the known musl recipe.

Use explicit `RUSTC_VERSION`, mrustc target-version selection, target triple, and output-directory selection. Preserve required upstream manifest and build-script overrides. Build the initial library/compiler/Cargo set using the recipe's actual dependencies.

Start with conservative minicargo concurrency. Enable ccache for C++ compilation and the generated C compilation path. Leave upstream compatibility extensions and patches intact.

Use upstream samples to test the raw compiler at the stage where they apply. Save the first successful output even if it has awkward paths or dynamic-library dependencies.

**Acceptance:** the generated seed compiler and Cargo execute; their exact paths are recorded; simple supported compilation tests pass. No official precompiled Rust toolchain supplied the accepted seed's Rust compilation.

**Important:** the raw mrustc-produced seed is not yet assumed to be an ordinary distributable Rust sysroot.

### M2 — Normalize the seed and prove the first release handoff

**Goal:** obtain a predecessor toolchain that the next Rust release can actually use.

Run the pinned recipe's `run_rustc`/native-library normalization procedure. Preserve its stage-specific directory and library conventions until the handoff works. Do not equate mrustc's intermediate library representation with the native rustc artifacts needed by `x.py`. Before inventing fixes, compare Gentoo's `mrustc_bootstrap()` and the Guix procedure for the failing stage, respecting each bundle's native-toolchain differences. [R01–R04]

Build Rust 1.91.1 using the normalized seed's rustc and Cargo. Produce its matching standard library and the Cargo needed for the next transition. Read the build output layout instead of guessing paths.

**Acceptance:** 1.91.1 compiles and runs the local smoke workspace, and its installed rustc/Cargo/sysroot can serve as the next release's inputs. The seed and 1.91.1 checkpoints are retained.

This is the most important early feasibility gate. It exercises more of the real bootstrap than a seed binary printing its version.

### M3a — Reproduce the selected reference endpoint

**Goal:** finish the selected StageX recipe's 1.96.0 endpoint with its prescribed release sequence, patches, and native dependency choices.

Preserve the seed and first-handoff checkpoints. Make only documented changes needed for observability, artifact retention, conservative resource limits, or a concrete environmental failure. Reuse the recipe's stage commands rather than guessing a new “minimal” build.

**Acceptance:** the reference endpoint passes its declared functional checks; logs establish local Rust compilation rather than a final-layer import; required runtime files remain available. This is a reference reproduction, not yet the full destination milestone.

### M3b — Extend the frozen release ladder to 1.99.1

**Goal:** extend from the last appropriate common predecessor using the section-2.2 ladder. Keep the 1.96.0 reference result and 1.96.1 extension result separate.

For each extension release, use a versioned prepared source/build directory, its exact patch series and tagged configuration, explicit predecessor rustc/Cargo/sysroot, and a compatible native/LLVM artifact. Use Alpine/Chimera packaging to investigate late-version musl failures; do not import their existing Rust bootstrap packages into this lineage. [R07, R08]

Build only the tools and libraries the next handoff requires, using the successful reference's stage structure where applicable. Validate new tags rather than blindly copying all options. Keep predecessors and their native runtime libraries until successors pass.

**Acceptance:** 1.99.1 rustc, Cargo, and matching libraries build and run the functional workspace without an ambient Rust installation. A failure resumes at its release. The reference/extension boundary and all imported non-Rust inputs are explicit.

Together with the functional acceptance in M4, this completes deliverable A.

### M4 — Demonstrate usability and a real same-version rebuild

**Goal:** establish that the final output is more than a narrowly functioning build artifact.

Run the expanded fixture suite, including procedural macros, build scripts, native FFI, threads/TLS, and unwind behavior. Build one pinned, modest external CLI or library fixture using the final toolchain and its own locked/vendored sources. Only then use a larger user project as an integration test.

Perform a fresh-work-directory same-version rebuild using the newly built 1.99.1 toolchain. Ensure Rust's stage uplifting or a completed-stage marker does not merely copy the previous compiler and masquerade as a fresh self-build. Use the pinned bootstrap configuration's full-bootstrap controls where relevant.

**Acceptance:** final tools work outside their original working tree in a declared runtime environment. The same-version rebuild produces working tools. Byte equality with official releases is not required.

**Scope:** this is a functional self-hosting check, not formal verification or diverse double-compiling.

### M5 — Optimize the iterative loop using measurements

**Goal:** make routine fixes cheap without changing the accepted semantics unnecessarily.

Measure no-op reruns, single-recipe changes, C++ source changes, generated-C rebuilds, LLVM rebuilds, and a late Rust-stage retry. Separate compile time from linking, configuration, extraction, and archive export. Start with existing Rust bootstrap timing/resource metrics, Cargo `--timings`, ccache counters, and native build logs; do not implement a profiling dashboard. Verify metrics options at each tag. [R26, R27]

Remove accidental rebuilds before tuning compiler flags. Add sccache only where it demonstrably helps. Reuse an external LLVM build across compatible Rust stages after the first successful handoff using it. Evaluate a lower intermediate stage count on a separate configuration before adopting it.

**Acceptance:** a no-op run avoids all completed expensive stages; a failed late release leaves earlier checkpoints intact; a targeted edit invalidates only its consumers; cache statistics and timings explain the result.

M5 work can begin during M1–M3 when it directly shortens the loop. It must not postpone M2 for a cache architecture project.

### M6 — Replace the borrowed lower toolchain with the Hex0-derived closure

**Goal:** connect the already-working Rust pipeline to an independently rebuilt lower compiler ancestry.

Reproduce the selected StageX bootstrap stages and the dependencies required by the Rust build. Let the upstream dependency system select the prerequisite closure. Do not assume every unrelated distribution package is required, and do not rewrite the dependency planner to save a few packages before the existing route works.

First establish lower-toolchain output, then compatible LLVM and native libraries, then rerun the mrustc/Rust stages against this new dependency identity. A new lineage must not silently consume development objects from a previous toolchain namespace.

Development may reuse locally produced checkpoints, but distinguish them from imported ones. Inspect the actual dependency resolution: a pulled final `core-rust` image is not a Rust build, and a preseeded compiler layer is not a reconstructed compiler ancestor.

**Acceptance:** a continuous recorded compiler-producing dependency path connects the seed stages to the final Rust toolchain. Every external assumption is named. The same functional tests pass.

This is deliverable B, not yet a claim about firmware, hardware, or the host kernel.

### M7 — Fresh replay and source/input accounting

**Goal:** remove the ambiguity introduced by development imports and caches.

Use a separate builder/output namespace. Keep verified source archives, but do not import previously compiled toolchain outputs or unaccounted compiler-cache entries. Disable caches or populate them only within the permitted replay lineage. Rebuild or omit Rust-written convenience helpers such as sccache rather than importing them invisibly.

Inventory generated code/data as well as executables. An archive being named “source” does not itself settle the status of every file inside it. Do this deliberately, rather than deleting unfamiliar files during the initial PoC.

Record both matching and differing outputs. Freeze paths, environment variables, codegen settings, and timestamps only as needed to investigate differences. Do not silently strip or normalize away unexplained differences.

**Acceptance:** the replay finishes with an accurate scope statement and passing functionality tests. A separate reproducibility report states which outputs match and why unmatched outputs remain unresolved.

### M8 — Reduce the implementation and trust surface

**Goal:** improve the working system without destroying the feasibility baseline.

Use actual build traces to rank dependencies and extensions. Remove unused LLVM targets and optional tools, shrink native dependencies, fix demonstrated undefined behavior, replace selected generated-C extensions, and explore a simpler backend only when the measured payoff justifies it.

A strict C subset, translation validation, DDC, a minimal execution environment, or a verified compiler component are separate research workstreams. Require each to preserve an existing end-to-end test before replacing the canonical route.

## 6. Work package: seed compiler integration

### 6.1 Read these files before editing

In the pinned mrustc tree, read `README.md`, `Makefile`, `minicargo.mk`, `build-1.90.0.sh`, `TestRustcBootstrap.sh`, `run_rustc/Makefile`, the version-specific patch/override files, and the minicargo codegen scheduling code. Read the selected StageX Rust recipe and its patch manifest alongside them. [S01–S03, S08, S18]

Also inspect Gentoo's `mrustc_bootstrap()` procedure and its mrustc source/override packaging, plus the Guix normalization change, before changing the seed-to-native handoff. Read called helpers before extracting distribution commands. [R01–R04]

Do not blindly run the oldest README download example. Do not assume a modern `master` script has exactly the behavior of the mrustc release selected by the distribution recipe.

### 6.2 Split the seed into resumable substeps

Use these logical boundaries, while preserving whatever upstream commands implement them:

1. Prepare and patch the selected sources.
2. Build mrustc and minicargo.
3. Build the seed libraries required by the compiler.
4. Build the seed rustc.
5. Build the seed Cargo.
6. Normalize the native standard-library/sysroot layout.
7. Validate and promote the resulting predecessor toolchain.

Do not make every boundary an elaborate package. A directory, a log, and a validated completion record are sufficient.

### 6.3 Treat version and target variables as an interface

Record and explicitly set the variables that the selected revision actually uses. The 1.90 helper establishes `RUSTC_VERSION=1.90.0`, `MRUSTC_TARGET_VER=1.90`, and an output suffix. `RUSTC_TARGET` and `MRUSTC_TARGET` are not automatically interchangeable: inspect how the pinned makefiles and compiler use each. [S02, S18]

The agent must test the resolved host/target against the resulting ELF files. A musl target name in a configuration file does not repair a wrong dynamic loader, wrong C++ runtime, or mixed sysroot.

### 6.4 Deferred codegen recovery

For the currently inspected implementation, this is **not** a disable operation:

```sh
MINICARGO_DEFER_CODEGEN=0
```

Its presence test still enables the path. A recovery adapter must unset the variable before invoking the underlying make/minicargo operations, or apply a small explicit patch that gives the wrapper a real boolean switch. Simply unsetting it and then calling a wrapper that restores a default of `1` is also insufficient. [S02, S03]

Log which route was used. Retry a suspected race with lower concurrency and the non-deferred path. Do not silently reinterpret every compilation failure as a scheduling race.

### 6.5 Compatibility patches are allowed

Use the selected recipe's required patches first. Do not opportunistically remove compiler flags, libc fallbacks, assembly accommodations, unwinding support, or C++ compatibility changes.

An accepted deviation needs a short entry: what it changes, why the current build needs it, which stages it affects, and the test that would permit its removal. This should take minutes of documentation, not a new governance process.

Avoid carrying identical patches twice when a newer pinned mrustc revision already includes them. Every patch application must either apply as intended or fail clearly; a rejected hunk is not a warning to ignore.

Classify patches and source edits as **compatibility**, **distribution policy**, or **performance**. Retain coupled changes for reference reproduction; later remove one coherent group at a time. Keep generated-source/vendor sanitation separate from basic PoC feasibility, and never retain a checksum/lockfile workaround whose corresponding source modification was accidentally omitted. [R05]

Resume must not mean reapplying the series to a partially modified tree. Record preparation identity; reprepare only the affected source when its patch set changes, without deleting independent predecessor prefixes.

## 7. Work package: release-ladder adapters

### 7.1 Inputs and outputs of one release

A release stage consumes:

- The exact Rust source archive and its vendored dependencies.
- The predecessor rustc, Cargo, and complete matching sysroot.
- The selected LLVM build and native C/C++ dependency environment.
- Its patch series, generated bootstrap configuration, and relevant flags.

It produces:

- A functioning compiler for the chosen host.
- The matching native library set required for the next stage.
- Cargo, and rustdoc when required by the selected tests or next stage.
- A version/target/runtime report and passing smoke-test result.

These are logical contracts. Do not require identical directory layouts across releases.

### 7.2 Keep release transitions explicit

Use the manifest sequence in section 2.2. It is better to spend one successful build on a known adjacent transition than to debug an unsupported multi-release jump.

The official bootstrap policy supports building a release with the previous minor release or itself; standard-library internals and bootstrap configuration are more tightly coupled than ordinary crate MSRVs. Do not infer that a large Rust source tree can skip releases just because a crate declares a low `rust-version`. [S11]

### 7.3 Configuration strategy

Render a separate configuration for each release. Inspect its `bootstrap.example.toml` and the reference config. Set explicit predecessor paths; turn off downloaded Rust compilers; request only required tools; select vendored sources; and either select compatible external LLVM or build the bundled LLVM from source.

For the currently inspected 1.99.1 tag, these names are real configuration keys:

```toml
# An illustrative subset, not a complete universally valid build file.
[build]
rustc = "/work/artifacts/PREDECESSOR/bin/rustc"
cargo = "/work/artifacts/PREDECESSOR/bin/cargo"
docs = false
vendor = true
extended = true
tools = ["cargo"]
ccache = "/usr/bin/ccache"

[llvm]
download-ci-llvm = false
targets = "X86"
link-jobs = 1

[rust]
channel = "stable"
download-rustc = false
optimize = 2
```

The agent must fill real paths, configure the actual musl target/native tools, and validate every option against the selected release. Do not copy the illustrative predecessor placeholder into a committed active configuration. [S12]

For development, an explicitly imported LLVM artifact is acceptable even while CI auto-download is disabled. Keep that choice visible rather than allowing the build system to choose an unrecorded LLVM behind the scenes.

### 7.4 Intermediate stages: reuse demonstrated commands

The inspected StageX recipe already uses stage-1 library and Cargo builds in its intermediate progression. That is an implementation reference to inspect, not a reason to invent a new stage convention. Preserve the working stage/library/Cargo relationship and validate it at every new release. [R05]

When extracting the recipe, copy only the proven handoff logic and retain a fuller build as a diagnostic fallback. The fastest nominal stage is useless if its sysroot cannot run the next bootstrap or load host procedural macros.

Use a more complete final build at the frozen destination. Do not use local-rebuild/keep-stage shortcuts as evidence that a compiler was freshly rebuilt. Those switches belong to debugging profiles until their exact effect is understood. [S19]

### 7.5 Find artifacts deterministically

Do not select Cargo with `find ... | head -1`, because multiple stages or stale trees can contain executables with that name. The adapter must identify the intended build stage and validate the path it exports.

Likewise, do not assume that `build/host`, `build/<triple>`, and stage-tools directories have identical layouts in every release. Inspect and test the actual tagged build.

## 8. Work package: LLVM and the native toolchain

### 8.1 Start with the compatible LLVM already used by the recipe

Avoid compiling a new LLVM merely to make the PoC appear more self-contained. First use a pinned compatible prebuilt LLVM in the borrowed environment. Source-build it later or when an incompatibility requires it.

Keep two meanings separate: the Clang executable compiling C/C++ and the LLVM libraries against which rustc's backend is built. They may have different versions. Label them separately in reports.

### 8.2 Compatibility groups, not “one LLVM for everything”

For each Rust release, record the actual accepted LLVM artifact. The selected StageX recipe already provides evidence for part of the ladder, but a later release still needs validation. Do not turn off a version check simply because it blocks the build.

Prefer the following escalation:

1. Use the known-compatible external LLVM for that transition.
2. Check the target release's LLVM requirements and patches.
3. Reuse an already-built compatible artifact only after a successful test.
4. Fall back to the release's bundled Rust LLVM revision.

Do not share by major-version number alone. Include the exact revision, patches, build options, compiler/runtime environment, and enabled targets in the identity.

### 8.3 Source-build settings when needed

Use Ninja, a release/optimized build, one backend family initially, no LTO/PGO/BOLT, and a separate linker-concurrency limit. Keep debug information off for ordinary iteration; use a dedicated debug profile when a real failure needs it.

Where supported by the selected LLVM revision, use CMake compiler launchers for ccache and `LLVM_PARALLEL_LINK_JOBS` for link concurrency. Do not overwrite `CMAKE_C_COMPILER` with a shell string containing both ccache and a compiler. [S20]

Build Clang/lld only when the selected dependency contract requires them; a rustc backend library build is not automatically a request for all LLVM projects. Conversely, do not remove a tool from the known recipe before confirming nothing consumes it.

### 8.4 Native dependencies and runtime closure

Keep the C++ standard library choice consistent with the selected recipe. Validate musl startup objects, compiler builtins, unwind libraries, zlib/zstd, and the native libraries Cargo actually links.

Dynamic linking is allowed for every intermediate compiler. Preserve required libraries and loader settings in each checkpoint. A later static-toolchain experiment must not destabilize the working bootstrap.

Do not globally force `panic=abort`. Compiler and test behavior may depend on unwinding. Preserve the chosen recipe's working exception/panic configuration and test it after normalization.

Keep predecessor runtime libraries available side by side during LLVM upgrades. A successful compiler prefix that dynamically loads an overwritten shared library is not a stable checkpoint. Chimera's bootstrap packaging explicitly addresses this upgrade-cycle problem; use it as integration prior art. [R08]

For late releases, consult current musl package fixes before changing compiler semantics. Alpine's inspected 1.99.1/LLVM-23 recipe includes a larger thread-stack setting and deliberate Cargo native-dependency choices. Treat them as version-specific evidence, not global mandatory flags. [R07]

## 9. Work package: iterative build performance

### 9.1 Use five separate retention layers

| Layer | Keep | Invalidate or prune when |
|---|---|---|
| Source downloads | Archives, commit snapshots, vendored source inputs | Only corruption or an explicit storage policy |
| Prepared source trees | Extracted/patched trees keyed by source plus patch identity | The source or patch identity changes |
| Work directories | Make/Ninja/Cargo intermediates per stage/configuration | The incompatible stage identity changes |
| Compiler object caches | C/C++ objects; optional eligible Rust objects | Cache keys account for inputs; namespaces separate lineages |
| Promoted artifacts | Complete validated predecessor toolchains | An explicit retention decision after dependent stages succeed |

A complete toolchain checkpoint is usually more valuable to this project than reusing a few more object files. It avoids configuration, metadata generation, linking, and repeated self-hosting stages.

### 9.2 Canonical paths

Inside the container, use stable paths such as:

```text
/work/src/<component>/<identity>
/work/build/<stage>/<identity>
/work/artifacts/<stage>/<identity>
/work/logs/<run>/<stage>
/cache/downloads
/cache/ccache/<environment-namespace>
/cache/sccache/<environment-namespace>
/cache/cargo
```

These are proposed project conventions. They avoid incidental path churn without needing risky path-rewriting tricks.

Keep large mutable build trees on persistent native storage rather than embedding them in every container layer. If using BuildKit cache mounts, explicitly export final artifacts outside disposable cache mounts; do not assume mounted data is included in the final image. [S15]

### 9.3 ccache: mandatory early, but prove that it is used

Use it for three distinct consumers: mrustc's C++ build, generated C compilation, and any source-built LLVM/native dependency compilation.

An initial configuration can be:

```ini
cache_dir = /cache/ccache/current-environment
max_size = 64G
compiler_check = content
compression = true
hard_link = false
```

The 64 GB allocation is a starting project budget, not a benchmark-derived optimum. Make it configurable and reserve space for build outputs.

Prefer canonical work paths and ordinary dependency tracking. Leave sloppiness disabled and directory hashing at its default initially. Do not set `base_dir=/` or ignore headers just to inflate hit rates. `compiler_check=content` does not by itself fingerprint every runtime library or compiler subprogram; use an environment/toolchain identity as well. [S13]

Use Make's appropriate `CXX` wrapper mechanism for compiling mrustc. For generated C, use the pinned mrustc's own ccache support rather than assuming a `CXX` wrapper covers it. For CMake builds, use compiler launchers. Avoid double wrapping the same invocation.

For each consumer, compile an eligible object, remove only that test object, repeat the identical compilation, and inspect ccache's counters. A no-op Make run is useful but does not demonstrate a ccache hit. Compilation-and-link commands may be uncacheable; measure rather than promise that every generated-C invocation is cached.

### 9.4 sccache: optional after the basic pipeline works

Use a separate cache and namespace. Scope it to native rustc/Cargo invocations; it is not a wrapper for mrustc's C++ executable.

For an ordinary Cargo test project, the intended mode is:

```sh
export RUSTC_WRAPPER=/usr/bin/sccache
export CARGO_INCREMENTAL=0
export SCCACHE_DIR=/cache/sccache/current-environment
```

For `x.py`, check the tagged bootstrap's wrapper integration and inspect actual compiler commands. Do not assume an environment variable reached every nested compilation. The currently inspected bootstrap source explicitly preserves an existing wrapper through `RUSTC_WRAPPER_REAL`, but the pinned release remains authoritative. [S21]

Do not claim all of rustc is cacheable. Measure the documented exclusions. A local compiler-edit profile may instead choose Rust incremental compilation without sccache; do not enable both and assume their benefits add. [S14]

A borrowed sccache binary is acceptable in development as an imported helper. For clean lineage replay, omit it or build it with a compiler already in the permitted lineage. Do not make bootstrapping sccache a prerequisite for bootstrapping the first Rust compiler.

### 9.5 Avoid global target-directory collisions

Preserve each Rust source tree's bootstrap-controlled build structure. Do not point ten different compiler releases at one shared `CARGO_TARGET_DIR`. Ordinary Cargo fixtures can use a target directory keyed by the exact compiler/sysroot/configuration. [S16]

Keep a shared source/download cache where appropriate, but distinguish source downloads from compiled Cargo artifacts and from the bootstrap program itself.

### 9.6 No remote cache infrastructure in v0

Local disk caching is sufficient. Do not require Redis, S3/R2, a cache daemon service manager, distributed compilation, or a new authentication system. Add a remote cache only after there are multiple working builders and measurements justify it.

### 9.7 Cache correctness and lineage are different checks

The ordinary key should cover source and patches, relevant recipe/config content, predecessor identity, target and ABI, native toolchain/LLVM/sysroot identities, and material flags.

Do not hash the whole project commit into every stage: editing documentation should not rebuild LLVM. Conversely, switching from imported to seed-derived tools must not silently reuse development outputs just because version strings match.

For clean replay, use a fresh cache namespace or disable caches. A content-identical artifact can be useful evidence, but its presence does not establish how this run obtained it.

## 10. Work package: scheduling, memory, and storage

### 10.1 Starting budget for the 64 GB builder

These are initial tuning choices, not measured performance guarantees:

| Work | Initial concurrency |
|---|---:|
| C/C++ compilation | 12 jobs |
| LLVM compilation | 12 jobs |
| LLVM or other especially large links | 1 simultaneous link |
| minicargo/seed Rust work | 2 jobs; serial recovery mode |
| Native Rust/Cargo builds | 8 jobs |
| Simultaneous release stages | 1 |
| Extra threaded rustc frontend | Leave disabled initially |

Read memory availability and cgroup limits at run time. Reduce jobs before invoking increasingly elaborate memory workarounds. Do not multiply `make -j`, Cargo jobs, LLVM jobs, codegen units, and frontend threads independently to the host's full CPU count.

Use optimized intermediate compilers: making them unoptimized can reduce their own compile cost while greatly increasing all subsequent work. Start around the selected recipe's working optimization settings, with debug info off and LTO off. The tagged Rust config explicitly warns against unoptimized compiler builds. [S12]

### 10.2 Native CPU tuning is optional, not a default shortcut

Use conservative CPU settings for the initial accepted artifacts. A host-specific intermediate profile can be measured later, but it belongs to a separate cache identity and must not be distributed as a generic x86-64 toolchain.

Do not adopt all of another recipe's aggressive flags simultaneously. The goal is a stable loop that can identify which change helped or broke the build.

### 10.3 Storage policy

The StageX full-reproduction documentation calls for at least 500 GB free space; that is a full-system reference, not a measured requirement for this narrower initial Rust PoC. Provision generous SSD headroom for the lower-chain phase and measure actual high-water usage. [S22]

Keep the original source archives, current failed work tree, validated seed, current predecessor, and final artifact. Retain older promoted toolchains according to a user-visible policy. Intermediate work trees may be pruned after a successor is validated, but not automatically while diagnosing a failure.

Use an explicit `clean --stage ...` operation. Never make a routine retry run `docker system prune`, delete the shared ccache, or wipe the whole bootstrap workspace.

## 11. Repository and controller design

### 11.1 Start smaller than the optional expanded layout

Before the reference endpoint works, prefer a pinned upstream checkout or submodule, a short manifest, a narrow overlay/patch directory, a launch script, a smoke-test script, and logs/artifact paths. Follow an existing repository's conventions. Do not create every file shown below merely to match a diagram.

After concrete repeated work justifies extraction, the following is a possible expanded layout, not a first-session deliverable:

```text
rust-bootstrap/
  README.md
  PLAN.md
  RESEARCH.md
  bootstrap                    # small non-Rust driver
  sources.lock.toml
  profiles/
    dev.toml
    debug-seed.toml
    seed-derived.toml
    replay.toml
  recipes/
    environment.sh
    mrustc.sh
    seed-rust.sh
    normalize-seed.sh
    rust-release.sh
    llvm.sh
    lower-chain.sh
  configs/
    rust/<version>/...
    ccache.conf
  patches/
    mrustc/...
    rust/<version>/...
  tests/
    smoke/...
    controller/...
  docs/
    compatibility.md
    failures.md
    performance.md
  work/                        # ignored; may instead be outside the repo
```

This is a shape to grow into, not a requirement to create empty boilerplate for every directory before building mrustc. Import only the files needed for the next milestone.

Keep third-party source trees and build outputs outside version control. Pin upstream commits/tarballs rather than committing hundreds of megabytes of vendored compiler sources into this project. Preserve attribution and applicable upstream licenses when copying recipes; the inspected dtolnay repository declares CC-BY-SA-4.0. [S05]

### 11.2 Optional CLI after reference reproduction

The initial interface may simply expose upstream commands with correct logging and retention. The commands below are a possible convenience interface, not an implementation requirement before actual compilation.

If a standalone controller becomes justified, these are candidate interfaces, not existing upstream commands or a mandatory initial contract:

```sh
./bootstrap doctor
./bootstrap plan --profile dev --until rust-1.99.1
./bootstrap fetch --until rust-1.99.1
./bootstrap run --profile dev --until seed-native
./bootstrap run --profile dev --until rust-1.91.1
./bootstrap run --profile dev --until rust-1.99.1
./bootstrap status
./bootstrap logs rust-1.94.1
./bootstrap test rust-1.99.1
./bootstrap cache stats
./bootstrap clean --stage rust-1.94.1 --work-only
./bootstrap export rust-1.99.1
```

Only after a demonstrated need for this controller, implement the smallest useful subset. An existing upstream invocation plus logs may remain sufficient. Avoid dozens of partially implemented flags.

### 11.3 Stage state

Keep stage state small:

```text
pending → running → succeeded
                 ↘ failed
                 ↘ interrupted
```

A succeeded stage must have both a matching input identity and validated artifacts. Directory existence or an old `.done` file is insufficient.

Use an atomic success-marker update after installation and smoke tests finish. Do not publish a partial prefix as a successful predecessor. Hold a workspace/stage lock so two agents cannot mutate the same source or build tree concurrently.

### 11.4 Subprocess behavior

Preserve real exit codes through logging. POSIX shell pipelines involving `tee` must not hide a failing compiler; use a reliable controller or an explicitly supported shell behavior.

Record the command, working directory, relevant environment, start/end timestamps, return code, and log path. Forward interrupts to the child process group. On interruption, leave resumable files and an honest interrupted state.

Do not log secrets or unnecessarily mount SSH keys, cloud credentials, or the user's entire home directory into the builder. This is ordinary build hygiene, not a hardened sandbox project.

### 11.5 Minimal receipts

For each promoted stage, generate a compact record containing:

- Source/patch/config identity and upstream reference.
- Predecessor toolchain and native environment identities.
- Output paths and checksums of promoted artifacts.
- rustc/Cargo/LLVM versions, host triple, and runtime dependencies.
- Tests executed, exit statuses, elapsed time, and available resource measurements.
- Whether dependencies or caches were imported, locally built, or replay-only.

TOML plus a checksum file is adequate. JSON is also fine as generated machine output; do not make a hand-maintained JSON database the project's central interface.

## 12. Test plan

Reuse upstream tests first: applicable mrustc local tests at the seed, then a curated set of the matching rustc tag's compiletest UI/run-make and library tests. Keep the small local workspace for integration coverage, not as the start of a new compiler-testing framework. Never use `--bless` or newly invented skips merely to hide failures. [R28]

At later backend/ABI changes, consider ABI Cafe and Rustlantis with their documented limitations; keep those Rust-written helpers outside the initial seed dependencies. At clean replay, use diffoscope rather than writing an ELF/archive comparison tool. [R29–R31]

### 12.1 Environment tests

Build and run C and C++ programs. Verify selected compiler and linker paths. Confirm the musl loader can execute produced binaries. Verify the selected LLVM artifact's tools run and its libraries can be loaded.

### 12.2 Seed tests

Run the pinned mrustc test/sample cases that apply to the intended Rust version. Test the raw seed separately from the normalized native seed. Do not require mrustc to diagnose invalid Rust like rustc; that is not the purpose of this stage.

### 12.3 Native smoke workspace

Create a small checked-in workspace with no network dependencies:

- A normal library and executable exercising generics, enums, pattern matching, closures, trait dispatch, arithmetic, `Vec`, `String`, and `HashMap`.
- A procedural-macro crate used by the executable.
- A build script that writes generated Rust source.
- A tiny C component built by an explicit native compiler invocation and linked through FFI.
- Thread creation, thread-local state, filesystem I/O, and a child-process test.
- A native unwind/catch-unwind test where the selected compiler configuration supports unwinding.

The workspace should compile and run with the installed toolchain, not only from inside the Rust source tree. Set explicit rustc/Cargo paths and a controlled PATH so rustup cannot mask a missing artifact.

### 12.4 Negative compiler tests

With native rustc, check that a small set of deliberately invalid programs fails: a type error, a lifetime/borrow error, and a malformed item. Require failure and an appropriate diagnostic category, not exact wording across every release.

### 12.5 FFI regression coverage

Include basic C-to-Rust and Rust-to-C calls with integer and boolean values. Rust 1.99.1's release notes specifically include an x86-64 FFI boolean-return fix; this gives one concrete reason not to replace the frozen point release with an earlier same-minor version casually. [S17]

### 12.6 Handoff tests

For every predecessor, test the installed rustc/Cargo pair and native sysroot before invoking the next `x.py`. After building the successor, confirm that its libraries were built for the intended compiler and that no runtime path still relies on a deleted predecessor work directory.

### 12.7 Cargo functionality

Use the new Cargo to build and test the offline fixture workspace. Include a procedural macro and build script so that host-tool compilation and dynamic loading are exercised, not just target-code generation. Disable doctests until a matching rustdoc is supplied, or build rustdoc explicitly and test them.

### 12.8 One external real-world fixture

Choose a modest pinned CLI/library with manageable native dependencies and a known lockfile. Vendor or otherwise preserve its sources. Do not use the user's largest workspace as the first acceptance test: its failures can be unrelated to compiler bootstrapping.

After it passes, add a selected Laputa-family project as a separate integration milestone, without modifying that project merely to make the bootstrap look successful.

### 12.9 Controller and cache tests

Use mock commands for fast controller tests. Cover failed subprocesses, interrupted stages, stale receipts, missing artifacts, changed toolchain identity, changed patch input, concurrent invocation, and a log pipeline that would otherwise hide failure.

Verify a warm no-op run. Verify that changing only README text does not rebuild LLVM. Verify that changing the predecessor/native environment invalidates affected consumers. Verify that failed-stage cleanup leaves earlier artifacts intact.

### 12.10 Promoted prefix and environment tests

Run each promoted toolchain with its original build tree unavailable, in the declared runtime environment. Resolve symlinks and check loader/backend/native-library availability. Record how Cargo, rustdoc where needed, host procedural macros, and target libraries are found. Do not equate copying `bin/rustc` with installing a usable predecessor.

Keep unrelated user Cargo configuration, rustup shims, `RUSTC_WORKSPACE_WRAPPER`, encoded Rust flags, global target/linker overrides, and profile tuning out of the canonical environment. An explicit diagnostic import is allowed; ambient discovery is not a successful handoff.

Test produced-program linking modes independently of host compiler linkage. Require only the modes advertised by the selected profile, and retain the inputs needed for them.

### 12.11 Same-version self-build and replay tests

A self-build must execute the compiler-generation steps rather than copy uplifted artifacts. Test its output functionally. A later replay must use its declared cache/import policy. These two checks answer different questions and should have separate reports.

## 13. Failure triage playbook

| Symptom | First investigation | Permitted next action | Avoid |
|---|---|---|---|
| mrustc C++ compilation fails | Compiler/runtime choice, exact patch set, supported language flags | Match the known recipe or backport a narrowly scoped fix | Rewriting mrustc before obtaining a baseline |
| Generated C is rejected | Retain the C and exact invocation; inspect the extension/assembly requirement | Preserve known flags or port the specific failing construct | Turning on strict ISO-C errors globally |
| Intermittent missing symbols/objects | Check minicargo scheduling and deferred codegen | Lower concurrency; unset the real deferred-codegen control via the correct path | `MINICARGO_DEFER_CODEGEN=0` as a false fix |
| Compiler is killed | Check cgroup memory, system logs, link concurrency | Reduce jobs and big-link overlap | Repeated identical all-core retries |
| rustc prints its version but cannot compile std programs | Inspect sysroot, library metadata, loader dependencies | Complete normalization and the matching library stage | Copying a random system sysroot |
| Bootstrap tries to download Rust | Inspect explicit predecessor paths, config defaults, missing tools | Fix the adapter or missing locally built component | Allowing an official compiler fallback and claiming success |
| Rust backend fails with external LLVM | Check exact version/revision and native library ABI | Use known-compatible LLVM or bundled sources | Disabling compatibility checks blindly |
| Proc macros fail on musl | Check dynamic loader, host libraries, linkage flags | Reuse the working dynamic-bootstrap convention | Forcing static linking everywhere |
| Cargo fails on native dependencies | Inspect pkg-config, selected source/native features, library paths | Use the reference dependency configuration | Replacing Cargo's network stack during the PoC |
| Almost no ccache hits | Inspect eligible invocations, paths, generated-file churn, wrapper placement | Correct one cache boundary and repeat a controlled test | Relaxing correctness checks merely to increase hit counters |
| Late stage restarts the entire ladder | Inspect controller keys and completion logic | Add or repair a stage checkpoint | Accepting global clean as normal recovery |
| Final artifact only runs in the original tree | Inspect RPATH/loader and escaped absolute paths | Bundle declared runtime libraries or install to a stable prefix | Publishing a lone rustc executable as a complete toolchain |
| StageX build completes instantly after preseeding | Inspect imported Rust layers and resolved dependency reuse | Force the Rust-producing stages in an isolated build identity | Treating a pulled image as a local compiler build |

Retry policies must be bounded and explicit. Preserve the first failed log. A retry that changes concurrency, codegen mode, or dependencies is a new configuration and should be recorded as such.

## 14. Agent execution strategy

### 14.1 Work serially along the critical path

The release ladder is inherently dependency-ordered. Parallel agents can help with read-only source research, tests, cache instrumentation, and the lower-chain documentation, but they must not launch competing full LLVM/Rust builds in one workspace.

One primary agent owns the canonical configuration and the next failing command. Supporting agents should return patches, focused findings, or test fixtures, not alternative giant build systems.

### 14.2 Suggested bounded assignments

**Primary integration agent:** M0–M3, actual commands, first compiler artifacts, stage handoffs.

**Cache/runner agent:** only after the initial build command exists; persistent paths, ccache observability, subprocess correctness, targeted resume.

**Test agent:** local offline fixture workspace and artifact validation; no modifications to the release ladder's semantics.

**Lower-chain researcher:** map the selected StageX dependency closure and imported-vs-built boundaries; do not replace the working Rust route before M3.

These are optional work divisions, not mandatory parallel infrastructure.

### 14.3 Implementation checkpoints

Use small coherent changes such as:

1. Add research pins, minimal environment, and a real mrustc build entry point.
2. Add seed-stage logs and ccache instrumentation.
3. Obtain the seed and normalize the native toolchain.
4. Make the 1.90-to-1.91.1 handoff work.
5. Generalize only the repeated release-stage logic and add the frozen ladder.
6. Add functional tests, final installation/export, and resume checks.
7. Optimize measured expensive stages.
8. Add the lower-chain adapter.
9. Add the separate clean replay mode.

Do not commit generated compiler trees, huge artifacts, or fake success receipts. Do not alter unrelated user repositories. Follow the repository's actual commit policy once a repository is supplied.

### 14.4 Required report after a meaningful iteration

Report the highest completed stage, the exact next failing command, the first useful error, whether the failure is deterministic, what outputs are retained, and the proposed narrow next action.

Avoid summaries such as “bootstrap mostly works” when only mrustc compiled. A useful report says, for example, “normalized 1.90 works; 1.91.1 fails linking the compiler driver against LLVM artifact X.”

### 14.5 Handoff between agent sessions

Keep a short `NEXT.md` or equivalent with the current pins, active profile, command to resume, failing log, known successful artifact, and no more than a few active hypotheses. This prevents a new agent from rediscovering the entire ancestry or wiping useful output.

## 15. Things explicitly deferred

Do not make any of these a prerequisite for the first end-to-end source-Rust result:

- Pure ISO C, a new verified C dialect, or a replacement C frontend.
- Removing all GNU/Clang extensions or all C++.
- LLVM-free rustc or a new Cranelift/GCC backend integration.
- Porting mrustc to C, Rust, Goose, or another implementation language.
- A custom libc, TLS stack, shell, build language, package manager, or kernel.
- AArch64/macOS/Windows support or a multi-architecture build farm.
- Fully static intermediates, PGO, LTO, BOLT, size minimization, or competitive compiler performance.
- Bit-for-bit identity with official release binaries.
- A complete generated-source audit, signed provenance infrastructure, or DDC.
- Remote caches, distributed compilation, cloud deployment, or automatic scheduling.

The initial goal is not a tiny TCB. It is a working route whose expensive and complex parts are visible enough to improve later.

## 16. Hardening after feasibility: ordered follow-up

### 16.1 First improve reproducibility of the experiment

Keep exact pins, preserve required generated inputs, make the network fetch boundary explicit, and eliminate accidental host-tool discovery. These changes are useful even before making any security claims because they make bugs repeatable.

### 16.2 Then reconstruct the compiler ancestry

Replace imported toolchain inputs with rebuilt equivalents and rerun their consumers. A rebuilt C++ compiler sitting beside a Rust binary still compiled by the imported compiler is not enough. The dependency graph must actually flow through the new artifacts.

### 16.3 Then investigate output reproducibility

Use separate clean builds. Classify differences: paths, timestamps, archives, codegen ordering, native CPU features, build descriptions, and genuine code differences. Keep normalization rules documented and narrowly justified.

### 16.4 Then reduce the source burden

Use build traces to identify actual extension/dependency use. Prefer removing an entire unused library or tool stage to replacing a harmless attribute with complicated portable scaffolding. Keep a functioning baseline at every reduction.

Use existing GCC-backend self-bootstrap work as a concrete alternative-backend reference, and consider an independently regenerated C snapshot only after its separate acceptance gates pass. Onramp/boot2 may inform a later smaller lower layer, but reaching a C toolchain alone does not provide the whole selected Rust build environment. [R09–R18, R22–R25]

### 16.5 Finally pursue stronger semantic and ancestry arguments

A verified compiler component, translation checker, or DDC experiment needs a separate statement of assumptions and acceptance criteria. Ordinary self-hosting and deterministic rebuilds do not establish these properties. Do not advertise formal verification merely because formal-methods tooling is present in the repository.

The earlier clean-C idea remains a useful long-term direction, but its concrete workload should be the generated C and bootstrap dependencies observed here, not an imagined ideal language detached from a working compiler chain.

## 17. First-session instructions for a coding agent

Read the audit summary and the existing repository before changing architecture. Then:

1. Pin one StageX reference bundle and inspect its actual target/import behavior. Record native dependencies and whether the Rust leaf will execute locally.
2. Prepare native musl prerequisites and verify C/C++/LLVM execution. Reuse upstream orchestration; add only a narrow launch/retention/logging overlay.
3. Enable and measure the existing ccache paths without simultaneously changing compiler optimization or runtime policy.
4. Actually compile mrustc/minicargo, then the seed and native normalization. Consult Gentoo/Guix for a concrete handoff failure before inventing machinery.
5. Attempt the first native-Rust successor, retaining complete prefixes and their dependency roots.
6. Finish the selected reference endpoint, then make only the adapter changes needed to extend to the frozen destination. Use current musl packaging as evidence for late-version issues.
7. Test the final functional toolchain, same-version rebuild, and recovery behavior; only then pursue lower-ancestry reconstruction.

Do not stop at a scaffold. Do not ask the user to choose among speculative compiler/cache architectures when the pinned recipe provides the next experiment.

If the available execution environment lacks the required architecture, disk, memory, or container capability, leave exact non-destructive launch/resume commands and report which gates were not run. Never manufacture a green build result.

The optional Rustic experiment is explicitly separate. It must not turn the first session into concurrent maintenance of two compiler infrastructures.

## 18. Research ledger and source index

S01–S24 are retained from the first research pass. Additional sources inspected during the completeness audit are R01–R31 in `RESEARCH_INDEX.md`. Branch-based references are observations, not immutable build pins. The implementation must resolve commits and archive checksums before using them. URLs are given for the agent to inspect; no source archive or compiler output is bundled with this plan.

### Primary implementation sources

**[S01] mrustc repository and README.** Independent compiler purpose, supported seed versions, build dependencies, primary tested environment, and bootstrap validation claims. Upstream's result is not a claim that this plan has reproduced it.

`https://github.com/thepowersgang/mrustc`

**[S02] mrustc 1.90 version-specific build helper.** Version selection, generated-C cache enablement, and deferred-codegen default.

`https://github.com/thepowersgang/mrustc/blob/master/build-1.90.0.sh`

**[S03] minicargo build implementation.** The searched source snapshot was `d85e86b199e2522d74bee19efa6ebf3af596270f`; its `deferred_codegen_enabled()` tests environment-variable presence. This is an inspected snapshot, not an instruction to mix it with a different release's patch set.

`https://github.com/thepowersgang/mrustc/blob/d85e86b199e2522d74bee19efa6ebf3af596270f/tools/minicargo/build.cpp`

**[S04] dtolnay release/version manifest.** Source for the explicit 0.12.0/mrustc and 1.90.0-through-1.99.1 recipe sequence.

`https://github.com/dtolnay/bootstrap/blob/master/versions.sh`

**[S05] dtolnay/bootstrap repository and build driver.** Useful compact orchestration reference; retain attribution and check licensing when copying material.

`https://github.com/dtolnay/bootstrap`

`https://github.com/dtolnay/bootstrap/blob/master/build.sh`

**[S06] dtolnay environment initialization.** Shows the reference's Debian/GNU environment; do not mistake it for a musl proof.

`https://github.com/dtolnay/bootstrap/blob/master/init.sh`

**[S07] dtolnay per-release configuration.** Explicit previous-toolchain paths and current target config. The 1.99.1 file uses 1.98.1's built compiler/Cargo; its GNU paths are not the paths for our proposed musl adapter.

`https://github.com/dtolnay/bootstrap/blob/master/configs/rustc-1.99.1/bootstrap.toml`

**[S08] StageX Rust package recipe.** The inspected rendered page reports 1.96.0. Use its musl integration as evidence and inspect the actual source/patch manifest at the selected revision; do not claim this page demonstrates 1.99.1 on musl.

`https://stagex.tools/packages/core/rust/`

**[S09] StageX stage0 recipe.** Documents the x86 seed entry; the seed-byte count is architecture/path specific, not the total TCB size.

`https://stagex.tools/packages/bootstrap/stage0/`

**[S10] StageX stage1 recipe.** Connects Stage0 to live-bootstrap and explicitly distinguishes this route from kernel bootstrapping.

`https://stagex.tools/packages/bootstrap/stage1/`

### Rust build and cache documentation

**[S11] Rust bootstrap-sequence redesign.** Official explanation of compiler/library staging and retained adjacent-release support.

`https://blog.rust-lang.org/inside-rust/2025/05/29/redesigning-the-initial-bootstrap-sequence/`

**[S12] Rust 1.99.1 bootstrap configuration.** Retrieved through the connected GitHub file reader at the `1.99.1` tag. File blob reported: `418c5a4a9cb81e23b777cd96454464639e372756`.

`https://github.com/rust-lang/rust/blob/1.99.1/bootstrap.example.toml`

**[S13] ccache manual.** Cache configuration, content-based compiler checks, path behavior, and hard-link caveats. The exact installed version should be recorded separately.

`https://ccache.dev/manual/latest.html`

**[S14] sccache Rust support limitations.** Read before treating it as a universal cache for compiler builds.

`https://github.com/mozilla/sccache/blob/main/docs/Rust.md`

**[S15] Docker cache optimization documentation.** Build layers, persistent cache mounts, and output-persistence boundaries.

`https://docs.docker.com/build/cache/optimize/`

**[S16] Cargo build cache reference.** Artifact directories, build-script/proc-macro separation, and wrapper integration for ordinary Cargo builds.

`https://doc.rust-lang.org/cargo/reference/build-cache.html`

**[S17] Rust 1.99.1 announcement.** Official release date and point-release fixes.

`https://blog.rust-lang.org/2026/10/15/Rust-1.99.1/`

**[S18] mrustc makefile and bootstrap test script.** Inspect version-dependent build targets, output suffixes, patches, and native seed validation.

`https://github.com/thepowersgang/mrustc/blob/master/minicargo.mk`

`https://github.com/thepowersgang/mrustc/blob/master/TestRustcBootstrap.sh`

**[S19] Rust compiler developer workflows.** Cautions around keeping old stages/libraries while iterating.

`https://rustc-dev-guide.rust-lang.org/building/suggested.html`

**[S20] LLVM CMake reference.** Target selection, compiler launchers/build configuration, and resource controls.

`https://llvm.org/docs/CMake.html`

**[S21] Rust bootstrap wrapper integration.** The searched current-source snapshot was `92b5b8c87c61b20adc9001b41baf587634a74734`; recheck the chosen release before relying on its wrapper behavior.

`https://github.com/rust-lang/rust/blob/92b5b8c87c61b20adc9001b41baf587634a74734/src/bootstrap/src/core/builder/cargo.rs`

`https://github.com/rust-lang/rust/blob/92b5b8c87c61b20adc9001b41baf587634a74734/src/bootstrap/src/bin/rustc.rs`

### Lower ancestry and reproduction sources

**[S22] StageX reproduction instructions.** Native x86-64/build-environment requirements; distinguishes preseeded development from a fresh reproduction.

`https://docs.stagex.tools/get-started/reproduce-stagex/`

**[S23] StageX contributor workflow.** Existing build and preseed workflow to reuse rather than replace prematurely.

`https://docs.stagex.tools/project/contribute-to-stagex/`

**[S24] live-bootstrap repository and component list.** Alternative/lower-chain implementation reference. Its current component listing includes GCC 15.2.0; the plan does not assume that arbitrary latest live-bootstrap output can be substituted for a pinned StageX dependency without validation.

`https://github.com/fosslinux/live-bootstrap`

`https://github.com/fosslinux/live-bootstrap/blob/master/parts.rst`

## 19. Final definition of done for v0

V0 is complete when a documented command can resume from retained sources and stage outputs, build the independent mrustc/minicargo seed, normalize it, advance the frozen Rust ladder, install rustc/Cargo/matching libraries, and pass the functional suite on the selected Linux musl target — while clearly identifying the borrowed non-Rust toolchain and cache inputs.

V0 does not require Hex0 closure, zero compiler extensions, static linking, byte-identical official outputs, or a proof. Those are later deliverables.

The first full project completion adds the Hex0-derived lower compiler closure and reruns the same Rust pipeline. The strongest later claim adds a clean replay with the remaining host assumptions stated accurately.

**Build the working chain. Preserve it. Measure it. Replace one assumption at a time.**


## 20. Optional C-snapshot feasibility experiment

This is a bounded research lane, not a prerequisite or replacement for the canonical independent mrustc route. Rustic publishes a generated-C archive and an associated compiler/backend workflow. See `AUDIT_AND_PRIOR_ART.md`, section 5, for the source-level limitations found during inspection. [R09–R13]

### 20.1 Purpose and inputs

Determine whether the inspected C archive can become a useful compiler predecessor using native tools, and what additional sysroot/Cargo/runtime inputs it needs. Use the exact inspected release/asset as an initial candidate; record the complete file inventory and native dependencies. Do not use a binary-toolchain archive while reporting a source-archive rebuild.

A generated-C seed is allowed for this experiment. Its producer is still an assumption until regeneration is connected to the independent lineage. Label its artifacts separately from mrustc-derived outputs. Do not quietly import its compiler into the canonical chain.

### 20.2 Acceptance sequence

1. Rebuild the compiler from the selected C archive without requiring an installed Rust compiler merely to launch the process.
2. Establish and document the matching sysroot/metadata and runtime closure; compile and run ordinary Rust programs.
3. Demonstrate Cargo, build scripts, procedural macros, native FFI, and unwinding.
4. Test a compiler-sized workload and the standalone native fallbacks, including recursion/stack pressure.
5. Attempt a specified next-release handoff with the resulting compiler/Cargo/sysroot.
6. Treat musl adaptation as a separate result from GNU/Linux success.
7. Later regenerate the C snapshot through the accepted independent toolchain and compare its behavior/artifacts.

Do not replace a failing native fallback with another unreviewed implementation simply to get a green hello-world. Prefer upstream native source or a narrowly justified existing fix, consistent with the project's acceptance of extensions.

### 20.3 Resource and scope limits

Run on separate resources or after the canonical early handoff so the experiment cannot starve the main build. End a session with the highest passed gate, exact blocker, and a recommendation to continue or park it. Do not port the whole backend to a new rustc tag as an unplanned side task.

The published backend test percentage is not a proof of standalone archive completeness. `CC`-wrapper behavior, optimization requirements, native stubs, generated crate metadata, and Cargo are separate things to inspect and test.

## 21. Evidence and remaining implementation gaps

Keep these states distinct in progress reports:

| State | Meaning |
|---|---|
| Recipe inspected | Its source/configuration was read |
| Upstream result reported | An author or project describes a successful result |
| Artifact published | A build output is available; its ancestry/test coverage still needs interpretation |
| Locally rebuilt | Commands actually executed on the selected builder |
| Handoff passed | Complete output drove the specified next compiler build |
| Clean replay passed | A separately defined ancestry/cache boundary was reproduced |

The actual musl reference run, final-release extension, cache effectiveness, standalone Rustic usability, and Hex0 closure remain build/test gates. More documentation cannot establish them. This plan is ready for those experiments; it is not a report that they already succeeded.
