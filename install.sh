#!/usr/bin/env bash
set -e

# ==============================================================
#  Inha / IUT Wi-Fi Auto-Login & Keep-Alive Installer for macOS
# ==============================================================

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BOLD}${CYAN}====================================================${RESET}"
echo -e "${BOLD}${CYAN}   INHA / IUT WI-FI AUTO-LOGIN INSTALLER (macOS)     ${RESET}"
echo -e "${BOLD}${CYAN}====================================================${RESET}"

# 1. OS check
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}❌ Error: This tool is designed for macOS (uses macOS networksetup & launchd).${RESET}"
    exit 1
fi

# 2. Python check
PYTHON_BIN="/usr/bin/python3"
if ! command -v "$PYTHON_BIN" &>/dev/null; then
    PYTHON_BIN="$(which python3 || true)"
fi

if [[ -z "$PYTHON_BIN" ]]; then
    echo -e "${RED}❌ Error: Python 3 not found. Please install Xcode Command Line Tools ('xcode-select --install').${RESET}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/inha-wifi"
CONFIG_FILE="$CONFIG_DIR/config.json"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$LAUNCH_AGENTS_DIR/uz.inha.wifi-autologin.plist"

mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$LAUNCH_AGENTS_DIR"

# 3. Credentials Configuration
if [[ -f "$CONFIG_FILE" ]]; then
    EXISTING_USER="$(python3 -c "import json; cfg=json.load(open('$CONFIG_FILE')); print(cfg.get('username',''))" 2>/dev/null || true)"
    if [[ -n "$EXISTING_USER" ]]; then
        echo -e "${YELLOW}ℹ️  Existing configuration found for student ID: ${BOLD}$EXISTING_USER${RESET}"
        read -p "Do you want to keep this configuration? (Y/n): " KEEP_CFG
        KEEP_CFG=${KEEP_CFG:-Y}
        if [[ "$KEEP_CFG" =~ ^[Nn] ]]; then
            rm -f "$CONFIG_FILE"
        fi
    fi
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo ""
    echo -e "${BOLD}Please enter your Inha / IUT Wi-Fi credentials:${RESET}"
    read -p "Student ID (e.g. U2610...): " USERNAME
    while [[ -z "$USERNAME" ]]; do
        read -p "Student ID cannot be empty: " USERNAME
    done

    read -s -p "Wi-Fi Password: " PASSWORD
    echo ""
    while [[ -z "$PASSWORD" ]]; do
        read -s -p "Password cannot be empty: " PASSWORD
        echo ""
    done

    cat > "$CONFIG_FILE" <<EOF
{
  "username": "$USERNAME",
  "password": "$PASSWORD",
  "check_interval_seconds": 30,
  "keepalive_interval_seconds": 60,
  "wifi_interface": "en0",
  "preferred_ssids": ["Inha", "IUT"],
  "show_notifications": true
}
EOF
    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}✅ Credentials safely stored in $CONFIG_FILE (chmod 600)${RESET}"
fi

# 4. Install Executable
cp "$SCRIPT_DIR/bin/inha-wifi" "$BIN_DIR/inha-wifi"
chmod +x "$BIN_DIR/inha-wifi"
ln -sf "$BIN_DIR/inha-wifi" "$BIN_DIR/iut-wifi"
echo -e "${GREEN}✅ Installed binary to $BIN_DIR/inha-wifi and symlinked $BIN_DIR/iut-wifi${RESET}"

# 5. Ensure PATH includes ~/.local/bin
SHELL_RC=""
if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
    SHELL_RC="$HOME/.bash_profile"
elif [[ -f "$HOME/.bashrc" ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -q '\.local/bin' "$SHELL_RC"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
        echo -e "${GREEN}✅ Added ~/.local/bin to PATH in $SHELL_RC${RESET}"
    fi

    # 6. Install ZSH Autocomplete
    if [[ "$SHELL" =~ "zsh" ]] || [[ "$SHELL_RC" == *".zshrc"* ]]; then
        if [[ -d "$HOME/.oh-my-zsh" ]]; then
            mkdir -p "$HOME/.oh-my-zsh/custom/completions"
            cp "$SCRIPT_DIR/completions/_inha-wifi" "$HOME/.oh-my-zsh/custom/completions/_inha-wifi"
            ln -sf _inha-wifi "$HOME/.oh-my-zsh/custom/completions/_iut-wifi" 2>/dev/null || true
        fi

        if ! grep -q '_inha_wifi_completion' "$SHELL_RC"; then
            cat >> "$SHELL_RC" <<'EOF'

# Inha / IUT Wi-Fi command autocomplete
_inha_wifi_completion() {
    local -a commands
    commands=(
        'status:Show current Wi-Fi, authentication, and daemon status'
        'login:Force immediate login check and authentication'
        'logout:Log out of the captive portal (useful for testing)'
        'start:Install and start background auto-login daemon'
        'stop:Stop the background daemon'
        'restart:Restart the background daemon'
        'logs:View real-time daemon logs (tail -f)'
        'config:View or update credentials (~/.config/inha-wifi/config.json)'
    )
    _describe -t commands 'command' commands
}
compdef _inha_wifi_completion inha-wifi iut-wifi 2>/dev/null
EOF
            echo -e "${GREEN}✅ Installed Zsh command autocompletion in $SHELL_RC${RESET}"
        fi
    fi
fi

# 7. Start the background LaunchAgent daemon
echo -e "${CYAN}🚀 Starting background autologin service...${RESET}"
"$BIN_DIR/inha-wifi" start

echo ""
echo -e "${BOLD}${GREEN}🎉 Installation Complete!${RESET}"
echo -e "You can now use ${BOLD}inha-wifi${RESET} or ${BOLD}iut-wifi${RESET} from anywhere."
echo ""
"$BIN_DIR/inha-wifi" status
