#!/usr/bin/env bash
###############################################################################
# Hollow Knight GRUB Theme — Universal Uninstaller
#
# One-line uninstall:
#   curl -fsSL https://raw.githubusercontent.com/opx0/grub-theme/main/uninstall.sh | sudo bash
#
# Headless:
#   curl -fsSL https://raw.githubusercontent.com/opx0/grub-theme/main/uninstall.sh \
#     | sudo bash -s -- --yes --purge --no-reboot
#
# Local:
#   sudo ./uninstall.sh
###############################################################################

set -Eeuo pipefail

main() {

    # ----- Configuration -----------------------------------------------------
    readonly THEME_NAME="hollow-knight"
    readonly THEME_DIR="/boot/grub/themes/${THEME_NAME}"
    readonly REPO_OWNER="opx0"
    readonly REPO_NAME="grub-theme"
    readonly REPO_RAW="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}"
    readonly DEFAULT_BRANCH="main"
    readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

    # ----- Defaults / flags --------------------------------------------------
    ASSUME_YES=false
    PURGE=false        # delete theme files without asking
    KEEP_FILES=false   # keep theme files (skip the prompt)
    NO_REBOOT=false
    DEBUG=false

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

    # ----- Usage -------------------------------------------------------------
    usage() {
        cat <<EOF
${BOLD}Hollow Knight GRUB Theme — Uninstaller${NC}

${BOLD}Quick uninstall${NC}:
    ${CYAN}curl -fsSL ${REPO_RAW}/${DEFAULT_BRANCH}/uninstall.sh | sudo bash${NC}

${BOLD}Usage:${NC}
    sudo ./uninstall.sh [OPTIONS]

${BOLD}Options:${NC}
    -y, --yes          Non-interactive mode (assume yes to prompts)
    -p, --purge        Also delete theme files from ${THEME_DIR}
    -k, --keep-files   Keep theme files on disk (skip the deletion prompt)
    -n, --no-reboot    Skip the post-uninstall reboot prompt
    -d, --debug        Verbose debug output
    -h, --help         Show this help and exit
EOF
    }

    # ----- Argument parsing --------------------------------------------------
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)         ASSUME_YES=true; shift ;;
            -p|--purge)       PURGE=true; ASSUME_YES=true; shift ;;
            -k|--keep-files)  KEEP_FILES=true; shift ;;
            -n|--no-reboot)   NO_REBOOT=true; shift ;;
            -d|--debug)       DEBUG=true; shift ;;
            -h|--help)        usage; exit 0 ;;
            --)               shift; break ;;
            *)                err "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [[ ! -t 0 ]]; then
        debug "stdin is not a TTY — running non-interactively."
        ASSUME_YES=true
        NO_REBOOT=true
        # When piped without a deliberate choice, default to keeping files.
        if [[ "${PURGE}" != true ]]; then
            KEEP_FILES=true
        fi
    fi

    # ----- Root check --------------------------------------------------------
    if [[ ${EUID} -ne 0 ]]; then
        err "This uninstaller must be run as root."
        info "Try: ${BOLD}sudo $0 $*${NC}"
        info "Or:  ${BOLD}curl -fsSL ${REPO_RAW}/${DEFAULT_BRANCH}/uninstall.sh | sudo bash${NC}"
        exit 1
    fi

    # ----- Banner ------------------------------------------------------------
    cat <<EOF
${CYAN}${BOLD}
   ╔══════════════════════════════════════════════════════════════╗
   ║      Hollow Knight GRUB Theme — Universal Uninstaller        ║
   ╚══════════════════════════════════════════════════════════════╝
${NC}
EOF

    # ----- Confirm helper ----------------------------------------------------
    confirm() {
        local prompt="$1" default="${2:-N}" reply
        if [[ "${ASSUME_YES}" == true ]]; then return 0; fi
        if [[ ! -t 0 ]]; then return 1; fi
        read -r -p "${prompt} " reply || return 1
        reply="${reply:-${default}}"
        [[ "${reply}" =~ ^[Yy]$ ]]
    }

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

    get_user_home() {
        if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            getent passwd "${SUDO_USER}" 2>/dev/null | cut -d: -f6 || echo "${HOME:-/root}"
        else
            echo "${HOME:-/root}"
        fi
    }

    # ----- Confirm intent ----------------------------------------------------
    warn "This will remove the Hollow Knight GRUB theme and restore default settings."
    if ! confirm "Continue? [y/N]" "N"; then
        info "Uninstallation cancelled."
        exit 0
    fi

    # ----- Backup ------------------------------------------------------------
    USER_HOME="$(get_user_home)"
    BACKUP_DIR="${USER_HOME}/.grub-theme-backups"
    mkdir -p "${BACKUP_DIR}"
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        chown "${SUDO_USER}:" "${BACKUP_DIR}" 2>/dev/null || true
    fi

    GRUB_CFG="$(detect_grub_cfg)"
    if [[ -f "${GRUB_CFG}" ]]; then
        info "Backing up ${GRUB_CFG}"
        cp "${GRUB_CFG}" "${BACKUP_DIR}/grub_uninstall_${TIMESTAMP}.bak"
        success "Config backup: ${BACKUP_DIR}/grub_uninstall_${TIMESTAMP}.bak"
    else
        warn "GRUB config not found at ${GRUB_CFG} — skipping config edit."
        GRUB_CFG=""
    fi

    # ----- Remove GRUB_THEME entry ------------------------------------------
    if [[ -n "${GRUB_CFG}" ]]; then
        info "Removing GRUB_THEME entry from ${GRUB_CFG}"
        sed -i '/^[[:space:]]*GRUB_THEME=/d' "${GRUB_CFG}"
        success "GRUB_THEME entry removed"
    fi

    # ----- Remove theme files ------------------------------------------------
    if [[ -d "${THEME_DIR}" ]]; then
        local should_remove=false
        if [[ "${PURGE}" == true ]]; then
            should_remove=true
        elif [[ "${KEEP_FILES}" == true ]]; then
            should_remove=false
        elif confirm "Delete theme files at ${THEME_DIR}? [y/N]" "N"; then
            should_remove=true
        fi

        if ${should_remove}; then
            info "Removing ${THEME_DIR}"
            rm -rf "${THEME_DIR}"
            success "Theme files removed"
        else
            info "Keeping theme files at ${THEME_DIR}"
        fi
    else
        warn "Theme directory not found: ${THEME_DIR}"
    fi

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
        info "Restore the previous config from ${BACKUP_DIR}/grub_uninstall_${TIMESTAMP}.bak if needed."
        exit 1
    fi
    success "GRUB menu regenerated"

    # ----- Done --------------------------------------------------------------
    cat <<EOF

${GREEN}${BOLD}   ╔══════════════════════════════════════════════════════════════╗
   ║                Uninstallation Complete!                      ║
   ╚══════════════════════════════════════════════════════════════╝${NC}

   ${BOLD}GRUB will use the default theme on next boot.${NC}
   ${BOLD}Backups:${NC} ${BACKUP_DIR}

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
