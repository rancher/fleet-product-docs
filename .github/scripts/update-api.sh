#!/bin/bash
set -euo pipefail
if [ -n "${DEBUG:-}" ]; then set -x; fi

BINARY_URL="https://github.com/clamoriniere/crd-to-markdown/releases/download/v0.0.3/crd-to-markdown_Linux_x86_64"
BINARY_CHECKSUM="2552e9bb3ee2c80e952961ae0de1a7d88aa1c2d859a3ba85e4b88cd6874ea13c"
CRD_BIN="./crd-to-markdown"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONVERTER_DIR="${SCRIPT_DIR}/asciidoc-convertor"
CONVERTER_SCRIPT="${CONVERTER_DIR}/convert.sh"

# Temporary working dirs 
TMP_DIR="$(mktemp -d)"
MD_WORKDIR="${TMP_DIR}/md"
ADOC_WORKDIR="${TMP_DIR}/adoc"

# The location of ref-crds.adoc files in fleet-product-docs repo
FLEET_DOCS_VERSIONS_DIR="./fleet-product-docs/versions"

# CRD source files in fleet repository (keep in sync)
RELEVANT_CRD_FILES=(
  "pkg/apis/fleet.cattle.io/v1alpha1/bundle_types.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/bundledeployment_types.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/bundlenamespacemapping_types.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/cluster_types.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/clustergroup_types.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/clusterregistration_types.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/clusterregistrationtoken_types.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/content_types.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/gitrepo_types.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/gitreporestriction_types.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/imagescan_types.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/fleetyaml.go"
  # pre v0.9 api files
  "pkg/apis/fleet.cattle.io/v1alpha1/git.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/bundle.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/image.go"
  "pkg/apis/fleet.cattle.io/v1alpha1/target.go"
)

ANTORA_HEADER_TEMPLATE='= Custom Resources Spec
:revdate: {REVDATE}
:page-revdate: {REVDATE}

'

# Logging helper
log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }

# cleanup temp on exit
cleanup() {
  rc=$?
  if [ -d "$TMP_DIR" ]; then rm -rf "$TMP_DIR" || true; fi
  return $rc
}
trap cleanup EXIT

# crd binary download
download_crd_binary() {
  if [ -x "$CRD_BIN" ]; then
    log "Using existing $CRD_BIN"
    return 0
  fi
  log "Downloading crd-to-markdown..."
  curl --fail -L -o "$CRD_BIN" "$BINARY_URL"
  echo "$BINARY_CHECKSUM  $CRD_BIN" | sha256sum --check --status
  chmod +x "$CRD_BIN"
}

# create markdown from CRD source files
create_markdown() {
  local out_md="$1"
  local crd_args=()
  for f in "${RELEVANT_CRD_FILES[@]}"; do
    [ -f "$f" ] && crd_args+=( -f "$f" )
  done

  if [ ${#crd_args[@]} -eq 0 ]; then
    log "No CRD source files found; skipping $out_md"
    return 0
  fi

  log "Generating CRD markdown -> $out_md"
  mkdir -p "$(dirname "$out_md")"
  # run crd-to-markdown and apply minimal fixes
  bash -c "set -o pipefail; ${CRD_BIN} ${crd_args[*]} -n Bundle -n BundleDeployment -n GitRepo -n GitRepoRestriction -n BundleNamespaceMapping -n Content -n Cluster -n ClusterRegistration -n ClusterRegistrationToken -n ClusterGroup -n ImageScan 2>&1" \
    | sed -e 's/\[\]\[/\\[\\]\[/' \
          -e '1 s/### Custom Resources/# Custom Resources Spec/; t' -e '1,// s//# Custom Resources Spec/' \
          -e '1 s/### Sub Resources/# Sub Resources/; t' -e '1,// s//# Sub Resources/' \
          -e 's/(#custom-resources)/(#custom-resources-spec)/g' \
          -e 's/\\n/\
/g' \
    | tail -n +2 > "$out_md"
}

# Try local asciidoc-convertor (preferred)
convert_with_local_converter() {
  if [ -x "$CONVERTER_SCRIPT" ]; then
    log "Running local asciidoc-convertor at: $CONVERTER_SCRIPT"
    mkdir -p "$ADOC_WORKDIR"
    # The converter may expect a workspace; call it with input dir MD_WORKDIR
    if bash "$CONVERTER_SCRIPT" "$MD_WORKDIR"; then
      log "Local converter succeeded"
      return 0
    else
      log "Local converter failed"
      return 1
    fi
  fi
  return 1
}

# Try pandoc fallback (good conversion if available)
convert_with_pandoc() {
  if command -v pandoc >/dev/null 2>&1; then
    log "Converting md -> adoc with pandoc"
    mkdir -p "$ADOC_WORKDIR"
    for md in "$MD_WORKDIR"/*.md; do
      [ -f "$md" ] || continue
      out="$ADOC_WORKDIR/$(basename "${md%.md}.adoc")"
      pandoc -f markdown -t asciidoc -o "$out" "$md"
    done
    return 0
  fi
  return 1
}

# Conservative sed fallback (limited)
convert_with_sed_fallback() {
  log "Converting md -> adoc with conservative sed fallback"
  mkdir -p "$ADOC_WORKDIR"
  for md in "$MD_WORKDIR"/*.md; do
    [ -f "$md" ] || continue
    out="$ADOC_WORKDIR/$(basename "${md%.md}.adoc")"
    sed -E \
      -e 's/^### (.*)/== \1/' \
      -e 's/^## (.*)/= \1/' \
      -e 's/^\# (.*)/= \1/' \
      -e 's/\[\]\[/\\[\\]\[/' \
      -e 's/(#custom-resources)/(#custom-resources-spec)/g' \
      "$md" > "$out"
  done
}

# Prepend Antora header and write out atomically
write_adoc_with_header() {
  local src="$1"
  local dest="$2"
  local revdate="$3"
  mkdir -p "$(dirname "$dest")"
  header=$(printf "%s" "$ANTORA_HEADER_TEMPLATE" | sed "s/{REVDATE}/$revdate/g")
  tmp="${dest}.new"
  printf "%s\n" "$header" > "$tmp"
  cat "$src" >> "$tmp"
  mv "$tmp" "$dest"
  log "Wrote $dest"
}

# Helper: find candidate reference page dir for a versions/<name>
# returns first matching reference directory under the version dir, or empty
find_reference_dir_for_version() {
  local version_dir="$1"   # e.g. ./fleet-product-docs/versions/v0.13
  # common Antora module page locations; try to detect the correct one:
  # try modules/*/pages/*/reference
  local cand
  for cand in "$version_dir"/modules/*/pages/*/reference "$version_dir"/modules/*/pages/reference; do
    # expand glob - check if exists
    for d in $cand; do
      if [ -d "$d" ]; then
        echo "$d"
        return 0
      fi
    done
  done
  # fallback: try old structure: versions/<name>/reference or versions/<name>/modules/pages/reference
  if [ -d "$version_dir/reference" ]; then
    echo "$version_dir/reference"
    return 0
  fi
  return 1
}

main() {
  # dynamic revdate in YYYY-MM-DD (UTC)
  REVDATE=$(date -u +%F)
  log "Using revdate: $REVDATE"

  download_crd_binary

  mkdir -p "$MD_WORKDIR" "$ADOC_WORKDIR"

  # Generate top-level ref-crds (next)
  create_markdown "${MD_WORKDIR}/ref-crds.md"

  # Generate per-version markdown: iterate through existing version directories under fleet-product-docs/versions
  if [ -d "$FLEET_DOCS_VERSIONS_DIR" ]; then
    for version_dir in "${FLEET_DOCS_VERSIONS_DIR}"/*; do
      [ -d "$version_dir" ] || continue
      version_name="$(basename "$version_dir")"   # e.g. v0.13 or next
      # Skip older versions that shouldn't be generated if desired:
      if [[ "$version_name" =~ ^version-0\.[4-8]$ ]] ; then
        log "Skipping $version_name per configured rule"
        continue
      fi
      # make a dedicated md output dir
      mkdir -p "${MD_WORKDIR}/version-${version_name}"
      # Try to derive numeric version (strip non-digits)
      ver_num="$(echo "$version_name" | sed -E 's/[^0-9.]*([0-9.]+).*/\1/')"
      if [ -n "$ver_num" ]; then
        pushd fleet >/dev/null 2>&1 || true
        # prefer branch release/v<ver_num> if it exists
        if git show-ref --verify --quiet "refs/heads/release/v${ver_num}"; then
          git checkout "release/v${ver_num}" || true
        else
          if git ls-remote --exit-code --heads origin "release/v${ver_num}" >/dev/null 2>&1; then
            git fetch origin "release/v${ver_num}:release/v${ver_num}" || true
            git checkout "release/v${ver_num}" || true
          else
            log "No fleet branch for version ${version_name}; using current fleet branch"
          fi
        fi
        popd >/dev/null 2>&1 || true
      fi

      create_markdown "${MD_WORKDIR}/version-${version_name}/ref-crds.md"
    done
  else
    log "Warning: ${FLEET_DOCS_VERSIONS_DIR} does not exist - no version directories found"
  fi

  # Conversion strategy: try local converter -> pandoc -> sed fallback
  if convert_with_local_converter; then
    log "Converted Markdown -> AsciiDoc using local converter"
  elif convert_with_pandoc; then
    log "Converted Markdown -> AsciiDoc using pandoc"
  else
    convert_with_sed_fallback
    log "Converted Markdown -> AsciiDoc using sed fallback"
  fi

  # final: find generated adoc files and write them with header to target version dirs
  # Prefer output from converter (ADOC_WORKDIR); if none, try converting existing md files directly
  found_any=0
  mapfile -t generated_adocs < <(find "${ADOC_WORKDIR}" -type f -name "ref-crds*.adoc" 2>/dev/null || true)
  if [ ${#generated_adocs[@]} -eq 0 ]; then
    # maybe converter wrote adoc files next to md (rare) — check MD_WORKDIR for .adoc fallback
    mapfile -t generated_adocs < <(find "${MD_WORKDIR}" -type f -name "*.adoc" 2>/dev/null || true)
  fi

  # If still empty, try converting md files on-the-fly for target placement
  if [ ${#generated_adocs[@]} -eq 0 ]; then
    log "No adoc output found from converter; attempting to convert individual md files via pandoc/sed"
    for md in "${MD_WORKDIR}"/*.md "${MD_WORKDIR}"/version-*/*.md; do
      [ -f "$md" ] || continue
      dst_adoc="${ADOC_WORKDIR}/$(basename "${md%.md}.adoc")"
      if command -v pandoc >/dev/null 2>&1; then
        pandoc -f markdown -t asciidoc -o "$dst_adoc" "$md"
      else
        sed -e 's/^### /== /' -e 's/^## /= /' "$md" > "$dst_adoc"
      fi
      generated_adocs+=("$dst_adoc")
    done
  fi

  # Iterate through generated adoc files and map them to version destination dirs
  for adoc in "${generated_adocs[@]}"; do
    [ -f "$adoc" ] || continue
    base="$(basename "$adoc")"
    # determine source version: look for version-<name> in path or filename
    if [[ "$adoc" =~ version-([0-9A-Za-z_.-]+) ]]; then
      ver="${BASH_REMATCH[1]}"
    else
      # default to 'next'
      ver="next"
    fi

    # find the target reference directory for this version
    version_dir="${FLEET_DOCS_VERSIONS_DIR}/${ver}"
    if [ ! -d "$version_dir" ]; then
      # try without prefixing (maybe versions are 'v0.13' not 'version-v0.13')
      version_dir="$(find ${FLEET_DOCS_VERSIONS_DIR} -maxdepth 1 -type d -iname "*${ver}*" | head -n1 || true)"
      [ -z "$version_dir" ] && version_dir="${FLEET_DOCS_VERSIONS_DIR}/${ver}"
    fi

    ref_dir="$(find_reference_dir_for_version "$version_dir" || true)"
    if [ -z "$ref_dir" ]; then
      log "ERROR: could not find reference directory for version '$ver' (checked ${version_dir}); skipping $adoc"
      continue
    fi

    dest="${ref_dir}/ref-crds.adoc"
    write_adoc_with_header "$adoc" "$dest" "$REVDATE"
    found_any=1
  done

  if [ "$found_any" -eq 0 ]; then
    log "No ref-crds.adoc files written (nothing to do)."
  else
    log "Done: ref-crds.adoc files updated."
  fi
}

main "$@"
