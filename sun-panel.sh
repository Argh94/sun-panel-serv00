#!/bin/bash

RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;33m'
RESET='\033[0m'

yellow() { echo -e "${YELLOW}$1${RESET}"; }
green() { echo -e "${GREEN}$1${RESET}"; }
red() { echo -e "${RED}$1${RESET}"; }

workdir="$HOME/serv00-play/sun-panel"
configdir="$workdir/conf"
configfile="$configdir/conf.ini"

checkProcAlive() { ps aux | grep "$1" | grep -v "grep" >/dev/null && return 0 || return 1; }
stopProc() {
  local pids=$(ps aux | grep "$1" | grep -v grep | awk '{print $2}')
  [ -n "$pids" ] && for pid in $pids; do kill -9 "$pid" && green "Stopped $1 (PID: $pid)!"; done || green "$1 is not running."
}

checkDownload() {
  local file=$1 url=$2 min_size=$3
  green "Downloading $file..."
  if ! curl -sL -o "$file" "$url" --connect-timeout 10; then
    red "Failed to download $file! Check network or URL."
    return 1
  fi
  local size=$(stat -f %z "$file" 2>/dev/null || stat -c %s "$file" 2>/dev/null)
  if [ ! -f "$file" ] || [ "$size" -lt "$min_size" ]; then
    red "Downloaded $file is too small (Size: $size bytes, Expected: >=$min_size bytes)!"
    [ -f "$file" ] && { cat "$file"; rm -f "$file"; }
    return 1
  fi
  green "Download $file completed! (Size: $size bytes)"
}

installSunPanel() {
  green "Installing Sun Panel..."
  mkdir -p "$workdir" "$configdir" || { red "Failed to create directories!"; exit 1; }
  cd "$workdir" || { red "Failed to access $workdir!"; exit 1; }
  rm -f sun-panel panelweb

  local os=$(uname -s | tr '[:upper:]' '[:lower:]')
  local binary_url
  if [ "$os" = "freebsd" ]; then
    binary_url="https://github.com/hslr-s/sun-panel/releases/download/v1.3.0/sun-panel_freebsd_amd64"
  elif [ "$os" = "linux" ]; then
    binary_url="https://github.com/hslr-s/sun-panel/releases/download/v1.3.0/sun-panel_linux_amd64"
  else
    red "Unsupported OS: $os. Use FreeBSD or Linux."
    exit 1
  fi

  checkDownload "sun-panel" "$binary_url" 500000 || exit 1
  chmod +x sun-panel
  checkDownload "panelweb" "https://github.com/hslr-s/sun-panel/releases/download/v1.3.0/panelweb" 50000 || exit 1

  yellow "Enter TCP port (e.g., 3000): "
  read -r port </dev/tty
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
    red "Invalid port! Use 1024-65535."
    exit 1
  fi

  cat > "$configfile" << EOF
[server]
port = $port
host = 0.0.0.0
[admin]
username = admin@sun.cc
password = 12345678
EOF
  green "Sun Panel installed!"
  yellow "Username: admin@sun.cc"
  yellow "Password: 12345678"
  yellow "Access: http://$(hostname):$port"
}

startSunPanel() {
  green "Starting Sun Panel..."
  cd "$workdir" || { red "Failed to access $workdir!"; exit 1; }
  [ -f sun-panel ] && [ -f "$configfile" ] || { red "Sun Panel or config not found!"; exit 1; }
  checkProcAlive "sun-panel" && stopProc "sun-panel"
  port=$(grep "port=" "$configfile" | cut -d'=' -f2 | tr -d ' ')
  nohup ./sun-panel --port="$port" > "$workdir/sun-panel.log" 2>&1 &
  sleep 3
  if checkProcAlive "sun-panel"; then
    green "Sun Panel started!"
    yellow "Access: http://$(hostname):$port"
  else
    red "Failed to start! Check logs:"
    cat "$workdir/sun-panel.log"
    exit 1
  fi
}

command -v curl >/dev/null || { red "Install curl with 'pkg install curl'."; exit 1; }
command -v stat >/dev/null || { red "Install stat with 'pkg install coreutils'."; exit 1; }

[ -d "$workdir" ] && [ -f "$configfile" ] && startSunPanel || { installSunPanel; startSunPanel; }
