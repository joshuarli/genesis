use std::thread;
thread_local! { static N: std::cell::Cell<u32> = const { std::cell::Cell::new(0) }; }
fn main() {
    let hs: Vec<_> = (0..4).map(|i| thread::spawn(move || { N.set(i); N.get() })).collect();
    let sum: u32 = hs.into_iter().map(|h| h.join().unwrap()).sum();
    assert_eq!(sum, 6);
    println!("threads ok {sum}");
}
