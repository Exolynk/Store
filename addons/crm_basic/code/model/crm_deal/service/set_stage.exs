//! Moves the active deal to the stage `stage` — or to the following open stage for "next" —
//! and applies the deal rules.

/// Returns the open stage after `stage`, or None at the end of the open pipeline.
fn next_stage(stage: String) -> String | None {
    let order = ["lead", "qualified", "proposal", "negotiation"];
    let index = order.index_of(stage);
    if index == None || index + 1 >= order.length() {
        ret None;
    }
    ret order[index + 1];
}

fn main(stage: String) -> Object | Error {
    let record = exo::db::get_record(exo::get_record()?.uuid)?;
    let previous = record.values.stage;
    if !(previous is exo::Selection) {
        // Records created through the API store no default values; use the model default.
        previous = exo::db::get_model(record.model)?.get_variable("stage")?.value;
    }
    if stage == "next" {
        let current = previous.get_selected_single();
        let following = None;
        if current is exo::Ident {
            following = next_stage(current.to_string());
        }
        if following == None {
            ret Error("ValidationError", "The deal has no following open stage", None);
        }
        stage = following;
    }
    if !previous.keys().contains(stage) {
        ret Error("ValidationError", f"Unknown stage: {stage}", { stage: stage });
    }
    let selection = previous.clone();
    selection.set_selected_single(exo::Ident::new(stage))?;
    ret exo::rpc_env("crm_deal_apply", record.uuid, "stage", selection, previous)?.first()?;
}

test "next stage follows the open pipeline" {
    assert_eq(next_stage("lead"), "qualified");
    assert_eq(next_stage("proposal"), "negotiation");
    assert_eq(next_stage("negotiation"), None);
    assert_eq(next_stage("won"), None);
}
