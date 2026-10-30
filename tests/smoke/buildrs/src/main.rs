include!(concat!(env!("OUT_DIR"), "/gen.rs"));
fn main() { assert_eq!(answer(), 42); assert_eq!(env!("BUILT_BY"), "seed-lineage"); println!("buildrs ok"); }
