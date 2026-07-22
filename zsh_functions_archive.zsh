#!/bin/bash
## Archive helper functions for zsh

extract() {
        emulate -L zsh

        local archive="$1"

        if [[ -z "$archive" || "$archive" == "-h" || "$archive" == "--help" ]]; then
                _arch_usage "extract <archive_file>" "Extracts known archive types into current directory."
                return 0
        fi

        if [[ ! -f "$archive" ]]; then
                echo "'$archive' is not a valid file"
                return 1
        fi

        case "$archive" in
            *.tar.bz2)
                tar xvjf "$archive"
                ;;
            *.tar.gz)
                tar xvzf "$archive"
                ;;
            *.tar.xz)
                tar xvJf "$archive"
                ;;
            *.tar.lzma)
                tar --lzma xvf "$archive"
                ;;
            *.bz2)
                if ! command -v bunzip2 >/dev/null 2>&1; then
                        echo "bunzip2 command not found."
                        return 1
                fi
                bunzip2 "$archive"
                ;;
            *.rar)
                if ! command -v unrar >/dev/null 2>&1; then
                        echo "unrar command not found."
                        return 1
                fi
                unrar x "$archive"
                ;;
            *.gz)
                gunzip "$archive"
                ;;
            *.tar)
                tar xvf "$archive"
                ;;
            *.tbz2)
                tar xvjf "$archive"
                ;;
            *.tgz)
                tar xvzf "$archive"
                ;;
            *.zip)
                if ! command -v unzip >/dev/null 2>&1; then
                        echo "unzip command not found."
                        return 1
                fi
                unzip "$archive"
                ;;
            *.Z)
                if ! command -v uncompress >/dev/null 2>&1; then
                        echo "uncompress command not found."
                        return 1
                fi
                uncompress "$archive"
                ;;
            *.7z)
                if ! command -v 7z >/dev/null 2>&1; then
                        echo "7z command not found."
                        return 1
                fi
                7z x "$archive"
                ;;
            *.dmg)
                if [[ "$(uname)" != "Darwin" ]]; then
                        echo "dmg mount is only supported on macOS."
                        return 1
                fi
                hdiutil mount "$archive"
                ;;
            *)
                echo "'$archive' cannot be extracted via extract"
                return 1
                ;;
        esac
}

# Internal usage printer to keep help output consistent.
_arch_usage() {
    echo "Usage: $1"
    if [[ -n "$2" ]]; then
        echo "$2"
    fi
}

# -------------------------------------------------------------------
# create archive from files/directories
# -------------------------------------------------------------------
arch_create() {
    emulate -L zsh

    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        _arch_usage "arch_create <format> <output_archive> <input...>" "Formats: tar.gz | tgz | tar.xz | txz | tar.bz2 | tbz2 | zip | 7z"
        return 0
    fi

    local format="$1"
    local output="$2"
    shift 2

    if [[ -z "$format" || -z "$output" || $# -lt 1 ]]; then
        _arch_usage "arch_create <format> <output_archive> <input...>" "Formats: tar.gz | tgz | tar.xz | txz | tar.bz2 | tbz2 | zip | 7z"
        return 1
    fi

    case "${format:l}" in
        tar.gz|tgz)
            tar -czf "$output" "$@"
            ;;
        tar.xz|txz)
            tar -cJf "$output" "$@"
            ;;
        tar.bz2|tbz2)
            tar -cjf "$output" "$@"
            ;;
        zip)
            if ! command -v zip >/dev/null 2>&1; then
                echo "zip command not found."
                return 1
            fi
            zip -r "$output" "$@"
            ;;
        7z)
            if ! command -v 7z >/dev/null 2>&1; then
                echo "7z command not found."
                return 1
            fi
            7z a "$output" "$@"
            ;;
        *)
            echo "Unsupported format: $format"
            _arch_usage "arch_create <format> <output_archive> <input...>" "Formats: tar.gz | tgz | tar.xz | txz | tar.bz2 | tbz2 | zip | 7z"
            return 1
            ;;
    esac
}

# -------------------------------------------------------------------
# list archive content
# -------------------------------------------------------------------
arch_list() {
    emulate -L zsh

    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        _arch_usage "arch_list <archive_file>" "Lists archive content without extraction."
        return 0
    fi

    local archive="$1"
    if [[ -z "$archive" ]]; then
        _arch_usage "arch_list <archive_file>" "Lists archive content without extraction."
        return 1
    fi

    if [[ ! -f "$archive" ]]; then
        echo "Archive not found: $archive"
        return 1
    fi

    case "$archive" in
        *.tar|*.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar.bz2|*.tbz2|*.tar.lzma)
            tar -tf "$archive"
            ;;
        *.zip)
            if ! command -v unzip >/dev/null 2>&1; then
                echo "unzip command not found."
                return 1
            fi
            unzip -l "$archive"
            ;;
        *.7z)
            if ! command -v 7z >/dev/null 2>&1; then
                echo "7z command not found."
                return 1
            fi
            7z l "$archive"
            ;;
        *)
            echo "Unsupported archive type: $archive"
            return 1
            ;;
    esac
}

# -------------------------------------------------------------------
# test archive integrity
# -------------------------------------------------------------------
arch_test() {
    emulate -L zsh

    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        _arch_usage "arch_test <archive_file>" "Checks archive integrity where supported."
        return 0
    fi

    local archive="$1"
    if [[ -z "$archive" ]]; then
        _arch_usage "arch_test <archive_file>" "Checks archive integrity where supported."
        return 1
    fi

    if [[ ! -f "$archive" ]]; then
        echo "Archive not found: $archive"
        return 1
    fi

    case "$archive" in
        *.tar|*.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar.bz2|*.tbz2|*.tar.lzma)
            tar -tf "$archive" >/dev/null
            ;;
        *.zip)
            if ! command -v unzip >/dev/null 2>&1; then
                echo "unzip command not found."
                return 1
            fi
            unzip -t "$archive"
            ;;
        *.7z)
            if ! command -v 7z >/dev/null 2>&1; then
                echo "7z command not found."
                return 1
            fi
            7z t "$archive"
            ;;
        *.gz)
            gzip -t "$archive"
            ;;
        *.bz2)
            bzip2 -t "$archive"
            ;;
        *.xz)
            xz -t "$archive"
            ;;
        *)
            echo "Unsupported archive type: $archive"
            return 1
            ;;
    esac

    local ret=$?
    if [[ $ret -eq 0 ]]; then
        echo "OK: archive integrity check passed"
    else
        echo "ERR: archive integrity check failed"
    fi
    return $ret
}

# -------------------------------------------------------------------
# extract archive to a target directory
# -------------------------------------------------------------------
arch_extract_to() {
    emulate -L zsh

    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        _arch_usage "arch_extract_to <archive_file> <target_directory>" "Extracts archive into target directory."
        return 0
    fi

    local archive="$1"
    local target_dir="$2"

    if [[ -z "$archive" || -z "$target_dir" ]]; then
        _arch_usage "arch_extract_to <archive_file> <target_directory>" "Extracts archive into target directory."
        return 1
    fi

    if [[ ! -f "$archive" ]]; then
        echo "Archive not found: $archive"
        return 1
    fi

    mkdir -p "$target_dir" || {
        echo "Could not create target directory: $target_dir"
        return 1
    }

    case "$archive" in
        *.tar.bz2|*.tbz2)
            tar -xjf "$archive" -C "$target_dir"
            ;;
        *.tar.gz|*.tgz)
            tar -xzf "$archive" -C "$target_dir"
            ;;
        *.tar.xz|*.txz)
            tar -xJf "$archive" -C "$target_dir"
            ;;
        *.tar.lzma)
            tar --lzma -xvf "$archive" -C "$target_dir"
            ;;
        *.tar)
            tar -xf "$archive" -C "$target_dir"
            ;;
        *.zip)
            if ! command -v unzip >/dev/null 2>&1; then
                echo "unzip command not found."
                return 1
            fi
            unzip "$archive" -d "$target_dir"
            ;;
        *.7z)
            if ! command -v 7z >/dev/null 2>&1; then
                echo "7z command not found."
                return 1
            fi
            7z x "$archive" "-o$target_dir"
            ;;
        *.rar)
            if ! command -v unrar >/dev/null 2>&1; then
                echo "unrar command not found."
                return 1
            fi
            unrar x "$archive" "$target_dir/"
            ;;
        *.gz)
            gunzip -c "$archive" > "$target_dir/${${archive:t}%.*}"
            ;;
        *.bz2)
            bunzip2 -c "$archive" > "$target_dir/${${archive:t}%.*}"
            ;;
        *.xz)
            unxz -c "$archive" > "$target_dir/${${archive:t}%.*}"
            ;;
        *.dmg)
            if [[ "$(uname)" != "Darwin" ]]; then
                echo "dmg extraction is only supported on macOS."
                return 1
            fi
            hdiutil attach "$archive"
            ;;
        *)
            echo "Unsupported archive type: $archive"
            return 1
            ;;
    esac
}

# -------------------------------------------------------------------
# help for archive helpers
# -------------------------------------------------------------------
arch_help() {
    echo "Archive helper functions:"
    printf "  %-36s %s\n" "extract ARCHIVE" "Extract supported archive in current directory"
    printf "  %-36s %s\n" "arch_create FORMAT OUTPUT INPUT..." "Create archive"
    printf "  %-36s %s\n" "arch_list ARCHIVE" "List archive contents"
    printf "  %-36s %s\n" "arch_test ARCHIVE" "Verify archive integrity"
    printf "  %-36s %s\n" "arch_extract_to ARCHIVE TARGET_DIR" "Extract archive into target directory"
    printf "  %-36s %s\n" "arch_help" "Show archive help"
}