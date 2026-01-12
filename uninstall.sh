#!/bin/bash

###############################################################################
# Hollow Knight GRUB Theme Uninstaller
# Removes the theme and restores default GRUB configuration
###############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Theme configuration
THEME_NAME="hollow-knight"
THEME_DIR="/boot/grub/themes/${THEME_NAME}"
GRUB_CFG="/etc/default/grub"
BACKUP_DIR="${HOME}/.grub-theme-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

# Detect the GRUB configuration command
detect_grub_cmd() {
    if command -v update-grub &> /dev/null; then
        echo "update-grub"
    elif command -v grub-mkconfig &> /dev/null; then
        if [[ -f /boot/grub/grub.cfg ]]; then
            echo "grub-mkconfig -o /boot/grub/grub.cfg"
        elif [[ -f /boot/grub2/grub.cfg ]]; then
            echo "grub-mkconfig -o /boot/grub2/grub.cfg"
        else
            echo "grub-mkconfig -o /boot/grub/grub.cfg"
        fi
    elif command -v grub2-mkconfig &> /dev/null; then
        echo "grub2-mkconfig -o /boot/grub2/grub.cfg"
    else
        echo ""
    fi
}

# Detect GRUB config file location
detect_grub_cfg() {
    if [[ -f /etc/default/grub ]]; then
        echo "/etc/default/grub"
    elif [[ -f /etc/grub.d/40_custom ]]; then
        echo "/etc/grub.d/40_custom"
    else
        echo "/etc/default/grub"
    fi
}

# Banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║     Hollow Knight GRUB Theme Uninstaller              ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Confirm uninstallation
print_warning "This will remove the Hollow Knight GRUB theme and restore default settings."
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Uninstallation cancelled."
    exit 0
fi

# Backup GRUB configuration before making changes
GRUB_CFG=$(detect_grub_cfg)
print_info "Backing up current GRUB configuration..."
mkdir -p "${BACKUP_DIR}"
cp "${GRUB_CFG}" "${BACKUP_DIR}/grub_uninstall_${TIMESTAMP}.bak"
print_success "GRUB config backed up to: ${BACKUP_DIR}/grub_uninstall_${TIMESTAMP}.bak"

# Remove GRUB_THEME line from configuration
print_info "Removing theme configuration from ${GRUB_CFG}..."
sed -i '/^GRUB_THEME=/d' "${GRUB_CFG}"
print_success "Theme configuration removed"

# Ask if user wants to remove theme files
if [[ -d "${THEME_DIR}" ]]; then
    read -p "Do you want to delete theme files from ${THEME_DIR}? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Removing theme files..."
        rm -rf "${THEME_DIR}"
        print_success "Theme files removed"
    else
        print_info "Theme files kept at: ${THEME_DIR}"
    fi
else
    print_warning "Theme directory not found: ${THEME_DIR}"
fi

# Regenerate GRUB configuration
GRUB_CMD=$(detect_grub_cmd)
if [[ -z "${GRUB_CMD}" ]]; then
    print_error "Could not detect GRUB update command"
    print_warning "Please manually run one of the following commands:"
    echo "  - update-grub"
    echo "  - grub-mkconfig -o /boot/grub/grub.cfg"
    echo "  - grub2-mkconfig -o /boot/grub2/grub.cfg"
    exit 1
fi

print_info "Regenerating GRUB configuration with: ${GRUB_CMD}"
eval "${GRUB_CMD}"

if [[ $? -eq 0 ]]; then
    print_success "GRUB configuration regenerated successfully"
else
    print_error "Failed to regenerate GRUB configuration"
    print_info "You can restore from backup: ${BACKUP_DIR}/grub_uninstall_${TIMESTAMP}.bak"
    exit 1
fi

# Uninstallation complete
echo -e "\n${GREEN}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║          Uninstallation Complete!                     ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_success "Hollow Knight theme has been uninstalled"
print_info "GRUB will now use the default theme"
print_info "Configuration backup: ${BACKUP_DIR}/grub_uninstall_${TIMESTAMP}.bak"
echo ""

# List available backups
if [[ -d "${BACKUP_DIR}" ]] && [[ -n "$(ls -A ${BACKUP_DIR})" ]]; then
    print_info "Available backups in ${BACKUP_DIR}:"
    ls -1 "${BACKUP_DIR}"
fi

echo ""
print_warning "Please reboot your system to see the default GRUB theme"
echo ""

# Ask if user wants to reboot
read -p "Would you like to reboot now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Rebooting system..."
    sleep 2
    reboot
else
    print_info "Remember to reboot to see the changes!"
fi
