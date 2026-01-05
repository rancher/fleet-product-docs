#!/usr/bin/env bash
set -euo pipefail

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"   
FLEET_DIR="${REPO_ROOT}/../fleet"                
CONVERTER_DIR="${SCRIPT_DIR}/asciidoc-convertor" 
CONVERTER_SCRIPT="${CONVERTER_DIR}/convert.sh"

CRD_BIN="${SCRIPT_DIR}/crd-to-markdown"
BINARY_URL="https://github.com/clamoriniere/crd-to-markdown/releases/download/v0.0.3/crd-to-markdown_Linux_x86_64"
BINARY_CHECKSUM="2552e9bb3ee2c80e952961ae0de1a7d88aa1c2d859a3ba85e4b88cd6874ea13c"

# Where the script  writes temp files
TMP_ROOT="$(mktemp -d)"
MD_WORKDIR="${TMP_ROOT}/md"
ADOC_WORKDIR="${TMP_ROOT}/adoc"

# Antora target base inside this repo
VERSIONS_DIR="${REPO_ROOT}/versions" # e.g. versions/v0.13/... and versions/next/...
# Each version file path: versions/<version>/modules/en/pages/reference/ref-crds.adoc
PAGE_REL_PATH="modules/en/pages/reference/ref-crds.adoc"

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
cleanup() {
  rc=$?

  if [ -n "${CRD_BIN:-}" ] && [ -f "${CRD_BIN}" ]; then
    log "Removing temporary crd-to-markdown binary"
    rm -f "${CRD_BIN}" || true
  fi

  if [ -d "${TMP_ROOT:-}" ]; then
    rm -rf "${TMP_ROOT}" || true
  fi

  exit $rc
}

download_crd_bin() {
  if [ -x "${CRD_BIN}" ]; then
    log "Using existing ${CRD_BIN}"
    return 0
  fi
  log "Downloading crd-to-markdown to ${CRD_BIN}..."
  curl --fail -L -o "${CRD_BIN}" "${BINARY_URL}"
  echo "${BINARY_CHECKSUM}  ${CRD_BIN}" | sha256sum --check --status
  chmod +x "${CRD_BIN}"
}

# create a markdown file from available CRD Go files in the fleet checkout
create_markdown() {
  local out_md="$1"
  shift
  local -a files=("$@") # absolute paths
  if [ ${#files[@]} -eq 0 ]; then
    log "create_markdown: no input files"
    return 1
  fi
  # only include files that actually exist
  local crd_args=()
  for f in "${files[@]}"; do
    if [ -f "$f" ]; then
      crd_args+=( -f "$f" )
    fi
  done
  if [ ${#crd_args[@]} -eq 0 ]; then
    log "No CRD source files found for this fleet checkout. Skipping -> $out_md"
    return 2
  fi

  log "Running crd-to-markdown to produce $out_md"
  mkdir -p "$(dirname "$out_md")"
  # run the binary with names; preserves exit code using bash -c + pipefail
  bash -c "set -o pipefail; ${CRD_BIN} ${crd_args[*]} -n Bundle -n BundleDeployment -n GitRepo -n GitRepoRestriction -n BundleNamespaceMapping -n Content -n Cluster -n ClusterRegistration -n ClusterRegistrationToken -n ClusterGroup -n ImageScan 2>&1" \
    | sed -e 's/\[\]\[/\\[\\]\[/' \
          -e '1 s/### Custom Resources/# Custom Resources Spec/; t' -e '1,// s//# Custom Resources Spec/' \
          -e '1 s/### Sub Resources/# Sub Resources/; t' -e '1,// s//# Sub Resources/' \
          -e 's/(#custom-resources)/(#custom-resources-spec)/g' \
          -e 's/\\n/\
/g' \
    | tail -n +2 \
    > "$out_md"
  return 0
}


convert_with_local_converter() {
  if [ -x "$CONVERTER_SCRIPT" ]; then
    log "Running local asciidoc-convertor: ${CONVERTER_SCRIPT} ${MD_WORKDIR}"
    # Many convert.sh implementations expect the workspace root; adapt if yours differs.
    if bash "${CONVERTER_SCRIPT}" "${MD_WORKDIR}"; then
      log "Local converter succeeded"
      return 0
    else
      log "Local converter failed"
      return 1
    fi
  fi
  return 1
}

convert_with_pandoc() {
  if command -v pandoc >/dev/null 2>&1; then
    log "Converting markdown -> adoc using pandoc"
    mkdir -p "${ADOC_WORKDIR}"
    for md in "${MD_WORKDIR}"/*.md; do
      [ -f "$md" ] || continue
      out="${ADOC_WORKDIR}/$(basename "${md%.md}.adoc")"
      pandoc -f markdown -t asciidoc -o "$out" "$md"
    done
    return 0
  fi
  return 1
}

convert_with_sed() {
  log "Falling back to sed-based md->adoc (limited)"
  mkdir -p "${ADOC_WORKDIR}"
  for md in "${MD_WORKDIR}"/*.md; do
    [ -f "$md" ] || continue
    out="${ADOC_WORKDIR}/$(basename "${md%.md}.adoc")"
    sed -E -e 's/^### (.*)/== \1/' -e 's/^## (.*)/= \1/' -e 's/^\# (.*)/= \1/' -e 's/\[\]\[/\\[\\]\[/' "$md" > "$out"
  done
  return 0
}

write_adoc_with_header() {
  local src="$1"; local dest="$2"; local rev="$3"
  mkdir -p "$(dirname "$dest")"
  tmp="${dest}.tmp"
  printf "%s" "${ANTORA_HEADER_TEMPLATE//\{REVDATE\}/$rev}" > "${tmp}"
  cat "$src" >> "${tmp}"
  mv "${tmp}" "${dest}"
  log "Wrote $dest"
}

main() {
  log "Starting update-api.sh"
  # dynamic revdate in YYYY-MM-DD (UTC)
  REVDATE=$(date -u +%F)
  log "Revdate set to ${REVDATE}"

  # confirm expected locations
  if [ ! -d "${REPO_ROOT}" ]; then
    log "ERROR: repo root ${REPO_ROOT} not found. Run script from repo root."
    exit 1
  fi
  if [ ! -d "${VERSIONS_DIR}" ]; then
    log "ERROR: versions dir ${VERSIONS_DIR} not found under repo root."
    exit 1
  fi
  if [ ! -d "${FLEET_DIR}" ]; then
    log "ERROR: fleet repo not found at ${FLEET_DIR}. CI must checkout rancher/fleet into this path."
    exit 1
  fi

  download_crd_bin

  mkdir -p "${MD_WORKDIR}" "${ADOC_WORKDIR}"

  # Iterate versions/* and "next"
  for version_path in "${VERSIONS_DIR}"/*; do
    [ -d "$version_path" ] || continue
    version_base="$(basename "$version_path")"   # v0.13 or next
    # Normalize version string (for release branch naming)
    if [ "$version_base" = "next" ]; then
      fleet_branch="main"
      out_md="${MD_WORKDIR}/next-ref-crds.md"
      out_adoc="${ADOC_WORKDIR}/next-ref-crds.adoc"
    else
      # accept both v0.13 and version-0.13 if needed; user said versions are v0.9..v0.13
      # strip leading 'v' if present for branch naming
      stripped="${version_base#v}"
      fleet_branch="release/v${stripped}"
      out_md="${MD_WORKDIR}/${stripped}-ref-crds.md"
      out_adoc="${ADOC_WORKDIR}/${stripped}-ref-crds.adoc"
    fi

    log "Processing version ${version_base} -> fleet branch ${fleet_branch}"

    # checkout appropriate branch inside fleet repo so the CRDGo files match that release
    pushd "${FLEET_DIR}" >/dev/null
    if git show-ref --verify --quiet "refs/heads/${fleet_branch}"; then
      git checkout --force "${fleet_branch}"
    else
      # try to fetch remote branch if not present locally
      if git ls-remote --exit-code --heads origin "${fleet_branch}" >/dev/null 2>&1; then
        git fetch origin "${fleet_branch}:${fleet_branch}"
        git checkout --force "${fleet_branch}"
      else
        log "Fleet branch ${fleet_branch} not found; skipping ${version_base}"
        popd >/dev/null
        continue
      fi
    fi
    popd >/dev/null

    # Build list of absolute CRD file paths to pass to crd-to-markdown
    crd_paths=()
    for f in "${RELEVANT_CRD_FILES[@]}"; do
      abs="${FLEET_DIR}/${f}"
      crd_paths+=( "$abs" )
    done

    # create markdown file
    create_markdown "${out_md}" "${crd_paths[@]}"
    rc=$?
    if [ $rc -ne 0 ]; then
      if [ $rc -eq 2 ]; then
        log "No markdown generated for ${version_base}; skipping"
        continue
      else
        log "create_markdown failed for ${version_base} (exit $rc)"
        continue
      fi
    fi

    # Convert to adoc using converter/pandoc/sed
    # We place MDs in MD_WORKDIR and expect ADOCs in ADOC_WORKDIR
    rm -rf "${ADOC_WORKDIR:?}"/* || true
    if convert_with_local_converter; then
      :
    elif convert_with_pandoc; then
      :
    else
      convert_with_sed
    fi

    # locate the converted adoc file
    # prefer matching name: e.g. next-ref-crds.adoc or 0.13-ref-crds.adoc
    candidate="$(find "${ADOC_WORKDIR}" -maxdepth 1 -type f -name "*ref-crds*.adoc" -print -quit || true)"
    if [ -z "$candidate" ]; then
      log "No converted adoc found for ${version_base}; attempting pandoc per-file"
      if command -v pandoc >/dev/null 2>&1; then
        pandoc -f markdown -t asciidoc -o "${out_adoc}" "${out_md}"
        candidate="${out_adoc}"
      else
        log "No conversion available; skipping ${version_base}"
        continue
      fi
    fi

    # write final adoc into the versions/<version>/modules/en/pages/reference/ref-crds.adoc
    dest="${version_path}/${PAGE_REL_PATH}"
    write_adoc_with_header "$candidate" "$dest" "${REVDATE}"
  done

  log "All done; temporary dir ${TMP_ROOT} will be removed by trap"
}

main "$@"
  