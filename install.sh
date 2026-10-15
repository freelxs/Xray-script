#!/usr/bin/env bash
# =============================================================================
# 注释: 通过 Qwen3-Coder 生成。
# 脚本名称: install.sh
# 脚本仓库: https://github.com/freelxs/Xray-script
# 功能描述: Xray-script 项目的安装引导脚本。
#           负责检查和安装系统依赖、下载项目文件、处理命令行参数、
#           初始化配置、设置语言以及启动主菜单。
# 作者: zxcvos
# 时间: 2025-07-25
# 版本: 1.0.0
# 依赖: bash, curl, wget, git, jq, sed, awk, grep
# 配置:
#   - 从 GitHub 下载项目文件到指定目录
#   - ${SCRIPT_CONFIG_DIR}/config.json: 用于读取/设置语言和版本信息
# Xray 官方链接:
#   - Xray-core: https://github.com/XTLS/Xray-core
#   - REALITY: https://github.com/XTLS/REALITY
#   - XHTTP: https://github.com/XTLS/Xray-core/discussions/4113
# Xray 配置模板:
#   - Xray 配置示例: https://github.com/chika0801/Xray-examples
#   - 最优组合示例: https://github.com/lxhao61/integrated-examples
#   - xhttp 五合一配置: https://github.com/XTLS/Xray-core/discussions/4118
#
# Copyright (C) 2025 zxcvos
# =============================================================================

# set -Eeuxo pipefail

# --- 环境与常量设置 ---
# 将常用路径添加到 PATH 环境变量，确保脚本能在不同环境中找到所需命令
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/snap/bin
export PATH

# 定义颜色代码，用于在终端输出带颜色的信息
readonly GREEN='\033[32m'  # 绿色
readonly YELLOW='\033[33m' # 黄色
readonly RED='\033[31m'    # 红色
readonly NC='\033[0m'      # 无颜色（重置）

# 获取当前脚本的目录绝对路径和文件名
readonly CUR_DIR="$(cd -P -- "$(dirname -- "$0")" && pwd -P)" # 当前脚本所在目录
readonly CUR_FILE="$(basename "$0")"                          # 当前脚本文件名

# 定义配置文件和相关目录的路径
readonly SCRIPT_CONFIG_DIR="${HOME}/.xray-script"              # 主配置文件目录
readonly SCRIPT_CONFIG_PATH="${SCRIPT_CONFIG_DIR}/config.json" # 脚本主配置文件路径

# --- 全局变量声明 ---
# 声明用于存储国际化数据、项目根目录和快速安装选项的全局变量
declare -A I18N_DATA=(
    ['error']='错误'
    ['root']='请使用 root 权限运行该脚本'
    ['supported']='不支持当前系统，请切换到 Ubuntu 16+、Debian 9+、CentOS 7+'
    ['ubuntu']='不支持当前版本，请切换到 Ubuntu 16+ 重试'
    ['debian']='不支持当前版本，请切换到 Debian 9+ 重试'
    ['centos']='不支持当前版本，请切换到 CentOS 7+ 重试'
    ['tip']='更新提示'
    ['new']='发现有新脚本, 是否更新'
    ['now']='是否更新 [Y/n] '
    ['promptly']='请及时更新脚本'
    ['completed']='更新完成'
    ['download']='正在下载'
    ['failed']='下载失败'
    ['downloaded']='文件已下载到'
    ['local']='使用本地仓库文件，不从网络下载'
    ['same']='已是本 fork 的当前版本'
    ['bad_checksum']='文件校验失败'
    ['refused']='拒绝访问 zxcvos/Xray-script，或脚本引用无效'
    ['bad_path']='安装路径无效'
)                        # 默认的国际化数据 (中文)
declare PROJECT_ROOT=''  # 项目安装根目录 (动态设置)
declare I18N_DIR=''      # 国际化文件目录 (动态设置)
declare CORE_DIR=''      # 核心脚本目录 (动态设置)
declare SERVICE_DIR=''   # 服务配置目录 (动态设置)
declare CONFIG_DIR=''    # 配置文件目录 (动态设置)
declare TOOL_DIR=''      # 工具脚本目录 (动态设置)
declare QUICK_INSTALL='' # 存储快速安装选项 (如 --vision, --xhttp)
declare SCRIPT_CONFIG='' # 存储脚本配置内容
declare LANG_PARAM=''    # 存储命令行指定的语言参数
declare FORCE_CHECK_DEPS=0 # 是否强制检查/安装依赖 (0/1)
declare DO_UPDATE=0         # 仅在 --update 时从本 fork 检查并替换已安装副本

# =============================================================================
# 函数名称: _os
# 功能描述: 检测当前操作系统的发行版名称。
# 参数: 无
# 返回值: 操作系统名称 (echo 输出: debian/ubuntu/centos/amazon/...)
# =============================================================================
function _os() {
    local os="" # 声明局部变量存储操作系统名称

    # 检查 Debian/Ubuntu 系列
    if [[ -f "/etc/debian_version" ]]; then
        # 读取 /etc/os-release 文件并提取 ID 字段
        source /etc/os-release && os="${ID}"
        # 输出检测到的操作系统名称
        printf -- "%s" "${os}" && return
    fi

    # 检查 Red Hat/CentOS 系列
    if [[ -f "/etc/redhat-release" ]]; then
        os="centos"
        # 输出检测到的操作系统名称
        printf -- "%s" "${os}" && return
    fi
}

# =============================================================================
# 函数名称: _os_full
# 功能描述: 获取当前操作系统的完整发行版信息。
# 参数: 无
# 返回值: 完整的操作系统版本信息 (echo 输出)
# =============================================================================
function _os_full() {
    # 检查 Red Hat/CentOS 系列
    if [[ -f /etc/redhat-release ]]; then
        # 从 /etc/redhat-release 文件中提取发行版名称和版本号
        awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    fi

    # 检查通用的 os-release 文件
    if [[ -f /etc/os-release ]]; then
        # 从 /etc/os-release 文件中提取 PRETTY_NAME 字段
        awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    fi

    # 检查 LSB (Linux Standard Base) 发布文件
    if [[ -f /etc/lsb-release ]]; then
        # 从 /etc/lsb-release 文件中提取 DESCRIPTION 字段
        awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
    fi
}

# =============================================================================
# 函数名称: _os_ver
# 功能描述: 获取当前操作系统的主版本号。
# 参数: 无
# 返回值: 操作系统的主版本号 (echo 输出)
# =============================================================================
function _os_ver() {
    # 调用 _os_full 函数获取完整版本信息，然后提取其中的数字和点
    local main_ver="$(echo $(_os_full) | grep -oE "[0-9.]+")"
    # 输出主版本号 (第一个点号前的部分)
    printf -- "%s" "${main_ver%%.*}"
}

# =============================================================================
# 函数名称: cmd_exists
# 功能描述: 检查指定的命令是否存在于系统中。
# 参数:
#   $1: 要检查的命令名称
# 返回值: 0-命令存在 1-命令不存在 (由命令检查工具的退出码决定)
# =============================================================================
function cmd_exists() {
    local cmd="$1" # 获取命令名称参数

    # 尝试使用不同的方法检查命令是否存在
    if eval type type >/dev/null 2>&1; then
        # 使用 type 命令检查
        eval type "$cmd" >/dev/null 2>&1
    elif command >/dev/null 2>&1; then
        # 使用 command -v 命令检查
        command -v "$cmd" >/dev/null 2>&1
    else
        # 使用 which 命令检查
        which "$cmd" >/dev/null 2>&1
    fi
}

# =============================================================================
# 函数名称: parse_args
# 功能描述: 解析命令行参数。
# 参数:
#   $@: 所有命令行参数
# 返回值: 无 (直接修改全局变量 QUICK_INSTALL, PROJECT_ROOT, LANG_PARAM)
# =============================================================================
function parse_args() {
    # 遍历所有命令行参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
        # 如果参数是语言设置
        --lang=*)
            LANG_PARAM="${1}"
            ;;
        --check-deps)
            FORCE_CHECK_DEPS=1
            ;;
        --update)
            DO_UPDATE=1
            ;;
        esac
        shift # 移动到下一个参数
    done
}

# =============================================================================
# 函数名称: load_i18n
# 功能描述: 加载国际化 (i18n) 数据。
# 参数: 无
# 返回值: 无 (直接修改全局变量 I18N_DATA)
# =============================================================================
function load_i18n() {
    local lang="${LANG_PARAM#*=}" # 从 LANG_PARAM 中提取语言代码

    # 如果存在脚本配置文件，则尝试从文件中获取语言代码
    if [[ -z "${lang}" && -f "${SCRIPT_CONFIG_PATH}" ]]; then
        # 尝试从脚本配置文件中获取语言代码
        if cmd_exists "jq"; then
            lang="$(jq -r '.language' "${SCRIPT_CONFIG_PATH}" 2>/dev/null)"
        fi
    fi

    # 如果语言设置为 "auto"，则使用系统环境变量 LANG 的第一部分作为语言代码
    if [[ "$lang" == "auto" ]]; then
        lang=$(echo "$LANG" | cut -d'_' -f1)
    fi

    # 如果语言设置为 "en"，则加载英文提示信息
    if [[ "$lang" == "en" ]]; then
        I18N_DATA=(
            ['error']='Error'
            ['root']='This script must be run as root'
            ['supported']='Not supported OS'
            ['ubuntu']='Not supported OS, please change to Ubuntu 18+ and try again.'
            ['debian']='Not supported OS, please change to Debian 9+ and try again.'
            ['centos']='Not supported OS, please change to CentOS 7+ and try again.'
            ['tip']='Update Notice'
            ['new']='A new version of the script is available. Do you want to update?'
            ['now']='Update now? [Y/n]'
            ['promptly']='Please update the script promptly.'
            ['completed']='Update completed'
            ['download']='Downloading'
            ['failed']='Download failed'
            ['downloaded']='The file has been downloaded to'
            ['local']='Using the local repository files. Nothing is downloaded.'
            ['same']='Already at the current version of this fork'
            ['bad_checksum']='File checksum verification failed'
            ['refused']='Refusing zxcvos/Xray-script, or the script ref is invalid'
            ['bad_path']='Invalid install path'
        )
    fi
}

# =============================================================================
# 函数名称: _error
# 功能描述: 以红色打印错误信息并退出脚本。
# 参数:
#   $@: 错误消息内容
# 返回值: 无 (直接打印到标准错误输出 >&2，然后 exit 1)
# =============================================================================
function _error() {
    # 用红色打印错误标题
    printf "${RED}[${I18N_DATA['error']}] ${NC}"
    # 打印传入的错误消息
    printf -- "%s" "$@"
    # 打印换行符
    printf "\n"
    # 退出脚本，错误码为 1
    exit 1
}

# =============================================================================
# 函数名称: check_os
# 功能描述: 检查操作系统是否受支持。
# 参数: 无
# 返回值: 无 (如果不支持则调用 _error 退出)
# =============================================================================
function check_os() {
    # 检查操作系统类型和版本
    case "$(_os)" in
    # CentOS 系列
    centos)
        # 检查版本号是否大于等于 7
        if [[ "$(_os_ver)" -lt 7 ]]; then
            _error "${I18N_DATA['centos']}"
        fi
        ;;
    # Ubuntu 系列
    ubuntu)
        # 检查版本号是否大于等于 16
        if [[ "$(_os_ver)" -lt 16 ]]; then
            _error "${I18N_DATA['ubuntu']}"
        fi
        ;;
    # Debian 系列
    debian)
        # 检查版本号是否大于等于 9
        if [[ "$(_os_ver)" -lt 9 ]]; then
            _error "${I18N_DATA['debian']}"
        fi
        ;;
    # 其他不支持的操作系统
    *)
        _error "${I18N_DATA['supported']}"
        ;;
    esac
}

# =============================================================================
# 函数名称: check_dependencies
# 功能描述: 检查必要的依赖软件是否已安装。
# 参数: 无
# 返回值: 0-所有依赖都已安装 1-有依赖缺失 (由命令检查结果决定)
# =============================================================================
function check_dependencies() {
    # 定义基础必需的软件包列表
    local packages=("ca-certificates" "openssl" "curl" "wget" "git" "jq" "tzdata" "qrencode" "socat")
    local missing_packages=() # 声明数组存储缺失的包

    # 根据操作系统类型检查特定的软件包
    case "$(_os)" in
    centos)
        # 为 CentOS/RHEL 添加系统管理工具
        packages+=("crontabs" "util-linux" "iproute" "procps-ng" "bind-utils")
        # 遍历包列表，检查是否安装
        for pkg in "${packages[@]}"; do
            if ! rpm -q "$pkg" &>/dev/null; then
                missing_packages+=("$pkg") # 如果未安装，添加到缺失列表
            fi
        done
        ;;
    debian | ubuntu)
        # 为 Debian/Ubuntu 添加系统管理工具
        packages+=("cron" "bsdmainutils" "iproute2" "procps" "dnsutils")
        # 遍历包列表，检查是否安装
        for pkg in "${packages[@]}"; do
            if ! dpkg -s "$pkg" &>/dev/null; then
                missing_packages+=("$pkg") # 如果未安装，添加到缺失列表
            fi
        done
        ;;
    esac

    # 如果缺失包列表为空，则返回 0 (成功)
    [[ ${#missing_packages[@]} -eq 0 ]]
}

# =============================================================================
# 函数名称: install_dependencies
# 功能描述: 根据操作系统类型安装必要的依赖包。
# 参数: 无
# 返回值: 无 (执行包管理器命令安装软件)
# =============================================================================
function install_dependencies() {
    # 定义基础必需的软件包列表
    local packages=("ca-certificates" "openssl" "curl" "wget" "git" "jq" "tzdata" "qrencode" "socat")

    # 根据操作系统类型添加特定的软件包并执行安装
    case "$(_os)" in
    centos)
        # 为 CentOS/RHEL 添加系统管理工具
        packages+=("crontabs" "util-linux" "iproute" "procps-ng" "bind-utils")
        # 检查是否使用 dnf 包管理器 (较新版本)
        if cmd_exists "dnf"; then
            # 使用 dnf 更新系统并安装软件包
            dnf update -y
            dnf install -y dnf-plugins-core
            dnf update -y
            for pkg in "${packages[@]}"; do
                dnf install -y ${pkg}
            done
        else
            # 使用 yum 包管理器 (较旧版本)
            yum update -y
            yum install -y epel-release yum-utils
            yum update -y
            for pkg in "${packages[@]}"; do
                yum install -y ${pkg}
            done
        fi
        ;;
    ubuntu | debian)
        # 为 Debian/Ubuntu 添加系统管理工具
        packages+=("cron" "bsdmainutils" "iproute2" "procps" "dnsutils")
        # 更新包列表并安装软件包
        apt update -y
        for pkg in "${packages[@]}"; do
            apt install -y ${pkg}
        done
        ;;
    esac
}

# =============================================================================
# 函数名称: project_tree_ready
# 功能描述: 判断目录是否包含可离线运行的完整脚本树。
# =============================================================================
function project_tree_ready() {
    local dir="$1"

    [[ -n "${dir}" && -f "${dir}/core/main.sh" && -f "${dir}/config.json" && -f "${dir}/install.sh" && -f "${dir}/service/nginx.sh" ]]
}

# =============================================================================
# 函数名称: assert_safe_project_root
# 功能描述: 拒绝空路径、相对路径和根目录，避免更新时删除错误目录。
# =============================================================================
function assert_safe_project_root() {
    [[ -n "${PROJECT_ROOT}" && "${PROJECT_ROOT}" == /* && "${PROJECT_ROOT}" != "/" ]] || _error "${I18N_DATA['bad_path']}"
}

# =============================================================================
# 函数名称: copy_project_tree
# 功能描述: 将本地仓库复制到安装目录，不访问网络。
# =============================================================================
function copy_project_tree() {
    local source_dir="$1"
    local target_dir="$2"

    [[ "${source_dir}" == "${target_dir}" ]] && return 0
    mkdir -p "${target_dir}"
    tar -C "${source_dir}" --exclude='.git' --exclude='nginxtemp.*' -cf - . | tar -C "${target_dir}" -xf -
    [[ "${PIPESTATUS[0]}" -eq 0 && "${PIPESTATUS[1]}" -eq 0 ]] || _error "${I18N_DATA['failed']}: ${source_dir}"
}

# =============================================================================
# 函数名称: script_ref
# 功能描述: 读取本 fork 的 git 引用。默认 main，可用 XRAY_SCRIPT_REF 覆盖。
# =============================================================================
function script_ref() {
    local ref="${XRAY_SCRIPT_REF:-main}"

    [[ "${ref}" =~ ^[A-Za-z0-9._-]+$ ]] || _error "${I18N_DATA['refused']}"
    printf '%s' "${ref}"
}

# =============================================================================
# 函数名称: forbid_upstream_url
# 功能描述: 运行时禁止任何指向原上游仓库的地址。
# =============================================================================
function forbid_upstream_url() {
    local url="$1"

    case "${url}" in
    *zxcvos* | *ZXCVOS*) _error "${I18N_DATA['refused']}" ;;
    esac
}

# =============================================================================
# 函数名称: verify_sha256_inline
# 功能描述: 校验文件的 SHA-256。期望值为 64 位十六进制。
# =============================================================================
function verify_sha256_inline() {
    local file="$1"
    local expected="$2"
    local actual

    [[ "${expected}" =~ ^[0-9a-fA-F]{64}$ ]] || return 1
    actual="$(sha256sum "${file}" | awk '{print $1}')"
    [[ "${actual,,}" == "${expected,,}" ]]
}

# =============================================================================
# 函数名称: download_xray_script_files
# 功能描述: 从 freelxs/Xray-script 下载指定引用的源码包并解压到目标目录。
#           设置 XRAY_SCRIPT_SHA256 时校验压缩包。
# =============================================================================
function download_xray_script_files() {
    local target_dir="$1"
    local ref url tmp extract

    assert_safe_project_root
    ref="$(script_ref)"
    if [[ "${ref}" =~ ^[0-9a-fA-F]{40}$ ]]; then
        url="https://github.com/freelxs/Xray-script/archive/${ref}.tar.gz"
    else
        url="https://github.com/freelxs/Xray-script/archive/refs/heads/${ref}.tar.gz"
    fi
    forbid_upstream_url "${url}"
    echo -e "${GREEN}[${I18N_DATA['download']}]${NC} ${url}"

    tmp="$(mktemp)"
    if ! curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 --retry 3 --retry-delay 2 --output "${tmp}" "${url}"; then
        rm -f "${tmp}"
        _error "${I18N_DATA['failed']}: ${url}"
    fi
    if [[ -n "${XRAY_SCRIPT_SHA256:-}" ]] && ! verify_sha256_inline "${tmp}" "${XRAY_SCRIPT_SHA256}"; then
        rm -f "${tmp}"
        _error "${I18N_DATA['bad_checksum']}"
    fi

    extract="$(mktemp -d)"
    if ! tar -xzf "${tmp}" -C "${extract}" --strip-components=1; then
        rm -rf "${tmp}" "${extract}"
        _error "${I18N_DATA['failed']}: ${url}"
    fi
    rm -f "${tmp}"
    mkdir -p "${target_dir}"
    tar -C "${extract}" -cf - . | tar -C "${target_dir}" -xf -
    [[ "${PIPESTATUS[0]}" -eq 0 && "${PIPESTATUS[1]}" -eq 0 ]] || _error "${I18N_DATA['failed']}: ${url}"
    rm -rf "${extract}"
}

# =============================================================================
# 函数名称: update_project_files
# 功能描述: 仅在 --update 时对照本 fork 的 config.json 版本，不一致则替换安装目录。
# =============================================================================
function update_project_files() {
    local ref url tmp local_version remote_version temp_dir updated

    ref="$(script_ref)"
    url="https://raw.githubusercontent.com/freelxs/Xray-script/${ref}/config.json"
    forbid_upstream_url "${url}"
    tmp="$(mktemp)"
    if ! curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 --retry 3 --retry-delay 2 --output "${tmp}" "${url}"; then
        rm -f "${tmp}"
        _error "${I18N_DATA['failed']}: ${url}"
    fi
    remote_version="$(jq -r '.version // empty' "${tmp}")"
    rm -f "${tmp}"
    [[ -n "${remote_version}" ]] || _error "${I18N_DATA['failed']}: ${url}"

    local_version=""
    if [[ -f "${PROJECT_ROOT}/config.json" ]]; then
        local_version="$(jq -r '.version // empty' "${PROJECT_ROOT}/config.json")"
    elif [[ -f "${SCRIPT_CONFIG_PATH}" ]]; then
        local_version="$(jq -r '.version // empty' "${SCRIPT_CONFIG_PATH}")"
    fi
    if [[ "${local_version}" == "${remote_version}" ]]; then
        echo -e "${GREEN}[${I18N_DATA['tip']}]${NC} ${I18N_DATA['same']}"
        return 0
    fi

    temp_dir="$(mktemp -d)"
    download_xray_script_files "${temp_dir}"
    rm -rf "${PROJECT_ROOT}"
    mkdir -p "$(dirname -- "${PROJECT_ROOT}")"
    mv -f "${temp_dir}" "${PROJECT_ROOT}"
    if [[ -f "${PROJECT_ROOT}/install.sh" && "${CUR_DIR}/${CUR_FILE}" != "${PROJECT_ROOT}/install.sh" ]]; then
        cp -f "${PROJECT_ROOT}/install.sh" "${CUR_DIR}/${CUR_FILE}"
    fi
    if [[ -f "${SCRIPT_CONFIG_PATH}" ]]; then
        updated="$(jq --arg version "${remote_version}" '.version = $version' "${SCRIPT_CONFIG_PATH}")"
        printf '%s\n' "${updated}" >"${SCRIPT_CONFIG_PATH}"
    fi
    echo -e "${GREEN}[${I18N_DATA['tip']}]${NC} ${I18N_DATA['completed']}"
    exec bash "${CUR_DIR}/${CUR_FILE}" "$@"
}

# =============================================================================
# 函数名称: install_project_files
# 功能描述: 优先使用本地完整仓库。只有缺少文件，或显式 --update 时，才访问本 fork。
# =============================================================================
function install_project_files() {
    assert_safe_project_root
    if [[ "${DO_UPDATE}" -eq 1 ]]; then
        update_project_files "$@"
        return 0
    fi
    if project_tree_ready "${CUR_DIR}"; then
        if [[ "${CUR_DIR}" != "${PROJECT_ROOT}" ]]; then
            echo -e "${GREEN}[${I18N_DATA['tip']}]${NC} ${I18N_DATA['local']}"
            copy_project_tree "${CUR_DIR}" "${PROJECT_ROOT}"
        fi
        return 0
    fi
    if project_tree_ready "${PROJECT_ROOT}"; then
        return 0
    fi
    download_xray_script_files "${PROJECT_ROOT}"
}

# =============================================================================
# 函数名称: main
# 功能描述: 脚本的主入口函数。
#           1. 解析命令行参数。
#           2. 加载国际化数据。
#           3. 检查 root 权限。
#           4. 检查操作系统。
#           5. 检查并安装依赖。
#           6. 处理项目目录和配置。
#           7. 启动主脚本。
# 参数:
#   $@: 所有命令行参数
# 返回值: 无 (协调调用其他函数完成整个安装流程)
# =============================================================================
function main() {
    # 解析命令行参数
    parse_args "$@"
    # 加载国际化数据
    load_i18n

    # 检查是否以 root 权限运行
    [[ $EUID -ne 0 ]] && _error "${I18N_DATA['root']}"

    # 检查操作系统
    check_os

    local is_first_run=0
    if [[ ! -f "${SCRIPT_CONFIG_PATH}" ]]; then
        is_first_run=1
    fi

    # 仅首次运行或显式强制时检查/安装依赖
    if [[ "${is_first_run}" -eq 1 || "${FORCE_CHECK_DEPS}" -eq 1 ]]; then
        # 检查依赖，如果缺失则安装
        if ! check_dependencies; then
            install_dependencies
        fi

        # 再次检查依赖 (安装后)
        if ! check_dependencies; then
            install_dependencies
        fi
    fi

    if [[ ! -d "${SCRIPT_CONFIG_DIR}" ]]; then
        mkdir -p "${SCRIPT_CONFIG_DIR}"
    fi

    # 保留原始参数。后面的循环会移走它们，--update 重启时还要原样传回。
    local original_args=("$@")

    # 处理命令行参数中的快速安装和自定义目录选项
    while [[ $# -gt 0 ]]; do
        case "$1" in
        # 快速安装选项
        --vision | --xhttp | --fallback)
            QUICK_INSTALL="${1}"
            ;;
        # 自定义安装目录选项
        -d)
            shift
            PROJECT_ROOT="${1}"
            ;;
        esac
        shift
    done

    # 已有配置里的路径优先于 -d，与原先的行为一致
    local script_path=""
    if [[ -f "${SCRIPT_CONFIG_PATH}" ]]; then
        script_path="$(jq -r '.path // empty' "${SCRIPT_CONFIG_PATH}")"
        if [[ "${script_path}" == "null" ]]; then
            script_path=""
        fi
    fi
    if [[ -n "${script_path}" ]]; then
        PROJECT_ROOT="${script_path}"
    elif [[ -z "${PROJECT_ROOT}" ]]; then
        PROJECT_ROOT='/usr/local/xray-script'
    fi

    # 本地完整仓库优先。缺少文件时才从 freelxs/Xray-script 下载。--update 才会替换已安装副本。
    install_project_files "${original_args[@]}"

    # 配置文件随仓库一起提供，不再单独从 raw.githubusercontent 拉取
    if [[ ! -f "${SCRIPT_CONFIG_PATH}" ]]; then
        cp -f "${PROJECT_ROOT}/config.json" "${SCRIPT_CONFIG_PATH}"
    fi
    script_path="$(jq -r '.path // empty' "${SCRIPT_CONFIG_PATH}")"
    if [[ -z "${script_path}" || "${script_path}" == "null" ]]; then
        SCRIPT_CONFIG="$(jq --arg path "${PROJECT_ROOT}" '.path = $path' "${SCRIPT_CONFIG_PATH}")"
        echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2
    fi

    # 设置各个子目录的路径
    I18N_DIR="${PROJECT_ROOT}/i18n"
    CORE_DIR="${PROJECT_ROOT}/core"
    SERVICE_DIR="${PROJECT_ROOT}/service"
    CONFIG_DIR="${PROJECT_ROOT}/config"
    TOOL_DIR="${PROJECT_ROOT}/tool"

    # 检查配置文件中的语言设置
    local lang="$(jq -r '.language' "${SCRIPT_CONFIG_PATH}")"
    if [[ -z "${lang}" && -z "${LANG_PARAM}" ]]; then
        # 如果语言未设置且未通过命令行指定，则运行菜单脚本选择语言
        bash "${CORE_DIR}/menu.sh" '--language'
        case $? in
        2) LANG_PARAM="en" ;; # 选择英文
        *) LANG_PARAM="zh" ;; # 默认中文
        esac
        # 更新配置文件中的语言设置
        SCRIPT_CONFIG="$(jq --arg language "${LANG_PARAM}" '.language = $language' "${SCRIPT_CONFIG_PATH}")"
        echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2
    elif [[ "${LANG_PARAM}" =~ ^--lang= ]]; then
        # 如果通过命令行指定了语言，则更新配置文件
        SCRIPT_CONFIG="$(jq --arg language "${LANG_PARAM#*=}" '.language = $language' "${SCRIPT_CONFIG_PATH}")"
        echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2
    fi

    # 启动主脚本，并传递快速安装选项
    bash "${CORE_DIR}/main.sh" "${QUICK_INSTALL}"
}

# --- 脚本执行入口 ---
# 将脚本接收到的所有参数传递给 main 函数开始执行
main "$@"
