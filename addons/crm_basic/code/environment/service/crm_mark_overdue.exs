//! Nightly job: marks open activities whose due date has passed as overdue.

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

/// Returns whether an open activity due at `due` is overdue at `now`; the epoch means "no date".
fn is_overdue(status: String, due, now: DateTime) -> Bool {
    if status != "open" || !(due is DateTime) {
        ret false;
    }
    ret due.as_unix_seconds() > 0 && due.is_before(now);
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

fn main() -> Int | Error {
    let now = DateTime::now();
    let models = {};
    let count = 0;
    for activity in exo::db::query(exo::SqlQuery::new().model("crm_activity"))? {
        let status = value_of(activity, models, "status")?.clone();
        if is_overdue(selected(status), value_of(activity, models, "due_date")?, now) {
            status.set_selected_single(exo::Ident::new("overdue"))?;
            let result = exo::update_record_value(activity.uuid, "status", status);
            if result is Error {
                ret result;
            }
            count = count + 1;
        }
    }
    log::info("crm_mark_overdue: marked", count, "activities as overdue");
    ret count;
}

test "only open activities with a past due date are overdue" {
    let now = DateTime::from_unix(1000000, 0, 0, None)?;
    let past = DateTime::from_unix(500000, 0, 0, None)?;
    let future = DateTime::from_unix(2000000, 0, 0, None)?;
    let none = DateTime::from_unix(0, 0, 0, None)?;
    assert(is_overdue("open", past, now));
    assert(!is_overdue("open", future, now));
    assert(!is_overdue("open", none, now));
    assert(!is_overdue("done", past, now));
    assert(!is_overdue("open", None, now));
}
