#!/bin/bash
## General helper functions for zsh

# -------------------------------------------------------------------
# display a neatly formatted path
# -------------------------------------------------------------------
path() {
  echo $PATH | tr ":" "\n" | \
    awk "{ sub(\"/usr\",   \"$fg_no_bold[green]/usr$reset_color\");
           sub(\"/bin\",   \"$fg_no_bold[blue]/bin$reset_color\");
           sub(\"/opt\",   \"$fg_no_bold[cyan]/opt$reset_color\");
           sub(\"/sbin\",  \"$fg_no_bold[magenta]/sbin$reset_color\");
           sub(\"/local\", \"$fg_no_bold[yellow]/local$reset_color\");
           print }"
}


power_on_hours() {
  # Read Power_On_Hours for all /dev/sd? devices, convert to years, and print both values
    for dev in /dev/sd?; do
        hours=$(smartctl -a -d sat "$dev" | awk '/Power_On_Hours/ {print $NF}')
        if [[ -n "$hours" && "$hours" =~ ^[0-9]+$ ]]; then
            years=$(awk "BEGIN {printf \"%.2f\", $hours/24/365}")
            echo "$dev: $hours Stunden ≈ $years Jahre"
        else
            echo "$dev: Value not available"
        fi
    done
}


# Outputs the current epoch time or converts argument to human-readable date and time
epoch() {
  if [ $# -eq 0 ]; then
    date +%s
  else
    date -d @"$@" -R
  fi
}


# Epoch to date (automatic Linux/macOS handling)
epoch2date() {
  if date -d @0 +%F >/dev/null 2>&1; then
    date -d "@$1"
  else
    date -r "$1"
  fi
}

# Aktuelles Datum zu Epoch
date2epoch() {
  date +%s
}


# Create a new directory and enter it
mkd() {
        mkdir -p "$@"
        cd "$@" || exit
}



# Very often changing to a directory is followed by the ls command to list its contents.
# Therefore it is helpful to have a second function doing both at once.
# In this example we will name it cl (change list) and show an error message if the specified directory does not exist.
cl() {
        local dir="$1"
        local dir="${dir:=$HOME}"
        if [[ -d "$dir" ]]; then
                cd "$dir" >/dev/null; ls -lah
        else
                echo "bash: cl: $dir: Directory not found"
        fi
}


# List folders sorted by size, showing the largest first.
# A helper where to start cleaning when the disk is full.
# Use it with the syntax whatsize directory or just whatsize to list the / directory sizes.
whatsize(){
    du -h -x -P -t 1 -d 1 --exclude=/{proc,sys,dev,run} --exclude='*/#snapshot' --exclude='#snapshot' ${1:-/} 2>/dev/null | sort -hr
}


# Restart all running services except ssh, dbus, systemd-logind
service-restart-all() {
    systemctl list-units --type=service --state=running --no-legend \
    | awk '{print $1}' \
    | grep -Ev '^(ssh|dbus|systemd-logind)\.service$' \
    | xargs systemctl restart
}

# List all running services
service-list-running() {
    systemctl list-units --type=service --state=running
}

# Internal usage printer to keep help output consistent.
_general_usage() {
  echo "Usage: $1"
  if [[ -n "$2" ]]; then
    echo "$2"
  fi
}

# Show resolved command type/path for troubleshooting shell resolution.
extractpath() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    _general_usage "extractpath <command_name>" "Shows alias/function/binary resolution."
    return 0
  fi

  whence -va "$1"
}

# Create and enter a temporary directory.
mkcdtemp() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    _general_usage "mkcdtemp [prefix]" "Creates a temp directory and enters it."
    return 0
  fi

  local prefix="${1:-mkcdtemp}"
  local tmpdir
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXX") || {
    echo "Could not create temporary directory."
    return 1
  }

  cd "$tmpdir" || return 1
  echo "$tmpdir"
}

# Create a timestamped backup copy.
backup_file() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    _general_usage "backup_file <path>" "Creates <path>.YYYYmmdd_HHMMSS.bak"
    return 0
  fi

  local src="$1"
  if [[ ! -e "$src" ]]; then
    echo "Path not found: $src"
    return 1
  fi

  local ts backup
  ts=$(date +"%Y%m%d_%H%M%S")
  backup="${src}.${ts}.bak"

  cp -p "$src" "$backup" || return 1
  echo "$backup"
}

# Retry a command several times with delay.
retry() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    _general_usage "retry <attempts> <delay_seconds> <command> [args...]" "Retries command until success or attempts exhausted."
    return 0
  fi

  local attempts="$1"
  local delay_seconds="$2"
  shift 2

  if [[ "$attempts" != <-> || "$attempts" -lt 1 || "$delay_seconds" != <-> || "$delay_seconds" -lt 0 || $# -lt 1 ]]; then
    _general_usage "retry <attempts> <delay_seconds> <command> [args...]" "Retries command until success or attempts exhausted."
    return 1
  fi

  local -i try=1
  local -i exit_code=1
  while (( try <= attempts )); do
    "$@"
    exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
      return 0
    fi

    if (( try < attempts )); then
      echo "Attempt $try/$attempts failed (exit $exit_code). Retrying in ${delay_seconds}s..."
      sleep "$delay_seconds"
    fi
    ((try++))
  done

  return $exit_code
}

# Run a command and report elapsed time.
stopwatch() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" || $# -lt 1 ]]; then
    _general_usage "stopwatch <command> [args...]" "Runs command and prints elapsed time."
    return 0
  fi

  local start end elapsed
  if [[ -n "$EPOCHREALTIME" ]]; then
    start="$EPOCHREALTIME"
    "$@"
    local exit_code=$?
    end="$EPOCHREALTIME"
    elapsed=$(awk -v s="$start" -v e="$end" 'BEGIN {printf "%.3f", (e-s)}')
    echo "Elapsed: ${elapsed}s"
    return $exit_code
  fi

  start=$(date +%s)
  "$@"
  local exit_code=$?
  end=$(date +%s)
  echo "Elapsed: $((end - start))s"
  return $exit_code
}

# Pretty-print JSON from file or stdin.
json_pretty() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    _general_usage "json_pretty [file]" "Pretty-prints JSON using jq/python fallback."
    return 0
  fi

  if command -v jq >/dev/null 2>&1; then
    if [[ -n "$1" ]]; then
      jq . "$1"
    else
      jq .
    fi
    return $?
  fi

  if command -v python3 >/dev/null 2>&1; then
    if [[ -n "$1" ]]; then
      python3 -m json.tool "$1"
    else
      python3 -m json.tool
    fi
    return $?
  fi

  echo "No supported tool found (jq/python3)."
  return 1
}

# URL-encode a string.
urlencode() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    _general_usage "urlencode <text>" "Encodes text for URL usage."
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
    return $?
  fi

  perl -MURI::Escape -e 'print uri_escape($ARGV[0]), "\n"' "$1"
}

# URL-decode a string.
urldecode() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    _general_usage "urldecode <text>" "Decodes URL-encoded text."
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote_plus(sys.argv[1]))' "$1"
    return $?
  fi

  perl -MURI::Escape -e 'print uri_unescape($ARGV[0]), "\n"' "$1"
}

# Show human-readable size for files/directories.
fsize() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    _general_usage "fsize [path ...]" "Shows human-readable size for each path (default: current directory)."
    return 0
  fi

  if [[ $# -eq 0 ]]; then
    set -- .
  fi

  local p
  for p in "$@"; do
    if [[ ! -e "$p" ]]; then
      echo "Not found: $p"
      continue
    fi
    du -sh "$p" 2>/dev/null
  done
}

# One-screen system summary.
sysinfo_short() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    _general_usage "sysinfo_short" "Prints compact OS, uptime, CPU, memory, disk and IP summary."
    return 0
  fi

  echo "Host: $(hostname)"
  echo "OS: $(uname -s) $(uname -r)"

  if command -v uptime >/dev/null 2>&1; then
    echo "Uptime: $(uptime | sed 's/^ *//')"
  fi

  if [[ "$(uname)" == "Darwin" ]]; then
    if command -v sysctl >/dev/null 2>&1; then
      echo "CPU: $(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
      echo "Memory: $(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.2f GiB", $1/1024/1024/1024}')"
    fi
  else
    if [[ -r /proc/cpuinfo ]]; then
      echo "CPU: $(awk -F: '/model name/ {gsub(/^ +/, "", $2); print $2; exit}' /proc/cpuinfo)"
    fi
    if command -v free >/dev/null 2>&1; then
      echo "Memory:"
      free -h
    fi
  fi

  echo "Disk:"
  df -h / | tail -n 1

  if command -v myip >/dev/null 2>&1; then
    echo "IP:"
    myip
  fi
}

# Case-insensitive process search.
psg() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    _general_usage "psg <pattern>" "Case-insensitive process search."
    return 0
  fi

  local pattern="$1"
  ps aux | awk -v p="$pattern" 'BEGIN{IGNORECASE=1} $0 ~ p && $0 !~ /awk -v p=/ {print}'
}

# Remove .DS_Store files recursively.
cleanup_dsstore() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    _general_usage "cleanup_dsstore [path]" "Deletes .DS_Store files recursively (default: current directory)."
    return 0
  fi

  local root="${1:-.}"
  if [[ ! -d "$root" ]]; then
    echo "Directory not found: $root"
    return 1
  fi

  find "$root" -type f -name ".DS_Store" -print -delete
}

# Quick weather lookup.
weather() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    _general_usage "weather [location]" "Shows weather from wttr.in (example: weather Berlin)."
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required for weather."
    return 1
  fi

  local loc="$1"
  if [[ -n "$loc" ]]; then
    curl -fsS --max-time 8 "wttr.in/${loc}?m"
  else
    curl -fsS --max-time 8 "wttr.in/?m"
  fi
}

# Lightweight expression calculator.
calc() {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" || $# -eq 0 ]]; then
    _general_usage "calc <expression>" "Evaluates arithmetic expression."
    return 0
  fi

  local expr="$*"

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import math,sys; print(eval(sys.argv[1], {"__builtins__":{}}, vars(math)))' "$expr"
    return $?
  fi

  if command -v bc >/dev/null 2>&1; then
    echo "$expr" | bc -l
    return $?
  fi

  perl -e 'my $e = shift; my $r = eval $e; die $@ if $@; print "$r\n";' "$expr"
}

# Overview of general helper functions.
general_help() {
  echo "General helper functions:"
  printf "  %-36s %s\n" "extractpath CMD" "Show command resolution"
  printf "  %-36s %s\n" "mkcdtemp [PREFIX]" "Create and enter temporary directory"
  printf "  %-36s %s\n" "backup_file PATH" "Create timestamped backup"
  printf "  %-36s %s\n" "retry N DELAY CMD [ARGS...]" "Retry command until success"
  printf "  %-36s %s\n" "stopwatch CMD [ARGS...]" "Run command and print elapsed time"
  printf "  %-36s %s\n" "json_pretty [FILE]" "Pretty-print JSON"
  printf "  %-36s %s\n" "urlencode TEXT" "URL-encode text"
  printf "  %-36s %s\n" "urldecode TEXT" "URL-decode text"
  printf "  %-36s %s\n" "fsize [PATH ...]" "Show file or directory size"
  printf "  %-36s %s\n" "sysinfo_short" "Print compact system summary"
  printf "  %-36s %s\n" "psg PATTERN" "Search processes"
  printf "  %-36s %s\n" "cleanup_dsstore [PATH]" "Delete .DS_Store files recursively"
  printf "  %-36s %s\n" "weather [LOCATION]" "Show weather forecast"
  printf "  %-36s %s\n" "calc EXPRESSION" "Evaluate expression"
}
