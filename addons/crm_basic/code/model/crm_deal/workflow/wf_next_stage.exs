//! Action "Next stage": moves the deal one step forward in the open pipeline.
//! Hidden for closed deals and in the last open stage.

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
    let stage = selected(exo::get_record()?.values.stage);
    // A record without a stored stage has the model default "lead".
    ret stage == "" || ["lead", "qualified", "proposal"].contains(stage);
}

fn main() {
    let result = exo::rpc_model("set_stage", "next")?[0];
    ret exo::ui::notification("success", f"Stage: {result.stage} ({result.probability} %)", 3000);
}
