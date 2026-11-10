//! Creates a contact for the active company and returns the new contact's UUID.

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

fn main(first_name: String, last_name: String, email: String) -> String | Error {
    first_name = first_name.trim();
    last_name = last_name.trim();
    email = email.trim();
    if first_name == "" || last_name == "" {
        ret Error("ValidationError", "First and last name are required", None);
    }
    if email != "" && !is_valid_email(email) {
        ret Error("ValidationError", f"Invalid e-mail address: {email}", { email: email });
    }

    let company = exo::get_record()?;
    let full_name = f"{first_name} {last_name}";
    let contact = exo::db::get_model("crm_contact")?.new_record()?;
    contact.set_value("name", exo::Language::new({ en: full_name, de: full_name }))?;
    contact.set_value("first_name", first_name)?;
    contact.set_value("last_name", last_name)?;
    contact.set_value("email", email)?;
    contact.set_value("company", exo::Reference::new(company.uuid))?;
    contact = exo::db::insert_record(contact)?;

    exo::rpc_env("crm_company_stats", company.uuid)?;
    let logged = exo::add_record_log_comment(company, f"Contact {full_name} created");
    if logged is Error {
        ret logged;
    }
    ret contact.uuid;
}

test "e-mail validation" {
    assert(is_valid_email("grace@example.com"));
    assert(!is_valid_email("grace"));
    assert(!is_valid_email("grace@example."));
}
