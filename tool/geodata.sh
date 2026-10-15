#!/usr/bin/env bash
# Refresh Loyalsoldier geoip/geosite and check the publisher's SHA-256 sums.
# The checksum file is published next to the data file, so this detects
# corruption and incomplete downloads. It does not pin a specific release
# unless GEODATA_TAG is set. Set GEODATA_TAG=YYYYMMDDHHMM to freeze a release.

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck source=../core/secure_fetch.sh
source "${SCRIPT_DIR}/../core/secure_fetch.sh"

XRAY_DIR="/usr/local/share/xray"
GEODATA_TAG="${GEODATA_TAG:-latest}"
if [[ ! "${GEODATA_TAG}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf 'invalid GEODATA_TAG\n' >&2
    exit 1
fi

if [[ "${GEODATA_TAG}" == "latest" ]]; then
    BASE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download"
else
    BASE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${GEODATA_TAG}"
fi

download_checked() {
    local name="$1"
    local expected listed

    secure_curl "${tmp}/${name}" "${BASE_URL}/${name}"
    secure_curl "${tmp}/${name}.sha256sum" "${BASE_URL}/${name}.sha256sum"
    expected="$(awk 'NF {print $1; exit}' "${tmp}/${name}.sha256sum")"
    listed="$(awk 'NF {print $2; exit}' "${tmp}/${name}.sha256sum")"
    listed="${listed#\*}"
    if [[ -n "${listed}" && "${listed}" != "${name}" ]]; then
        printf 'checksum filename mismatch for %s\n' "${name}" >&2
        exit 1
    fi
    if ! verify_sha256_file "${tmp}/${name}" "${expected}"; then
        printf 'SHA-256 mismatch for %s\n' "${name}" >&2
        exit 1
    fi
}

mkdir -p "${XRAY_DIR}"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

download_checked geoip.dat
download_checked geosite.dat

install -m 0644 "${tmp}/geoip.dat" "${XRAY_DIR}/geoip.dat"
install -m 0644 "${tmp}/geosite.dat" "${XRAY_DIR}/geosite.dat"

if systemctl -q is-active xray; then
    systemctl restart xray
fi
