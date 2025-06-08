#!/bin/bash

RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;33m'
RESET='\033[0m'

yellow() { echo -e "${YELLOW}$1${RESET}"; }
green() { echo -e "${GREEN}$1${RESET}"; }
red() { echo -e "${RED}$1${RESET}"; }

installpath="$HOME"
workdir="$installpath/serv00-play/sunpanel"
configdir="$workdir/conf"
configfile="$configdir/conf.ini"

checkProcAlive() {
  ps aux | grep "$1" | grep -v "grep" >/dev/null && return 0 || return 1
}

stopProc() {
  local pids=$(ps aux | grep "$1" | grep -v grep | awk '{print $2}')
  if [ -n "$pids" ]; then
    for pid in $pids; do
      kill -9 "$pid" && green "Stopped $1 (PID: $pid)!"
    done
  else
    green "$1 is not running."
  fi
}

checkDownload() {
  local file=$1
  local is_dir=${2:-0}
  local filegz="$file.gz"
  if [ $is_dir -eq 1 ]; then
    filegz="$file.tar.gz"
  fi
  green "Downloading $file..."
  local url="https://gfg.fkj.pp.ua/app/serv00/$filegz?pwd=fkjyyds666"
  if ! curl -L -sS --max-time 20 -o "$filegz" "$url"; then
    red "Failed to download $file! Check network or URL."
    return 1
  fi
  if file "$filegz" | grep -q "text"; then
    red "Invalid download for $file!"
    rm -f "$filegz"
    return 1
  fi
  if [ $is_dir -eq 1 ]; then
    tar -zxf "$filegz" || { red "Failed to decompress $filegz!"; rm -f "$filegz"; return 1; }
  else
    gzip -d "$filegz" || { red "Failed to decompress $filegz!"; rm -f "$filegz"; return 1; }
  fi
  if [ $is_dir -eq 0 ] && [ ! -e "$file" ]; then
    red "Failed to extract $file!"
    return 1
  fi
  [ $is_dir -eq 0 ] && chmod +x "$file"
  green "Download $file completed!"
  return 0
}

get_webip() {
  local hostname=$(hostname)
  local host_number=$(echo "$hostname" | awk -F'[s.]' '{print $2}')
  local hosts=("web${host_number}.serv00.com" "cache${host_number}.serv00.com")
  local final_ip=""
  for host in "${hosts[@]}"; do
    local response=$(curl -s "https://ss.botai.us.kg/api/getip?host=$host")
    if [[ "$response" =~ "not found" ]]; then
      continue
    fi
    local ip=$(echo "$response" | awk -F "|" '{ if ($2 == "Accessible") print $1 }')
    if [ -n "$ip" ]; then
      echo "$ip"
      return
    fi
    if [[ "$host" == "web${host_number}.serv00.com" ]]; then
      final_ip=$(echo "$response" | awk -F "|" '{print $1}')
    fi
  done
  echo "$final_ip"
}

makeWWW() {
  local port=$1
  local user=$(whoami)
  local domain="panel.$user.serv00.net"
  local webIp=$(get_webip)
  yellow "Using webIp: $webIp, domain: $domain"
  if ! devil www add "$domain" proxy localhost "$port"; then
    red "Failed to bind domain $domain!"
    return 1
  fi
  cat > "$workdir/config.json" <<EOF
{
  "webip": "$webIp",
  "domain": "$domain",
  "port": "$port"
}
EOF
  green "Domain binding successful: $domain"
  return 0
}

installSunPanel() {
  green "Installing Sun Panel..."
  mkdir -p "$workdir" "$configdir" || { red "Failed to create directories!"; exit 1; }
  cd "$workdir" || { red "Failed to access $workdir!"; exit 1; }
  rm -f sun-panel panelweb sun-panel.gz panelweb.gz
  if ! checkDownload "sun-panel"; then
    exit 1
  fi
  if ! checkDownload "panelweb" 1; then
    exit 1
  fi
  if [ ! -e "sun-panel" ]; then
    red "Failed to extract sun-panel!"
    exit 1
  fi
  ./sun-panel -password-reset || { red "Failed to reset password!"; exit 1; }
  if [ ! -e "$configfile" ]; then
    red "Config file not generated!"
    exit 1
  fi
  yellow "Enter TCP port (e.g., 17323): "
  read -r port </dev/tty
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
    red "Invalid port! Use 1024-65535."
    exit 1
  fi
  if ! devil port add tcp "$port"; then
    red "Failed to add port $port!"
    exit 1
  fi
  cd "$configdir" || { red "Failed to access $configdir!"; exit 1; }
  sed -i.bak -E "s/^http_port=[0-9]+$/http_port=$port/" conf.ini || { red "Failed to update config!"; exit 1; }
  cd "$workdir" || { red "Failed to access $workdir!"; exit 1; }
  if ! makeWWW "$port"; then
    exit 1
  fi
  green "Sun Panel installed!"
  yellow "Username: admin@sun.cc"
  yellow "Password: 12345678"
  yellow "Access: http://$domain:$port"
}

startSunPanel() {
  green "Starting Sun Panel..."
  cd "$workdir" || { red "Failed to access $workdir!"; exit 1; }
  [ -f sun-panel ] && [ -f "$configfile" ] || { red "Sun Panel or config not found!"; exit 1; }
  checkProcAlive "sun-panel" && stopProc "sun-panel"
  yellow "Need logs ($workdir/running.log)? [y/n] [n]: "
  read -r input </dev/tty
  input=${input:-n}
  local args=""
  if [ "$input" = "y" ]; then
    args=" > running.log 2>&1"
  else
    args=" > /dev/null 2>&1"
  fi
  nohup ./sun-panel $args &
  sleep 2
  if checkProcAlive "sun-panel"; then
    green "Sun Panel started!"
    yellow "Access: http://$(hostname):$(grep "http_port=" "$configfile" | cut -d'=' -f2 | tr -d ' ')"
  else
    red "Failed to start! Check logs:"
    cat "$workdir/running.log"
    exit 1
  fi
}

command -v curl >/dev/null || { red "Install curl with 'pkg install curl'."; exit 1; }
command -v stat >/dev/null || { red "Install stat with 'pkg install coreutils'."; exit 1; }
command -v gunzip >/dev/null || { red "Install gunzip with 'pkg install gzip'."; exit 1; }
command -v devil >/dev/null || { red "Devil command not found! Ensure serv00 environment."; exit 1; }

[ -d "$workdir" ] && [ -f "$configfile" ] && startSunPanel || { installSunPanel; startSunPanel; }
