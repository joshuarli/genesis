fn main() { cc::Build::new().file("csrc/add.c").compile("add"); println!("cargo:rerun-if-changed=csrc/add.c"); }
