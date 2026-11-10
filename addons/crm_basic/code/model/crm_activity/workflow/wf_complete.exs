//! Action "Complete": marks the activity as done. Hidden once it is done.

/// Returns the single selected option of a Selection, or "" for anything else. Values of
/// `exo::get_record()` arrive as plain Objects `{ selected, options }`, so both shapes count.
fn selected(value) -> String {
    if value is exo::Selection {
        let ident = value.get_selected_single();
        if ident is exo::Ident {
            ret ident.to_string();
        }
        ret "";
    }
    if value is Object {
        let list = value.get("selected");
        if list is List && list.length() > 0 {
            let first = list[0];
            if first is exo::Ident {
                ret first.to_string();
            }
            if first is String {
                ret first;
            }
        }
    }
    ret "";
}

fn show() -> Bool | Error {
    ret selected(exo::get_record()?.values.status) != "done";
}

fn main() {
    exo::rpc_model("complete")?;
    ret exo::ui::notification("success", "Activity completed", 3000);
}
