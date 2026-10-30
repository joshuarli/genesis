unsafe extern "C" { fn add42(x: i32) -> i32; }
fn main() { assert_eq!(unsafe { add42(0) }, 42); println!("ffi ok"); }
