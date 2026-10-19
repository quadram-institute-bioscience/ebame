#!/bin/bash

# EBAME user-level setup — called from deploy.sh during the Deployment phase.
# Configures dotfiles, environment variables, and per-user tools.

source /etc/os-release
LOCUSER=${LOCUSER:-$ID}
LOCUSER_HOME=`eval echo "~$LOCUSER"`
VMNAME="${VMNAME:-EBAME}"

setup_screenrc() {
  local dst="$LOCUSER_HOME/.screenrc"
  if [[ ! -e "$dst" ]]; then
    curl -o "$dst" -sSL \
      "https://gist.githubusercontent.com/telatin/58ba9b07765a8f30b4a06eac1a39ff5e/raw/b4c39bbac20634d66509a6b848e343919076abc6/.screenrc"
  fi
}

setup_tmux_conf() {
  local dst="$LOCUSER_HOME/.tmux.conf"
  if [[ ! -e "$dst" ]]; then
    curl -o "$dst" -sSL \
      "https://gist.githubusercontent.com/telatin/34431aefae197284cecdb08f3017897f/raw/f522f744673598eb9219f2f85ebb0f5439fdcdfd/.tmux.conf"
  fi
}

setup_env_vars() {
  local bashrc="$LOCUSER_HOME/.bashrc"
  local virome_path

  if [[ -d /ifb/data/public/teachdata/ebame/viral-metagenomics ]]; then
    virome_path=/ifb/data/public/teachdata/ebame/viral-metagenomics
  elif [[ -d $LOCUSER_HOME/data/ebame8/virome ]]; then
    virome_path=$LOCUSER_HOME/data/ebame8/virome
  else
    virome_path=$LOCUSER_HOME/virome
  fi

  grep -q '^export VIROME=' "$bashrc" 2>/dev/null \
    || echo "export VIROME=$virome_path" >> "$bashrc"

  grep -q '^export DB=' "$bashrc" 2>/dev/null \
    || echo 'export DB=$HOME/db' >> "$bashrc"

  grep -q 'PATH.*HOME/.local/bin.*HOME/bin' "$bashrc" 2>/dev/null \
    || echo 'export PATH=$PATH:$HOME/.local/bin:$HOME/bin/' >> "$bashrc"

  grep -q 'shopt -s direxpand' "$bashrc" 2>/dev/null \
    || echo 'shopt -s direxpand' >> "$bashrc"
}

setup_hostname_customization() {
  local bashrc="$LOCUSER_HOME/.bashrc"
  sed -i.bak "s|\\\\h|${VMNAME}-VMs|" "$bashrc"
}

setup_database_symlinks() {
  mkdir -p "$LOCUSER_HOME/db"
  local ibis=/ifb/data/public/teachdata/ebame/viral-metagenomics

  if [[ -d "$ibis" ]]; then
    ln -sfn "$ibis/genomad_db" "$LOCUSER_HOME/db/genomad_db"
    ln -sfn "$ibis/checkv-db-v1.5" "$LOCUSER_HOME/db/checkv-db-v1.5"
  fi
}

setup_miniforge_ownership() {
  if [[ -d /var/lib/miniforge ]]; then
    chown -R "$LOCUSER:$LOCUSER" /var/lib/miniforge
  fi
}

setup_zoxide_init() {
  local bashrc="$LOCUSER_HOME/.bashrc"
  if command -v zoxide >/dev/null 2>&1; then
    grep -q 'zoxide init bash' "$bashrc" 2>/dev/null \
      || echo 'eval "$(zoxide init bash)"' >> "$bashrc"
  fi
}

setup_screenrc
setup_tmux_conf
setup_env_vars
setup_hostname_customization
setup_database_symlinks
setup_miniforge_ownership
setup_zoxide_init

chown -R "$LOCUSER:$LOCUSER" "$LOCUSER_HOME/.screenrc" "$LOCUSER_HOME/.tmux.conf" "$LOCUSER_HOME/.bashrc" 2>/dev/null