//! Action "Mark as lost": closes the deal as lost. Hidden for closed deals.

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

/// Returns whether the active deal is still open.
fn show() -> Bool | Error {
    let stage = selected(exo::get_record()?.values.stage);
    ret stage != "won" && stage != "lost";
}

fn main() {
    exo::rpc_model("set_stage", "lost")?;
    ret exo::ui::notification("warning", "Deal lost", 3000);
}
