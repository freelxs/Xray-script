#!/usr/bin/env bash
# Local address detection. No third-party lookup unless XRAY_SCRIPT_IP_LOOKUP=1.

ip_lookup_enabled() {
    case "${XRAY_SCRIPT_IP_LOOKUP:-0}" in
    1 | true | TRUE | yes | YES) return 0 ;;
    *) return 1 ;;
    esac
}

config_network_value() {
    local key="$1"
    local cfg value

    cfg="${XRAY_SCRIPT_CONFIG:-${HOME}/.xray-script/config.json}"
    [[ -f "${cfg}" ]] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    value="$(jq -r --arg key "${key}" '.network[$key] // empty' "${cfg}" 2>/dev/null || true)"
    [[ "${value}" == "null" ]] && value=""
    printf '%s' "${value}"
}

is_public_ipv4() {
    local ip="$1"
    local o1 o2 o3

    [[ "${ip}" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
    o1=$((10#${BASH_REMATCH[1]}))
    o2=$((10#${BASH_REMATCH[2]}))
    o3=$((10#${BASH_REMATCH[3]}))
    o4=$((10#${BASH_REMATCH[4]}))
    if ((o1 > 255 || o2 > 255 || o3 > 255 || o4 > 255)); then
        return 1
    fi
    # Unspecified, loopback, multicast, reserved, RFC1918, link-local, CGNAT, documentation.
    if ((o1 == 0 || o1 == 10 || o1 == 127 || o1 >= 224)); then
        return 1
    fi
    if ((o1 == 169 && o2 == 254)); then
        return 1
    fi
    if ((o1 == 172 && o2 >= 16 && o2 <= 31)); then
        return 1
    fi
    if ((o1 == 192 && o2 == 168)); then
        return 1
    fi
    if ((o1 == 100 && o2 >= 64 && o2 <= 127)); then
        return 1
    fi
    if ((o1 == 192 && o2 == 0 && o3 == 2)); then
        return 1
    fi
    if ((o1 == 198 && o2 == 51 && o3 == 100)); then
        return 1
    fi
    if ((o1 == 203 && o2 == 0 && o3 == 113)); then
        return 1
    fi
    if ((o1 == 198 && (o2 == 18 || o2 == 19))); then
        return 1
    fi
    return 0
}

is_public_ipv6() {
    local ip="${1,,}"

    [[ "${ip}" == *:* ]] || return 1
    [[ "${ip}" == "::" || "${ip}" == "::1" ]] && return 1
    [[ "${ip}" == fe80:* ]] && return 1
    [[ "${ip}" == fc* || "${ip}" == fd* ]] && return 1
    [[ "${ip}" == ff* ]] && return 1
    return 0
}

collect_local_addrs() {
    local family="$1"
    local addr

    if command -v ip >/dev/null 2>&1; then
        ip "-${family}" -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1
        return 0
    fi
    if [[ "${family}" == "4" ]] && command -v hostname >/dev/null 2>&1; then
        for addr in $(hostname -I 2>/dev/null || true); do
            [[ "${addr}" =~ ^[0-9.]+$ ]] && printf '%s\n' "${addr}"
        done
    fi
}

# Print one IPv4 address: explicit value, then a public local address, then
# an opt-in HTTPS lookup, then any remaining global address.
detect_ipv4() {
    local configured ip
    local public_ip=""
    local private_ip=""

    if [[ -n "${XRAY_SCRIPT_PUBLIC_IP:-}" ]]; then
        printf '%s\n' "${XRAY_SCRIPT_PUBLIC_IP}"
        return 0
    fi
    configured="$(config_network_value public_ip)"
    if [[ -n "${configured}" ]]; then
        printf '%s\n' "${configured}"
        return 0
    fi
    while read -r ip; do
        [[ -z "${ip}" ]] && continue
        if is_public_ipv4 "${ip}"; then
            public_ip="${ip}"
            break
        fi
        [[ -z "${private_ip}" ]] && private_ip="${ip}"
    done < <(collect_local_addrs 4)
    if [[ -n "${public_ip}" ]]; then
        printf '%s\n' "${public_ip}"
        return 0
    fi
    if ip_lookup_enabled; then
        secure_lookup_ip "https://ipv4.icanhazip.com" && return 0
    fi
    if [[ -n "${private_ip}" ]]; then
        printf '%s\n' "${private_ip}"
        return 0
    fi
    return 1
}

detect_ipv6() {
    local configured ip
    local public_ip=""

    if [[ -n "${XRAY_SCRIPT_PUBLIC_IPV6:-}" ]]; then
        printf '%s\n' "${XRAY_SCRIPT_PUBLIC_IPV6}"
        return 0
    fi
    configured="$(config_network_value public_ipv6)"
    if [[ -n "${configured}" ]]; then
        printf '%s\n' "${configured}"
        return 0
    fi
    while read -r ip; do
        [[ -z "${ip}" ]] && continue
        if is_public_ipv6 "${ip}"; then
            public_ip="${ip}"
            break
        fi
    done < <(collect_local_addrs 6)
    if [[ -n "${public_ip}" ]]; then
        printf '%s\n' "${public_ip}"
        return 0
    fi
    if ip_lookup_enabled; then
        secure_lookup_ip "https://ipv6.icanhazip.com" && return 0
    fi
    return 1
}

secure_lookup_ip() {
    local url="$1"
    local body
    local folded="${url,,}"

    case "${folded}" in
    *zxcvos*) return 1 ;;
    https://*) ;;
    *) return 1 ;;
    esac

    body="$(curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 --max-time 8 "${url}" | tr -d '[:space:]')"
    [[ -n "${body}" ]] || return 1
    printf '%s\n' "${body}"
}

# Every address DNS checks may treat as "this host", one per line.
address_candidates() {
    local configured ip

    [[ -n "${XRAY_SCRIPT_PUBLIC_IP:-}" ]] && printf '%s\n' "${XRAY_SCRIPT_PUBLIC_IP}"
    [[ -n "${XRAY_SCRIPT_PUBLIC_IPV6:-}" ]] && printf '%s\n' "${XRAY_SCRIPT_PUBLIC_IPV6}"
    configured="$(config_network_value public_ip)"
    [[ -n "${configured}" ]] && printf '%s\n' "${configured}"
    configured="$(config_network_value public_ipv6)"
    [[ -n "${configured}" ]] && printf '%s\n' "${configured}"
    collect_local_addrs 4 || true
    collect_local_addrs 6 || true
    if ip_lookup_enabled; then
        secure_lookup_ip "https://ipv4.icanhazip.com" || true
        secure_lookup_ip "https://ipv6.icanhazip.com" || true
    fi
}

# Address placed in client share links. IPv6 is bracketed.
resolve_share_address() {
    local ip

    if ip="$(detect_ipv4)"; then
        printf '%s\n' "${ip}"
        return 0
    fi
    if ip="$(detect_ipv6)"; then
        printf '[%s]\n' "${ip}"
        return 0
    fi
    return 1
}

share_address_is_public() {
    local host="${1}"

    host="${host#[}"
    host="${host%]}"
    if [[ "${host}" == *:* ]]; then
        is_public_ipv6 "${host}"
        return
    fi
    is_public_ipv4 "${host}"
}
