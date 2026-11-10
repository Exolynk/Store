//! Smoke test: returns a greeting and the number of CRM companies.

fn main(name: String) -> String | Error {
    let companies = 0;
    for _company in exo::db::query(exo::SqlQuery::new().model("crm_company"))? {
        companies = companies + 1;
    }
    ret f"pong {name}: {companies} companies";
}
