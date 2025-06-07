#!/bin/bash

# Independent script for managing Sun Panel on FreeBSD servers (e.g., serv00)
# Extracted from https://github.com/Argh94/serv00-play
# Version: 1.3.0
# Date: June 7, 2025
# Removed dependency checking to match original script behavior

# Color definitions for output
RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Helper functions for colored output
yellow() {
  echo -e "${YELLOW}$1${RESET}"
}
green() {
  echo -e "${GREEN}$1${RESET}"
}
red() {
  echo -e "${RED}$1${RESET}"
}

# Installation path
installpath="$HOME"

# Check if a process is running
checkProcAlive() {
  local procname=$1
  if ps aux | grep "$procname" | grep -v "grep" >/dev/null; then
    return 0
  else
    return 1
  fi
}

# Stop a process
stopProc() {
  local procname=$1
  r=$(ps aux | grep "$procname" | grep -v "grep" | awk '{print $2}')
  if [ -z "$r" ]; then
    return 0
  else
    kill -9 $r
  fi
  green "Stopped $procname!"
}

# Install Sun Panel
installSunPanel() {
  green "Installing Sun Panel..."
  cd "${installpath}" || { red "Failed to change directory to $installpath!"; exit 1; }
  
  # Download Sun Panel binary
  if ! curl -sL -o sun-panel https://github.com/hslr-sun/panel/releases/latest/download/sun-panel_freebsd_amd64; then
    red "Failed to download Sun Panel binary!"
    exit 1
  fi
  
  # Set execution permissions
  chmod +x sun-panel
  
  # Create configuration directory
  mkdir -p "${installpath}/sun-panel/config"
  
  # Create default configuration file
  cat > "${installpath}/sun-panel/config/config.yaml" << EOF
server:
  port: 8080
  host: 0.0.0.0
EOF
  
  green "Sun Panel installed successfully!"
  green "Configuration file created at ${installpath}/sun-panel/config/config.yaml"
  green "You can modify the configuration file as needed."
}

# Start or restart Sun Panel
startSunPanel() {
  green "Starting Sun Panel..."
  
  if checkProcAlive "sun-panel"; then
    stopProc "sun-panel"
  fi
  
  # Start Sun Panel in the background
  cd "${installpath}" || { red "Failed to change directory to $installpath!"; exit 1; }
  if [ -f sun-panel ]; then
    nohup ./sun-panel --config "${installpath}/sun-panel/config/config.yaml" > sun-panel.log 2>&1 &
    sleep 2
    if checkProcAlive "sun-panel"; then
      green "Sun Panel started successfully!"
      green "Logs are available at ${installpath}/sun-panel.log"
    else
      red "Failed to start Sun Panel!"
      cat sun-panel.log
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
  
  if checkProcAlive "sun-panel"; then
    stopProc "sun-panel"
    green "Sun Panel stopped successfully!"
  else
    green "Sun Panel is not running."
  fi
}

# Uninstall Sun Panel
uninstallSunPanel() {
  red "Uninstalling Sun Panel..."
  
  # Stop Sun Panel if running
  if checkProcAlive "sun-panel"; then
    stopProc "sun-panel"
  fi
  
  # Remove Sun Panel files
  cd "${installpath}" || { red "Failed to change directory to $installpath!"; exit 1; }
  rm -rf sun-panel sun-panel.log sun-panel/
  green "Sun Panel uninstalled successfully!"
}

# Main menu for Sun Panel management
mainMenu() {
  while true; do
    yellow "-------------------------"
    echo "Sun Panel Management"
    echo "1. Install Sun Panel"
    echo "2. Start/Restart Sun Panel"
    echo "3. Stop Sun Panel"
    echo "4. Uninstall Sun Panel"
    echo "0. Exit"
    yellow "-------------------------"
    read -p "Please select an option: " choice
    case $choice in
      1) installSunPanel ;;
      2) startSunPanel ;;
      3) stopSunPanel ;;
      4) uninstallSunPanel ;;
      0) exit 0 ;;
      *) red "Invalid option, please try again." ;;
    esac
  done
}

# Start the main menu directly
mainMenu
