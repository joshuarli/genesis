extern crate proc_macro;
use proc_macro::TokenStream;
#[proc_macro_derive(IdTag)]
pub fn id_tag(input: TokenStream) -> TokenStream {
    let src = input.to_string();
    let raw = src.split_whitespace().nth(1).unwrap_or("?");
    let name: String = raw.chars().take_while(|c| c.is_alphanumeric() || *c == '_').collect();
    format!("impl {name} {{ pub fn tag() -> &'static str {{ \"{name}\" }} }}").parse().unwrap()
}
