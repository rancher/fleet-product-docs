#!/bin/bash
set -euxo pipefail

BINARY_URL="https://github.com/clamoriniere/crd-to-markdown/releases/download/v0.0.3/crd-to-markdown_Linux_x86_64"
BINARY_CHECKSUM="2552e9bb3ee2c80e952961ae0de1a7d88aa1c2d859a3ba85e4b88cd6874ea13c"

ASCIIDOC_CONVERTOR="../asciidoc-convertor/convert.py"

REVDATE=$(date +"%Y-%m-%d")

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

download_binary() {
    curl --fail -L -o crd-to-markdown "$BINARY_URL"
    echo "$BINARY_CHECKSUM crd-to-markdown" | sha256sum --check --status
    chmod +x crd-to-markdown
}

create_markdown() {
    local output_md="$1"
    local crd_files=""

    for file_path in "${RELEVANT_CRD_FILES[@]}"; do
        [[ -f "$file_path" ]] && crd_files="$crd_files -f $file_path"
    done

    # shellcheck disable=SC2086
    ../crd-to-markdown $crd_files \
        -n Bundle -n BundleDeployment -n GitRepo -n GitRepoRestriction -n BundleNamespaceMapping -n Content \
        -n Cluster -n ClusterRegistration -n ClusterRegistrationToken -n ClusterGroup -n ImageScan \
        | sed -e 's/\[\]\[/\\[\\]\[/' \
        | sed -e '1 s/### Custom Resources/# Custom Resources Spec/; t' -e '1,// s//# Custom Resources Spec/' \
        | sed -e '1 s/### Sub Resources/# Sub Resources/; t' -e '1,// s//# Sub Resources/' \
        | sed -e 's/(#custom-resources)/(#custom-resources-spec)/g' \
        | sed 's/\\n/\n/g' \
        | tail -n +2 \
        > "$output_md"
}

convert_md_to_adoc() {
    local md_file="$1"
    local adoc_file="$2"

    python3 "$ASCIIDOC_CONVERTOR" "$md_file" "$adoc_file"

    sed -i "1i :revdate: ${REVDATE}\n:page-revdate: {revdate}\n" "$adoc_file"
}

generate_all() {
    pushd fleet || exit
    git checkout main
    # ---------- versioned docs ----------
    for directory in ./fleet-product-docs/versions/*; do
        [[ "$directory" =~ version-0\.[4-8] ]] && continue

        pushd fleet || exit
        version="${directory##*/}"
        version="${version#version-}"

        git checkout "release/v${version}"

        local tmp_md="../fleet-product-docs/versions/version-$version/ref-crds.md"
        local out_adoc="../fleet-product-docs/versions/version-$version/ref-crds.adoc"

        create_markdown "$tmp_md"
        convert_md_to_adoc "$tmp_md" "$out_adoc"
        rm -f "$tmp_md"

        popd || exit
    done
}

# ---------- Run ----------
download_binary
generate_all
