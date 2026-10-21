# Repository structure, branching and versions

The layout, branch model, backporting script, navigation and translation rules are in [README.md](../../README.md). See the sections "Edit the Documentation", "File Organization" (including "Backporting Changes", "Updating Navigation" and "Translations"). This file adds the decisions an agent must make before it edits anything.

## Which branch and directory to edit

| Change | Branch | Directory |
|---|---|---|
| Content for both sites (most changes) | `main` | `community-docs/<VERSION>/modules/ROOT/` |
| Text that applies to only one site | `main` | Same files, wrapped in `ifeval` on `{build-type}` |
| Product-only configuration such as `antora.yml` | `product-docs` | `versions/<VERSION>/` |

- Do not edit `versions/<VERSION>/modules/en/` for content that exists in `community-docs/`. The `sync-product-docs.yml` workflow overwrites it with the community version.
- Do not add product-only pages or images under `versions/<VERSION>/modules/en/`. The sync deletes files there that are missing from `community-docs/`. Use `ifeval` instead.
- The `sync-product-docs.yml` workflow mirrors `pages/`, `images/`, `assets/` and `nav.adoc`, but never `antora.yml` or translated modules.
- The sync pull request comes from the `sync/community-docs-update` branch. Do not edit it by hand.

## Which version to edit

- `next` is the unreleased version. Edit it for new features and general updates.
- If fixes and general updates apply to a released version, backport the changes to that version's directory, for example `community-docs/v0.16/`.

## Translations

Do not edit any locale other than `en` (on `product-docs`). Translations are imported in batches.

## Branches and pull requests

- Work in a branch on a fork. Do not push to `main` or `product-docs`.
- Open pull requests against `rancher/fleet-product-docs`.
- Do not commit, push or open a pull request unless the user asks.
