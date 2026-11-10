//! Recalculates the key figures of one company from its contacts, deals and activities.
//! A company with won revenue that is still a lead or prospect becomes a customer.

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

/// Returns a Currency value converted to CHF, or zero CHF when there is no amount.
fn in_chf(value) -> exo::Currency | Error {
    if value is exo::Currency {
        ret value.convert(CURRENCY);
    }
    ret exo::Currency::new(0, CURRENCY);
}

/// Stores one value and passes a failure on.
fn put(record, ident: String, value) {
    let result = exo::update_record_value(record, ident, value);
    if result is Error {
        ret result;
    }
}

/// Returns the records of `model` whose reference `column` points to `company`.
fn related(model: String, company: String) {
    ret exo::db::query(exo::SqlQuery::new().model(model).and("company", "=", company));
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

fn main(company: String) -> Object | Error {
    let models = {};
    let contacts = 0;
    for _contact in related("crm_contact", company)? {
        contacts = contacts + 1;
    }

    let open_deals = 0;
    let pipeline = exo::Currency::new(0, CURRENCY);
    let won = exo::Currency::new(0, CURRENCY);
    for deal in related("crm_deal", company)? {
        let stage = selected(value_of(deal, models, "stage")?);
        let amount = in_chf(value_of(deal, models, "amount")?)?;
        if stage == "won" {
            won = (won + amount)?;
        } else if stage != "lost" {
            open_deals = open_deals + 1;
            pipeline = (pipeline + amount)?;
        }
    }

    let last_activity = None;
    for activity in related("crm_activity", company)? {
        let at = value_of(activity, models, "completed_at")?;
        if selected(value_of(activity, models, "status")?) == "done" && at is DateTime {
            if last_activity == None || at.is_after(last_activity) {
                last_activity = at;
            }
        }
    }

    let record = exo::db::get_record(company)?;
    put(record, "contact_count", contacts)?;
    put(record, "open_deal_count", open_deals)?;
    put(record, "open_pipeline", pipeline)?;
    put(record, "won_revenue", won)?;
    if last_activity != None {
        put(record, "last_activity", last_activity)?;
    }

    let status = value_of(record, models, "status")?.clone();
    let promoted = false;
    if won.amount_minor() > 0 && ["lead", "prospect"].contains(selected(status)) {
        status.set_selected_single(exo::Ident::new("customer"))?;
        put(record, "status", status)?;
        promoted = true;
    }

    ret {
        contacts: contacts,
        open_deals: open_deals,
        open_pipeline: pipeline.to_string(),
        won_revenue: won.to_string(),
        promoted_to_customer: promoted,
    };
}

test "selected ignores values that are no selection" {
    assert_eq(selected(None), "");
    assert_eq(selected("won"), "");
}
