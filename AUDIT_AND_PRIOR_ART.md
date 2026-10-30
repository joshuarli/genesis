# Rust bootstrap roadmap — sanity, completeness, and prior-art audit

**Revision:** 2 · **Research date:** October 30, 2026  
**Scope:** audit of the earlier roadmap and coding-agent prompt; source and recipe inspection, not an executed bootstrap.

## Executive conclusion

The central approach survives: use an existing independent Rust compiler, get a working modern Rust toolchain, retain intermediate results, then reconstruct the lower compiler ancestry. The first plan was nevertheless too quick to design an adapter/controller and too narrow in its prior-art coverage.

The most important change is **reference reproduction before recipe synthesis**. Keep one distribution's complete, pinned combination of mrustc, patches, native runtime, LLVM, and normalization procedure. Do not compose a new bootstrap from the most attractive fragments of five recipes before obtaining a working reference.

The revised implementation order is:

```text
Pinned StageX musl recipe, borrowed native prerequisites
  → locally built mrustc and Rust seed
  → normalized predecessor + first release handoff
  → reference recipe's 1.96.0 endpoint
  → minimal extraction/resume improvements where actually needed
  → frozen extension to 1.99.1, informed by current musl packaging
  → functional self-build and useful programs
  → Hex0-derived native prerequisites, then replay/reduction
```

Rustic's generated-C snapshot is now a worthwhile **separate experiment**, but it does not supersede that default. Its independent-seed status, package completeness, and standalone behavior require different tests.

The R references resolve in `RESEARCH_INDEX.md`. The original S references remain in the revised roadmap. Neither source list is a ready-to-build lockfile.

## 1. Findings and priority

| Priority | Finding | Required change |
|---|---|---|
| P0 | The plan could encourage writing a new runner before reproducing the existing build | Use upstream StageX orchestration and the selected recipe first; add only thin, demonstrated conveniences |
| P0 | Seed normalization was under-researched relative to its importance | Compare upstream mrustc, Gentoo, and Guix procedures before editing it |
| P0 | “mrustc 0.12.0” is not a complete compatibility specification | Pin compiler source, patch series, native compiler/runtime, LLVM, and override files as a bundle |
| P0 | The musl target's default linking policy was underspecified | Separate compiler-host requirements from the default linking behavior of programs it produces |
| P0 | The initial target extended beyond the inspected reference without a mandatory reference checkpoint | Reproduce the selected 1.96.0 recipe before treating 1.99.1 as merely another tested configuration |
| P1 | Current Alpine/Chimera integration was omitted | Use their late-release packaging as compatibility evidence, without importing their binary Rust ancestry |
| P1 | Generated-C Rust compiler snapshots were omitted | Add a bounded Rustic experiment with its own acceptance ladder and trust label |
| P1 | LLVM alternatives were treated too speculatively | Include demonstrated GCC-backend self-bootstrap results; distinguish them from gccrs |
| P1 | Profiling/test infrastructure was underused | Reuse Rust bootstrap metrics, Cargo timings, compiletest, and existing ABI/differential tools |
| P1 | Resume behavior lacked several concrete invalidation/runtime checks | Protect complete predecessor closures; isolate mutable source, Cargo configuration, and LLVM upgrades |
| P2 | Some ecosystem claims could be confused with accepted production paths | Record branch/PR status and remaining seed dependencies explicitly |
| P2 | Small C bootstrap alternatives were not sharply bounded | Keep Onramp/boot2 and snapshot-format precedents in later design work, not the initial dependency chain |

“P0” here means important to a reliable feasibility experiment, not a request to build a security certification framework.

## 2. Reproduce a known route before composing a new one

### 2.1 The earlier design had avoidable integration risk

The old roadmap combined StageX's musl environment, Tolnay's release ladder, mrustc's standalone helpers, and a proposed new controller. Each is useful. Their combination was not already tested by any one source we inspected.

For example, a package recipe's compiler flags may be compensating for a particular C++ standard library or generated-C behavior. Replacing its compiler because another project uses GCC, while retaining Clang-specific patches and changing LLVM, creates several simultaneous explanations for a failure.

**Revision:** preserve one exact recipe's behavior first. Its build system remains the authority for dependency scheduling. Keep a small overlay for cache paths, conservative resource limits, and retaining successful artifacts. Log such changes as experimental deltas. Do not “clean up” the recipe before reproducing it.

StageX already provides development/import and reproduction workflows. Use those rather than introducing a new graph resolver. A dependency-only import is acceptable in the PoC; a preseeded final Rust result is not a locally executed Rust bootstrap. [R05, R06]

### 2.2 What reference reproduction actually means

The first log should establish which commands compiled mrustc and which commands built the Rust seed. Merely running a package target whose result was imported does not establish that either happened locally.

Conversely, do not require rebuilding unrelated distribution packages. Follow the selected Rust target's declared prerequisites and borrow them initially. Audit the leaf-target import/cache behavior once so that an execution result cannot be mistaken for a download result.

A fixed package version, commit, and output log are sufficient initially. There is no requirement for a custom provenance database.

### 2.3 Preserve the exact reference endpoint

The observed StageX endpoint is 1.96.0; the chosen later ladder uses 1.96.1. Preserve them as different checkpoints. Do not overwrite one source directory with the other's files or reuse a success marker across them.

After reference success, extend from the last appropriate common predecessor. If the retained 1.95.0 compiler is the specified predecessor for the 1.96.1 adapter, use it. Do not invent a 1.96.0-to-1.96.1 handoff merely to make a visual sequence linear. Same-release bootstrapping may be supported, but the adapter must establish it rather than assume it.

A GNU/Linux Tolnay reproduction is a useful isolated control if musl integration fails. It can answer whether the seed or release adapter is generally broken. It does not satisfy the canonical musl milestone and should not quietly replace it.

## 3. Concrete seed-normalization prior art the first plan missed

### 3.1 Gentoo is immediately useful

Gentoo packages both mrustc and a Rust `mrustc-bootstrap` path. The inspected mrustc package requires GCC for its route, supplies its source and patches explicitly, and installs the intermediate artifacts and overrides needed by the Rust package. The Rust package has a dedicated `mrustc_bootstrap()` function, with comments pointing to upstream native-sysroot and bootstrap-test procedures. [R01–R03]

This is more valuable than another general explanation of bootstrapping: it is maintained integration code for exactly the transition that can otherwise consume weeks of trial and error.

**What to take:** the sequence of stage-specific compiler/library setup, provided-source conventions, explicit native dependencies, and cleanup of bootstrap environment variables.

**What not to do:** execute a copied ebuild as a standalone script, assume its helpers are ordinary shell commands, mix its GCC assumptions into the StageX Clang recipe, or use its installed compiler package as an unexplained seed.

### 3.2 Guix supplies another concrete implementation

The inspected `rust-team` commit adds a Rust 1.90 bootstrap using a separately pinned mrustc source and an explicit normalization step. The retrieved artifact is a branch commit diff, not proof that the change was merged into the main branch or independently reproduced here. [R04]

**Use it as a comparison:** when a seed output cannot drive Cargo or `x.py`, inspect another implementation's stage and installation logic before creating new normalization machinery. Do not combine patch sets simply because both list Rust 1.90.

### 3.3 Pin a compatibility bundle

A useful initial manifest records:

```text
mrustc source revision
Rust seed source archive
mrustc and Rust patch/override series
C and C++ compiler identities
C++ standard library and compiler runtime
LLVM backend artifact and llvm-config
host and target triples
native dependency root
normalization recipe revision
```

This is a practical debugging aid. Compiler source version alone cannot explain a build that changes from GCC/libstdc++ to Clang/libc++ or from one native dependency set to another.

Before applying an upstream fix, check whether it is already in the selected source. Patch rejection, offset drift, and duplicated workarounds should be explicit failures or deliberate reviewed adjustments—not ignored output.

## 4. The musl contract needs to be explicit

### 4.1 “A musl compiler” describes several different properties

These are separate decisions:

| Question | Initial recommendation |
|---|---|
| Which libc runs the compiler process? | musl in the canonical reference environment |
| Is the compiler itself static? | Not required |
| Is LLVM shared or static? | Preserve the selected working recipe |
| Which target triple does rustc advertise and use by default? | Record and validate it explicitly |
| Are compiled user programs static by default? | Follow a documented policy, not an inference from the host's libc |
| Are C archives/CRT objects needed for another output mode retained? | Preserve until the declared target policy and tests justify removal |

A dynamic compiler can emit static programs, and a static compiler can emit dynamic programs. Testing one does not establish the other.

### 4.2 StageX's package choices are not neutral defaults

The inspected recipe changes musl's default static-link policy and removes `.a` files from its final installation. It also sanitizes generated/vendor inputs. These are distribution choices beyond “make rustc compile.” [R05]

**Revision:** retain an exact reference profile, then classify changes as required compatibility, distribution policy, or performance tuning. Do not remove a sanitizer while keeping its checksum/lockfile modifications by accident, and do not advertise stock static-musl output without testing the required archives and CRT path.

This is not a demand to undo StageX's policy. It is a demand to choose deliberately what this project's output promises.

### 4.3 Alpine and Chimera address the late releases

The inspected Alpine recipe targets Rust 1.99.1 with LLVM 23 and sets `RUST_MIN_STACK=16777216`, with a comment tying increased stack needs to LLVM 23. It also avoids arbitrary system libgit2, whose compatibility changes have previously disrupted Cargo packaging. [R07]

**Action:** add a version-specific stack/LLVM note to late-ladder triage. Do not turn every compiler crash into a code-generation investigation before comparing the relevant distribution's stack/runtime requirements. Do not globally apply a stack override to all stages without a reason.

The inspected Chimera template supplies useful musl/Clang/libc++ configuration and explicitly addresses preserving bootstrap compilers across LLVM upgrades. It also separates host/target native flags and pkg-config handling. [R08]

**Action:** retain each predecessor's native runtime closure while building its successor. Replacing a shared LLVM installation underneath an otherwise unchanged predecessor can break the next transition before any Rust source is compiled.

Neither recipe removes the independent-seed requirement: both consume already-existing Rust bootstrap packages. Borrow packaging knowledge, not an unrecorded Rust binary.

## 5. Rustic is a significant missed option—with a different question to answer

### 5.1 What makes it relevant

`rustic-compiler/rustc_codegen_c` documents producing a Rust compiler from a generated-C archive and publishes such artifacts. This is much closer to the original C-substrate idea than a generic experimental backend. The inspected release and CI correspond to a 1.94.1-based fork and GNU/Linux assets. [R09–R11]

A useful architecture could eventually be:

```text
independent mrustc route → working rustc
    → reproducibly generate a maintained C compiler snapshot
    → rebuild that snapshot with a selected C toolchain
    → use it as a shorter operational entry point
```

That is a proposal, not an achieved result. The independent route could establish the snapshot's derivation later. Initially an imported C snapshot is a declared source-like seed, not proof of independent source ancestry.

### 5.2 The current evidence does not justify replacing mrustc

The project's reported UI-test result applies to the backend-built compiler tested by its workflow. Its standalone C artifact follows a different native linking path. The inspected source uses weak native fallbacks; the PSM fallback directly calls the callback instead of switching stacks. [R09, R11, R12]

Therefore there are two separate artifacts to test: a compiler built normally using the backend, and a compiler rebuilt solely from the released C archive. Success of the first cannot simply be assigned to the second.

The C archive workflow also does not itself demonstrate a complete standalone Cargo/compiler/sysroot handoff. Generated standard-library C and compiled library objects are not automatically all of the Rust crate metadata and host libraries a compiler needs. This is an acceptance question, not a conclusion that the package is necessarily unusable.

### 5.3 Define a contained experiment

Run this separately, preferably after the canonical first handoff or on independent resources. Stop the experiment at a concrete blocker rather than converting it into a rewrite of Rust's C backend.

| Gate | Evidence to collect |
|---|---|
| X0: source archive is the input | Exact release, asset name, checksum, file inventory; no binary-toolchain asset substituted |
| X1: rebuild without an installed Rust compiler | C/C++/native dependencies and generated sources produce a running compiler; explicit fixed host tuple avoids `rustc` merely to choose a download name |
| X2: compile ordinary Rust | Produce and execute programs using a declared matching sysroot; identify how metadata and host libraries were produced |
| X3: tool ecosystem | Build/run Cargo fixtures, a procedural macro, build.rs, native FFI, and an unwinding example |
| X4: nontrivial compiler workload | Deep types/recursion, realistic crate, and same-version compiler build exercise standalone native fallbacks |
| X5: handoff | Use the resulting compiler/Cargo/sysroot for a specified next-release build |
| X6: musl | Separate tested adaptation; do not infer it from GNU/Linux archives |
| X7: independent regeneration | Recreate the C snapshot with the accepted independent lineage and compare outputs/behavior |

For X1, the initial source-like seed may contain generated C; that is allowed by the experiment's definition. Imported `.o`, `.a`, `.so`, `.rlib`, or binary metadata, if required, must be named rather than hidden. They may be acceptable for a diagnostic result but change its classification.

The inspected backend passes `CC` directly to an executable launcher, so a space-containing `CC="ccache gcc"` will not work as a universal solution. Use a real wrapper executable for that consumer. Its fixed optimization/aliasing/unwind flags also need to be preserved until a working baseline is established. [R13]

### 5.4 Distinguish similarly named projects

`rust-lang/rustc_codegen_c`, Rustic's fork, and `FractalFir/rustc_codegen_clr` are separate projects. They are valuable lowering/test references, but one project's release assets and results do not establish another's capabilities. All rustc-backend paths still need a rustc frontend or a generated compiler snapshot; they are not equivalent to the independent mrustc entry. [R09, R14, R15]

## 6. LLVM removal has stronger prior art than the first answer acknowledged

The Rust project's GSoC 2025 results report stage-2 and stage-3 rustc builds using `rustc_codegen_gcc`. This is concrete self-bootstrap work, not merely a speculative future backend. It still depends on rustc's frontend and a compatible backend/GCC setup. [R16]

**Revision:** after the LLVM route is stable, consider a narrowly pinned GCC-backend self-build before designing a new backend. Reuse its tests and upstream fixes. Do not claim a smaller TCB merely because the backend's name changes; measure the complete dependency closure.

The separate **gccrs** project is an independent GCC Rust frontend. The inspected August 2026 report does not establish a modern-rustc bootstrap path. It remains a watch item, not a dependency of this project. Cranelift likewise belongs in a later codegen/performance experiment, not as a substitute for proving the initial frontend seed. [R17, R18]

## 7. Expanded prior-art map: what to reuse and what not to inherit

| Prior art | Best use for this project | Boundary |
|---|---|---|
| mrustc + minicargo + upstream bootstrap scripts | Independent seed implementation and native normalization | Not a full validating Rust implementation for arbitrary invalid input |
| StageX | Canonical musl recipe, native prerequisites, lower ancestry, existing build orchestration | Distribution policy and imported artifact behavior must be understood |
| dtolnay/bootstrap | Compact release ladder and explicit predecessor configuration | GNU-oriented setup does not establish musl success |
| Gentoo | Seed integration and concrete bootstrap sysroot procedure | GCC-specific bundle and package-manager helpers |
| Guix | Independently organized seed recipe and source accounting | Inspected branch commit is not a local build result |
| Alpine | Current musl Rust/LLVM/Cargo packaging | Existing Rust seed remains an input |
| Chimera | musl/Clang/libc++ runtime integration and bootstrap packaging | Existing Rust seed remains an input |
| Rustic | Generated-C compiler-snapshot experiment | Different ancestry claim; standalone path needs its own tests |
| rustc_codegen_gcc | Later backend self-hosting and ABI tests | Not gccrs; does not itself break frontend circularity |
| Cranelift / original C / CIL-C backends | Alternative lowering and testing ideas | Backend plugins, not automatically complete source bootstrap routes |
| Nixpkgs proposal | Derivation organization and practical review history | Inspected PR closed without merge |
| Freedesktop SDK | Native source bootstrap, BuildStream artifact/dependency concepts | This audit did not close the Rust-stage1 ancestry |
| live-bootstrap / Mes / Stage0 | Existing lower compiler ancestry | Follow the selected integration rather than mixing untested endpoints |
| Onramp / boot2 | Later minimal C substrate and staged bootstrap ideas | A C endpoint is not yet the required C++/LLVM/Rust environment |
| Nim generated C / historical Zig WASM-to-C | Snapshot formats, regeneration, small bootstrap drivers | Translated snapshots still carry seed assumptions |
| compiletest / ABI Cafe / Rustlantis / diffoscope | Validation and comparison infrastructure | Use after the required compiler exists; interpret each tool's assumptions |

The table is a reuse map, not a demand to install sixteen build systems. The canonical runtime remains one small selected workflow. References are in S01–S24 and R01–R31.

### Evidence-quality corrections

The inspected Nixpkgs PR #528074 is closed and unmerged. Its associated author account contains a correction retracting an earlier claim of a completed compiler update. Treat it as useful proposal/review material, not an accepted default or a benchmark. [R19, R20]

Freedesktop SDK has substantial native bootstrap and Rust packaging work, but the inspected Rust recipe's predecessor was not fully traced here. Its small native seed cannot be used as proof that its Rust compiler has no binary Rust ancestor. [R21]

Onramp's README explicitly calls out unfinished functionality; boot2's documented C toolchain endpoint does not supply the remaining C++/LLVM bridge. Neither should displace the demonstrated integration path at the beginning. [R22, R23]

Nim's C-source bootstraps and the historical Zig WASM-to-C approach show that portable compiler snapshots are practical engineering artifacts. They also illustrate why “compiled using C” and “independently derived from source” must stay separate labels. The Zig GitHub material inspected here is archived/historical, not its current development tree. [R24, R25]

## 8. Iteration and caching: additions that reduce real wasted work

The old plan's layered retention strategy is sound. Keep it, with the following more operational rules.

### 8.1 Keep build directories distinct from disposable caches

Downloads, mutable source trees, compiler objects, installed predecessor prefixes, logs, and optional object caches have different lifetimes. A cache garbage-collection operation must never delete the only successful seed or the only record of a failed build.

Retain at least the seed, the last passing predecessor, the reference endpoint, and the selected final toolchain. Do not require every large old source tree to remain unpacked forever. Make source eviction separate from successful compiler-prefix eviction.

If a container cache mount contains all compiler objects, a cache reset may reasonably cause recompilation. If it contains the only installed compiler checkpoint, the artifact-retention design is wrong. Promote outputs to an explicit artifact location.

### 8.2 Measure existing tools first

Use Rust bootstrap's step timings/resource metrics, Cargo's `--timings`, ccache statistics, and normal build-system logs. Add a small summary script only when these fail to answer a specific question. [R26, R27]

The initial performance checks should be:

| Change | Expected behavior |
|---|---|
| No source/config changes | No expensive completed stage reruns |
| Touch a non-build documentation file | No compiler rebuild |
| Change one mrustc C++ source | Relevant native object rebuild; later affected consumers are invalidated |
| Change only a late-release patch | Earlier installed compilers remain usable |
| Replace compiler/native runtime | New object-cache identity; no reuse pretending this was the same toolchain |
| Interrupt a late link/build | Resume its stage; do not erase the seed |
| Rebuild an eligible identical C object | Observable cache hit, not merely a Make no-op |

Do not promise any particular speedup until measured. Global codegen-thread tuning, output compression, and remote caches should not precede these checks.

### 8.3 Account for layered scheduling

Make jobs, minicargo workers, Cargo jobs, rustc codegen units/threads, and linker concurrency can multiply. One recorded resource policy should control the limits actually supported by each pinned tool. Preserve jobserver semantics where supplied; do not launch a second unrestricted scheduler because `nproc` reports many CPUs.

Resource defaults in the roadmap remain estimates. Record cgroup memory/CPU limits, peak resident memory, and any OOM termination. Keep an isolated recovery profile rather than globally disabling optimization.

### 8.4 Source mutation and caches must agree

Extract source archives into a known prepared tree once. Reapplying a patch stack on top of a partially patched tree is not resume. Store the prepared-tree identity and compare it before reuse. If changing a patch requires re-preparing one tree, preserve independent predecessor artifacts.

Keep stable execution paths per active variant. Avoid needlessly changing every compiler's working path whenever an unrelated manifest entry changes. Do not compensate for poor path layout by disabling all path-sensitive cache checks.

### 8.5 Scope environment/configuration deliberately

Use a dedicated Cargo home/configuration for each incompatible build profile or compiler stage; downloads may still be shared. Log relevant inherited overrides and explicitly neutralize unrelated user settings, including wrapper variables, encoded Rust flags, target/linker settings, and release-profile knobs.

Separate host and target flags when native build scripts or cross-target libraries are involved. Even on a native build, the bootstrap process can run host tools while compiling a different library set. Prefer a native-only initial configuration; do not add extra targets merely because a distribution package supports them.

A rootless or non-root container setup is useful, but not a new platform project. Ensure cache/artifact ownership permits the next run to write them without destructive recursive permission fixes.

## 9. Test completeness without inventing another compiler test framework

The small local workspace remains useful as an integration smoke test. It should not become a replacement for upstream tests.

**At mrustc:** use its applicable local tests and the selected valid-code samples. Do not require it to reject invalid Rust as if it were rustc.

**At the normalized seed and first handoff:** test real compilation, Cargo build-script execution, procedural-macro loading, native library lookup, threads/TLS, and unwinding. These expose many incomplete-prefix failures earlier than a full late-ladder build.

**At the reference/final endpoints:** run a curated subset of upstream UI/run-make and library tests with the matching tagged harness. Do not use `--bless` or new skip lists merely to obtain a green result. Preserve the difference between an expected upstream failure, an unavailable test dependency, and a regression. [R28]

**At backend changes:** ABI Cafe and Rustlantis provide reusable deeper tests. They have their own domains and assumptions: ABI Cafe is descriptive and may construct undefined-behavior cases; Rustlantis exercises rustc MIR and requires matching tooling. Neither is an initial dependency or an automatic proof of correctness. [R29, R30]

**At replay:** use diffoscope and existing reproducible-build tools to explain differences. Functional equality, byte equality, and source/binary correspondence remain separate assertions. [R31]

### Additional acceptance checks

A promoted compiler must work with the original build directory unavailable, in the declared runtime environment. Verify symlinks, executable interpreter, required shared libraries, codegen backend, native library/metadata directories, and Cargo. A wrapper that refers to a deleted absolute build path is not an installed checkpoint.

The first same-version rebuild must demonstrably execute compilation. Cache hits are allowed in development but cannot transform a copy/uplift operation into evidence of self-compilation. Preserve the specific commands and resulting output location.

For the final advertised target policy, test both the default executable and any separately promised static/dynamic mode. Inspect the output rather than assuming a triple name proves the linking mode.

## 10. Revised delegation and first-session output

The primary agent should follow the canonical build. A research/helper agent can inspect one failing release, compare a specific distribution patch, or examine the Rustic experiment. They should not mutate the same source/build tree or launch competing memory-heavy compiler stages.

The first meaningful handoff should contain:

```text
Selected reference and exact revision
Borrowed native prerequisites
Actual seed-build command and log
Highest passing compiler stage
Exact first failing command, if any
First substantive error and relevant runtime/configuration details
Retained predecessor/artifact paths
Next narrow experiment
```

A complete `doctor/status/clean/export/cache` CLI is not a prerequisite. A few repeatable commands, faithful exit statuses, preserved work, and an honest handoff are better than an untested orchestration framework.

## 11. Remaining questions that require builds, not more prose

1. Does the selected StageX bundle reproduce its published reference endpoint on the actual builder with imported native prerequisites but a locally built Rust leaf?
2. Which exact transition and LLVM/native runtime configuration first fails when extending the reference to 1.99.1?
3. Does the normalized seed's complete installed prefix work outside the build tree, including procedural macros and Cargo build scripts?
4. Which caches actually receive eligible compiler invocations, and how much work do they avoid?
5. Can the inspected Rustic source archive yield a complete usable predecessor without an unrecorded Rust compiler/sysroot, and can it survive a compiler-sized workload?
6. What additional work is required for that snapshot route on musl?
7. Which lower-toolchain prerequisites must be rebuilt before claiming the Hex0-derived compiler ancestry, and can the selected host execute the early seed stages?

The revised plan has concrete gates for these questions. It does not label unanswered questions as solved, and it does not postpone the first build until every one is answered.

## Bottom line

The revised project is **an integration and reproduction effort first**, a compiler/toolchain simplification effort second. Reuse the actual recipe, stage-specific sysroot logic, late-version musl fixes, built-in metrics, and existing tests. Preserve successful artifacts. Explore the C-snapshot shortcut separately. Only then replace the machinery underneath the working route.
