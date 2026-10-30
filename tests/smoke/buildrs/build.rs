fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rustc-env=BUILT_BY=seed-lineage");
    std::fs::write(std::env::var("OUT_DIR").unwrap() + "/gen.rs", "pub fn answer() -> u32 { 42 }").unwrap();
}
