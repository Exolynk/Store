//! After a contact value changed: reverts invalid e-mail addresses, keeps the full name in
//! sync with first and last name and refreshes the key figures of the old and new company.

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

/// Stores one value and passes a failure on.
fn put(record, ident: String, value) {
    let result = exo::update_record_value(record, ident, value);
    if result is Error {
        ret result;
    }
}

/// Recalculates the key figures of the company a reference points to.
fn refresh_company(value) {
    if value is exo::Reference && !value.is_nil() {
        exo::rpc_env("crm_company_stats", value.to_string())?;
    }
}

fn main(old: exo::Variable, new: exo::Variable) {
    let ident = new.ident;
    let value = new.value;
    let record = exo::db::get_record(exo::get_record()?.uuid)?;

    if ident == "email" && value is String && value.trim() != "" && !is_valid_email(value.trim()) {
        put(record.uuid, "email", old.value)?;
        let logged = exo::add_record_log_comment(record.uuid, f"Invalid e-mail address reverted: {value}");
        if logged is Error {
            ret logged;
        }
        ret Error("ValidationError", f"Invalid e-mail address: {value}", { email: value });
    }

    if ident == "first_name" || ident == "last_name" {
        let name = full_name(record.values.first_name, record.values.last_name)?;
        put(record.uuid, "name", exo::Language::new({ en: name, de: name }))?;
    }

    if ident == "company" {
        refresh_company(old.value)?;
        refresh_company(value)?;
    }
}

test "full name joins the given parts" {
    assert_eq(full_name("Ada", "Lovelace"), "Ada Lovelace");
    assert_eq(full_name(" Ada ", ""), "Ada");
    assert_eq(full_name(None, "Lovelace"), "Lovelace");
}

test "e-mail validation" {
    assert(is_valid_email("ada@example.ch"));
    assert(!is_valid_email("ada"));
}
