//! Hourly job: brings every derived CRM value up to date — closed deals get their final
//! probability and closing date, every deal its weighted amount, every contact its full name
//! and every company its key figures. Values that are already correct are not written.
//!
//! It replaces the record-level ValueChanged hooks, which the server runs as Rune only.

const CURRENCY = "CHF";

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

/// Stores `value` unless the record already holds it; returns whether it was written.
fn sync(record, ident: String, value) -> Bool | Error {
    let current = record.values.get(ident);
    if current is Error {
        ret current;
    }
    if current == value {
        ret false;
    }
    let result = exo::update_record_value(record.uuid, ident, value);
    if result is Error {
        ret result;
    }
    ret true;
}

/// Returns the default win probability in percent of a pipeline stage.
fn default_probability(stage: String) -> Int {
    let probabilities = { lead: 10, qualified: 25, proposal: 50, negotiation: 75, won: 100, lost: 0 };
    let probability = probabilities[stage];
    if probability is Int {
        ret probability;
    }
    ret 10;
}

/// Returns the probability a closed deal must have, or None for an open one.
fn closed_probability(stage: String) -> Int | None {
    if stage == "won" {
        ret 100;
    }
    if stage == "lost" {
        ret 0;
    }
    ret None;
}

/// Returns the weighted amount of a deal in its own currency.
fn weighted(amount, probability) -> exo::Currency | Error {
    if amount is exo::Currency && probability is Int {
        ret (amount * (probability / 100.0))?;
    }
    ret exo::Currency::new(0, CURRENCY);
}

/// Returns the full name of a person; missing parts are left out.
fn full_name(first, last) -> String | Error {
    let parts = [];
    for part in [first, last] {
        if part is String && part.trim() != "" {
            parts.push(part.trim());
        }
    }
    ret parts.join(" ")?;
}

/// Returns the value of `ident` of `record` like the server sees it: records created through
/// the API store no default values, so a missing value is the model default. `models` caches
/// the models by UUID.
fn value_of(record, models: Object, ident: String) -> Any | Error {
    let model = models[record.model];
    if model == None {
        model = exo::db::get_model(record.model)?;
        models[record.model] = model;
    }
    let value = record.values.get(ident);
    if value != None {
        ret value;
    }
    let variable = model.get_variable(ident);
    if variable == None {
        ret None;
    }
    ret variable.value;
}

fn main() -> Object | Error {
    let now = DateTime::now();
    let models = {};
    let deals = 0;
    for deal in exo::db::query(exo::SqlQuery::new().model("crm_deal"))? {
        let changed = false;
        let stage = selected(value_of(deal, models, "stage")?);
        let probability = value_of(deal, models, "probability")?;
        let final_probability = closed_probability(stage);
        if !(probability is Int) {
            // Records created through the API start without default values.
            probability = default_probability(stage);
            changed = sync(deal, "probability", probability)? || changed;
        }
        if final_probability != None {
            probability = final_probability;
            changed = sync(deal, "probability", probability)? || changed;
            let closed_at = value_of(deal, models, "closed_at")?;
            if !(closed_at is DateTime) || closed_at.as_unix_seconds() <= 0 {
                changed = sync(deal, "closed_at", now)? || changed;
            }
        }
        changed = sync(deal, "weighted_amount", weighted(value_of(deal, models, "amount")?, probability)?)? || changed;
        if changed {
            deals = deals + 1;
        }
    }

    let contacts = 0;
    for contact in exo::db::query(exo::SqlQuery::new().model("crm_contact"))? {
        let name = full_name(contact.values.first_name, contact.values.last_name)?;
        let current = contact.values.name;
        if name != "" && (!(current is exo::Language) || current.get("en") != name) {
            sync(contact, "name", exo::Language::new({ en: name, de: name }))?;
            contacts = contacts + 1;
        }
    }

    let companies = 0;
    for company in exo::db::query(exo::SqlQuery::new().model("crm_company"))? {
        exo::rpc_env("crm_company_stats", company.uuid)?;
        companies = companies + 1;
    }

    log::info("crm_recalc_all:", deals, "deals and", contacts, "contacts updated,", companies, "companies recalculated");
    ret { deals_updated: deals, contacts_updated: contacts, companies_recalculated: companies };
}

test "closed deals have a fixed probability" {
    assert_eq(closed_probability("won"), 100);
    assert_eq(closed_probability("lost"), 0);
    assert_eq(closed_probability("proposal"), None);
}

test "missing probabilities follow the stage" {
    assert_eq(default_probability("negotiation"), 75);
    assert_eq(default_probability(""), 10);
}

test "full name joins the given parts" {
    assert_eq(full_name("Ada", "Lovelace"), "Ada Lovelace");
    assert_eq(full_name("", "Lovelace"), "Lovelace");
}
