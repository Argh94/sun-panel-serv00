#!/bin/bash

# Independent script for managing Sun Panel on FreeBSD servers (e.g., serv00)
# Extracted from https://github.com/frankiejun/serv00-play
# Version: 1.7.0
# Date: June 7, 2025
# Mimics original start.sh behavior with port prompt and credential display

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
installpath="$HOME"

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
  
  cd "$installpath" || { red "Failed to access home directory!"; exit 1; }
  
  # Remove any existing files
  rm -f sun-panel panelweb
  
  # Download sun-panel binary
  green "Downloading sun-panel..."
  if ! curl -sL -o sun-panel https://github.com/hslr-s/sun-panel/releases/latest/download/sun-panel_freebsd_amd64; then
    red "Failed to download sun-panel binary! Check your internet connection."
    exit 1
  fi
  if [ ! -f sun-panel ] || [ $(stat -f %z sun-panel) -lt 1000000 ]; then
    red "Downloaded sun-panel binary is invalid or too small!"
    rm -f sun-panel
    exit 1
  fi
  green "Download completed!"
  
  # Download panelweb
  green "Downloading panelweb..."
  if ! curl -sL -o panelweb https://github.com/hslr-s/sun-panel/releases/latest/download/panelweb; then
    red "Failed to download panelweb! Check your internet connection."
    exit 1
  fi
  if [ ! -f panelweb ] || [ $(stat -f %z panelweb) -lt 100000 ]; then
    red "Downloaded panelweb is invalid or too small!"
    rm -f panelweb
    exit 1
  fi
  green "Download completed!"
  
  chmod +x sun-panel
  
  # Create configuration directory
  mkdir -p "$installpath/conf" || { red "Failed to create configuration directory!"; exit 1; }
  
  # Prompt for TCP port
  yellow "Enter a TCP port for Sun Panel (e.g., 8080): "
  read -r port </dev/tty
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
    red "Invalid port! Please enter a number between 1024 and 65535."
    exit 1
  fi
  
  # Create configuration file
  cat > "$installpath/conf/conf.ini" << EOF
[server]
port = $port
host = 0.0.0.0
EOF
  
  # Display default credentials
  green "Sun Panel installed successfully!"
  green "Configuration file: $installpath/conf/conf.ini"
  yellow "Default account information:"
  yellow "Username: admin@sun.cc"
  yellow "Password: 12345678"
  yellow "Access Sun Panel at: http://$(hostname):$port"
  green "Run 'Start/Restart Sun Panel' to activate."
}

# Start or restart Sun Panel
startSunPanel() {
  green "Starting Sun Panel..."
  
  checkProcAlive "sun-panel" && stopProc "sun-panel"
  
  cd "$installpath" || { red "Failed to access home directory!"; exit 1; }
  if [ -f sun-panel ] && [ -f conf/conf.ini ]; then
    nohup ./sun-panel > "$installpath/sun-panel.log" 2>&1 &
    sleep 3
    if checkProcAlive "sun-panel"; then
      green "Sun Panel started successfully!"
      green "Logs: $installpath/sun-panel.log"
      yellow "Access Sun Panel at: http://$(hostname):$(grep port conf/conf.ini | cut -d'=' -f2 | tr -d ' ')"
      yellow "Username: admin@sun.cc"
      yellow "Password: 12345678"
    else
      red "Failed to start Sun Panel!"
      cat "$installpath/sun-panel.log"
      exit 1
    fi
  else
    red "Sun Panel binary or configuration file not found! Please install first."
    exit 1
  fi
}

# Stop Sun Panel
stopSunPanel() {
  green "Stopping Sun Panel..."
  checkProcAlive "sun-panel" && stopProc "sun-panel" || green "Sun Panel is not running."
}

# Reset Password
resetPassword() {
  green "Resetting Sun Panel password..."
  
  cd "$installpath" || { red "Failed to access home directory!"; exit 1; }
  if [ -f sun-panel ]; then
    ./sun-panel --reset-password > "$installpath/reset-password.log" 2>&1
    green "Password reset successfully!"
    yellow "Username: admin@sun.cc"
    yellow "Password: 12345678"
    green "Details in: $installpath/reset-password.log"
  else
    red "Sun Panel binary not found! Please install first."
    exit 1
  fi
}

# Uninstall Sun Panel
uninstallSunPanel() {
  red "Uninstalling Sun Panel..."
  checkProcAlive "sun-panel" && stopProc "sun-panel"
  cd "$installpath" || { red "Failed to access home directory!"; exit 1; }
  rm -f sun-panel panelweb sun-panel.log reset-password.log
  rm -rf "$installpath/conf"
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
    echo "4. Reset Password"
    echo "8. Uninstall Sun Panel"
    echo "0. Exit"
    yellow "-------------------------"
    echo -n "Select an option (0-4, 8): "
    read -r choice </dev/tty
    case $choice in
      1) installSunPanel ;;
      2) startSunPanel ;;
      3) stopSunPanel ;;
      4) resetPassword ;;
      8) uninstallSunPanel ;;
      0) exit 0 ;;
      *) red "Invalid option, please try again." ;;
    esac
    echo -n "Press Enter to continue..."
    read -r </dev/tty
  done
}

mainMenu
