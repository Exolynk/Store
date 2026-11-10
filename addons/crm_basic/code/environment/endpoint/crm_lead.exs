// ! Web-to-lead endpoint (POST): creates a company, its contact and a follow-up call.
// !
// ! Body: { "company": "...", "first_name": "...", "last_name": "...", "email": "...",
// !         "phone": "...", "message": "..." }

use exo::net::{Method, Request, Response};

/// Returns whether `text` looks like an e-mail address: one `@`, a local part and a dotted domain.
fn is_valid_email(text: String) -> Bool {
    let parts = text.split("@");
    if parts is Error || parts.length() != 2 || parts[0] == "" {
        ret false;
    }
    let labels = parts[1].split(".");
    if labels is Error || labels.length() < 2 {
        ret false;
    }
    ret labels[0] != "" && labels[labels.length() - 1] != "";
}

/// Returns the trimmed String field `key` of `body`, or "".
fn field(body: Object, key: String) -> String {
    let value = body.get(key);
    if value is String {
        ret value.trim();
    }
    ret "";
}

/// Returns localized text with the same content in English and German.
fn text(value: String) -> exo::Language {
    ret exo::Language::new({en: value, de: value});
}

/// Selects the option `option` of the Selection `ident` of the stored record `uuid`.
fn select(uuid: String, ident: String, option: String) -> Unit | Error {
    let selection = exo::db::get_record(uuid)?.values.get(ident)?;
    if !(selection is exo::Selection) {
        ret Error("TypeError", f"{ident} is no selection", {value: selection});
    }
    selection.set_selected_single(exo::Ident::new(option))?;
    let stored = exo::update_record_value(uuid, ident, selection);
    if stored is Error {
        ret stored;
    }
}

/// Returns a 400 response with a JSON error message.
fn bad_request(message: String) -> Response | Error {
    let response = Response::json({error: message})?;
    response.status = 400;
    ret response;
}

fn main(request: Request) -> Response | Error {
    if request.method != Method::Post {
        ret Response::new(405);
    }
    let body = request.json();
    if !(body is Object) {
        ret bad_request("The body must be a JSON object");
    }

    let company_name = field(body, "company");
    let first_name = field(body, "first_name");
    let last_name = field(body, "last_name");
    let email = field(body, "email");
    if company_name == "" || last_name == "" {
        ret bad_request("company and last_name are required");
    }
    if email != "" && !is_valid_email(email) {
        ret bad_request(f"Invalid e-mail address: {email}");
    }

    let company = exo::db::get_model("crm_company")?.new_record()?;
    company.set_value("name", text(company_name))?;
    company.set_value("email", email)?;
    company.set_value("phone", field(body, "phone"))?;
    company = exo::db::insert_record(company)?;

    let full_name = f"{first_name} {last_name}".trim();
    let contact = exo::db::get_model("crm_contact")?.new_record()?;
    contact.set_value("name", text(full_name))?;
    contact.set_value("first_name", first_name)?;
    contact.set_value("last_name", last_name)?;
    contact.set_value("email", email)?;
    contact.set_value("phone", field(body, "phone"))?;
    contact.set_value("company", exo::Reference::new(company.uuid))?;
    contact = exo::db::insert_record(contact)?;

    let activity = exo::db::get_model("crm_activity")?.new_record()?;
    activity.set_value("name", text(f"Follow up web lead: {company_name}"))?;
    activity.set_value("description", text(field(body, "message")))?;
    activity.set_value("due_date", DateTime::now().add_duration(Duration::days(2)?)?)?;
    activity.set_value("company", exo::Reference::new(company.uuid))?;
    activity.set_value("contact", exo::Reference::new(contact.uuid))?;
    activity = exo::db::insert_record(activity)?;
    // A Selection changed on a new or just inserted Record is not stored, so the type is set
    // on the freshly loaded record.
    select(activity.uuid, "kind", "call")?;

    exo::rpc_env("crm_company_stats", company.uuid)?;
    log::info("crm_lead: created lead", company_name);

    let response = Response::json({company: company.uuid, contact: contact.uuid, activity: activity.uuid})?;
    response.status = 201;
    ret response;
}

test "e-mail validation" {
    assert(is_valid_email("ada@example.ch"));
    assert(!is_valid_email("ada.example.ch"));
    assert(!is_valid_email("@example.ch"));
    assert(!is_valid_email("ada@example"));
    assert(!is_valid_email("ada@@example.ch"));
}
