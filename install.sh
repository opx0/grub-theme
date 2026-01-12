#!/bin/bash

###############################################################################
# Hollow Knight GRUB Theme Installer
# Installs the theme to /boot/grub/themes/ and configures GRUB
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
echo "║     Hollow Knight GRUB Theme Installer               ║"
echo "║     Installing theme to: ${THEME_DIR}  ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if theme directory already exists
if [[ -d "${THEME_DIR}" ]]; then
    print_warning "Theme directory already exists: ${THEME_DIR}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled."
        exit 0
    fi
    
    # Backup existing theme
    print_info "Backing up existing theme..."
    mkdir -p "${BACKUP_DIR}"
    cp -r "${THEME_DIR}" "${BACKUP_DIR}/${THEME_NAME}_${TIMESTAMP}"
    print_success "Backup saved to: ${BACKUP_DIR}/${THEME_NAME}_${TIMESTAMP}"
fi

# Create theme directory
print_info "Creating theme directory..."
mkdir -p "${THEME_DIR}"
mkdir -p "${THEME_DIR}/icons"

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Copy theme files
print_info "Copying theme files..."
cp "${SCRIPT_DIR}/theme.txt" "${THEME_DIR}/" 2>/dev/null || print_warning "theme.txt not found"
cp "${SCRIPT_DIR}/background.png" "${THEME_DIR}/" 2>/dev/null || print_warning "background.png not found"
cp "${SCRIPT_DIR}/logo.png" "${THEME_DIR}/" 2>/dev/null || print_warning "logo.png not found"
cp "${SCRIPT_DIR}"/*.pf2 "${THEME_DIR}/" 2>/dev/null || print_warning "No font files found"
cp "${SCRIPT_DIR}"/*.png "${THEME_DIR}/" 2>/dev/null || true

# Copy icons
if [[ -d "${SCRIPT_DIR}/icons" ]]; then
    print_info "Copying icon files..."
    cp "${SCRIPT_DIR}"/icons/*.png "${THEME_DIR}/icons/" 2>/dev/null || print_warning "No icons found"
else
    print_warning "Icons directory not found"
fi

# Set permissions
print_info "Setting file permissions..."
chmod -R 755 "${THEME_DIR}"

# Backup GRUB configuration
GRUB_CFG=$(detect_grub_cfg)
print_info "Backing up GRUB configuration: ${GRUB_CFG}"
mkdir -p "${BACKUP_DIR}"
cp "${GRUB_CFG}" "${BACKUP_DIR}/grub_${TIMESTAMP}.bak"
print_success "GRUB config backed up to: ${BACKUP_DIR}/grub_${TIMESTAMP}.bak"

# Update GRUB configuration
print_info "Updating GRUB configuration..."

# Remove existing GRUB_THEME line if present
sed -i '/^GRUB_THEME=/d' "${GRUB_CFG}"

# Add new GRUB_THEME line
echo "GRUB_THEME=\"${THEME_DIR}/theme.txt\"" >> "${GRUB_CFG}"

# Set recommended GRUB settings if not already set
if ! grep -q "^GRUB_GFXMODE=" "${GRUB_CFG}"; then
    print_info "Setting recommended graphics mode..."
    echo "GRUB_GFXMODE=1920x1080" >> "${GRUB_CFG}"
fi

if ! grep -q "^GRUB_GFXPAYLOAD_LINUX=" "${GRUB_CFG}"; then
    echo "GRUB_GFXPAYLOAD_LINUX=keep" >> "${GRUB_CFG}"
fi

print_success "GRUB configuration updated"

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
    exit 1
fi

# Installation complete
echo -e "\n${GREEN}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║          Installation Complete!                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_success "Hollow Knight theme installed successfully!"
print_info "Theme location: ${THEME_DIR}"
print_info "Backups saved to: ${BACKUP_DIR}"
echo ""
print_warning "Please reboot your system to see the new GRUB theme"
echo ""
print_info "To customize the theme, edit: ${THEME_DIR}/theme.txt"
print_info "To uninstall, run: sudo ./uninstall.sh"
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
