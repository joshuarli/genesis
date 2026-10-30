# Coding-agent handoff — Rust bootstrap, revision 2

Read `README.md`, then the findings in `AUDIT_AND_PRIOR_ART.md`. Use `RUST_BOOTSTRAP_ROADMAP.md` for detailed work packages and `RESEARCH_INDEX.md` for additional primary sources. Research date: October 30, 2026. No compiler build was performed while preparing these documents.

## Mission and decision rule

Obtain a functioning modern Rust compiler from the independently implemented C++ mrustc compiler. Make iteration cheap. Then reconstruct the lower toolchain from the chosen Hex0-derived route. Only afterward tighten extensions, dependencies, reproducibility, and verification.

**Feasibility first. Reproduce before extracting. Reuse before implementing.**

GNU/Clang extensions, C++, LLVM, dynamic linking, compiler-specific flags, compatible distribution patches, Bash/Python helpers, borrowed native tools, and caches are allowed in the PoC. Do not create a C compiler/dialect, replace LLVM, rewrite libc/TLS, or build a kernel as prerequisites.

The canonical initial environment is native Linux x86-64/musl. The selected StageX recipe is the integration reference. Its observed endpoint is Rust 1.96.0. The frozen later destination is Rust 1.99.1. A GNU/glibc control build is allowed to diagnose a blocker, but is not a substitute for the musl target.

## Required ordering

1. **Inspect and pin one complete reference bundle.** Use StageX's existing workflow, dependency/import semantics, source archives, patches, mrustc revision, native runtime, and LLVM choices. Do not combine unrelated distribution defaults before reference success.
2. **Execute the seed build.** Borrow native prerequisites, but make sure mrustc/minicargo and the Rust leaf actually compile locally. An imported final Rust image is not a successful local build.
3. **Normalize the seed and prove the first release handoff.** Preserve upstream stage conventions. Compare Gentoo's `mrustc_bootstrap()` and the Guix implementation before inventing new sysroot logic.
4. **Finish the exact reference endpoint.** Keep the first working seed and the 1.96.0 reference artifact, including their runtime dependencies.
5. **Extract only the convenience glue that real usage justifies.** Thin launch/resume/test scripts are enough. Do not build a new DAG engine, compiler test framework, telemetry dashboard, or package manager.
6. **Extend to the frozen destination.** Use the existing release ladder and current Alpine/Chimera musl packaging as compatibility references, without admitting their existing Rust bootstrap packages into this lineage.
7. **Prove functional usability and an actual same-version rebuild.** Then connect the lower seed-derived native toolchain, rerun its consumers, and perform a separately defined clean replay.

Do not stop after generating a scaffold. Execute real compilation as resources permit. If the environment lacks the required resources/capabilities, produce exact non-destructive commands for the appropriate builder and mark the unexecuted gates honestly.

## Reference bundle, not just a version number

Record the selected mrustc commit, seed Rust archive, patches/overrides, C/C++ compiler, C++ runtime, compiler runtime, LLVM backend artifact, native dependencies, triples, and normalization recipe.

Gentoo's inspected route uses GCC; StageX has a Clang-oriented integration. These are not interchangeable without their associated patches and runtime choices. Likewise, “LLVM 21” is not a complete artifact identity. Pin the exact compatible build and retain shared dependencies needed by already-built predecessor compilers.

Resolve source references on the implementation host; research links are not a complete lockfile. Read an entire called helper/function before extracting it from a distribution recipe. Preserve copied material's applicable notices and attribution.

## Frozen extension ladder

The inspected Tolnay manifest contains:

```text
mrustc 0.12.0 family with the selected recipe's exact revision/patches
  → Rust 1.90.0
  → 1.91.1 → 1.92.0 → 1.93.1 → 1.94.1 → 1.95.0
  → 1.96.1 → 1.97.1 → 1.98.1 → 1.99.1
```

Preserve StageX's exact 1.96.0 endpoint as a reference branch. Extend from the appropriate common retained predecessor; do not overwrite 1.96.0 with 1.96.1 or invent a new same-release transition to make the diagram linear.

Each predecessor means compiler **plus Cargo plus matching sysroot/host libraries plus required runtime dependencies**, not just a path to an executable. `rustc --version` is a diagnostic, not a completed handoff.

For each tag, inspect `bootstrap.example.toml`, the chosen reference configuration, and actual output directories. Explicitly select predecessor paths and disable unrecorded Rust binary downloads. Keep source archives/vendor inputs available. Do not select an arbitrary Cargo using `find | head`.

## First-session implementation budget

Prefer a pinned upstream checkout, narrow overlay, manifest, launch script, smoke test, and logs/artifact paths. Use existing Make/BuildKit/Ninja/Cargo/bootstrap commands. Do not implement the roadmap's expanded CLI/layout before a reference build needs it.

Verify native C/C++ programs run, LLVM libraries load, the Rust leaf is not preseeded, disk capacity is adequate, and cgroup limits are understood. For the later Hex0 phase, separately verify execution of its early seed/32-bit stages.

Proceed to the mrustc build, Rust seed, normalization, and the first successor. Fix concrete failures with the selected recipe and relevant prior art. Change one meaningful compatibility variable at a time.

## Retention and caching

Separate downloads, prepared sources, mutable build trees, object caches, installed compiler checkpoints, and logs. Routine retries must not erase the entire workspace. Preserve at least the working seed, current predecessor, reference endpoint, and final compiler. Export artifacts outside disposable cache-only mounts.

Enable and verify ccache for:

- mrustc's own C++ compilation;
- mrustc-generated C, using the selected revision's `MRUSTC_CCACHE` path;
- source-built LLVM and other native dependencies.

Use stable paths, content-based compiler checking, a native-environment identity, compression, no hard links, and no sloppiness initially. Avoid double wrapping. A CMake launcher, a shell compiler command, and an API accepting a single executable have different interfaces; do not assume `CC="ccache gcc"` works everywhere.

Demonstrate an eligible repeated object compilation hitting the cache. A no-op Make run is a different success signal. Use Rust's built-in step timings/metrics, Cargo `--timings`, ccache counters, and normal logs before writing profiling infrastructure.

sccache is optional after the seed works. Use a separate profile, disable Cargo incremental compilation where its Rust caching requires that, and inspect tagged bootstrap wrapper integration. Do not make bootstrapping sccache a prerequisite for bootstrapping Rust. A borrowed helper stays outside the later clean-replay claim unless rebuilt/accounted for.

Suggested starting limits on a 64 GB host are 12 native jobs, 8 Rust jobs, 2 minicargo jobs, and one large link. These are tuning guesses; respect actual cgroup resources and nested scheduling. Keep intermediate compilers optimized, with no LTO/PGO and little debug info initially. Preserve recipe-specific optimization requirements.

## Must-handle integration pitfalls

**Deferred codegen:** in the inspected minicargo implementation, `MINICARGO_DEFER_CODEGEN=0` still enables the path because it tests variable presence. Unset it when calling the underlying operations, or use a narrow explicit-control patch. A convenience wrapper may reintroduce the default.

**Patches:** distinguish compatibility changes, distribution policy, and tuning. Do not apply a patch twice or resume by layering patches onto a partially patched tree. Reprepare only the affected source tree when necessary.

**musl:** document compiler-host linkage separately from produced-program linkage. The StageX package policy must not silently become a claim of stock static-musl output. Test every output mode actually promised; preserve required CRT objects and native archives.

**late LLVM:** compare current Alpine/Chimera packaging before diagnosing every crash as a Rust miscompile. Alpine's inspected 1.99.1/LLVM-23 recipe has stack-size guidance; Chimera addresses predecessor runtime survival across LLVM changes. Apply fixes only to the affected compatibility profile.

**Cargo/native dependencies:** don't automatically substitute arbitrary system libgit2 or native libraries for a recipe's vendored versions. Use declared compatible dependencies before reducing them.

**environment leakage:** isolate unrelated Cargo config, rustup shims, `RUSTC_WRAPPER`, `RUSTC_WORKSPACE_WRAPPER`, encoded flags, target/linker overrides, and global release-profile knobs. Preserve host/target flag distinctions. Do not require mounting the user's entire home directory or secrets.

**runtime checkpoints:** test promoted prefixes with their original build tree unavailable. Broken absolute symlinks, wrappers, or missing shared LLVM/libstd dependencies invalidate the checkpoint even if it worked inside the build directory.

**exit status and retries:** keep the actual failing command/status through logging. A bounded retry must not turn repeated failure into success. Do not interpret all failures as races or clear the whole build tree reflexively.

## Tests and acceptance

Reuse mrustc's applicable local tests and rustc's matching tagged harnesses. Keep a small offline workspace for ordinary code, procedural macros, build.rs, C FFI, threads/TLS, and unwinding. Invalid-program rejection belongs to native rustc, not mrustc's intentionally limited validation model.

At the reference/final compiler, run a curated upstream UI/run-make/library subset plus one modest external fixture. Do not bless changed output or add skips solely to get green results. Record unavailable dependencies separately from test failures.

A same-version rebuild must execute actual compilation rather than stage uplift/copy. Final installed tools must function outside their original work tree in the declared runtime environment. Byte equality with official releases is not a v0 requirement.

ABI Cafe, Rustlantis, and diffoscope are later reusable tools, not initial prerequisites or automatic correctness proofs.

## Optional Rustic experiment — separate label and scope

The audit found a generated-C compiler-snapshot route in `rustic-compiler/rustc_codegen_c`. Do not confuse it with the original `rust-lang` project or make it the canonical path based on its README alone.

Run a bounded experiment after the early canonical handoff or on separate resources. Test: source archive inventory; rebuild with no installed Rust compiler; complete sysroot/metadata; Cargo/proc macros/build scripts; native fallback behavior and deep recursion; compiler-sized workload; next-release handoff; separate musl adaptation.

The standalone C archive has different native fallbacks from the normal backend build. Its producer and any supplied metadata/native binaries remain admitted inputs. Record the highest passed gate and stop at a concrete blocker rather than launching an unplanned backend rewrite. Independent regeneration through the mrustc-derived lineage is a later goal.

## Later milestones and reporting

After the borrowed-native-toolchain PoC, rebuild the necessary lower StageX/Stage0 compiler closure. Rerun its consumers under a new native/cache identity. A rebuilt C++ compiler sitting next to outputs produced by an imported compiler does not change those outputs' ancestry.

For clean replay, use a separate boundary for outputs and compiled caches; source downloads may remain. Document host kernel, hardware, and orchestration assumptions. Do not call ordinary self-hosting verified or diverse double-compilation.

After meaningful progress, report: selected reference; highest passing stage; exact next failing command; first substantive error; useful runtime/config details; retained artifact paths; and the narrow next experiment. Maintain a brief resume note. Never report a successful workflow/scaffold as a successfully built compiler.
