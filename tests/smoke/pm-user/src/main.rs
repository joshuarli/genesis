use pm_derive::IdTag;
#[derive(IdTag)]
struct Widget;
fn main() { assert_eq!(Widget::tag(), "Widget"); println!("pm ok"); }
