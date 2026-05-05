#!/usr/bin/env bash
###############################################################################
# Hollow Knight GRUB Theme — Universal Installer
#
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/opx0/grub-theme/main/install.sh | sudo bash
#
# With options (e.g. headless / no reboot prompt):
#   curl -fsSL https://raw.githubusercontent.com/opx0/grub-theme/main/install.sh \
#     | sudo bash -s -- --yes --no-reboot
#
# Local install (cloned repo):
#   sudo ./install.sh
###############################################################################

set -Eeuo pipefail

# Wrap everything in main() so the script is fully read before execution.
# This protects against partial-pipe bugs when run via `curl | bash`.
main() {

    # ----- Configuration -----------------------------------------------------
    readonly THEME_NAME="hollow-knight"
    readonly THEME_DIR="/boot/grub/themes/${THEME_NAME}"
    readonly REPO_OWNER="opx0"
    readonly REPO_NAME="grub-theme"
    readonly REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
    readonly REPO_RAW="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}"
    readonly DEFAULT_BRANCH="main"
    readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

    # Required theme assets — used to verify the source directory.
    readonly REQUIRED_FILES=(theme.txt background.png)

    # ----- Defaults / flags --------------------------------------------------
    BRANCH="${DEFAULT_BRANCH}"
    ASSUME_YES=false
    FORCE=false
    NO_REBOOT=false
    DEBUG=false
    TMPDIR=""

    # ----- Output helpers ----------------------------------------------------
    if [[ -t 1 ]]; then
        RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
        BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; NC=$'\033[0m'
    else
        RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; BOLD=""; DIM=""; NC=""
    fi

    info()    { printf "%s[INFO]%s %s\n" "${BLUE}"   "${NC}" "$1"; }
    success() { printf "%s[ OK ]%s %s\n" "${GREEN}"  "${NC}" "$1"; }
    warn()    { printf "%s[WARN]%s %s\n" "${YELLOW}" "${NC}" "$1"; }
    err()     { printf "%s[FAIL]%s %s\n" "${RED}"    "${NC}" "$1" >&2; }
    debug()   { [[ "${DEBUG}" == true ]] && printf "%s[DBG ]%s %s\n" "${CYAN}" "${NC}" "$1" || true; }

    # ----- Cleanup -----------------------------------------------------------
    cleanup() {
        local rc=$?
        if [[ -n "${TMPDIR}" && -d "${TMPDIR}" ]]; then
            debug "Cleaning up temp dir: ${TMPDIR}"
            rm -rf "${TMPDIR}"
        fi
        return "${rc}"
    }
    trap cleanup EXIT INT TERM

    # ----- Usage -------------------------------------------------------------
    usage() {
        cat <<EOF
${BOLD}Hollow Knight GRUB Theme — Installer${NC}

${BOLD}Quick install${NC} (one-liner):
    ${CYAN}curl -fsSL ${REPO_RAW}/${DEFAULT_BRANCH}/install.sh | sudo bash${NC}

${BOLD}Usage:${NC}
    sudo ./install.sh [OPTIONS]

${BOLD}Options:${NC}
    -y, --yes          Non-interactive mode (assume yes to prompts)
    -f, --force        Overwrite existing theme without asking (implies -y)
    -n, --no-reboot    Skip the post-install reboot prompt
    -b, --branch REF   Use a specific branch, tag, or commit (default: ${DEFAULT_BRANCH})
    -d, --debug        Verbose debug output
    -h, --help         Show this help and exit

${BOLD}Examples:${NC}
    # Headless one-liner (CI / scripts)
    ${DIM}curl -fsSL ${REPO_RAW}/${DEFAULT_BRANCH}/install.sh | sudo bash -s -- --yes --no-reboot${NC}

    # Install a tagged release
    ${DIM}sudo ./install.sh --branch v1.0.0${NC}
EOF
    }

    # ----- Argument parsing --------------------------------------------------
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)        ASSUME_YES=true; shift ;;
            -f|--force)      FORCE=true; ASSUME_YES=true; shift ;;
            -n|--no-reboot)  NO_REBOOT=true; shift ;;
            -b|--branch)
                [[ $# -ge 2 ]] || { err "--branch requires an argument"; exit 1; }
                BRANCH="$2"; shift 2 ;;
            -d|--debug)      DEBUG=true; shift ;;
            -h|--help)       usage; exit 0 ;;
            --)              shift; break ;;
            *)               err "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    # When piped (no TTY on stdin), force non-interactive defaults.
    if [[ ! -t 0 ]]; then
        debug "stdin is not a TTY — running non-interactively."
        ASSUME_YES=true
        NO_REBOOT=true
    fi

    # ----- Root check --------------------------------------------------------
    if [[ ${EUID} -ne 0 ]]; then
        err "This installer must be run as root."
        info "Try one of:"
        printf "    ${BOLD}sudo %s%s${NC}\n" "$0" "${1+ $*}"
        printf "    ${BOLD}curl -fsSL %s/${DEFAULT_BRANCH}/install.sh | sudo bash${NC}\n" "${REPO_RAW}"
        exit 1
    fi

    # ----- Banner ------------------------------------------------------------
    cat <<EOF
${CYAN}${BOLD}
   ╔══════════════════════════════════════════════════════════════╗
   ║       Hollow Knight GRUB Theme — Universal Installer         ║
   ║                                                              ║
   ║  Repo:   ${REPO_URL}              ║
   ║  Target: ${THEME_DIR}             ║
   ║  Branch: ${BRANCH}$(printf '%*s' $((54 - ${#BRANCH})) '')║
   ╚══════════════════════════════════════════════════════════════╝
${NC}
EOF

    # ----- Dependency check --------------------------------------------------
    need_cmd() {
        command -v "$1" >/dev/null 2>&1 || { err "Required command not found: $1"; exit 1; }
    }
    need_cmd sed
    need_cmd grep
    need_cmd tar
    need_cmd mktemp
    need_cmd install
    need_cmd find

    HAVE_CURL=false; HAVE_WGET=false
    command -v curl >/dev/null 2>&1 && HAVE_CURL=true
    command -v wget >/dev/null 2>&1 && HAVE_WGET=true

    # ----- GRUB detection ----------------------------------------------------
    detect_grub_cmd() {
        if command -v update-grub >/dev/null 2>&1; then
            echo "update-grub"
        elif command -v grub-mkconfig >/dev/null 2>&1; then
            if   [[ -f /boot/grub/grub.cfg  ]]; then echo "grub-mkconfig -o /boot/grub/grub.cfg"
            elif [[ -f /boot/grub2/grub.cfg ]]; then echo "grub-mkconfig -o /boot/grub2/grub.cfg"
            else echo "grub-mkconfig -o /boot/grub/grub.cfg"
            fi
        elif command -v grub2-mkconfig >/dev/null 2>&1; then
            if   [[ -f /boot/grub2/grub.cfg ]]; then echo "grub2-mkconfig -o /boot/grub2/grub.cfg"
            elif [[ -f /boot/grub/grub.cfg  ]]; then echo "grub2-mkconfig -o /boot/grub/grub.cfg"
            else echo "grub2-mkconfig -o /boot/grub2/grub.cfg"
            fi
        else
            echo ""
        fi
    }

    detect_grub_cfg() {
        if   [[ -f /etc/default/grub  ]]; then echo "/etc/default/grub"
        elif [[ -f /etc/sysconfig/grub ]]; then echo "/etc/sysconfig/grub"
        else echo "/etc/default/grub"
        fi
    }

    # ----- User-home detection (for backup convenience) ----------------------
    get_user_home() {
        if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            getent passwd "${SUDO_USER}" 2>/dev/null | cut -d: -f6 || echo "${HOME:-/root}"
        else
            echo "${HOME:-/root}"
        fi
    }

    # ----- Confirm helper ----------------------------------------------------
    confirm() {
        local prompt="$1" default="${2:-N}" reply
        if [[ "${ASSUME_YES}" == true ]]; then return 0; fi
        if [[ ! -t 0 ]]; then return 1; fi
        read -r -p "${prompt} " reply || return 1
        reply="${reply:-${default}}"
        [[ "${reply}" =~ ^[Yy]$ ]]
    }

    # ----- Locate / fetch source directory -----------------------------------
    resolve_script_dir() {
        local src="${BASH_SOURCE[0]:-}"
        [[ -z "${src}" || "${src}" == "bash" || "${src}" == "/dev/stdin" || "${src}" == "-" ]] && return 0
        # Resolve symlinks
        while [[ -h "${src}" ]]; do
            local d; d="$(cd -P "$(dirname "${src}")" >/dev/null 2>&1 && pwd)" || return 0
            src="$(readlink "${src}")"
            [[ "${src}" != /* ]] && src="${d}/${src}"
        done
        cd -P "$(dirname "${src}")" >/dev/null 2>&1 && pwd
    }

    has_required_files() {
        local dir="$1" f
        for f in "${REQUIRED_FILES[@]}"; do
            [[ -f "${dir}/${f}" ]] || return 1
        done
        return 0
    }

    download_tarball() {
        local url="$1" out="$2"
        if ${HAVE_CURL}; then
            debug "curl -fsSL '${url}' -o '${out}'"
            curl -fsSL --retry 3 --retry-delay 1 "${url}" -o "${out}"
        elif ${HAVE_WGET}; then
            debug "wget -qO '${out}' '${url}'"
            wget --tries=3 -qO "${out}" "${url}"
        else
            err "Neither curl nor wget is available — cannot download theme."
            exit 1
        fi
    }

    locate_or_fetch_source() {
        local script_dir; script_dir="$(resolve_script_dir)"
        if [[ -n "${script_dir}" ]] && has_required_files "${script_dir}"; then
            info "Using local theme files: ${script_dir}"
            SOURCE_DIR="${script_dir}"
            return 0
        fi

        info "No local theme files found — fetching from GitHub..."
        TMPDIR="$(mktemp -d -t grub-hollow-knight.XXXXXX)"
        debug "Temp dir: ${TMPDIR}"

        local tarball="${TMPDIR}/theme.tar.gz"
        local url="${REPO_URL}/archive/${BRANCH}.tar.gz"
        info "Downloading ${DIM}${url}${NC}"
        if ! download_tarball "${url}" "${tarball}"; then
            err "Failed to download theme archive."
            err "URL: ${url}"
            exit 1
        fi
        success "Archive downloaded ($(du -h "${tarball}" | cut -f1))"

        info "Extracting archive..."
        tar -xzf "${tarball}" -C "${TMPDIR}"

        # GitHub archives extract to <repo>-<ref>/. Find any matching dir.
        local extracted
        extracted="$(find "${TMPDIR}" -mindepth 1 -maxdepth 1 -type d -name "${REPO_NAME}-*" | head -n1)"
        if [[ -z "${extracted}" ]] || ! has_required_files "${extracted}"; then
            err "Extracted archive does not contain the expected theme files."
            exit 1
        fi
        SOURCE_DIR="${extracted}"
        success "Theme files ready at: ${SOURCE_DIR}"
    }

    # ----- Pre-flight --------------------------------------------------------
    info "Checking environment..."
    [[ -d /boot ]] || { err "/boot does not exist — is GRUB installed on this system?"; exit 1; }
    if [[ ! -d /boot/grub && ! -d /boot/grub2 ]]; then
        warn "Neither /boot/grub nor /boot/grub2 exists — GRUB may not be installed."
        confirm "Continue anyway? [y/N]" "N" || { info "Aborting."; exit 0; }
    fi

    # ----- Acquire source ----------------------------------------------------
    SOURCE_DIR=""
    locate_or_fetch_source
    [[ -n "${SOURCE_DIR}" ]] || { err "Could not determine theme source directory."; exit 1; }

    # ----- Backup directory --------------------------------------------------
    USER_HOME="$(get_user_home)"
    BACKUP_DIR="${USER_HOME}/.grub-theme-backups"
    mkdir -p "${BACKUP_DIR}"
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        chown "${SUDO_USER}:" "${BACKUP_DIR}" 2>/dev/null || true
    fi

    # ----- Existing theme handling -------------------------------------------
    if [[ -d "${THEME_DIR}" ]]; then
        warn "Theme directory already exists: ${THEME_DIR}"
        if [[ "${FORCE}" != true ]]; then
            if ! confirm "Overwrite the existing theme? [y/N]" "N"; then
                info "Installation cancelled."
                exit 0
            fi
        fi
        info "Backing up existing theme..."
        local existing_backup="${BACKUP_DIR}/${THEME_NAME}_${TIMESTAMP}"
        cp -r "${THEME_DIR}" "${existing_backup}"
        success "Existing theme backed up: ${existing_backup}"
    fi

    # ----- Install theme files -----------------------------------------------
    info "Installing theme files to ${THEME_DIR}"
    install -d -m 0755 "${THEME_DIR}"
    install -d -m 0755 "${THEME_DIR}/icons"
    install -d -m 0755 "${THEME_DIR}/backgrounds"

    # Copy everything required from SOURCE_DIR. We use a glob list rather than
    # `cp -r SOURCE/*` so that no stray files (.git, README, scripts) sneak in.
    shopt -s nullglob
    local f
    for f in "${SOURCE_DIR}"/*.png "${SOURCE_DIR}"/*.pf2 "${SOURCE_DIR}"/theme.txt; do
        install -m 0644 "${f}" "${THEME_DIR}/"
    done
    if [[ -d "${SOURCE_DIR}/icons" ]]; then
        for f in "${SOURCE_DIR}"/icons/*.png; do
            install -m 0644 "${f}" "${THEME_DIR}/icons/"
        done
    fi
    if [[ -d "${SOURCE_DIR}/backgrounds" ]]; then
        for f in "${SOURCE_DIR}"/backgrounds/*; do
            [[ -f "${f}" ]] && install -m 0644 "${f}" "${THEME_DIR}/backgrounds/"
        done
    fi
    shopt -u nullglob

    # Sanity-check the install
    [[ -f "${THEME_DIR}/theme.txt" ]] || { err "theme.txt missing after install."; exit 1; }
    success "Theme files installed"

    # ----- GRUB config -------------------------------------------------------
    GRUB_CFG="$(detect_grub_cfg)"
    if [[ ! -f "${GRUB_CFG}" ]]; then
        warn "GRUB config not found at ${GRUB_CFG} — creating it."
        : > "${GRUB_CFG}"
    fi

    info "Backing up ${GRUB_CFG}"
    cp "${GRUB_CFG}" "${BACKUP_DIR}/grub_${TIMESTAMP}.bak"
    success "Config backup: ${BACKUP_DIR}/grub_${TIMESTAMP}.bak"

    info "Updating ${GRUB_CFG}"
    # Drop any prior GRUB_THEME line, then append the new one.
    sed -i '/^[[:space:]]*GRUB_THEME=/d' "${GRUB_CFG}"
    printf 'GRUB_THEME="%s/theme.txt"\n' "${THEME_DIR}" >> "${GRUB_CFG}"

    # Set sensible graphics defaults if missing.
    if ! grep -qE '^[[:space:]]*GRUB_GFXMODE=' "${GRUB_CFG}"; then
        info "Setting GRUB_GFXMODE=1920x1080"
        echo 'GRUB_GFXMODE=1920x1080' >> "${GRUB_CFG}"
    fi
    if ! grep -qE '^[[:space:]]*GRUB_GFXPAYLOAD_LINUX=' "${GRUB_CFG}"; then
        info "Setting GRUB_GFXPAYLOAD_LINUX=keep"
        echo 'GRUB_GFXPAYLOAD_LINUX=keep' >> "${GRUB_CFG}"
    fi
    success "GRUB config updated"

    # ----- Regenerate grub.cfg ----------------------------------------------
    GRUB_CMD="$(detect_grub_cmd)"
    if [[ -z "${GRUB_CMD}" ]]; then
        err "Could not detect a GRUB regenerate command."
        warn "Run one of these manually, then reboot:"
        echo "  - update-grub"
        echo "  - grub-mkconfig  -o /boot/grub/grub.cfg"
        echo "  - grub2-mkconfig -o /boot/grub2/grub.cfg"
        exit 1
    fi

    info "Regenerating GRUB menu: ${GRUB_CMD}"
    if ! eval "${GRUB_CMD}"; then
        err "GRUB regeneration failed."
        info "Restore the previous config from ${BACKUP_DIR}/grub_${TIMESTAMP}.bak if needed."
        exit 1
    fi
    success "GRUB menu regenerated"

    # ----- Done --------------------------------------------------------------
    cat <<EOF

${GREEN}${BOLD}   ╔══════════════════════════════════════════════════════════════╗
   ║                Installation Complete!                        ║
   ╚══════════════════════════════════════════════════════════════╝${NC}

   ${BOLD}Theme:${NC}   ${THEME_DIR}
   ${BOLD}Config:${NC}  ${GRUB_CFG}
   ${BOLD}Backups:${NC} ${BACKUP_DIR}

   ${YELLOW}Reboot to see the new GRUB theme.${NC}

   To uninstall:
       ${CYAN}curl -fsSL ${REPO_RAW}/${DEFAULT_BRANCH}/uninstall.sh | sudo bash${NC}

EOF

    if [[ "${NO_REBOOT}" != true ]] && [[ -t 0 ]]; then
        if confirm "Reboot now? [y/N]" "N"; then
            info "Rebooting in 3 seconds... (Ctrl-C to cancel)"
            sleep 3
            systemctl reboot 2>/dev/null || reboot
        else
            info "Skipped reboot. Reboot manually when ready."
        fi
    fi
}

main "$@"
