//! Applies a value change to a deal and keeps its derived values consistent:
//! stage -> probability and closing date, amount/probability -> weighted amount,
//! and the key figures of the old and new company.

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

/// Stores one value and passes a failure on.
fn put(record, ident: String, value) {
    let result = exo::update_record_value(record, ident, value);
    if result is Error {
        ret result;
    }
}

/// Returns the default win probability in percent of a pipeline stage.
fn probability_for(stage: String) -> Int {
    // A lookup instead of `match` on String literals, which ExS 0.2.0 fails to compile (E0999).
    let probabilities = { lead: 10, qualified: 25, proposal: 50, negotiation: 75, won: 100, lost: 0 };
    let probability = probabilities[stage];
    if probability is Int {
        ret probability;
    }
    ret 10;
}

/// Returns the company UUID of a reference value, or None when it is empty.
fn company_uuid(value) -> String | None {
    if value is exo::Reference && !value.is_nil() {
        ret value.to_string();
    }
    ret None;
}

/// Applies `value` to the deal `deal`; `previous` is the value `ident` had before the change.
fn main(deal: String, ident: String, value, previous) -> Object | Error {
    if ident == "probability" {
        if !(value is Int) || value < 0 || value > 100 {
            ret Error("ValidationError", "The probability must be between 0 and 100", { value: value });
        }
    }

    let record = exo::db::get_record(deal)?;
    let values = record.values.clone();
    // Records created through the API store no default values; the model default applies.
    let model = exo::db::get_model(record.model)?;
    for name in ["stage", "amount", "probability"] {
        if values.get(name) == None {
            values[name] = model.get_variable(name)?.value;
        }
    }
    let old_company = company_uuid(values.company);
    if ident == "company" {
        old_company = company_uuid(previous);
    }

    // Only the choice of a Selection is taken over; its options stay those of the record.
    if value is exo::Selection && values[ident] is exo::Selection {
        let choice = values[ident].clone();
        choice.set_selected(value.get_selected());
        value = choice;
    }

    put(record, ident, value)?;
    values[ident] = value;

    if ident == "stage" {
        let stage = selected(value);
        let probability = probability_for(stage);
        put(record, "probability", probability)?;
        values.probability = probability;
        if stage == "won" || stage == "lost" {
            put(record, "closed_at", DateTime::now())?;
        }
    }

    let weighted = exo::Currency::new(0, "CHF");
    if values.amount is exo::Currency && values.probability is Int {
        weighted = (values.amount * (values.probability / 100.0))?;
    }
    put(record, "weighted_amount", weighted)?;

    let stats = None;
    let company = company_uuid(values.company);
    if company != None {
        stats = exo::rpc_env("crm_company_stats", company)?.first();
    }
    if old_company != None && old_company != company {
        exo::rpc_env("crm_company_stats", old_company)?;
    }

    ret {
        deal: deal,
        stage: selected(values.stage),
        probability: values.probability,
        weighted_amount: weighted.to_string(),
        company_stats: stats,
    };
}

test "stages map to their default probability" {
    assert_eq(probability_for("lead"), 10);
    assert_eq(probability_for("proposal"), 50);
    assert_eq(probability_for("won"), 100);
    assert_eq(probability_for("lost"), 0);
    assert_eq(probability_for("unknown"), 10);
}
