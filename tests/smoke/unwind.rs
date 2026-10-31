fn main() {
    let r = std::panic::catch_unwind(|| panic!("boom"));
    assert!(r.is_err());
    println!("unwind ok");
}
