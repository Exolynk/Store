![Exolynk Logo](./assets/logo.svg)

# Store

The community addon store for Exolynk.

## Submit an addon

Use **Addons > Prepare addon** in Exolynk to select objects and download a
submission ZIP. Extract it into this repository, so its files are placed under
`addons/<ident>/`, and open a pull request. The ZIP contains `addon.json` and
reviewable `.exs`, `.rn`, or `.wasm` code files. Review them for credentials and
environment-specific references before publishing.

Each addon directory is self-contained. The Store only lists merged addons;
contributors do not need write access to this repository.
