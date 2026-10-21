---
applyTo: "community-docs/**/*.adoc,versions/**/*.adoc"
---
# AsciiDoc conventions for this repository

Apply this checklist when you create or edit a page. Follow [suse-style.instructions.md](suse-style.instructions.md) for the prose. [README.md](../../README.md) has the full explanations and code examples: "Single-Sourcing with Conditionals", "Required Anchor IDs for Headings" and "Updating Navigation".

- **Header**: keep `:description:`, `:revdate:` and `:page-revdate: {revdate}` under the title. Set `:description:` to one sentence that summarizes the page. Update `:revdate:` (format `YYYY-MM-DD`) when you change content.
- **Anchors**: put an explicit anchor on the line directly above every heading, in the form `[#_lowercase_words_joined_by_underscores]`. Leave the anchor of an existing heading unchanged, because translations and links depend on it. Some headings use `[discrete]`. Keep the anchor next to the heading.
- **Cross-references**: link to other pages with `xref:path/to/page.adoc[Link text]` and never with an absolute URL. Link to a heading with `xref:#_anchor[Link text]`.
- **Single-sourcing**: wrap text for one site in `ifeval::["{build-type}" == "community"]` or `ifeval::["{build-type}" == "product"]`, and close it with `endif::[]`.
- **Product names**: use `{product_name}`, not a hard-coded name. `antora.yml` sets it per version and build type.
- **Navigation**: when you add, move, rename or remove a page, update `nav.adoc` in the same version. On `main` that is `community-docs/<VERSION>/modules/ROOT/nav.adoc`.
- **Images**: store them in the `images/` directory of the same module and reference them by file name.
