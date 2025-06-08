#!/bin/bash

# تعریف رنگ‌ها برای خروجی
RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# توابع برای نمایش پیام‌ها
yellow() { echo -e "${YELLOW}$1${RESET}"; }
green() { echo -e "${GREEN}$1${RESET}"; }
red() { echo -e "${RED}$1${RESET}"; }

# مسیر نصب
installpath="$HOME"
workdir="$installpath/serv00-play/sun-panel"
configdir="$workdir/conf"
configfile="$configdir/conf.ini"

# تابع بررسی فرآیند فعال
checkProcAlive() {
  ps aux | grep "$1" | grep -v "grep" >/dev/null && return 0 || return 1
}

# تابع توقف فرآیند
stopProc() {
  local procname=$1
  local pids
  pids=$(ps aux | grep "$procname" | grep -v grep | awk '{print $2}')
  if [ -n "$pids" ]; then
    for pid in $pids; do
      kill -9 "$pid" && green "Stopped $procname (PID: $pid)!" || red "Failed to stop $procname (PID: $pid)!"
    done
  else
    green "$procname is not running."
  fi
}

# تابع دانلود فایل
checkDownload() {
  local file=$1
  local url=$2
  local min_size=$3
  green "Downloading $file..."
  if ! curl -sL -o "$file" "$url"; then
    red "Failed to download $file! Check your internet connection."
    return 1
  fi
  if [ ! -f "$file" ] || [ $(stat -f %z "$file") -lt "$min_size" ]; then
    red "Downloaded $file is invalid or too small!"
    rm -f "$file"
    return 1
  fi
  green "Download $file completed!"
  return 0
}

# تابع نصب sun-panel
installSunPanel() {
  green "Installing Sun Panel..."
  mkdir -p "$workdir" "$configdir" || { red "Failed to create directories!"; exit 1; }
  cd "$workdir" || { red "Failed to access directory $workdir!"; exit 1; }

  # حذف فایل‌های قبلی
  rm -f sun-panel panelweb

  # دانلود sun-panel
  checkDownload "sun-panel" "https://github.com/hslr-s/sun-panel/releases/latest/download/sun-panel_freebsd_amd64" 1000000
  if [ $? -ne 0 ]; then
    red "Installation failed due to sun-panel download error!"
    exit 1
  fi
  chmod +x sun-panel

  # دانلود panelweb
  checkDownload "panelweb" "https://github.com/hslr-s/sun-panel/releases/latest/download/panelweb" 100000
  if [ $? -ne 0 ]; then
    red "Installation failed due to panelweb download error!"
    exit 1
  fi

  # درخواست پورت
  yellow "Enter a TCP port for Sun Panel (e.g., 3000): "
  read -r port </dev/tty
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
    red "Invalid port! Please enter a number between 1024 and 65535."
    exit 1
  fi

  # ایجاد فایل پیکربندی
  cat > "$configfile" << EOF
[server]
port = $port
host = 0.0.0.0
[admin]
username = admin@sun.cc
password = 12345678
EOF
  green "Sun Panel installed successfully!"
  green "Configuration file: $configfile"
  yellow "Default account information:"
  yellow "Username: admin@sun.cc"
  yellow "Password: 12345678"
  yellow "Access Sun Panel at: http://$(hostname):$port"
  green "Run 'Start/Restart Sun Panel' to activate."
}

# تابع راه‌اندازی sun-panel
startSunPanel() {
  green "Starting Sun Panel..."
  cd "$workdir" || { red "Failed to access directory $workdir!"; exit 1; }
  if [ -f sun-panel ] && [ -f "$configfile" ]; then
    checkProcAlive "sun-panel" && stopProc "sun-panel"
    port=$(grep "port=" "$configfile" | cut -d'=' -f2 | tr -d ' ')
    nohup ./sun-panel --port="$port" > "$workdir/sun-panel.log" 2>&1 &
    sleep 3
    if checkProcAlive "sun-panel"; then
      green "Sun Panel started successfully!"
      green "Logs: $workdir/sun-panel.log"
      yellow "Access Sun Panel at: http://$(hostname):$port"
      yellow "Username: admin@sun.cc"
      yellow "Password: 12345678"
    else
      red "Failed to start Sun Panel!"
      cat "$workdir/sun-panel.log"
      exit 1
    fi
  else
    red "Sun Panel binary or configuration file not found! Please install first."
    exit 1
  fi
}

# تابع توقف sun-panel
stopSunPanel() {
  green "Stopping Sun Panel..."
  checkProcAlive "sun-panel" && stopProc "sun-panel" || green "Sun Panel is not running."
}

# تابع ریست رمز عبور
resetPassword() {
  green "Resetting Sun Panel password..."
  cd "$workdir" || { red "Failed to access directory $workdir!"; exit 1; }
  if [ -f sun-panel ]; then
    ./sun-panel --reset-password > "$workdir/reset-password.log" 2>&1
    green "Password reset successfully!"
    yellow "Username: admin@sun.cc"
    yellow "Password: 12345678"
    green "Details in: $workdir/reset-password.log"
  else
    red "Sun Panel binary not found! Please install first."
    exit 1
  fi
}

# تابع حذف sun-panel
uninstallSunPanel() {
  red "Uninstalling Sun Panel..."
  checkProcAlive "sun-panel" && stopProc "sun-panel"
  cd "$workdir" || { red "Failed to access directory $workdir!"; exit 1; }
  rm -f sun-panel panelweb sun-panel.log reset-password.log
  rm -rf "$configdir"
  green "Sun Panel uninstalled successfully!"
}

# منوی اصلی
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

# بررسی وابستگی‌ها
command -v curl >/dev/null 2>&1 || { red "curl is not installed! Install it with 'pkg_install curl'."; exit 1; }
command -v stat >/dev/null 2>&1 || { red "stat is not installed! Install it with 'pkg_install coreutils'."; exit 1; }

mainMenu
