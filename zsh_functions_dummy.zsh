#!/bin/bash
# Dummy file generator for testing purposes.

# Create one or multiple dummy files with selectable default sizes and optional custom size.
dummyfiles() {
  emulate -L zsh
  setopt localoptions noxtrace no_notify no_monitor

  if ! command -v dd >/dev/null 2>&1; then
    echo "dummyfiles: dd command not found."
    return 1
  fi

  if ! command -v perl >/dev/null 2>&1; then
    echo "dummyfiles: perl command not found."
    return 1
  fi

  local target_dir base_name data_mode_choice data_source
  local block_size_input block_size_bytes
  local custom_size_input custom_size_bytes
  local source_input defaults_input repeat_input
  local selection token idx
  local use_interactive=1
  local -a default_sizes selected_sizes
  local -a cli_sizes positional_sizes

  # Parse human-readable size (SI/Binary units) and return bytes as integer.
  _dummy_parse_size_bytes() {
    local input="$1"
    local parsed

    parsed=$(perl -e '
      use strict;
      use warnings;

      my $s = shift // q{};
      $s =~ s/\s+//g;
      $s = lc $s;

      if ($s !~ /\A([0-9]+(?:\.[0-9]+)?)([kmgtpe]?i?b?)?\z/) {
        exit 1;
      }

      my ($n, $u) = ($1, defined $2 ? $2 : q{});
      my %m = (
        q{} => 1,
        b   => 1,
        k   => 1000,
        kb  => 1000,
        m   => 1000**2,
        mb  => 1000**2,
        g   => 1000**3,
        gb  => 1000**3,
        t   => 1000**4,
        tb  => 1000**4,
        p   => 1000**5,
        pb  => 1000**5,
        e   => 1000**6,
        eb  => 1000**6,
        ki  => 1024,
        kib => 1024,
        mi  => 1024**2,
        mib => 1024**2,
        gi  => 1024**3,
        gib => 1024**3,
        ti  => 1024**4,
        tib => 1024**4,
        pi  => 1024**5,
        pib => 1024**5,
        ei  => 1024**6,
        eib => 1024**6,
      );

      exit 1 if !exists $m{$u};

      my $bytes = $n * $m{$u};
      exit 1 if $bytes < 1;

      printf "%.0f\n", $bytes;
    ' -- "$input" 2>/dev/null)

    if [[ -z "$parsed" || "$parsed" != <-> ]]; then
      return 1
    fi

    echo "$parsed"
  }

  # Expand SIZE or SIZE*COUNT / SIZExCOUNT into one size per line.
  _dummy_expand_size_token() {
    local token="$1"
    local default_repeat="${2:-1}"
    local size_expr
    local repeat_count="$default_repeat"
    local -i i

    token="${token#"${token%%[![:space:]]*}"}"
    token="${token%"${token##*[![:space:]]}"}"
    if [[ -z "$token" ]]; then
      return 1
    fi

    size_expr="$token"
    if [[ "$size_expr" == *\*<-> ]]; then
      repeat_count="${size_expr##*\*}"
      size_expr="${size_expr%\*${repeat_count}}"
    elif [[ "$size_expr" == *[xX]<-> ]]; then
      repeat_count="${size_expr##*[xX]}"
      size_expr="${size_expr%[xX]${repeat_count}}"
    fi

    size_expr="${size_expr#"${size_expr%%[![:space:]]*}"}"
    size_expr="${size_expr%"${size_expr##*[![:space:]]}"}"

    if [[ -z "$size_expr" || "$repeat_count" != <-> || "$repeat_count" -lt 1 ]]; then
      return 1
    fi

    _dummy_parse_size_bytes "$size_expr" >/dev/null || return 1

    for ((i=1; i<=repeat_count; i++)); do
      echo "$size_expr"
    done
  }

  default_sizes=("1MiB" "10MiB" "100MiB" "1GiB" "5GiB")

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--interactive)
        use_interactive=1
        ;;
      -d|--dir)
        shift
        if [[ -z "$1" ]]; then
          echo "Missing value for --dir"
          return 1
        fi
        target_dir="$1"
        use_interactive=0
        ;;
      -n|--name)
        shift
        if [[ -z "$1" ]]; then
          echo "Missing value for --name"
          return 1
        fi
        base_name="$1"
        use_interactive=0
        ;;
      -s|--source)
        shift
        if [[ -z "$1" ]]; then
          echo "Missing value for --source"
          return 1
        fi
        source_input="$1"
        use_interactive=0
        ;;
      -b|--block-size)
        shift
        if [[ -z "$1" ]]; then
          echo "Missing value for --block-size"
          return 1
        fi
        block_size_input="$1"
        use_interactive=0
        ;;
      -r|--repeat)
        shift
        if [[ -z "$1" ]]; then
          echo "Missing value for --repeat"
          return 1
        fi
        repeat_input="$1"
        use_interactive=0
        ;;
      -z|--size|--sizes)
        shift
        if [[ -z "$1" ]]; then
          echo "Missing value for --size/--sizes"
          return 1
        fi
        cli_sizes+=("$1")
        use_interactive=0
        ;;
      --defaults)
        shift
        if [[ -z "$1" ]]; then
          echo "Missing value for --defaults"
          return 1
        fi
        defaults_input="$1"
        use_interactive=0
        ;;
      -h|--help)
        echo "Usage:"
        printf "  %-36s %s\n" "dummyfiles" "# interactive mode"
        printf "  %-36s %s\n" "dummyfiles [options] [SIZE ...]" "# non-interactive mode"
        echo
        echo "Options:"
        printf "  %-36s %s\n" "-i, --interactive" "Force interactive mode"
        printf "  %-36s %s\n" "-d, --dir DIR" "Target directory"
        printf "  %-36s %s\n" "-n, --name NAME" "Base filename (default: dummy)"
        printf "  %-36s %s\n" "-s, --source zero|random|/dev/path" "Data source (default: zero)"
        printf "  %-36s %s\n" "-b, --block-size SIZE" "dd block size (default: 1MiB)"
        printf "  %-36s %s\n" "-r, --repeat N" "Repeat each size token N times (non-interactive)"
        printf "  %-36s %s\n" "-z, --size SIZE_LIST" "File size(s), repeatable; supports comma lists"
        printf "  %-36s %s\n" "" "Per-size repeat: append xN or *N (safe: 1GiBx3)"
        printf "  %-36s %s\n" "--defaults all|1,3,5" "Include default menu sizes"
        printf "  %-36s %s\n" "" "Defaults: 1=1MiB, 2=10MiB, 3=100MiB, 4=1GiB, 5=5GiB"
        printf "  %-36s %s\n" "" "zsh note: unquoted * is globbing; use xN, quote *N, or prefix with noglob"
        printf "  %-36s %s\n" "" "Why: interactive mode reads raw input; CLI args are expanded by zsh before dummyfiles runs"
        printf "  %-36s %s\n" "" "For CLI *N use: -z 2GiBx2, -z \"2GiB*2\", or: noglob dummyfiles ... -z 2GiB*2"
        printf "  %-36s %s\n" "-h, --help" "Show this help"
        echo
        echo "Examples:"
        echo "  dummyfiles -d ~/Temp -n test -s random -b 4MiB --defaults 1,3 -z 25MB,25MiB -z 55KiB"
        echo "  dummyfiles -d /tmp -n load -z 1GiBx3,500MiBx2"
        echo "  noglob dummyfiles -d /tmp -n load -z 1GiB*3"
        echo "  dummyfiles -d /tmp -n load -r 3 -z 1GiB"
        echo "  dummyfiles -d /tmp -s zero 10MiB 100MiB"
        return 0
        ;;
      --)
        shift
        if [[ $# -gt 0 ]]; then
          positional_sizes+=("$@")
          use_interactive=0
        fi
        break
        ;;
      -*)
        echo "Unknown option: $1"
        echo "Use --help for syntax."
        return 1
        ;;
      *)
        positional_sizes+=("$1")
        use_interactive=0
        ;;
    esac
    shift
  done

  if [[ $use_interactive -eq 0 ]]; then
    local -i repeat_multiplier=1

    target_dir=${target_dir:-.}
    target_dir="${target_dir#"${target_dir%%[![:space:]]*}"}"
    target_dir="${target_dir%"${target_dir##*[![:space:]]}"}"
    target_dir=${~target_dir}
    if [[ ! -d "$target_dir" ]]; then
      mkdir -p "$target_dir" || {
        echo "Could not create directory: $target_dir"
        return 1
      }
    fi

    base_name=${base_name:-dummy}

    source_input=${source_input:-zero}
    case "${source_input:l}" in
      zero) data_source="/dev/zero" ;;
      random) data_source="/dev/urandom" ;;
      /dev/*)
        data_source="$source_input"
        ;;
      *)
        echo "Invalid source: $source_input (allowed: zero, random, /dev/*)"
        return 1
        ;;
    esac

    block_size_input=${block_size_input:-1MiB}
    block_size_bytes=$(_dummy_parse_size_bytes "$block_size_input") || {
      echo "Invalid block size: $block_size_input"
      echo "Examples: 4096, 4KiB, 1MiB, 2MB"
      return 1
    }

    if [[ -n "$repeat_input" ]]; then
      if [[ "$repeat_input" != <-> || "$repeat_input" -lt 1 ]]; then
        echo "Invalid repeat value: $repeat_input (must be integer >= 1)"
        return 1
      fi
      repeat_multiplier=$repeat_input
    fi

    if [[ -n "$defaults_input" ]]; then
      defaults_input=${defaults_input// /}
      if [[ "${defaults_input:l}" == "all" || "${defaults_input:l}" == "a" ]]; then
        selected_sizes+=("${default_sizes[@]}")
      else
        local -a default_tokens
        default_tokens=(${(s:,:)defaults_input})
        for token in "${default_tokens[@]}"; do
          if [[ "$token" != <-> ]]; then
            echo "Invalid defaults token: $token"
            return 1
          fi

          idx=$((token))
          if (( idx < 1 || idx > ${#default_sizes[@]} )); then
            echo "Defaults selection out of range: $token"
            return 1
          fi

          selected_sizes+=("${default_sizes[idx]}")
        done
      fi
    fi

    if (( ${#cli_sizes[@]} > 0 )); then
      local cli_entry
      local -a cli_tokens
      for cli_entry in "${cli_sizes[@]}"; do
        cli_tokens=(${(s:,:)cli_entry})
        for token in "${cli_tokens[@]}"; do
          token="${token#"${token%%[![:space:]]*}"}"
          token="${token%"${token##*[![:space:]]}"}"
          if [[ -z "$token" ]]; then
            echo "Invalid size list: empty entry found."
            return 1
          fi
          local expanded_output
          local -a expanded_sizes
          expanded_output=$(_dummy_expand_size_token "$token" "$repeat_multiplier") || {
            echo "Invalid custom size: $token"
            return 1
          }
          expanded_sizes=(${(f)expanded_output})
          selected_sizes+=("${expanded_sizes[@]}")
        done
      done
    fi

    if (( ${#positional_sizes[@]} > 0 )); then
      local pos_entry
      local -a pos_tokens
      for pos_entry in "${positional_sizes[@]}"; do
        pos_tokens=(${(s:,:)pos_entry})
        for token in "${pos_tokens[@]}"; do
          token="${token#"${token%%[![:space:]]*}"}"
          token="${token%"${token##*[![:space:]]}"}"
          if [[ -z "$token" ]]; then
            echo "Invalid positional size list: empty entry found."
            return 1
          fi
          local expanded_output
          local -a expanded_sizes
          expanded_output=$(_dummy_expand_size_token "$token" "$repeat_multiplier") || {
            echo "Invalid size argument: $token"
            return 1
          }
          expanded_sizes=(${(f)expanded_output})
          selected_sizes+=("${expanded_sizes[@]}")
        done
      done
    fi
  else

    read -r "target_dir?Target directory [.]: "
    target_dir=${target_dir:-.}
    target_dir="${target_dir#"${target_dir%%[![:space:]]*}"}"
    target_dir="${target_dir%"${target_dir##*[![:space:]]}"}"
    target_dir=${~target_dir}
    if [[ ! -d "$target_dir" ]]; then
      mkdir -p "$target_dir" || {
        echo "Could not create directory: $target_dir"
        return 1
      }
    fi

    read -r "base_name?Base filename [dummy]: "
    base_name=${base_name:-dummy}

    echo "Select data source:"
    echo "1) zero (/dev/zero)"
    echo "2) random (/dev/urandom)"
    read -r "data_mode_choice?Choice (1-2) [1]: "
    data_mode_choice=${data_mode_choice:-1}
    case "$data_mode_choice" in
      1) data_source="/dev/zero" ;;
      2) data_source="/dev/urandom" ;;
      *)
        echo "Invalid data source selection."
        return 1
        ;;
    esac

    read -r "block_size_input?Block size for dd [1MiB]: "
    block_size_input=${block_size_input:-1MiB}
    block_size_bytes=$(_dummy_parse_size_bytes "$block_size_input") || {
      echo "Invalid block size: $block_size_input"
      echo "Examples: 4096, 4KiB, 1MiB, 2MB"
      return 1
    }

    echo
    echo "Default file sizes:"
    local i=1
    for token in "${default_sizes[@]}"; do
      echo "$i) $token"
      ((i++))
    done
    echo "c) custom size"
    echo "a) all defaults"
    echo "Enter a subset as comma-separated values (example: 1,3,c)"

    read -r "selection?Selection: "
    selection=${selection// /}
    if [[ -z "$selection" ]]; then
      echo "No selection provided."
      return 1
    fi

    if [[ "$selection" == "a" || "$selection" == "A" ]]; then
      selected_sizes=("${default_sizes[@]}")
    else
      local include_custom=0
      local -a items
      items=(${(s:,:)selection})

      for token in "${items[@]}"; do
        if [[ "$token" == "c" || "$token" == "C" ]]; then
          include_custom=1
          continue
        fi

        if [[ "$token" != <-> ]]; then
          echo "Invalid selection token: $token"
          return 1
        fi

        idx=$((token))
        if (( idx < 1 || idx > ${#default_sizes[@]} )); then
          echo "Selection out of range: $token"
          return 1
        fi

        selected_sizes+=("${default_sizes[idx]}")
      done

      if (( include_custom == 1 )); then
        read -r "custom_size_input?Custom size(s) (SI/Binary; comma-separated; supports *N/xN, e.g. 500MB,2GiB*2,55KiB): "

        local -a custom_items
        local custom_item
        local -i custom_added=0
        custom_items=(${(s:,:)custom_size_input})

        for custom_item in "${custom_items[@]}"; do
          custom_item="${custom_item#"${custom_item%%[![:space:]]*}"}"
          custom_item="${custom_item%"${custom_item##*[![:space:]]}"}"

          if [[ -z "$custom_item" ]]; then
            echo "Invalid custom size list: empty entry found."
            return 1
          fi

          local expanded_output
          local -a expanded_sizes
          expanded_output=$(_dummy_expand_size_token "$custom_item") || {
            echo "Invalid custom size: $custom_item"
            return 1
          }

          expanded_sizes=(${(f)expanded_output})
          selected_sizes+=("${expanded_sizes[@]}")
          custom_added=$((custom_added + ${#expanded_sizes[@]}))
        done

        if (( custom_added == 0 )); then
          echo "No custom size provided."
          return 1
        fi
      fi
    fi
  fi

  if (( ${#selected_sizes[@]} == 0 )); then
    echo "No file size selected."
    return 1
  fi

  local size_label size_bytes count out_file clean_label
  local file_index
  local worker_pid
  local -i spinner_available=0
  local -A size_label_counts

  if (( $+functions[spinner_progress_wait] )) || whence -w spinner_progress_wait >/dev/null 2>&1; then
    spinner_available=1
  fi

  for size_label in "${selected_sizes[@]}"; do
    size_bytes=$(_dummy_parse_size_bytes "$size_label") || {
      echo "Skipping invalid size: $size_label"
      continue
    }

    count=$(( (size_bytes + block_size_bytes - 1) / block_size_bytes ))
    clean_label=${size_label// /}
    clean_label=${clean_label//\//_}
    size_label_counts[$clean_label]=$(( ${size_label_counts[$clean_label]:-0} + 1 ))
    file_index=${size_label_counts[$clean_label]}
    if (( file_index > 1 )); then
      out_file="$target_dir/${base_name}_${clean_label}_${file_index}.bin"
    else
      out_file="$target_dir/${base_name}_${clean_label}.bin"
    fi

    (
      dd if="$data_source" of="$out_file" bs="$block_size_bytes" count="$count" 2>/dev/null || exit 1

      if command -v truncate >/dev/null 2>&1; then
        truncate -s "$size_bytes" "$out_file"
      else
        if ! command -v perl >/dev/null 2>&1; then
          echo "Failed to create: perl is required when truncate is unavailable."
          exit 1
        fi
        perl -e 'truncate($ARGV[0], $ARGV[1]) or die "truncate failed\n"' "$out_file" "$size_bytes"
      fi
    ) &
    worker_pid=$!

    if [[ -t 1 && $spinner_available -eq 1 ]]; then
      if ! spinner_progress_wait "$worker_pid" "$out_file" "$size_bytes" "Creating $out_file ($size_label)"; then
        echo "Failed to create: $out_file"
        continue
      fi
    else
      wait "$worker_pid"
      if [[ $? -ne 0 ]]; then
        echo "Failed to create: $out_file"
        continue
      fi
      echo "Done: $out_file"
    fi
  done
}

# -------------------------------------------------------------------
# show available dummy helper functions
# -------------------------------------------------------------------
dummy_help() {
  echo "Dummy helper functions:"
  printf "  %-36s %s\n" "dummyfiles" "Create one or more dummy files"
}

