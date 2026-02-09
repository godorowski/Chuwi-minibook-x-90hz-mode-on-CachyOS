#!/usr/bin/env bash
#
# 90Hz Display Fix for Chuwi MiniBook X (N100/N150)
#
# This script installs a patched VBT (Video BIOS Table) firmware that forces
# the internal display to run at 90Hz instead of the default 60Hz.
#
# The patched VBT comes from: https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/11due
# (adjust URL to your actual source)
#
# What this script does:
#   1. Backs up the original VBT (if present) to /lib/firmware/vbt_original_backup.bin
#   2. Copies the patched VBT to /lib/firmware/vbt
#   3. Adds FILES=(/lib/firmware/vbt) to /etc/mkinitcpio.conf (if not already there)
#   4. Adds i915.vbt_firmware=vbt to the kernel cmdline in /etc/default/limine (if not already there)
#   5. Rebuilds initramfs for all installed kernels via limine-mkinitcpio
#
# Usage:
#   sudo ./install_90hz.sh
#
# A reboot is required after running this script.
#

set -euo pipefail

# --- Color helpers ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Pre-flight checks ---
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Try: sudo $0"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHED_VBT="$SCRIPT_DIR/vbt_patched.bin"

if [[ ! -f "$PATCHED_VBT" ]]; then
    error "Patched VBT file not found at $PATCHED_VBT — it should be next to this script."
fi

# --- Step 1: Backup original VBT ---
info "Step 1: Backing up original VBT..."
if [[ -f /lib/firmware/vbt ]]; then
    if [[ ! -f /lib/firmware/vbt_original_backup.bin ]]; then
        cp /lib/firmware/vbt /lib/firmware/vbt_original_backup.bin
        info "Original VBT backed up to /lib/firmware/vbt_original_backup.bin"
    else
        warn "Backup already exists at /lib/firmware/vbt_original_backup.bin — skipping backup."
    fi
else
    info "No existing VBT at /lib/firmware/vbt — nothing to back up."
fi

# --- Step 2: Install patched VBT ---
info "Step 2: Installing patched VBT to /lib/firmware/vbt..."
cp "$PATCHED_VBT" /lib/firmware/vbt
chmod 644 /lib/firmware/vbt
info "Patched VBT installed."

# --- Step 3: Update mkinitcpio.conf ---
info "Step 3: Updating /etc/mkinitcpio.conf..."
MKINITCPIO_CONF="/etc/mkinitcpio.conf"

if grep -q '/lib/firmware/vbt' "$MKINITCPIO_CONF"; then
    info "mkinitcpio.conf already references /lib/firmware/vbt — no changes needed."
else
    # Replace the FILES=() line or append to existing FILES=(...)
    if grep -qE '^FILES=\(\)' "$MKINITCPIO_CONF"; then
        sed -i 's|^FILES=()|FILES=(/lib/firmware/vbt)|' "$MKINITCPIO_CONF"
        info "Set FILES=(/lib/firmware/vbt) in mkinitcpio.conf."
    elif grep -qE '^FILES=\(' "$MKINITCPIO_CONF"; then
        # Append to existing FILES array (before the closing paren)
        sed -i 's|^FILES=(\(.*\))|FILES=(\1 /lib/firmware/vbt)|' "$MKINITCPIO_CONF"
        info "Appended /lib/firmware/vbt to existing FILES array in mkinitcpio.conf."
    else
        # No FILES line found at all, add one
        echo 'FILES=(/lib/firmware/vbt)' >> "$MKINITCPIO_CONF"
        info "Added FILES=(/lib/firmware/vbt) to mkinitcpio.conf."
    fi
fi

# --- Step 4: Update kernel cmdline (Limine bootloader) ---
info "Step 4: Updating kernel cmdline in /etc/default/limine..."
LIMINE_CONF="/etc/default/limine"

if [[ ! -f "$LIMINE_CONF" ]]; then
    error "/etc/default/limine not found. Is Limine your bootloader? If you use a different bootloader, add 'i915.vbt_firmware=vbt' to your kernel cmdline manually."
fi

if grep -q 'i915.vbt_firmware=vbt' "$LIMINE_CONF"; then
    info "Kernel cmdline already contains i915.vbt_firmware=vbt — no changes needed."
else
    if grep -qE '^KERNEL_CMDLINE\[default\]' "$LIMINE_CONF"; then
        # Append before the closing quote
        sed -i '/^KERNEL_CMDLINE\[default\]/s|"$| i915.vbt_firmware=vbt"|' "$LIMINE_CONF"
        info "Added i915.vbt_firmware=vbt to kernel cmdline."
    else
        error "Could not find KERNEL_CMDLINE[default] in $LIMINE_CONF. Please add 'i915.vbt_firmware=vbt' to your kernel cmdline manually."
    fi
fi

# --- Step 5: Rebuild initramfs ---
info "Step 5: Rebuilding initramfs for all kernels..."
if command -v limine-mkinitcpio &>/dev/null; then
    limine-mkinitcpio
    info "Initramfs rebuilt successfully."
elif command -v mkinitcpio &>/dev/null; then
    mkinitcpio -P
    info "Initramfs rebuilt successfully (via mkinitcpio -P)."
else
    error "Neither limine-mkinitcpio nor mkinitcpio found. Please rebuild your initramfs manually."
fi

# --- Done ---
echo ""
info "========================================="
info "  90Hz patch installed successfully!"
info "  Please reboot to apply the changes."
info "========================================="
echo ""
