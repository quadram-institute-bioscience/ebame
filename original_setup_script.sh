
#!/usr/bin/env bash
VERSION=2.8
# EBAME VM Setup Script
# Author: Andrea Telatin
# Year: 2026
# Version: 2.8

# Description:
# This script sets up Virtual Machines (VMs) for the EBAME (European Bioinformatics Array of Microbial Ecology) workshop,
# focusing on viral metagenomics. It performs the following tasks:
# 1. Detects the EBAME environment and sets up dataset shortcuts
# 2. Configures bash environment and screen settings
# 3. Installs necessary software dependencies
# 4. Sets up SeqFu, a sequence manipulation toolkit
# 5. Configures screen for better usability
# 6. Performs system checks (sudo privileges, Ubuntu version, available memory)

# Get an optional VM name
# Check if a parameter was provided
if [ $# -eq 0 ]; then
    # No parameter provided, use default value
    VMNAME="EBAME"
else
    # Parameter provided, use it
    VMNAME="$1"
fi

# Ensure HOME is set: some provisioning environments (cloud-init, sudo, agents)
# leave it empty, which makes "$HOME/bin" expand to /bin while "~" still
# resolves to the real home directory, breaking paths below.
if [ -z "${HOME:-}" ]; then
    HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
fi
export HOME



backup_file="$HOME/.bashrc.backup"
suffix=1

# Find a unique backup file name
while [[ -e "${backup_file}.${suffix}" ]]; do
    ((suffix++))
done

TAG="${VMNAME}-${suffix}"

cp "$HOME/.bashrc" "${backup_file}.${suffix}"
cd "$HOME" || exit
mkdir -p "$HOME/bin"


# function to write in green bold the first argument, and the second argument in normal text
green_bold () {
    printf "                            \r" &&    echo -e "\033[1;32m$1\t\033[0m $2"
}

red_bold () {
    printf "                            \r" &&    echo -e "\033[1;31m$1\t\033[0m $2"
}

yellow_bold () {
    printf "                            \r" &&    echo -e "\033[1;33m$1\t\033[0m $2"
}

write_log() {
    local tag="$1"
    local message="$2"
    local datetimestamp="[time]"
    datetimestamp="$(date +"%Y-%m-%d %H:%M:%S")"
    echo -e "$datetimestamp\t$message" >> /tmp/ebame-${tag}.log
}

write_log "$TAG" "Starting EBAME setup script ($VERSION)"


# Function to check for sudo privileges
check_sudo() {
    if sudo -n true 2>/dev/null; then
        green_bold "OK" "Sudo privileges available"
    else
        red_bold "ERROR" "This script requires sudo privileges"
        exit 1
    fi
}

check_and_append_in_screen() {
    local bashrc_file="$HOME/.bashrc"
    # shellcheck disable=SC2016
    local in_screen_function='
function in_screen() {
    if [ -n "$STY" ]; then
        echo "*"
    else
        echo "[no screen]"
    fi
}
'
    
# shellcheck disable=SC2016
local ps1_modification='PS1="$(in_screen)$PS1"'

# Check if in_screen function is already present
write_log "$TAG" "Check in_screen()"
if ! grep -q "function in_screen()" "$bashrc_file"; then
    echo "$in_screen_function" >> "$bashrc_file"
    echo "$ps1_modification" >> "$bashrc_file"

    if grep -q "function in_screen()" "$bashrc_file"; then
        green_bold "OK" "in_screen function added to .bashrc"
        write_log "$TAG" "Check in_screen() - OK"
    else
        yellow_bold "INFO" "Failed to add in_screen function to .bashrc, but do not worry"
        write_log "$TAG" "Check in_screen() - Failed"
    fi
else
    green_bold "OK" "in_screen function already exists in .bashrc. No changes made."
    write_log "$TAG" "Check in_screen() - existing"
fi

}

printf '\033[1;33m'
cat <<'EOF'
 _____ _                          
|  ___| |                         
| |__ | |__   __ _ _ __ ___   ___ 
|  __|| '_ \ / _` | '_ ` _ \ / _ \\
| |___| |_) | (_| | | | | | |  __/
\____/|_.__/ \__,_|_| |_| |_|\___|
                                  
                                  
EOF
printf '\033[0m'
echo -e "\033[1;32m---\t\033[0m EBAME-11 Virome Workshop ($VERSION) \033[1;32m---\033[0m \n"

# Workshop main directory: prefer the dataset mounted by the VM image
VIROME1=/ifb/data/public/teachdata/ebame/viral-metagenomics
VIROME2=~/data/ebame8/virome

if [[ -d "$VIROME1" ]]; then
    VIROME="$VIROME1"
    DOWNLOAD_TRAINING=0
    green_bold "OK" "Found mounted dataset: $VIROME"
elif [[ -d "$VIROME2" ]]; then
    VIROME="$VIROME2"
    DOWNLOAD_TRAINING=0
    green_bold "OK" "Found mounted dataset: $VIROME"
else
    VIROME=~/virome/
    DOWNLOAD_TRAINING=1
    mkdir -p "$VIROME"
    yellow_bold "WARN" "No mounted dataset found, falling back to $VIROME"
fi
write_log "$TAG" "Location: $VIROME"





# First, update .bashrc
FILE=~/.bashrc
STRING='shopt -s direxpand'
# append STRING to FILE
if grep -q "$STRING" "$FILE"; then
    green_bold "OK" ".bashrc already updated"
    write_log "$TAG" "direxpand - existed"
else
    echo "$STRING" >> "$FILE"
    echo "export VIROME=$VIROME" >> "$FILE"
    echo "export DB=~/db" >> "$FILE"
    echo "shopt -s direxpand" >> "$FILE"
    green_bold "OK" "Updated settings in $FILE"
    write_log "$TAG" "direxpand - OK"
fi

# Second, install some programs

check_sudo
write_log "$TAG" "Check sudo"

# Give the workshop user ownership of the Miniforge installation
if [[ -d /var/lib/miniforge ]]; then
    if sudo chown -R ubuntu:ubuntu /var/lib/miniforge; then
        green_bold "OK" "Set ownership of /var/lib/miniforge to ubuntu:ubuntu"
        write_log "$TAG" "miniforge chown - OK"
    else
        yellow_bold "WARN" "Could not change ownership of /var/lib/miniforge"
        write_log "$TAG" "miniforge chown - failed"
    fi
else
    yellow_bold "INFO" "/var/lib/miniforge not found, skipping chown"
    write_log "$TAG" "miniforge chown - not found"
fi

# CHECK UBUNTU
if grep "DISTRIB_DESCRIPTION" /etc/lsb-release > /dev/null 2> /dev/null; then
    green_bold "OK" "You are using $(grep DISTRIB_DESCRIPTION /etc/lsb-release | cut -f 2 -d '=')"
    write_log "$TAG" "Check ubuntu - OK"
else
    red_bold "ERROR" "Not Ubuntu?"
    write_log "$TAG" "Check ubuntu - failed"
    exit 1
fi

#CHECK MEMORY
# Get total memory in kB
total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# Convert kB to GB
total_mem_gb=$((total_mem / 1024 / 1024))

if [ $total_mem_gb -gt 30 ]; then
    green_bold "OK" "Total memory is greater than 30GB"
    write_log "$TAG" "Total memory - OK"
else
    yellow_bold "WARN" "Total memory is less than 32GB ($total_mem_gb GB)"
    write_log "$TAG" "Total memory - failed"
fi

yellow_bold "WAIT" "Starting to download packages... might take a while"
sudo apt update 2>/dev/null 1>/dev/null

# Write a blue line ending with \r to be erased with the text "hello"


if sudo apt install -y --quiet openjdk-21-jre-headless pipx unzip  bat visidata pv tree mc libpcre3-dev >/tmp/ebame-apt.out 2>/tmp/ebame-apt.err; then
    if [[ ! -e  ~/bin/bat ]]; then
        mkdir -p ~/bin
        ln -sf /usr/bin/batcat ~/bin/bat
        
    fi
    write_log "$TAG" "apt - OK"
    green_bold "OK" "Installed requirements"
else
    write_log "$TAG" "apt - failed"
    red_bold "ERROR" "unable to install requirements (you need unzip, visidata, libpcre3-dev)"
fi

# Optional tools: zoxide and fzf. Failures here are not critical.
if sudo apt install -y --quiet zoxide fzf >/tmp/ebame-apt-tools.out 2>/tmp/ebame-apt-tools.err; then
    write_log "$TAG" "apt tools - OK"
    green_bold "OK" "Installed zoxide and fzf"
else
    write_log "$TAG" "apt tools - failed"
    yellow_bold "INFO" "Could not install zoxide and fzf (not critical)"
fi

# Initialize zoxide in bash (only if zoxide is available)
if command -v zoxide >/dev/null 2>&1; then
    zoxide init bash >/dev/null 2>&1
    if grep -q 'eval "$(zoxide init bash)"' ~/.bashrc; then
        green_bold "OK" "zoxide already initialized in .bashrc"
    else
        echo 'eval "$(zoxide init bash)"' >> ~/.bashrc
        green_bold "OK" "Initialized zoxide in .bashrc"
    fi
else
    yellow_bold "INFO" "zoxide not found, skipping initialization"
fi

# Install seqfu

URL="https://github.com/quadram-institute-bioscience/seqfu_v1/releases/download/v1.30.3/seqfu-linux-x86_64"
if [[ -e ~/bin/seqfu ]]; then
    VER=$("$HOME"/bin/seqfu version)
    green_bold "OK" "SeqFu already installed: $VER"
    write_log "$TAG" "seqfu - existing"
else
    if curl -fsSL -o /tmp/seqfu "$URL" && chmod +x /tmp/seqfu && mv /tmp/seqfu "$HOME/bin/seqfu"; then
        green_bold "OK" "Installed SeqFu"
        write_log "$TAG" "seqfu installation - OK"
    else
        red_bold "ERROR" "Could not install SeqFu"
        write_log "$TAG" "seqfu installation - failed"
    fi
fi

# add $HOME/bin to PATH in .bashrc
STRING='export PATH=$PATH:$HOME/.local/bin:$HOME/bin/'
# append STRING to FILE
if grep -q "$STRING" "$FILE"; then
    touch /tmp/ebame-path.stone
else
    echo "$STRING" >> "$FILE"
    green_bold "OK" "Updated settings in $FILE"
fi



# Set up .screenrc configuration
if [[ ! -e ~/.screenrc ]]; then
    if curl -o ~/.screenrc -sSL "https://gist.githubusercontent.com/telatin/58ba9b07765a8f30b4a06eac1a39ff5e/raw/b4c39bbac20634d66509a6b848e343919076abc6/.screenrc"; then
        green_bold "OK" "Installed .screenrc"
    else
        red_bold "WARNING" "Could not install .screenrc"
    fi
else
    if grep -q "EBAME" ~/.screenrc; then
        green_bold "OK" "You already have a valid .screenrc"
    else
        red_bold "WARNING" "You already have a .screenrc, not the EBAME one"
    fi
fi

# Set up .tmux.conf configuration
if [[ ! -e ~/.tmux.conf ]]; then
    if curl -o ~/.tmux.conf -sSL "https://gist.githubusercontent.com/telatin/34431aefae197284cecdb08f3017897f/raw/f522f744673598eb9219f2f85ebb0f5439fdcdfd/.tmux.conf"; then
        green_bold "OK" "Installed .tmux.conf"
    else
        red_bold "WARNING" "Could not install .tmux.conf"
    fi
else
    green_bold "OK" "You already have a ~/.tmux.conf, not overwriting it"
fi

# Add screen status check to bash prompt
#check_and_append_in_screen

# zellij
wget --quiet "https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz"
tar xfz zellij-x86_64-unknown-linux-musl.tar.gz
mv zellij ~/bin/

sed -i.bak "s|\\\\h|${VMNAME}-VMs|" ~/.bashrc

# Function to check if Conda is already initialized in .bashrc
is_conda_initialized() {
    grep -q "# >>> conda initialize >>>" ~/.bashrc
}

# cleanup
for FILE in ~/zellij-x86_64-unknown-linux-musl.* /tmp/seqfu; 
do
    if [[ -e $FILE ]]; then
        rm "$FILE"
    fi
done

pipx install votuderep
if [[ "${DOWNLOAD_TRAINING:-0}" == "1" ]]; then
    "$HOME/.local/bin/votuderep" trainingdata --outdir "$VIROME/"
else
    green_bold "OK" "Using mounted dataset, skipping trainingdata download"
fi

# Silent Nextflow installation function
# Returns: 0 on success, 1 on failure
# Sets ERROR_MSG variable on failure
install_nf() {
    local bin_dir="$HOME/bin"
    local temp_dir
    
    # Create bin directory if it doesn't exist
    if ! mkdir -p "$bin_dir" 2>/dev/null; then
        ERROR_MSG="Failed to create directory: $bin_dir"
        return 1
    fi
    
    # Create temporary directory for download
    if ! temp_dir=$(mktemp -d 2>/dev/null); then
        ERROR_MSG="Failed to create temporary directory"
        return 1
    fi
    
    # Download Nextflow (silent mode with -s flag)
    cd "$temp_dir" || {
        ERROR_MSG="Failed to change to temporary directory"
        rm -rf "$temp_dir"
        return 1
    }
    
    if ! curl -fsSL https://get.nextflow.io | bash > /dev/null 2>&1; then
        ERROR_MSG="Failed to download Nextflow from https://get.nextflow.io"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Move to bin directory and make executable
    if ! mv nextflow "$bin_dir/nextflow" 2>/dev/null; then
        ERROR_MSG="Failed to move nextflow to $bin_dir"
        rm -rf "$temp_dir"
        return 1
    fi
    
    
    # Cleanup
    rm -rf "$temp_dir"

    return 0
}

# Call installation and print result
if install_nf; then
    green_bold "OK" "Nextflow installed successfully"
else
    red_bold "ERROR" "Nextflow installation failed: $ERROR_MSG"
fi

# Attempt to initialize Conda if necessary
if command -v conda >/dev/null 2>&1; then
    if is_conda_initialized; then
        green_bold "OK" "Conda is already initialized in .bashrc"
    else
        echo "Conda found but not initialized. Attempting to initialize..."
        if conda init bash >/dev/null 2>&1; then
            green_bold "OK" "Conda initialized successfully"

        else
            yellow_bold "WARNING" "Conda initialization failed: try 'conda init bash'"
      
        fi
    fi
else
    yellow_bold "INFO" "Conda not found, please manually run: '/var/lib/miniforge/bin/conda init'"
fi

# DOWNLOAD DATABASES
mkdir -p ~/db/

IBIS_PATH=/ifb/data/public/teachdata/ebame/viral-metagenomics/
if [ -d "$IBIS_PATH" ]; 
then
    # Cloudbis
    ln -sfn "${IBIS_PATH}/genomad_db" ~/db/genomad_db
    green_bold "OK" "Linked Genomad database from Cloudbis"
    write_log "$TAG" "Genomad link - OK"
    ln -sfn "${IBIS_PATH}/checkv-db-v1.5" ~/db/checkv-db-v1.5
    green_bold "OK" "Linked CheckV database from Cloudbis"
    write_log "$TAG" "CheckV link - OK"
else
    # Fallback: VM without the /ifb mount, download the databases
    yellow_bold "WARN" "No mounted databases found in ${IBIS_PATH}"
    if "$HOME/.local/bin/votuderep" getdbs -o ~/db/; then
        green_bold "OK" "Downloaded databases with votuderep getdbs"
        write_log "$TAG" "getdbs - OK"
    else
        red_bold "ERROR" "Could not download databases (run: votuderep getdbs -o ~/db/)"
        write_log "$TAG" "getdbs - failed"
    fi
fi


# Final message
echo -e "\033[1;32m===\t\033[0m Setup completed \033[1;32m===\t\033[0m"
echo ""
yellow_bold "TO DO" "To ensure all changes take effect, please restart your terminal session or run:"
echo "----------------"
echo "source ~/.bashrc"
echo "----------------"
yellow_bold "NOTE" "Shortcut to our dataset is in \033[1;32m\$VIROME\033[0m"
