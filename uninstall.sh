#!/usr/bin/env bash
set -e

# ==============================================================
#  Inha / IUT Wi-Fi Auto-Login Uninstaller for macOS
# ==============================================================

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BOLD}Uninstalling Inha / IUT Wi-Fi Auto-Login...${RESET}"

PLIST_FILE="$HOME/Library/LaunchAgents/uz.inha.wifi-autologin.plist"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/inha-wifi"

# 1. Stop background service
if [[ -f "$PLIST_FILE" ]]; then
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    rm -f "$PLIST_FILE"
    echo -e "${GREEN}✅ Removed background LaunchAgent service${RESET}"
fi

# 2. Remove binaries
rm -f "$BIN_DIR/inha-wifi" "$BIN_DIR/iut-wifi"
echo -e "${GREEN}✅ Removed inha-wifi and iut-wifi binaries${RESET}"

# 3. Remove completions
rm -f "$HOME/.oh-my-zsh/custom/completions/_inha-wifi" "$HOME/.oh-my-zsh/custom/completions/_iut-wifi" 2>/dev/null || true

# 4. Prompt to remove credentials and logs
if [[ -d "$CONFIG_DIR" ]]; then
    read -p "Do you want to delete your credentials and logs ($CONFIG_DIR)? (y/N): " DEL_CFG
    if [[ "$DEL_CFG" =~ ^[Yy] ]]; then
        rm -rf "$CONFIG_DIR"
        echo -e "${GREEN}✅ Removed $CONFIG_DIR${RESET}"
    else
        echo -e "${YELLOW}ℹ️  Preserved configuration at $CONFIG_DIR${RESET}"
    fi
fi

echo ""
echo -e "${BOLD}${GREEN}Uninstallation complete.${RESET}"
