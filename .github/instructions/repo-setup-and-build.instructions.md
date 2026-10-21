# Setting up and building the documentation

The commands, prerequisites and playbook details are in [README.md](../../README.md). See the sections "Prerequisites", "Install Dependencies", "Build the Static Website Using the Local Documentation Content", "Using Make" and "Troubleshooting Common Issues". This file lists only what an agent should do differently.

## Before you build

- Initialize submodules with `git submodule update --init --recursive`, and use `npm ci`, not `npm install`.

## Build and verify

- Prefer `make local-community` or `make local-product`. They write a log to `tmp/local-<TYPE>-build.log`.
- Build only the site that matches your change:

  | Branch | Content | Build | Output |
  |---|---|---|---|
  | `main` | `community-docs/` | `make local-community` | `build/site-community/` |
  | `product-docs` | `versions/` | `make local-product` | `build/site-product/` |

- Read the log for `WARN` and `ERROR` lines, especially unresolved xrefs and missing anchors. Fix them before you report the work as done.
- There is no live reload. Rebuild after every edit.

## Previewing

- `make preview-community` (port 8080) and `make preview-product` (port 8081) run a server that never exits. Do not run them in the foreground. Run them in the background, or ask the user to run them.
- Report the output directory so the user can open `index.html` directly.
