use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=csrc/add.c");
    let out = PathBuf::from(env::var("OUT_DIR").unwrap());
    let cc = env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let obj = out.join("add.o");
    let archive = out.join("libadd.a");
    let status = Command::new(&cc)
        .args(["-O2", "-c", "csrc/add.c", "-o"])
        .arg(&obj)
        .status()
        .expect("run cc");
    assert!(status.success(), "cc failed");
    let ar = env::var("AR").unwrap_or_else(|_| "ar".to_string());
    let status = Command::new(&ar)
        .arg("crs")
        .arg(&archive)
        .arg(&obj)
        .status()
        .expect("run ar");
    assert!(status.success(), "ar failed");
    println!("cargo:rustc-link-search=native={}", out.display());
    println!("cargo:rustc-link-lib=static=add");
}
