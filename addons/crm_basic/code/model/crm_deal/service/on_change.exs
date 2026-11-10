//! After a deal value changed: applies the shared deal rules of the environment.
//! A change the rules refuse, such as a probability above 100, is reverted.

/// Returns whether a change of `ident` affects derived deal or company values.
fn relevant(ident: String) -> Bool {
    ret ["stage", "amount", "probability", "company"].contains(ident);
}

fn main(old: exo::Variable, new: exo::Variable) {
    if !relevant(new.ident) {
        ret;
    }
    let record = exo::get_record()?;
    let result = exo::rpc_env("crm_deal_apply", record.uuid, new.ident, new.value, old.value);
    if result is Error && result.kind() == "ValidationError" {
        let reverted = exo::update_record_value(record.uuid, new.ident, old.value);
        if reverted is Error {
            ret reverted;
        }
        let logged = exo::add_record_log_comment(record.uuid, f"Change of {new.ident} reverted: {result.message()}");
        if logged is Error {
            ret logged;
        }
    }
    if result is Error {
        ret result;
    }
}

test "only value changes with derived values are relevant" {
    assert(relevant("stage"));
    assert(relevant("amount"));
    assert(!relevant("weighted_amount"));
    assert(!relevant("name"));
}
