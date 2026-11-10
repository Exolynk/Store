//! Recalculates the key figures of the active company.

fn main() -> Object | Error {
    let company = exo::get_record()?;
    ret exo::rpc_env("crm_company_stats", company.uuid)?.first()?;
}
