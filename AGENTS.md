# Agent guidelines: Fleet and SUSE Rancher Prime Continuous Delivery documentation

This repository is the source of the Fleet (community) and SUSE Rancher Prime Continuous Delivery (product) documentation. [Antora](https://docs.antora.org/antora/latest/) builds it from [AsciiDoc](https://docs.asciidoctor.org/asciidoc/latest/) files.

Read [README.md](README.md) first. It is the authoritative source for prerequisites, builds, file layout, branching, backporting and troubleshooting. The files below add only agent-specific guidance and link back to the README instead of repeating it.

## Which file to read

| Task | Read |
|---|---|
| Set up the environment, build or preview the site | [repo-setup-and-build](.github/instructions/repo-setup-and-build.instructions.md) |
| Decide which branch or version to edit, backport, open a PR | [repo-structure-and-branching](.github/instructions/repo-structure-and-branching.instructions.md) |
| Create or edit an `.adoc` page | [asciidoc-conventions](.github/instructions/asciidoc-conventions.instructions.md) and [suse-style](.github/instructions/suse-style.instructions.md) |

Some tools load `*.instructions.md` files automatically for matching files. Others do not. If you edit `.adoc` files, open both AsciiDoc-related files above yourself.

## Rules that always apply

- Never hand-edit translated locales (any `modules/<LOCALE>/` other than `en` and `ROOT`). See [repo-structure-and-branching](.github/instructions/repo-structure-and-branching.instructions.md).
- Put an explicit anchor above every heading. See [asciidoc-conventions](.github/instructions/asciidoc-conventions.instructions.md).
- Update `nav.adoc` when you add, move, rename or remove a page.
- Do not commit, push or open a pull request unless the user asks.
- Build the affected site and check the log before you report docs work as done. See [repo-setup-and-build](.github/instructions/repo-setup-and-build.instructions.md).
