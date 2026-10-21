# SUSE® Rancher Prime Continuous Delivery and Fleet Documentation

This is the source for the official SUSE Rancher Prime Continuous Delivery and Fleet documentation.

For inquiries about the Fleet software, please refer to the [Fleet GitHub repository](https://github.com/rancher/fleet/).

## Build the Documentation Site

This repository uses [Antora](https://docs.antora.org/antora/latest/) to build [AsciiDoc](https://docs.asciidoctor.org/asciidoc/latest/) content into a static website.

### Prerequisites

#### git

You need git to get the source code of this repository. Run the command below to check whether git is installed on your machine.

```bash
git --version
```

If you don't have git installed on your machine, it is recommended to install it through your operating system or distribution's package manager. Otherwise, you can download and install from the [git downloads](https://git-scm.com/downloads) page.

#### Node.js

Antora requires an active long term support (LTS) release of Node.js. Run the command below to check if you have Node.js installed, and which version. This command should return an [active Node.js LTS version number](https://nodejs.org/en/about/releases/).

```bash
node -v
```

The minimum supported version is declared in the `engines` field of `package.json` and enforced during `make environment` because `.npmrc` sets `engine-strict=true`. An older Node.js version fails the install instead of the build.

If you don't have Node.js installed on your machine, install it, preferably via [nvm](https://github.com/nvm-sh/nvm)

### Install Dependencies

#### Git Submodules

This repository uses [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) to manage some of its dependencies, including the Antora files that provide the custom GUI for the documentation website. Run the command below to initialize the submodules recursively (including any nested submodules).

```bash
git submodule update --init --recursive
```

After initializing, and whenever the referenced commits for the submodules are updated in the repository (such as after a `git pull`), you need to use the `update` command to fetch the latest data for the submodules:

```bash
git submodule update --recursive
```

#### Node Modules

Open a terminal at the root of the git repository. Run the command below.

```bash
npm ci
```

### Build the Static Website Using the Local Documentation Content

There are several playbook files available to build different variants of the documentation site, such as the community (Fleet) or product (SUSE Rancher Prime Continuous Delivery) site, using either local or remote content.

If you want to build and view the documentation content from your local machine, you can use one of the local playbooks:

- `fleet-community-local-playbook.yml`
- `fleet-product-local-playbook.yml`

Run the command below to build the site using your chosen playbook file, replacing `<PLAYBOOK_FILE>` with the respective playbook:

```bash
npx antora <PLAYBOOK_FILE>
```

To preview the built documentation using a local HTTP server, run the command below, replacing `<SITE_DIRECTORY>` with the corresponding build output directory (for example, `build/site-product` or `build/site-community`):

```bash
npx http-server <SITE_DIRECTORY> -c-1
```

Alternatively, you can preview the documentation by accessing the HTML files directly. To do so, open the `<SITE_DIRECTORY>/index.html` file.

Subsequent updates require rebuilding (that is running `npx antora <PLAYBOOK_FILE>` again) as there is no live reloading.

### Using Make

Alternatively, you can use `make` to build and preview the documentation. Note that you must have the `make` package installed on your system to use this method.

The following targets are available in the `Makefile` for building the documentation locally:

- `make local-community`
- `make local-product`

To preview the built documentation using a local HTTP server, you can use the following targets:

- `make preview-community`
- `make preview-product`

Other utility targets include `make environment` to install the `npm` dependencies, and `make clean` to remove the `build` directory.

## Contributing to the Documentation

You can contribute to the documentation by raising awareness about inaccuracies or suggesting changes directly. This can be done in two ways:

1. [Open an issue](https://github.com/rancher/fleet-product-docs/issues/new/choose).
1. Edit the documentation in the way you see fit and submitting a [pull request](https://github.com/rancher/fleet-product-docs/compare).

### Edit the Documentation

To get started, [fork](https://github.com/rancher/fleet-product-docs/fork) and clone the `fleet-product-docs` repository.

Our repository does not allow you to make changes directly to the `main` or `product-docs` branches. Create a working branch and make pull requests from your fork to [rancher/fleet-product-docs](https://github.com/rancher/fleet-product-docs).

### File Organization

#### Content and Asset Files

This repository contains both community and product documentation across two separate branches and directory trees:

- `main` branch: Contains community documentation in `community-docs/<VERSION>/`, published at [fleet.rancher.io](https://fleet.rancher.io/) (generated locally at `build/site-community/`).
- `product-docs` branch: Contains product documentation in `versions/<VERSION>/`, published at [documentation.suse.com/cloudnative/continuous-delivery/](https://documentation.suse.com/cloudnative/continuous-delivery/) (generated locally at `build/site-product/`).

To support single-sourcing, changes pushed to `community-docs/` on the `main` branch are automatically synced to `versions/` on the `product-docs` branch (via a pull request) by the [`.github/workflows/sync-product-docs.yml`](.github/workflows/sync-product-docs.yml) GitHub Actions workflow.

For community docs on the `main` branch, AsciiDoc files are organized under the following directory structure:

- `community-docs/<VERSION>/modules/ROOT/pages/`

For product docs on the `product-docs` branch, the directory structure is as follows:

- `versions/<VERSION>/modules/<LOCALE>/pages/`

Other asset files (for example, images) have their own subdirectories, such as `community-docs/<VERSION>/modules/ROOT/images` on `main` or `versions/<VERSION>/modules/en/images` on `product-docs`.

#### Backporting Changes

When you need to backport changes between different versions, you can try running the `./product-docs-common/scripts/recurring/backport_modules.sh` script. This script helps contributors with porting changes as found in Git-modified files or in a specific commit.

For example, to port changes to versions `v0.15` and `v0.16`, run:

```bash
./product-docs-common/scripts/recurring/backport_modules.sh v0.15 v0.16
```

For more information and a complete list of options, refer to the script's help menu by running:

```bash
./product-docs-common/scripts/recurring/backport_modules.sh --help
```

#### Single-Sourcing with Conditionals

Because most documentation content is single-sourced and shared across the community (Fleet) and product (SUSE Rancher Prime Continuous Delivery) sites, you might encounter situations where certain text, links, or instructions apply to only one specific build type.

To handle these differences, use AsciiDoc `ifeval::[]` conditionals based on the `{build-type}` attribute. This ensures the appropriate content is selectively rendered for the respective target site.

Here are some practical examples of how to use these conditionals in the `.adoc` files:

```asciidoc
// Content specifically for the community site
ifeval::["{build-type}" == "community"]
This content only appears in the Fleet community documentation.
endif::[]

// Content specifically for the Prime site
ifeval::["{build-type}" == "product"]
This content only appears in the SUSE Rancher Prime Continuous Delivery documentation.
endif::[]
```

For more information on the directive syntax, refer to the [AsciiDoc Conditionals documentation](https://docs.asciidoctor.org/asciidoc/latest/directives/conditionals/).

#### Required Anchor IDs for Headings

To support content translations, you must use explicit anchors for cross-references. Auto-generated anchors do not survive the translation process, which causes links to break.

When creating a heading, always define an explicit anchor directly above it. Use the following anchor format:

```asciidoc
[#_my_anchor]
== My Anchor

My paragraph.
```

You can then safely refer to this heading using the explicit anchor:

```asciidoc
xref:#_my_anchor[My Anchor]
```

> [!NOTE]
> If you want to link from one documentation page to another, do not use absolute URLs. Antora uses a special xref: syntax to cross-reference pages. For example:
>
> ```asciidoc
> xref:explanations/concepts.adoc[Concepts]
> ```
>
> For more information, refer to the [Antora Xref documentation](https://docs.antora.org/antora/latest/page/xref/).

#### Updating Navigation

When adding a new documentation page, or renaming or removing an existing one, you must update the navigation file (`nav.adoc`) for the respective version (and locale). This ensures that the site's sidebar menu accurately reflects the available content:

- `community-docs/<VERSION>/modules/ROOT/nav.adoc` (on the `main` branch)
- `versions/<VERSION>/modules/en/nav.adoc` (on the `product-docs` branch)

For more information on how to structure the navigation lists, refer to the [Antora Navigation Files and Lists documentation](https://docs.antora.org/antora/latest/navigation/files-and-lists/).

#### Configuration Files

- Site-level configuration is done through a playbook file. For example, `fleet-community-local-playbook.yml`. Refer to the [Antora playbook documentation](https://docs.antora.org/antora/latest/playbook/) for more information.
- Component-level configuration is done through a file called `antora.yml`. For example, `community-docs/<VERSION>/antora.yml` (on `main`) or `versions/<VERSION>/antora.yml` (on `product-docs`). Refer to the [Antora antora.yml documentation](https://docs.antora.org/antora/latest/component-version-descriptor/) for more information.

#### Translations

Translations are only published for the Prime site and are available on the `product-docs` branch under the `versions/<VERSION>/modules/` directory. Translations are imported in batches, so contributors should not update individual translations manually.

The list of available locales for each page is defined by the `:page-languages:` attribute at the beginning of each page. This attribute is used for the language switcher on the Prime site.

#### Troubleshooting Common Issues

**Error:** `Antora documentation component not found` or CSS formatting looks completely broken.
**Fix:** You likely forgot to initialize the submodules. Run `git submodule update --init --recursive` and rebuild.

**Error:**  `npm ERR! code EBADENGINE` or dependency conflicts.
**Fix:** Ensure you are using a modern Node.js LTS version (e.g., Node 18 or Node 20). If you used `npm install`, delete your `node_modules` directory and run `npm ci` instead.

**Issue:** Changes aren't updating in the browser.
**Fix:** Antora does not feature "live-reload". Every time you make a change to a file, you must stop your terminal process, rerun `npx antora <PLAYBOOK_FILE>`, and refresh your browser.

## License

Copyright (c) 2014-2026 [SUSE, LLC.](https://www.suse.com/)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
