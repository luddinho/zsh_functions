#!/bin/bash
# Functions for managing SSH keys

# Update the comment of an existing SSH key
function sshkey_update_comment {
  if [[ $# -lt 2 ]]; then
    echo "Usage: sshkey_update_comment <keyfile> <new_comment>"
    return 1
  fi
  local keyfile="$1"
  local new_comment="$2"
  if [[ ! -f "$keyfile" ]]; then
    echo "Keyfile not found: $keyfile"
    return 1
  fi
  ssh-keygen -c -C "$new_comment" -f "$keyfile"
}

# Install a public key on a remote server
function sshkey_install_pubkey {
  if [[ $# -lt 4 ]]; then
    echo "Usage: sshkey_install_pubkey <pubkey_file> <user> <host> <port>"
    return 1
  fi
  local pubkey_file="$1"
  local user="$2"
  local host="$3"
  local port="$4"
  if [[ ! -f "$pubkey_file" ]]; then
    echo "Public key file not found: $pubkey_file"
    return 1
  fi
  cat "$pubkey_file" | ssh -p "$port" "$user@$host" install-ssh-key
}

# Export the public key from a private key file
function sshkey_export_pubkey {
  if [[ $# -lt 1 ]]; then
    echo "Usage: sshkey_export_pubkey <private_key_file> [output_pubkey_file]"
    return 1
  fi
  local privkey="$1"
  local pubkey="${2:-${privkey}.pub}"
  if [[ ! -f "$privkey" ]]; then
    echo "Private key file not found: $privkey"
    return 1
  fi
  ssh-keygen -y -f "$privkey" > "$pubkey"
  echo "Public key exported to: $pubkey"
}

# Change the password (passphrase) of an existing private key
function sshkey_update_password {
  if [[ $# -lt 1 ]]; then
    echo "Usage: sshkey_update_password <private_key_file>"
    return 1
  fi
  local privkey="$1"
  if [[ ! -f "$privkey" ]]; then
    echo "Private key file not found: $privkey"
    return 1
  fi
  ssh-keygen -p -f "$privkey"
}

# Create a new ed25519 SSH key with comment
function sshkey_create_ed25519 {
  if [[ $# -lt 2 ]]; then
    echo "Usage: sshkey_create_ed25519 <output_file> <comment>"
    return 1
  fi
  local output_file="$1"
  local comment="$2"
  ssh-keygen -t ed25519 -f "$output_file" -C "$comment"
}

# Show fingerprint and type of a public key
function sshkey_show_fingerprint {
  if [[ $# -lt 1 ]]; then
    echo "Usage: sshkey_show_fingerprint <pubkey_file>"
    return 1
  fi
  local pubkey="$1"
  if [[ ! -f "$pubkey" ]]; then
    echo "Public key file not found: $pubkey"
    return 1
  fi
  ssh-keygen -lf "$pubkey"
}

# Check whether a public key is already installed on a server
# Tries ~/.ssh/authorized_keys first; if unavailable, tries /home/.ssh/authorized_keys
function sshkey_check_on_server {
  if [[ $# -lt 4 ]]; then
    echo "Usage: sshkey_check_on_server <pubkey_file> <user> <host> <port>"
    return 1
  fi
  local pubkey_file="$1"
  local user="$2"
  local host="$3"
  local port="$4"
  local pubkey
  pubkey=$(cat "$pubkey_file")
  ssh -p "$port" "$user@$host" "
    if [ -f ~/.ssh/authorized_keys ]; then
      grep -qF '$pubkey' ~/.ssh/authorized_keys && echo 'Key found in ~/.ssh/authorized_keys' || echo 'Key not found in ~/.ssh/authorized_keys'
    elif [ -f /home/.ssh/authorized_keys ]; then
      grep -qF '$pubkey' /home/.ssh/authorized_keys && echo 'Key found in /home/.ssh/authorized_keys' || echo 'Key not found in /home/.ssh/authorized_keys'
    else
      echo 'authorized_keys file not found'
    fi
  "
}

# Remove a public key from authorized_keys on the server
function sshkey_remove_from_server {
  if [[ $# -lt 4 ]]; then
    echo "Usage: sshkey_remove_from_server <pubkey_file> <user> <host> <port>"
    return 1
  fi
  local pubkey_file="$1"
  local user="$2"
  local host="$3"
  local port="$4"
  local pubkey
  pubkey=$(cat "$pubkey_file")
  # Try ~/.ssh/authorized_keys first; if unavailable, try /home/.ssh/authorized_keys
  ssh -p "$port" "$user@$host" "
    if [ -f ~/.ssh/authorized_keys ]; then
      grep -vF '$pubkey' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys
      echo 'Key removed from ~/.ssh/authorized_keys'
    elif [ -f /home/.ssh/authorized_keys ]; then
      grep -vF '$pubkey' /home/.ssh/authorized_keys > /home/.ssh/authorized_keys.tmp && mv /home/.ssh/authorized_keys.tmp /home/.ssh/authorized_keys
      echo 'Key removed from /home/.ssh/authorized_keys'
    else
      echo 'authorized_keys file not found'
    fi
  "
}

# List all public SSH keys in the .ssh directory
function sshkey_list {
find ~/.ssh -maxdepth 1 -type f -name "*.pub" 2>/dev/null
}

# Show all available SSH key helper functions with short descriptions
function sshkey_help {
  echo "SSH key helper functions:"
  printf "  %-36s %s\n" "sshkey_update_comment" "Update key comment"
  printf "  %-36s %s\n" "sshkey_install_pubkey" "Install public key on server"
  printf "  %-36s %s\n" "sshkey_export_pubkey" "Export public key from private key"
  printf "  %-36s %s\n" "sshkey_update_password" "Change private key passphrase"
  printf "  %-36s %s\n" "sshkey_create_ed25519" "Create ed25519 key"
  printf "  %-36s %s\n" "sshkey_show_fingerprint" "Show public key fingerprint"
  printf "  %-36s %s\n" "sshkey_check_on_server" "Check key presence in authorized_keys"
  printf "  %-36s %s\n" "sshkey_remove_from_server" "Remove key from authorized_keys"
  printf "  %-36s %s\n" "sshkey_list" "List local public keys"
}