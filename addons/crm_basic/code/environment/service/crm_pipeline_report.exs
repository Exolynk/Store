//! Summarizes all deals per pipeline stage in CHF, with forecast and win rate.

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

/// Returns the pipeline stages in their order.
fn stages() -> List {
    ret ["lead", "qualified", "proposal", "negotiation", "won", "lost"];
}

/// Returns the share of won deals among the closed ones in percent, or None without any.
fn win_rate(won: Int, lost: Int) -> Float | None {
    if won + lost == 0 {
        ret None;
    }
    ret won * 100.0 / (won + lost);
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
    let rows = {};
    for stage in stages() {
        rows[stage] = { count: 0, total: exo::Currency::new(0, CURRENCY), weighted: exo::Currency::new(0, CURRENCY) };
    }

    let models = {};
    for deal in exo::db::query(exo::SqlQuery::new().model("crm_deal"))? {
        let row = rows[selected(value_of(deal, models, "stage")?)];
        if row == None {
            continue;
        }
        row.count = row.count + 1;
        row.total = (row.total + in_chf(value_of(deal, models, "amount")?)?)?;
        row.weighted = (row.weighted + in_chf(value_of(deal, models, "weighted_amount")?)?)?;
    }

    let open_total = exo::Currency::new(0, CURRENCY);
    let forecast = exo::Currency::new(0, CURRENCY);
    let open_count = 0;
    let result = [];
    for stage in stages() {
        let row = rows[stage];
        if stage != "won" && stage != "lost" {
            open_count = open_count + row.count;
            open_total = (open_total + row.total)?;
            forecast = (forecast + row.weighted)?;
        }
        result.push({ stage: stage, count: row.count, total: row.total.to_string() });
    }

    ret {
        stages: result,
        open_deals: open_count,
        open_pipeline: open_total.to_string(),
        weighted_forecast: forecast.to_string(),
        won_revenue: rows.won.total.to_string(),
        win_rate_percent: win_rate(rows.won.count, rows.lost.count),
    };
}

test "win rate is based on closed deals only" {
    assert_eq(win_rate(0, 0), None);
    assert_eq(win_rate(1, 1), 50.0);
    assert_eq(win_rate(3, 1), 75.0);
}
