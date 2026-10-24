#!/usr/bin/env bash
# HTTPS downloads with certificate verification and SHA-256 checks.
# Source this file; it does not execute anything on its own.

# Download url to dest. TLS is required; redirects may only stay on HTTPS.
secure_curl() {
    local dest="$1"
    local url="$2"
    local folded="${url,,}"

    # 折叠大小写，拒绝任何拼写的 zxcvos 下载地址（含 tarball/zipball/API）。
    case "${folded}" in
    *zxcvos*)
        printf 'refusing upstream URL: %s\n' "${url}" >&2
        return 1
        ;;
    esac

    case "${url}" in
    https://*) ;;
    *)
        printf 'refusing non-HTTPS URL: %s\n' "${url}" >&2
        return 1
        ;;
    esac

    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --proto '=https' \
        --tlsv1.2 \
        --retry 3 \
        --retry-delay 2 \
        --output "${dest}" \
        "${url}"
}

# Return 0 when file matches the expected lowercase or uppercase SHA-256 hex digest.
verify_sha256_file() {
    local file="$1"
    local expected="$2"
    local actual

    [[ "${expected}" =~ ^[0-9a-fA-F]{64}$ ]] || return 1
    actual="$(sha256sum "${file}" | awk '{print $1}')"
    [[ "${actual,,}" == "${expected,,}" ]]
}

# Download url to dest and require expected_sha256.
fetch_verified() {
    local url="$1"
    local dest="$2"
    local expected_sha256="$3"

    secure_curl "${dest}" "${url}" || return 1
    if ! verify_sha256_file "${dest}" "${expected_sha256}"; then
        printf 'SHA-256 mismatch for %s\n' "${url}" >&2
        rm -f "${dest}"
        return 1
    fi
}
