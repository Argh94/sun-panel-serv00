#!/bin/bash

# Independent script for managing Sun Panel on FreeBSD servers (e.g., serv00)
# Extracted from https://github.com/Argh94/serv00-play
# Version: 1.5.0
# Date: June 7, 2025
# Simplified for reliable execution and file conflict handling

# Color definitions for output
RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Helper functions for colored output
yellow() { echo -e "${YELLOW}$1${RESET}"; }
green() { echo -e "${GREEN}$1${RESET}"; }
red() { echo -e "${RED}$1${RESET}"; }

# Installation path
installpath="$HOME/sunpanel"  # Changed to avoid conflict with binary

# Check if a process is running
checkProcAlive() {
  local procname=$1
  ps aux | grep "$procname" | grep -v "grep" >/dev/null && return 0 || return 1
}

# Stop a process
stopProc() {
  local procname=$1
  local pid
  pid=$(ps aux | grep "$procname" | grep -v "grep" | awk '{print $2}')
  [ -n "$pid" ] && kill -9 "$pid" && green "Stopped $procname!" || return 0
}

# Install Sun Panel
installSunPanel() {
  green "Installing Sun Panel..."
  
  cd "$HOME" || { red "Failed to access home directory!"; exit 1; }
  
  # Download Sun Panel binary
  if ! curl -sL -o sun-panel https://github.com/hslr-sun/panel/releases/latest/download/sun-panel_freebsd_amd64; then
    red "Failed to download Sun Panel binary! Check your internet connection."
    exit 1
  fi
  
  chmod +x sun-panel
  
  # Create configuration directory
  if [ -e "$installpath" ] && [ ! -d "$installpath" ]; then
    red "Error: A file named 'sunpanel' exists at $installpath. Please remove or rename it (e.g., 'mv $installpath $installpath.bak')."
    exit 1
  fi
  mkdir -p "$installpath/config" || { red "Failed to create configuration directory!"; exit 1; }
  
  # Create configuration file
  cat > "$installpath/config/config.yaml" << EOF
server:
  port: 8080
  host: 0.0.0.0
EOF
  
  green "Sun Panel installed successfully!"
  green "Binary: $HOME/sun-panel"
  green "Config: $installpath/config/config.yaml"
}

# Start or restart Sun Panel
startSunPanel() {
  green "Starting Sun Panel..."
  
  checkProcAlive "sun-panel" && stopProc "sun-panel"
  
  cd "$HOME" || { red "Failed to access home directory!"; exit 1; }
  if [ -f sun-panel ]; then
    nohup ./sun-panel --config "$installpath/config/config.yaml" > "$installpath/sun-panel.log" 2>&1 &
    sleep 2
    if checkProcAlive "sun-panel"; then
      green "Sun Panel started successfully!"
      green "Logs: $installpath/sun-panel.log"
    else
      red "Failed to start Sun Panel!"
      cat "$installpath/sun-panel.log"
      exit 1
    fi
  else
    red "Sun Panel binary not found! Please install it first."
    exit 1
  fi
}

# Stop Sun Panel
stopSunPanel() {
  green "Stopping Sun Panel..."
  checkProcAlive "sun-panel" && stopProc "sun-panel" || green "Sun Panel is not running."
}

# Uninstall Sun Panel
uninstallSunPanel() {
  red "Uninstalling Sun Panel..."
  checkProcAlive "sun-panel" && stopProc "sun-panel"
  cd "$HOME" || { red "Failed to access home directory!"; exit 1; }
  rm -f sun-panel
  rm -rf "$installpath"
  green "Sun Panel uninstalled successfully!"
}

# Main menu
mainMenu() {
  while true; do
    clear
    yellow "-------------------------"
    echo "Sun Panel Management"
    echo "1. Install Sun Panel"
    echo "2. Start/Restart Sun Panel"
    echo "3. Stop Sun Panel"
    echo "4. Uninstall Sun Panel"
    echo "0. Exit"
    yellow "-------------------------"
    echo -n "Select an option (0-4): "
    read -r choice </dev/tty
    case $choice in
      1) installSunPanel ;;
      2) startSunPanel ;;
      3) stopSunPanel ;;
      4) uninstallSunPanel ;;
      0) exit 0 ;;
      *) red "Invalid option, please try again." ;;
    esac
    echo -n "Press Enter to continue..."
    read -r </dev/tty
  done
}

mainMenu
