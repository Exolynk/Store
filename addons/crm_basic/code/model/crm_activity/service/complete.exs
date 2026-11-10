//! Completes the active activity and refreshes the key figures of its company.

fn main() -> String | Error {
    let record = exo::db::get_record(exo::get_record()?.uuid)?;
    let status = record.values.status;
    if !(status is exo::Selection) {
        // Records created through the API store no default values; use the model default.
        status = exo::db::get_model(record.model)?.get_variable("status")?.value;
    }
    status = status.clone();
    let current = status.get_selected_single();
    if current is exo::Ident && current.to_string() == "done" {
        ret "already done";
    }

    status.set_selected_single(exo::Ident::new("done"))?;
    let result = exo::update_record_value(record, "status", status);
    if result is Error {
        ret result;
    }
    result = exo::update_record_value(record, "completed_at", DateTime::now());
    if result is Error {
        ret result;
    }
    result = exo::add_record_log_comment(record, "Activity completed");
    if result is Error {
        ret result;
    }

    let company = record.values.company;
    if company is exo::Reference && !company.is_nil() {
        exo::rpc_env("crm_company_stats", company.to_string())?;
    }
    ret "done";
}
