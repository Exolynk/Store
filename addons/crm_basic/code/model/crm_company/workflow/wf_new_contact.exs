//! Action "New contact" in the record action bar: asks for the contact's data and opens
//! the created contact.

/// Returns an empty String input for the popup.
fn input(ident: String, en: String, de: String) -> exo::Variable {
    let variable = exo::Variable::new(ident, "");
    variable.name = exo::Language::new({ en: en, de: de });
    ret variable;
}

/// Offers the workflow in the record action bar.
fn show() -> Bool {
    ret true;
}

fn main() {
    let result = exo::ui::popup(
        "New contact",
        "Create a contact for this company",
        input("first_name", "First name", "Vorname"),
        input("last_name", "Last name", "Nachname"),
        input("email", "E-Mail", "E-Mail"),
    )?;
    if !result.submitted {
        ret;
    }

    let values = {};
    for variable in result.variables {
        values[variable.ident] = variable.value;
    }
    let created = exo::rpc_model("create_contact", values.first_name, values.last_name, values.email);
    if created is Error {
        ret exo::ui::notification("error", created.message(), 5000);
    }
    ret exo::ui::open_record(created[0]);
}
