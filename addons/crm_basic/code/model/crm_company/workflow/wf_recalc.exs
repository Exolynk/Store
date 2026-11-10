//! Button "Recalculate" next to the key figures: refreshes the key figures of the company.

/// Keeps the workflow out of the action bar; the layout button next to the key figures starts it.
fn show() -> Bool {
    ret false;
}

fn main() {
    let stats = exo::rpc_model("recalc")?[0];
    ret exo::ui::notification(
        "success",
        f"{stats.contacts} contacts, {stats.open_deals} open deals, pipeline {stats.open_pipeline}",
        4000,
    );
}
