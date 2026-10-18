#!/bin/bash
## General helper functions for zsh

# -------------------------------------------------------------------
# display a neatly formatted path
# -------------------------------------------------------------------
function path {
  echo $PATH | tr ":" "\n" | \
    awk "{ sub(\"/usr\",   \"$fg_no_bold[green]/usr$reset_color\");
           sub(\"/bin\",   \"$fg_no_bold[blue]/bin$reset_color\");
           sub(\"/opt\",   \"$fg_no_bold[cyan]/opt$reset_color\");
           sub(\"/sbin\",  \"$fg_no_bold[magenta]/sbin$reset_color\");
           sub(\"/local\", \"$fg_no_bold[yellow]/local$reset_color\");
           print }"
}


function disk_power_on_hours {
  # Read Power_On_Hours from whole-disk devices and convert the value to years.
  emulate -L zsh

  local hours years dev
  local -a devices

  if ! command -v smartctl >/dev/null 2>&1; then
    echo "disk_power_on_hours: smartctl is not installed."
    if [[ "$(uname)" == "Darwin" ]]; then
      echo "Tip (macOS): brew install smartmontools"
    fi
    return 1
  fi

  if [[ "$(uname)" == "Darwin" ]]; then
    devices=(/dev/disk<->(N))
  else
    devices=(/dev/sd[a-z](N))
  fi

  if (( ${#devices[@]} == 0 )); then
    echo "disk_power_on_hours: no matching disk devices found."
    return 1
  fi

  for dev in "${devices[@]}"; do
    if [[ "$(uname)" == "Darwin" ]]; then
      hours=$(smartctl -a "$dev" 2>/dev/null | awk '/Power_On_Hours|Power on Hours/ {print $NF; exit}')
    else
      hours=$(smartctl -a -d sat "$dev" 2>/dev/null | awk '/Power_On_Hours|Power on Hours/ {print $NF; exit}')
    fi

    if [[ -n "$hours" && "$hours" =~ ^[0-9]+$ ]]; then
      years=$(awk "BEGIN {printf \"%.2f\", $hours/24/365}")
      echo "$dev: $hours hours ~= $years years"
    else
      echo "$dev: Value not available"
    fi
  done
}


# Outputs the current epoch time or converts argument to human-readable date and time
function epoch {
  if [ $# -eq 0 ]; then
    date +%s
  else
    date -d @"$@" -R
  fi
}


# Epoch to date (automatic Linux/macOS handling)
function epoch2date {
  if date -d @0 +%F >/dev/null 2>&1; then
    date -d "@$1"
  else
    date -r "$1"
  fi
}

# Current date to epoch
function date2epoch {
  date +%s
}


# Create a new directory and enter it
function mkd {
        mkdir -p "$@"
        cd "$@" || exit
}



# Very often changing to a directory is followed by the ls command to list its contents.
# Therefore it is helpful to have a second function doing both at once.
# In this example we will name it cl (change list) and show an error message if the specified directory does not exist.
function cl {
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
function whatsize {
    emulate -L zsh

    local root="${1:-/}"
    if [[ ! -d "$root" ]]; then
      echo "Directory not found: $root"
      return 1
    fi

    # GNU du (Linux)
    if du --version >/dev/null 2>&1; then
      du -h -x -P -t 1 -d 1 \
        --exclude=/{proc,sys,dev,run} \
        --exclude='*/#snapshot' \
        --exclude='#snapshot' \
        "$root" 2>/dev/null | sort -hr
      return $?
    fi

    # BSD du (macOS)
    du -h -d 1 "$root" 2>/dev/null | sort -hr
}


# Restart all running services except ssh, dbus, systemd-logind
function service-restart-all {
  emulate -L zsh

  if command -v systemctl >/dev/null 2>&1; then
    systemctl list-units --type=service --state=running --no-legend \
    | awk '{print $1}' \
    | grep -Ev '^(ssh|dbus|systemd-logind)\.service$' \
    | xargs systemctl restart
    return $?
  fi

  if command -v launchctl >/dev/null 2>&1; then
    echo "service-restart-all: bulk service restart is not supported on macOS launchctl."
    echo "Use launchctl kickstart -k <domain/service> for a specific service."
    return 1
  fi

  echo "service-restart-all: no supported service manager found (systemctl/launchctl)."
  return 1
}

# List all running services
function service-list-running {
  emulate -L zsh

  if command -v systemctl >/dev/null 2>&1; then
    systemctl list-units --type=service --state=running
    return $?
  fi

  if command -v launchctl >/dev/null 2>&1; then
    launchctl list | awk 'NR == 1 || $1 != "-"'
    return $?
  fi

  echo "service-list-running: no supported service manager found (systemctl/launchctl)."
  return 1
}

# Internal usage printer to keep help output consistent.
function _general_usage {
  echo "Usage: $1"
  if [[ -n "$2" ]]; then
    echo "$2"
  fi
}

# Show resolved command type/path for troubleshooting shell resolution.
function extractpath {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    _general_usage "extractpath <command_name>" "Shows alias/function/binary resolution."
    return 0
  fi

  whence -va "$1"
}

# Create and enter a temporary directory.
function mkcdtemp {
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
function backup_file {
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
function retry {
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
function stopwatch {
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
function json_pretty {
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
function urlencode {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" || $# -eq 0 ]]; then
    _general_usage "urlencode <text>" "Encodes text for URL usage."
    return 0
  fi

  local input="$*"

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$input"
    return $?
  fi

  perl -MURI::Escape -e 'print uri_escape($ARGV[0]), "\n"' "$input"
}

# URL-decode a string.
function urldecode {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" || $# -eq 0 ]]; then
    _general_usage "urldecode <text>" "Decodes URL-encoded text."
    return 0
  fi

  local input="$*"

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote_plus(sys.argv[1]))' "$input"
    return $?
  fi

  perl -MURI::Escape -e 'print uri_unescape($ARGV[0]), "\n"' "$input"
}

# Show largest files recursively.
function fsize {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    _general_usage "fsize [path] [limit]" "Recursively lists largest files first (default: current directory, 20 results)."
    return 0
  fi

  local root="${1:-.}"
  local limit="${2:-20}"

  if [[ ! -e "$root" ]]; then
    echo "Path not found: $root"
    return 1
  fi

  if [[ "$limit" != <-> || "$limit" -lt 1 ]]; then
    echo "Limit must be a whole number >= 1."
    return 1
  fi

  if [[ -f "$root" ]]; then
    du -kh "$root" 2>/dev/null
    return $?
  else
    find "$root" -type f -exec du -k {} + 2>/dev/null \
      | sort -nr \
      | head -n "$limit" \
      | awk '
          function human(kib, units, i, bytes) {
            split("B KiB MiB GiB TiB PiB", units, " ")
            bytes = kib * 1024
            i = 1
            while (bytes >= 1024 && i < 6) {
              bytes /= 1024
              i++
            }
            return sprintf("%.2f %s", bytes, units[i])
          }
          {
            size = $1
            $1 = ""
            sub(/^\s+/, "", $0)
            printf "%10s  %s\n", human(size), $0
          }
        '
    return $?
  fi
}

# One-screen system summary.
function sysinfo_short {
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
function psg {
  emulate -L zsh

  if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    _general_usage "psg <pattern>" "Case-insensitive process search."
    return 0
  fi

  local pattern="$1"
  ps aux | awk -v p="$pattern" 'BEGIN{IGNORECASE=1} $0 ~ p && $0 !~ /awk -v p=/ {print}'
}

# Remove .DS_Store files recursively.
function cleanup_dsstore {
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
function weather {
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
function calc {
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

# Entropy-focused generator mode for `pwgen -i`.
function _pwgen_entropy_mode {
  emulate -L zsh

  if ! command -v python3 >/dev/null 2>&1; then
    echo "Entropy mode requires python3."
    return 1
  fi

  local answer
  local entropy_bits="128"
  local max_length="20"
  local count="1"
  local special_set='!@#$%^&*()-_=+[]{}:,.?/~'
  local copy_first="0"

  echo "Entropy-only mode"

  while true; do
    read "answer?Requested entropy in bits (example 128): "
    answer="${answer:-$entropy_bits}"
    if [[ "$answer" == <-> && "$answer" -ge 1 ]]; then
      entropy_bits="$answer"
      break
    fi
    echo "Please enter a whole number >= 1."
  done

  while true; do
    read "answer?Maximum password length allowed: "
    answer="${answer:-$max_length}"
    if [[ "$answer" == <-> && "$answer" -ge 1 ]]; then
      max_length="$answer"
      break
    fi
    echo "Please enter a whole number >= 1."
  done

  while true; do
    read "answer?How many passwords to generate (default ${count}): "
    answer="${answer:-$count}"
    if [[ "$answer" == <-> && "$answer" -ge 1 && "$answer" -le 1000 ]]; then
      count="$answer"
      break
    fi
    echo "Please enter a number between 1 and 1000."
  done

  if [[ "$(uname)" == "Darwin" ]] && command -v pbcopy >/dev/null 2>&1; then
    while true; do
      read "answer?Copy first generated password to clipboard? [y/N]: "
      case "${answer:l}" in
        "") break ;;
        y|yes) copy_first="1"; break ;;
        n|no) copy_first="0"; break ;;
        *) echo "Please answer y or n." ;;
      esac
    done
  fi

  local filtered_special="${special_set//[O0Il1|]/}"
  local -i pool_size=$((25 + 24 + 8 + ${#filtered_special}))
  if (( pool_size < 2 )); then
    echo "Final character pool is too small."
    return 1
  fi

  local bits_per_char required_length max_entropy
  bits_per_char=$(awk -v pool="$pool_size" 'BEGIN { printf "%.3f", log(pool)/log(2) }')
  required_length=$(awk -v min="$entropy_bits" -v pool="$pool_size" 'BEGIN { bpc=log(pool)/log(2); req=min/bpc; if (req==int(req)) print int(req); else print int(req)+1 }')

  while true; do
    max_entropy=$(awk -v l="$max_length" -v pool="$pool_size" 'BEGIN { printf "%.1f", l*(log(pool)/log(2)) }')
    if (( required_length <= max_length )); then
      break
    fi

    echo "Backend: python (entropy mode)"
    echo "Pool size: ${pool_size} characters"
    echo "Entropy per character: ${bits_per_char} bits"
    echo "Requested minimum entropy: ${entropy_bits} bits"
    echo "Maximum allowed length: ${max_length}"
    echo "Not possible within ${max_length} characters."
    echo "Estimated entropy at max length: ${max_entropy} bits"
    echo "Minimum needed length: ${required_length}"

    while true; do
      read "answer?Proceed with minimum needed length ${required_length}? [Y/n/new]: "
      case "${answer:l}" in
        ""|y|yes)
          max_length="$required_length"
          break
          ;;
        n|no)
          echo "Cancelled."
          return 1
          ;;
        new)
          while true; do
            read "answer?Enter new maximum password length: "
            if [[ "$answer" == <-> && "$answer" -ge 1 ]]; then
              max_length="$answer"
              break
            fi
            echo "Please enter a whole number >= 1."
          done
          break
          ;;
        *)
          echo "Please answer y, n, or new."
          ;;
      esac
    done
  done

  PW_ENTROPY_BITS="$entropy_bits" \
  PW_MAX_LENGTH="$max_length" \
  PW_USED_LENGTH="$required_length" \
  PW_COUNT="$count" \
  PW_COPY_FIRST="$copy_first" \
  PW_SPECIAL_SET="$special_set" \
  python3 - <<'PY'
import math
import os
import secrets
import string
import subprocess
import sys


def b(name: str) -> bool:
    return os.environ.get(name, "0") == "1"


target_entropy = int(os.environ["PW_ENTROPY_BITS"])
max_length = int(os.environ["PW_MAX_LENGTH"])
used_length = int(os.environ["PW_USED_LENGTH"])
count = int(os.environ["PW_COUNT"])
copy_first = b("PW_COPY_FIRST")
special_set = os.environ.get("PW_SPECIAL_SET", "")

groups = [string.ascii_lowercase, string.ascii_uppercase, string.digits, special_set]
ambiguous = set("O0Il1|")
groups = ["".join(ch for ch in grp if ch not in ambiguous) for grp in groups]
groups = [grp for grp in groups if grp]

pool = "".join(dict.fromkeys("".join(groups)))
if not pool:
    print("Final character pool is empty.", file=sys.stderr)
    sys.exit(1)

bits_per_char = math.log2(len(pool))
max_entropy = max_length * bits_per_char

print("Backend: python (entropy mode)")
print(f"Pool size: {len(pool)} characters")
print(f"Entropy per character: {bits_per_char:.3f} bits")
print(f"Requested minimum entropy: {target_entropy} bits")
print(f"Maximum allowed length: {max_length}")
print(f"Estimated entropy at max length: {max_entropy:.1f} bits")


def gen_password() -> str:
    chars = [secrets.choice(grp) for grp in groups]
    chars += [secrets.choice(pool) for _ in range(used_length - len(chars))]
    secrets.SystemRandom().shuffle(chars)
    return "".join(chars)


passwords = [gen_password() for _ in range(count)]
entropy_bits = used_length * bits_per_char
print(f"Used length: {used_length}")
print(f"Estimated entropy: {entropy_bits:.1f} bits per password")
for idx, pwd in enumerate(passwords, start=1):
    print(f"{idx:>3}: {pwd}")

if copy_first and passwords:
    try:
        subprocess.run(["pbcopy"], input=passwords[0], text=True, check=True)
        print("First password copied to clipboard.")
    except Exception:
        print("Could not copy to clipboard.", file=sys.stderr)
PY
}

# Interactive password generator helper used by `pwgen -i`.
function _pwgen_generate_interactive {
  emulate -L zsh

  local force_entropy_mode="0"
  if [[ "$1" == "-e" || "$1" == "--entropy-mode" ]]; then
    force_entropy_mode="1"
    shift
  fi

  local has_python="0"
  local has_pwgen="0"
  local pwgen_bin=""
  if command -v python3 >/dev/null 2>&1; then
    has_python="1"
  fi
  pwgen_bin=$(whence -p pwgen 2>/dev/null)
  if [[ -n "$pwgen_bin" ]]; then
    has_pwgen="1"
  fi

  if [[ "$has_python" == "0" && "$has_pwgen" == "0" ]]; then
    echo "pwgen -i: requires either pwgen or python3 to be installed."
    return 1
  fi

  local profile="1"
  local length="16"
  local count="1"
  local only_numbers="0"
  local use_lower="1"
  local use_upper="1"
  local use_digits="1"
  local use_special="1"
  local special_set='!@#$%^&*()-_=+[]{}:,.?/~'
  local custom_special_set=""
  local exclude_ambiguous="1"
  local ensure_each_group="1"
  local min_entropy_bits="0"
  local copy_first="0"
  local backend_choice="auto"
  local answer
  local is_custom_profile="0"

  if [[ "$force_entropy_mode" == "1" ]]; then
    _pwgen_entropy_mode
    return $?
  fi

  while true; do
    read "answer?Mode: [1] Full wizard [2] Entropy-only (default 1): "
    case "$answer" in
      ""|1)
        break
        ;;
      2)
        _pwgen_entropy_mode
        return $?
        ;;
      *)
        echo "Please enter 1 or 2."
        ;;
    esac
  done

  echo "Password generator profiles:"
  echo "  1) General use (16, upper+lower+digits+special)"
  echo "  2) Compatible (16, upper+lower+digits, no special)"
  echo "  3) PIN/OTP style (6, numbers only)"
  echo "  4) Wi-Fi key (20, upper+lower+digits+special)"
  echo "  5) Custom"
  read "profile?Choose profile [1-5] (default 1): "
  profile="${profile:-1}"

  local profile_name="Custom"

  case "$profile" in
    1)
      profile_name="General use"
      length="16"; only_numbers="0"; use_lower="1"; use_upper="1"; use_digits="1"; use_special="1"
      ;;
    2)
      profile_name="Compatible"
      length="16"; only_numbers="0"; use_lower="1"; use_upper="1"; use_digits="1"; use_special="0"
      ;;
    3)
      profile_name="PIN/OTP style"
      length="6"; only_numbers="1"; use_lower="0"; use_upper="0"; use_digits="1"; use_special="0"
      ;;
    4)
      profile_name="Wi-Fi key"
      length="20"; only_numbers="0"; use_lower="1"; use_upper="1"; use_digits="1"; use_special="1"
      ;;
    5)
      profile_name="Custom"
      is_custom_profile="1"
      ;;
    *)
      echo "Invalid profile."
      return 1
      ;;
  esac

  echo "Selected profile: ${profile_name}"
  echo "Press Enter to keep each default value."
  if [[ "$is_custom_profile" == "0" ]]; then
    echo "Preset profile selected: character sets are fixed by profile. Use profile 5 (Custom) to change them."
  fi

  while true; do
    read "answer?Password length (default ${length}): "
    answer="${answer:-$length}"
    if [[ "$answer" == <-> && "$answer" -ge 4 ]]; then
      length="$answer"
      break
    fi
    echo "Please enter a number >= 4."
  done

  while true; do
    read "answer?How many passwords to generate (default ${count}): "
    answer="${answer:-$count}"
    if [[ "$answer" == <-> && "$answer" -ge 1 && "$answer" -le 1000 ]]; then
      count="$answer"
      break
    fi
    echo "Please enter a number between 1 and 1000."
  done

  if [[ "$is_custom_profile" == "1" ]]; then
    while true; do
      if [[ "$only_numbers" == "1" ]]; then
        read "answer?Numbers only? [Y/n]: "
      else
        read "answer?Numbers only? [y/N]: "
      fi

      case "${answer:l}" in
        "")
          break
          ;;
        y|yes)
          only_numbers="1"
          break
          ;;
        n|no)
          only_numbers="0"
          break
          ;;
        *)
          echo "Please answer y or n."
          ;;
      esac
    done

    if [[ "$only_numbers" == "1" ]]; then
      use_lower="0"
      use_upper="0"
      use_digits="1"
      use_special="0"
      custom_special_set=""
      echo "Numbers-only enabled: lowercase/uppercase/special disabled, digits enabled."
    fi

    if [[ "$only_numbers" == "0" ]]; then
      while true; do
        if [[ "$use_lower" == "1" ]]; then
          read "answer?Include lowercase letters? [Y/n]: "
        else
          read "answer?Include lowercase letters? [y/N]: "
        fi
        case "${answer:l}" in
          "") break ;;
          y|yes) use_lower="1"; break ;;
          n|no) use_lower="0"; break ;;
          *) echo "Please answer y or n." ;;
        esac
      done

      while true; do
        if [[ "$use_upper" == "1" ]]; then
          read "answer?Include uppercase letters? [Y/n]: "
        else
          read "answer?Include uppercase letters? [y/N]: "
        fi
        case "${answer:l}" in
          "") break ;;
          y|yes) use_upper="1"; break ;;
          n|no) use_upper="0"; break ;;
          *) echo "Please answer y or n." ;;
        esac
      done

      while true; do
        if [[ "$use_digits" == "1" ]]; then
          read "answer?Include digits? [Y/n]: "
        else
          read "answer?Include digits? [y/N]: "
        fi
        case "${answer:l}" in
          "") break ;;
          y|yes) use_digits="1"; break ;;
          n|no) use_digits="0"; break ;;
          *) echo "Please answer y or n." ;;
        esac
      done

      while true; do
        if [[ "$use_special" == "1" ]]; then
          read "answer?Include special characters? [Y/n]: "
        else
          read "answer?Include special characters? [y/N]: "
        fi
        case "${answer:l}" in
          "")
            break
            ;;
          y|yes)
            use_special="1"
            break
            ;;
          n|no)
            use_special="0"
            break
            ;;
          *)
            echo "Please answer y or n."
            ;;
        esac
      done

      if [[ "$use_special" == "1" ]]; then
        read "answer?Use only specific special characters (empty = default set): "
        if [[ -n "$answer" ]]; then
          custom_special_set="$answer"
        fi
      else
        custom_special_set=""
      fi
    fi
  fi

  if [[ "$use_lower" == "0" && "$use_upper" == "0" && "$use_digits" == "0" && "$use_special" == "0" ]]; then
    echo "No character groups selected."
    return 1
  fi

  while true; do
    if [[ "$exclude_ambiguous" == "1" ]]; then
      read "answer?Exclude ambiguous characters (O,0,l,1,|,I)? [Y/n]: "
    else
      read "answer?Exclude ambiguous characters (O,0,l,1,|,I)? [y/N]: "
    fi
    case "${answer:l}" in
      "") break ;;
      y|yes) exclude_ambiguous="1"; break ;;
      n|no) exclude_ambiguous="0"; break ;;
      *) echo "Please answer y or n." ;;
    esac
  done

  local -i selected_groups=0
  [[ "$use_lower" == "1" ]] && ((selected_groups++))
  [[ "$use_upper" == "1" ]] && ((selected_groups++))
  [[ "$use_digits" == "1" ]] && ((selected_groups++))
  [[ "$use_special" == "1" ]] && ((selected_groups++))

  if (( selected_groups > 1 )); then
    while true; do
      if [[ "$ensure_each_group" == "1" ]]; then
        read "answer?Ensure at least one character from each selected group? [Y/n]: "
      else
        read "answer?Ensure at least one character from each selected group? [y/N]: "
      fi
      case "${answer:l}" in
        "") break ;;
        y|yes) ensure_each_group="1"; break ;;
        n|no) ensure_each_group="0"; break ;;
        *) echo "Please answer y or n." ;;
      esac
    done
  else
    ensure_each_group="0"
  fi

  while true; do
    read "answer?Minimum entropy in bits (0 to disable, example 128): "
    answer="${answer:-0}"
    if [[ "$answer" == <-> ]]; then
      min_entropy_bits="$answer"
      break
    fi
    echo "Please enter a whole number >= 0."
  done

  while true; do
    read "answer?Backend [a]uto/[p]wgen/[py]thon (default auto): "
    case "${answer:l}" in
      ""|a|auto)
        backend_choice="auto"
        break
        ;;
      p|pwgen)
        backend_choice="pwgen"
        break
        ;;
      py|python)
        backend_choice="python"
        break
        ;;
      *)
        echo "Please enter auto, pwgen or python."
        ;;
    esac
  done

  if [[ "$(uname)" == "Darwin" ]] && command -v pbcopy >/dev/null 2>&1; then
    while true; do
      if [[ "$copy_first" == "1" ]]; then
        read "answer?Copy first generated password to clipboard? [Y/n]: "
      else
        read "answer?Copy first generated password to clipboard? [y/N]: "
      fi
      case "${answer:l}" in
        "") break ;;
        y|yes) copy_first="1"; break ;;
        n|no) copy_first="0"; break ;;
        *) echo "Please answer y or n." ;;
      esac
    done
  fi

  if [[ -n "$custom_special_set" ]]; then
    special_set="$custom_special_set"
  fi

  local backend="python"
  local pwgen_compatible="1"
  local -a incompat_reasons

  if [[ "$only_numbers" == "1" ]]; then
    pwgen_compatible="0"
    incompat_reasons+=("numbers-only mode")
  fi
  if [[ -n "$custom_special_set" ]]; then
    pwgen_compatible="0"
    incompat_reasons+=("custom special-character set")
  fi
  case "$backend_choice" in
    python)
      backend="python"
      ;;
    pwgen)
      if [[ "$has_pwgen" == "1" && "$pwgen_compatible" == "1" ]]; then
        backend="pwgen"
      else
        backend="python"
        echo "Requested pwgen backend is not available for current options; using python backend."
        if (( ${#incompat_reasons[@]} > 0 )); then
          echo "Reason: ${incompat_reasons[*]}"
        fi
      fi
      ;;
    auto)
      if [[ "$has_pwgen" == "1" && "$pwgen_compatible" == "1" ]]; then
        backend="pwgen"
      else
        backend="python"
      fi
      ;;
  esac

  if [[ "$backend" == "python" && "$has_python" != "1" ]]; then
    echo "python3 is required for selected options."
    if [[ "$has_pwgen" == "1" ]]; then
      echo "Tip: choose backend=pwgen and avoid advanced-only options."
    fi
    return 1
  fi

  if [[ "$backend" == "pwgen" ]]; then
    local -a pwgen_opts
    local remove_chars=""
    local lower_chars="abcdefghijklmnopqrstuvwxyz"

    pwgen_opts=(-s -1)
    if [[ "$use_upper" == "1" ]]; then
      pwgen_opts+=(-c)
    else
      pwgen_opts+=(-A)
    fi

    if [[ "$use_digits" == "1" ]]; then
      pwgen_opts+=(-n)
    else
      pwgen_opts+=(-0)
    fi

    if [[ "$use_special" == "1" ]]; then
      pwgen_opts+=(-y)
    fi

    if [[ "$exclude_ambiguous" == "1" ]]; then
      pwgen_opts+=(-B)
    fi

    if [[ "$use_lower" == "0" ]]; then
      remove_chars+="$lower_chars"
    fi

    if [[ -n "$remove_chars" ]]; then
      pwgen_opts+=(-r "$remove_chars")
    fi

    local -i pool_size=0
    if [[ "$use_lower" == "1" ]]; then
      (( pool_size += 26 ))
      if [[ "$exclude_ambiguous" == "1" ]]; then
        (( pool_size -= 1 ))
      fi
    fi
    if [[ "$use_upper" == "1" ]]; then
      (( pool_size += 26 ))
      if [[ "$exclude_ambiguous" == "1" ]]; then
        (( pool_size -= 2 ))
      fi
    fi
    if [[ "$use_digits" == "1" ]]; then
      (( pool_size += 10 ))
      if [[ "$exclude_ambiguous" == "1" ]]; then
        (( pool_size -= 2 ))
      fi
    fi
    if [[ "$use_special" == "1" ]]; then
      (( pool_size += ${#special_set} ))
    fi

    if (( pool_size < 2 )); then
      echo "Final character pool is too small for pwgen backend."
      return 1
    fi

    local adjusted_length="$length"
    if [[ "$min_entropy_bits" != "0" ]]; then
      adjusted_length=$(awk -v min="$min_entropy_bits" -v pool="$pool_size" 'BEGIN { bpc=log(pool)/log(2); req=min/bpc; if (req==int(req)) print int(req); else print int(req)+1 }')
      if [[ "$adjusted_length" != <-> ]]; then
        echo "Could not compute entropy-adjusted length."
        return 1
      fi
      if (( adjusted_length < length )); then
        adjusted_length="$length"
      fi
      length="$adjusted_length"
    fi

    local pw_output
    if ! pw_output=$("$pwgen_bin" "${pwgen_opts[@]}" "$length" "$count" 2>/dev/null); then
      echo "pwgen generation failed."
      echo "Tip: run '$pwgen_bin --help' to verify supported options on your system."
      return 1
    fi

    local entropy_bits
    entropy_bits=$(awk -v l="$length" -v pool="$pool_size" 'BEGIN { printf "%.1f", l*(log(pool)/log(2)) }')

    echo "Backend: pwgen"
    if [[ "$ensure_each_group" == "1" ]]; then
      echo "Note: pwgen applies group requirements best-effort (strict guarantees may differ from python backend)."
    fi
    echo "Pool size: ${pool_size} characters"
    if [[ "$min_entropy_bits" != "0" ]]; then
      echo "Requested minimum entropy: ${min_entropy_bits} bits"
      echo "Adjusted password length: ${length}"
    fi
    echo "Estimated entropy: ${entropy_bits} bits per password"

    local idx=1
    local first_password=""
    local line
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      if [[ -z "$first_password" ]]; then
        first_password="$line"
      fi
      printf "%3d: %s\n" "$idx" "$line"
      ((idx++))
    done <<< "$pw_output"

    if [[ "$copy_first" == "1" && -n "$first_password" ]]; then
      printf "%s" "$first_password" | pbcopy
      echo "First password copied to clipboard."
    fi

    return 0
  fi

  PW_LENGTH="$length" \
  PW_COUNT="$count" \
  PW_LOWER="$use_lower" \
  PW_UPPER="$use_upper" \
  PW_DIGITS="$use_digits" \
  PW_SPECIAL="$use_special" \
  PW_ONLY_NUMBERS="$only_numbers" \
  PW_SPECIAL_SET="$special_set" \
  PW_EXCLUDE_AMBIGUOUS="$exclude_ambiguous" \
  PW_ENSURE_EACH="$ensure_each_group" \
  PW_MIN_ENTROPY="$min_entropy_bits" \
  PW_COPY_FIRST="$copy_first" \
  python3 - <<'PY'
import math
import os
import secrets
import string
import subprocess
import sys


def b(name: str) -> bool:
    return os.environ.get(name, "0") == "1"


length = int(os.environ["PW_LENGTH"])
count = int(os.environ["PW_COUNT"])
use_lower = b("PW_LOWER")
use_upper = b("PW_UPPER")
use_digits = b("PW_DIGITS")
use_special = b("PW_SPECIAL")
only_numbers = b("PW_ONLY_NUMBERS")
special_set = os.environ.get("PW_SPECIAL_SET", "")
exclude_ambiguous = b("PW_EXCLUDE_AMBIGUOUS")
ensure_each = b("PW_ENSURE_EACH")
min_entropy_bits = int(os.environ.get("PW_MIN_ENTROPY", "0"))
copy_first = b("PW_COPY_FIRST")

groups = []
if only_numbers:
    groups.append(string.digits)
else:
    if use_lower:
        groups.append(string.ascii_lowercase)
    if use_upper:
        groups.append(string.ascii_uppercase)
    if use_digits:
        groups.append(string.digits)
    if use_special:
        groups.append(special_set)

if not groups:
    print("No character groups selected.", file=sys.stderr)
    sys.exit(1)

ambiguous = set("O0Il1|")
if exclude_ambiguous:
    groups = ["".join(ch for ch in grp if ch not in ambiguous) for grp in groups]
    groups = [grp for grp in groups if grp]

if not groups:
    print("Character set became empty after filtering ambiguous characters.", file=sys.stderr)
    sys.exit(1)

if ensure_each and length < len(groups):
    print(f"Length {length} is too short for {len(groups)} required groups.", file=sys.stderr)
    sys.exit(1)

pool = "".join(dict.fromkeys("".join(groups)))
if not pool:
    print("Final character pool is empty.", file=sys.stderr)
    sys.exit(1)

bits_per_char = math.log2(len(pool))
if bits_per_char <= 0:
  print("Character pool is too small to provide entropy.", file=sys.stderr)
  sys.exit(1)

if min_entropy_bits > 0:
  required_length = math.ceil(min_entropy_bits / bits_per_char)
  if required_length > length:
    length = required_length


def gen_password() -> str:
    if ensure_each:
        chars = [secrets.choice(grp) for grp in groups]
        chars += [secrets.choice(pool) for _ in range(length - len(chars))]
        secrets.SystemRandom().shuffle(chars)
        return "".join(chars)
    return "".join(secrets.choice(pool) for _ in range(length))


passwords = [gen_password() for _ in range(count)]
entropy_bits = length * math.log2(len(pool))

print("Backend: python")
print(f"Pool size: {len(pool)} characters")
if min_entropy_bits > 0:
  print(f"Requested minimum entropy: {min_entropy_bits} bits")
  print(f"Adjusted password length: {length}")
print(f"Estimated entropy: {entropy_bits:.1f} bits per password")
for idx, pwd in enumerate(passwords, start=1):
    print(f"{idx:>3}: {pwd}")

if copy_first and passwords:
    try:
        subprocess.run(["pbcopy"], input=passwords[0], text=True, check=True)
        print("First password copied to clipboard.")
    except Exception:
        print("Could not copy to clipboard.", file=sys.stderr)
PY
}

# Keep system pwgen behavior; use `pwgen -i` for interactive generation.
function pwgen {
  emulate -L zsh

  local pwgen_bin
  pwgen_bin=$(whence -p pwgen 2>/dev/null)

  if [[ "$1" == "-i" || "$1" == "--interactive" || "$1" == "-g" || "$1" == "--generate" ]]; then
    if [[ -z "$pwgen_bin" ]]; then
      echo "pwgen binary not found."
      if [[ "$(uname)" == "Darwin" ]]; then
        echo "Install with: brew install pwgen"
      elif command -v apt >/dev/null 2>&1; then
        echo "Install with: sudo apt install pwgen"
      elif command -v dnf >/dev/null 2>&1; then
        echo "Install with: sudo dnf install pwgen"
      elif command -v yum >/dev/null 2>&1; then
        echo "Install with: sudo yum install pwgen"
      elif command -v pacman >/dev/null 2>&1; then
        echo "Install with: sudo pacman -S pwgen"
      elif command -v zypper >/dev/null 2>&1; then
        echo "Install with: sudo zypper install pwgen"
      else
        echo "Install pwgen using your distribution's package manager."
      fi
      return 1
    fi
    shift
    _pwgen_generate_interactive "$@"
    return $?
  fi

  if [[ -n "$pwgen_bin" ]]; then
    "$pwgen_bin" "$@"
    return $?
  fi

  echo "pwgen binary not found."
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "Install with: brew install pwgen"
  elif command -v apt >/dev/null 2>&1; then
    echo "Install with: sudo apt install pwgen"
  elif command -v dnf >/dev/null 2>&1; then
    echo "Install with: sudo dnf install pwgen"
  elif command -v yum >/dev/null 2>&1; then
    echo "Install with: sudo yum install pwgen"
  elif command -v pacman >/dev/null 2>&1; then
    echo "Install with: sudo pacman -S pwgen"
  elif command -v zypper >/dev/null 2>&1; then
    echo "Install with: sudo zypper install pwgen"
  else
    echo "Install pwgen using your distribution's package manager."
  fi
  return 1
}

# Verify a file against a hash. Prompts for anything not given as argument.
# Usage: verify_hash [-a ALGO] [FILE] [HASH|CHECKSUM_FILE]
# The algorithm (md5, sha1, sha224, sha256, sha384, sha512) is auto-detected from the hash length.
function verify_hash {
  emulate -L zsh
  setopt local_options no_unset

  local algo="" file="" expected="" input=""
  local c_ok="" c_bad="" c_dim="" c_rst=""
  if [[ -t 1 ]]; then
    c_ok=$'\e[32m'; c_bad=$'\e[31m'; c_dim=$'\e[2m'; c_rst=$'\e[0m'
  fi

  while (( $# > 0 )); do
    case "$1" in
      -h|--help)
        echo "Usage: verify_hash [-a ALGO] [FILE] [HASH|CHECKSUM_FILE]"
        echo "  Verifies a file against a hash; missing values are asked for interactively."
        echo "  ALGO: md5 sha1 sha224 sha256 sha384 sha512 (auto-detected by hash length)"
        echo "  Accepts a plain hash, 'algo:hash', or a checksum file (sha256sum/shasum format)."
        return 0 ;;
      -a|--algo) algo="${2:l}"; shift 2 || { echo "verify_hash: -a needs a value"; return 2; } ;;
      *)
        if [[ -z "$file" ]]; then file="$1"
        elif [[ -z "$expected" ]]; then expected="$1"
        else echo "verify_hash: too many arguments"; return 2; fi
        shift ;;
    esac
  done

  # Ask for the file until it exists
  while [[ -z "$file" || ! -f "$file" ]]; do
    if [[ -n "$file" ]]; then
      echo "${c_bad}Not a file:${c_rst} $file"
      [[ -t 0 ]] || return 1
    fi
    [[ -t 0 ]] || { echo "verify_hash: no file given"; return 2; }
    vared -p "File to verify (drag & drop works, empty = abort): " -c input
    [[ -z "$input" ]] && { echo "Aborted."; return 130; }
    file="${input//\\ / }"                 # unescape drag & drop spaces
    file="${file#\'}"; file="${file%\'}"   # strip quotes
    file="${file/#\~/$HOME}"
    input=""
  done

  # Ask for the hash
  if [[ -z "$expected" ]]; then
    [[ -t 0 ]] || { echo "verify_hash: no hash given"; return 2; }
    vared -p "Expected hash or checksum file (empty = abort): " -c expected
    [[ -z "$expected" ]] && { echo "Aborted."; return 130; }
  fi

  # Expected may be a checksum file: pick the line matching the file name, else the first line
  if [[ -f "$expected" ]]; then
    local base="${file:t}" line
    line=$(grep -F -- "$base" "$expected" 2>/dev/null | head -n 1)
    [[ -z "$line" ]] && line=$(head -n 1 "$expected")
    if [[ "$line" == *"= "* ]]; then       # BSD style: SHA256 (file) = hash
      [[ -z "$algo" ]] && algo="${${${line%% *}:l}//-/}"
      expected="${line##*= }"
    else
      expected="${line%%[[:space:]]*}"
    fi
  fi

  # Normalize: "algo:hash" prefix, whitespace, case
  if [[ "$expected" == *:* ]]; then
    [[ -z "$algo" ]] && algo="${${expected%%:*}:l}"
    expected="${expected#*:}"
  fi
  expected="${${expected//[[:space:]]/}:l}"

  if [[ ! "$expected" =~ ^[0-9a-f]+$ ]]; then
    echo "${c_bad}Invalid hash:${c_rst} must contain only hex characters (0-9, a-f)."
    return 2
  fi

  if [[ -z "$algo" ]]; then
    case ${#expected} in
      32) algo=md5 ;;
      40) algo=sha1 ;;
      56) algo=sha224 ;;
      64) algo=sha256 ;;
      96) algo=sha384 ;;
      128) algo=sha512 ;;
      *) echo "${c_bad}Cannot detect algorithm:${c_rst} hash has ${#expected} characters. Use -a ALGO."; return 2 ;;
    esac
  fi
  algo="${algo//-/}"

  local actual
  case "$algo" in
    md5)
      if command -v md5sum >/dev/null 2>&1; then actual=$(md5sum "$file")
      else actual=$(md5 -q "$file"); fi ;;
    sha1|sha224|sha256|sha384|sha512)
      if command -v "${algo}sum" >/dev/null 2>&1; then actual=$("${algo}sum" "$file")
      else actual=$(shasum -a "${algo#sha}" "$file"); fi ;;
    *) echo "verify_hash: unsupported algorithm '$algo'"; return 2 ;;
  esac
  actual="${${actual%%[[:space:]]*}:l}"

  if [[ -z "$actual" ]]; then
    echo "${c_bad}Could not compute hash for${c_rst} $file"
    return 2
  fi

  echo "${c_dim}File:     ${c_rst}$file"
  echo "${c_dim}Algorithm:${c_rst} $algo"
  echo "${c_dim}Expected: ${c_rst}$expected"
  echo "${c_dim}Actual:   ${c_rst}$actual"
  if [[ "$actual" == "$expected" ]]; then
    echo "${c_ok}✔ MATCH – file is intact.${c_rst}"
    return 0
  fi
  echo "${c_bad}✘ MISMATCH – file differs from the expected hash!${c_rst}"
  return 1
}

# Overview of general helper functions.
# -------------------------------------------------------------------
# Show access permissions of a folder (octal, symbolic, owner, group)
# Usage: show_perms [-p] [FOLDER]   (-p: also list every parent directory)
# -------------------------------------------------------------------
# Print the comma-separated members of a group (supplementary + primary group)
function _show_perms_group_members {
  emulate -L zsh
  local grp="$1" gid members line
  local -a users

  if [[ "$(uname)" == "Darwin" ]]; then
    users=(${(s: :)$(dscl . -read "/Groups/$grp" GroupMembership 2>/dev/null | sed 's/^GroupMembership: *//')})
    gid=$(dscl . -read "/Groups/$grp" PrimaryGroupID 2>/dev/null | awk '{print $2}')
    [[ -n "$gid" ]] && users+=(${(f)"$(dscl . -list /Users PrimaryGroupID 2>/dev/null | awk -v g="$gid" '$2==g{print $1}')"})
  else
    line=$(getent group "$grp" 2>/dev/null)
    members="${line##*:}"
    users=(${(s:,:)members})
    gid="${${line#*:*:}%%:*}"
    [[ -n "$gid" ]] && users+=(${(f)"$(getent passwd 2>/dev/null | awk -F: -v g="$gid" '$4==g{print $1}')"})
  fi
  users=(${(ou)users})
  print -r -- "${(j:, :)users}"
}

function show_perms {
  emulate -L zsh

  local parents=0 dir
  if [[ "$1" == "-p" ]]; then
    parents=1
    shift
  fi
  dir="${1:-.}"

  if [[ ! -d "$dir" ]]; then
    echo "show_perms: '$dir' is not a directory." >&2
    return 1
  fi

  dir="${dir:A}"

  local -a paths
  if (( parents )); then
    local p="$dir"
    while true; do
      paths=("$p" "${paths[@]}")
      [[ "$p" == "/" ]] && break
      p="${p:h}"
    done
  else
    paths=("$dir")
  fi

  local item octal symbolic owner group
  local -a rows entries grows
  local -a r_oct r_sym r_own r_grp r_path
  local src line mask has_acl etype ename eperm eff i
  local w_oct=5 w_sym=8 w_own=5 w_grp=5 n

  # Gather data first so column widths can adapt to the content
  for item in "${paths[@]}"; do
    if [[ "$(uname)" == "Darwin" ]]; then
      octal=$(stat -f '%Lp' "$item")
      symbolic=$(stat -f '%Sp' "$item")
      owner=$(stat -f '%Su' "$item")
      group=$(stat -f '%Sg' "$item")
    else
      octal=$(stat -c '%a' "$item")
      symbolic=$(stat -c '%A' "$item")
      owner=$(stat -c '%U' "$item")
      group=$(stat -c '%G' "$item")
    fi

    # Entries are "type:name:perms"; the mask limits named users and groups
    entries=()
    mask="rwx"
    has_acl=0
    if [[ "$(uname)" != "Darwin" ]] && command -v getfacl >/dev/null 2>&1; then
      for line in "${(@f)$(getfacl -p -c "$item" 2>/dev/null)}"; do
        [[ -z "$line" || "$line" == default:* ]] && continue
        [[ "$line" == mask::* ]] && mask="${line##*:}"
        [[ "$line" != (user|group|other)::* && "$line" != mask::* ]] && has_acl=1
        entries+=("$line")
      done
    fi
    if (( ! ${#entries[@]} )); then
      entries=("user::${symbolic[2,4]}" "group::${symbolic[5,7]}" "other::${symbolic[8,10]}")
    fi
    (( has_acl )) && [[ "$symbolic" != *+ ]] && symbolic+="+"

    r_oct+=("$octal"); r_sym+=("$symbolic"); r_own+=("$owner"); r_grp+=("$group"); r_path+=("$item")
    (( ${#octal} > w_oct )) && w_oct=${#octal}
    (( ${#symbolic} > w_sym )) && w_sym=${#symbolic}
    (( ${#owner} > w_own )) && w_own=${#owner}
    (( ${#group} > w_grp )) && w_grp=${#group}

    # Build the per-entry rows: type|name|entry|effective
    local -a erows=() gl=()
    for line in "${entries[@]}"; do
      etype="${line%%:*}"
      [[ "$etype" == mask ]] && continue
      ename="${${line#*:}%%:*}"
      eperm="${${line##*:}[1,3]}"
      eff="$eperm"
      if [[ "$etype" == group || ( "$etype" == user && -n "$ename" ) ]]; then
        eff=""
        for i in 1 2 3; do
          if [[ "${eperm[i]}" != "-" && "${mask[i]}" != "-" ]]; then
            eff+="${eperm[i]}"
          else
            eff+="-"
          fi
        done
      fi
      if [[ "$etype" == group ]]; then
        gl+=("${ename:-$group}|$eff")
      fi
      src="ACL"
      [[ -z "$ename" ]] && src="UNIX"
      case "$etype:$ename" in
        user:)  ename="$owner (owner)" ;;
        group:) ename="$group (owning group)" ;;
        other:) ename="everyone else" ;;
      esac
      erows+=("$etype|$ename|$eperm|$eff|$src")
    done
    rows+=("${(F)erows}")
    grows+=("${(F)gl}")
  done

  local -a g_names g_effs g_users
  local gn ge gu w_gn w_ge
  local w_type=4 w_name=4 w_ent=5 w_eff=9 idx
  local -a f
  for line in "${rows[@]}"; do
    for line in "${(@f)line}"; do
      f=("${(@s:|:)line}")
      (( ${#f[1]} > w_type )) && w_type=${#f[1]}
      (( ${#f[2]} > w_name )) && w_name=${#f[2]}
      (( ${#f[3]} > w_ent )) && w_ent=${#f[3]}
      (( ${#f[4]} > w_eff )) && w_eff=${#f[4]}
    done
  done

  echo "Folder: basic mode, ownership and path"
  printf "%-${w_oct}s  %-${w_sym}s  %-${w_own}s  %-${w_grp}s  %s\n" "OCTAL" "SYMBOLIC" "OWNER" "GROUP" "PATH"
  for idx in {1..${#paths[@]}}; do
    printf "%-${w_oct}s  %-${w_sym}s  %-${w_own}s  %-${w_grp}s  %s\n" \
      "${r_oct[idx]}" "${r_sym[idx]}" "${r_own[idx]}" "${r_grp[idx]}" "${r_path[idx]}"
    echo
    echo "Access: who gets which rights (UNIX bits or ACL), after the ACL mask"
    printf "  %-${w_type}s  %-${w_name}s  %-${w_ent}s  %-${w_eff}s  %s\n" "TYPE" "NAME" "ENTRY" "EFFECTIVE" "SOURCE"
    for line in "${(@f)rows[idx]}"; do
      f=("${(@s:|:)line}")
      printf "  %-${w_type}s  %-${w_name}s  %-${w_ent}s  %-${w_eff}s  %s\n" "${f[1]}" "${f[2]}" "${f[3]}" "${f[4]}" "${f[5]}"
    done

    if [[ -n "${grows[idx]}" ]]; then
      w_gn=5; w_ge=9
      g_names=(); g_effs=(); g_users=()
      for line in "${(@f)grows[idx]}"; do
        f=("${(@s:|:)line}")
        gn="${f[1]}"; ge="${f[2]}"
        gu=$(_show_perms_group_members "$gn")
        g_names+=("$gn"); g_effs+=("$ge"); g_users+=("${gu:-(none)}")
        (( ${#gn} > w_gn )) && w_gn=${#gn}
      done
      echo
      echo "Groups: members of the groups involved in the access above"
      printf "  %-${w_gn}s  %-${w_ge}s  %s\n" "GROUP" "EFFECTIVE" "MEMBERS"
      for i in {1..${#g_names[@]}}; do
        printf "  %-${w_gn}s  %-${w_ge}s  %s\n" "${g_names[i]}" "${g_effs[i]}" "${g_users[i]}"
      done
    fi
    if (( idx < ${#paths[@]} )); then echo; fi
  done
  return 0
}

function general_help {
  echo "General helper functions:"
  printf "  %-36s %s\n" "disk_power_on_hours" "Show disk power-on hours"
  printf "  %-36s %s\n" "extractpath CMD" "Show command resolution"
  printf "  %-36s %s\n" "mkcdtemp [PREFIX]" "Create and enter temporary directory"
  printf "  %-36s %s\n" "backup_file PATH" "Create timestamped backup"
  printf "  %-36s %s\n" "retry N DELAY CMD [ARGS...]" "Retry command until success"
  printf "  %-36s %s\n" "stopwatch CMD [ARGS...]" "Run command and print elapsed time"
  printf "  %-36s %s\n" "json_pretty [FILE]" "Pretty-print JSON"
  printf "  %-36s %s\n" "urlencode TEXT" "URL-encode text"
  printf "  %-36s %s\n" "urldecode TEXT" "URL-decode text"
  printf "  %-36s %s\n" "fsize [PATH] [LIMIT]" "List largest files recursively"
  printf "  %-36s %s\n" "sysinfo_short" "Print compact system summary"
  printf "  %-36s %s\n" "psg PATTERN" "Search processes"
  printf "  %-36s %s\n" "cleanup_dsstore [PATH]" "Delete .DS_Store files recursively"
  printf "  %-36s %s\n" "weather [LOCATION]" "Show weather forecast"
  printf "  %-36s %s\n" "calc EXPRESSION" "Evaluate expression"
  printf "  %-36s %s\n" "pwgen -i [-e]" "Interactive generator (full or entropy-only mode)"
  printf "  %-36s %s\n" "verify_hash [-a ALGO] [FILE] [HASH]" "Verify file hash (interactive prompts)"
  printf "  %-36s %s\n" "show_perms [-p] [FOLDER]" "Show permissions, ACLs, effective rights per user/group"
}
