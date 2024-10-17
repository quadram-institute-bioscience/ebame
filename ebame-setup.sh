#!/usr/bin/env bash

# EBAME VM Setup Script
# Author: Andrea Telatin
# Year: 2024
# Version: 1.0

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

# Define paths for EBAME datasets
VIROME1=/ifb/data/public/teachdata/ebame/viral-metagenomics
VIROME2=~/data/ebame8/virome

backup_file="$HOME/.bashrc.backup"
suffix=1

# Find a unique backup file name
while [[ -e "${backup_file}.${suffix}" ]]; do
    ((suffix++))
done

TAG="${VMNAME}-${suffix}"

cp "$HOME/.bashrc" "${backup_file}.${suffix}"
cd "$HOME" || exit


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

write_log "$TAG" "Starting EBAME setup script"


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
echo -e "\033[1;32m---\t\033[0m EBAME-9 Virome Workshop \033[1;32m---\033[0m \n"

if [[ -d $VIROME1 ]]; then
    VIROME=$VIROME1
    green_bold "OK" "Biosphere site detected"
elif [[ -d $VIROME2 ]]; then
    VIROME=$VIROME2
    green_bold "OK" "Biosphere site detected (2)"
else
    red_bold "ERROR" "Cannot figure out if you are in an EBAME VM (Biosphere)"
    exit 1
fi
write_log "$TAG" "Location: $VIROME"
yellow_bold "NOTE" "Shortcut to our dataset is in \033[1;32m\$VIROME\033[0m"

# First, add a string to ~/.bashrc

mkdir -p ~/bin/
if [[ -d "$VIROME"/bin ]]; then
    if [[ ! -e "$HOME"/bin/seqfu ]]; then
        ln -s "$VIROME"/bin/* ~/bin/
        green_bold "OK" "Linked \$VIROME/bin to ~/bin"
        
    fi
fi
FILE=~/.bashrc


STRING='shopt -s direxpand'
# append STRING to FILE
if grep -q "$STRING" "$FILE"; then
    green_bold "OK" ".bashrc already updated"
    write_log "$TAG" "direxpand - existed"
else
    echo "$STRING" >> "$FILE"
    echo "export VIROME=$VIROME" >> "$FILE"
    echo "shopt -s direxpand" >> "$FILE"
    green_bold "OK" "Updated settings in $FILE"
    write_log "$TAG" "direxpand - OK"
fi

# Second, install some programs

check_sudo
write_log "$TAG" "Checksudo"

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

sudo apt update 2>/dev/null 1>/dev/null

# Write a blue line ending with \r to be erased with the text "hello"


if sudo apt install -y --quiet unzip  bat visidata pv tree mc libpcre3-dev >/tmp/ebame-apt.out 2>/tmp/ebame-apt.err; then
    if [[ ! -e  ~/bin/bat ]]; then
        ln -s /usr/bin/batcat ~/bin/bat
        
    fi
    write_log "$TAG" "apt - OK"
    green_bold "OK" "Installed requirements"
else
    write_log "$TAG" "apt - failed"
    red_bold "ERROR" "unable to install requirements (you need unzip, visidata, libpcre3-dev)"
fi

# Install seqfu

URL="https://github.com/telatin/seqfu2/releases/download/v1.22.3/SeqFu-v1.22.3-Linux-x86_64.zip"
if [[ -e ~/bin/seqfu ]]; then
    VER=$("$HOME"/bin/seqfu version)
    green_bold "OK" "SeqFu already installed: $VER"
    write_log "$TAG" "apt - existing"
else
    if curl -sSL -o /tmp/seqfu.zip "$URL"; then
        unzip -q -d "$HOME"/ /tmp/seqfu.zip
        green_bold "OK" "Installed SeqFu"
        write_log "$TAG" "apt - OK"
    else
        red_bold "ERROR" "Could not install SeqFu"
        write_log "$TAG" "apt - failed"
    fi
fi

# add $HOME/bin to PATH in .bashrc
STRING='export PATH=$PATH:$HOME/bin/'
# append STRING to FILE
if grep -q "$STRING" "$FILE"; then
    touch /tmp/ebame-path.stone
else
    echo "$STRING" >> "$FILE"
    green_bold "OK" "Updated settings in $FILE"
fi



# Set up .screenrc configuration
if [[ ! -e ~/.screenrc ]]; then
    if curl -o ~/.screenrc -sSL "https://gist.githubusercontent.com/telatin/58ba9b07765a8f30b4a06eac1a39ff5e/raw/b4c39bbac20634d66509a6b848e343919076abc6/.bashrc"; then
        green_bold "OK" "Installed .screenrc just in case"
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

# Add screen status check to bash prompt
#check_and_append_in_screen
# zellij
wget --quiet "https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz"
tar xfz zellij-x86_64-unknown-linux-musl.tar.gz
mv zellij ~/bin/


sed -i.bak "s|\\\\h|${NAME}-VMs|" ~/.bashrc

# Function to check if Conda is already initialized in .bashrc
is_conda_initialized() {
    grep -q "# >>> conda initialize >>>" ~/.bashrc
}


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

# Final message
echo -e "\033[1;32m===\t\033[0m Setup completed \033[1;32m===\t\033[0m"
echo ""
yellow_bold "TO DO" "To ensure all changes take effect, please restart your terminal session or run:"
echo "----------------"
echo "source ~/.bashrc"
echo "----------------"