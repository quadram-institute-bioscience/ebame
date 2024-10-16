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

# Define paths for EBAME datasets
VIROME1=/ifb/data/public/teachdata/ebame/viral-metagenomics
VIROME2=~/data/ebame8/virome

backup_file="$HOME/.bashrc.backup"
suffix=1

# Find a unique backup file name
while [[ -e "${backup_file}.${suffix}" ]]; do
    ((suffix++))
done

cp "$HOME/.bashrc" "${backup_file}.${suffix}"
cd "$HOME" || exit

# function to write in green bold the first argument, and the second argument in normal text
green_bold () {
    echo -e "\033[1;32m$1\t\033[0m $2"
}

red_bold () {
    echo -e "\033[1;31m$1\t\033[0m $2"
}

yellow_bold () {
    echo -e "\033[1;33m$1\t\033[0m $2"
}

status_print() {
    local color_code="0" # default to no color
    local clear_line=false
    local new_line=false
    local message=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --color=*)
                case "${1#*=}" in
                    red) color_code="31" ;;
                    green) color_code="32" ;;
                    yellow) color_code="33" ;;
                    blue) color_code="34" ;;
                    magenta) color_code="35" ;;
                    cyan) color_code="36" ;;
                    *) printf "Invalid color. Using default.\n" >&2 ;;
                esac
                shift
                ;;
            --clear)
                clear_line=true
                shift
                ;;
            --newline)
                new_line=true
                shift
                ;;
            *)
                message+="$1 "
                shift
                ;;
        esac
    done

    # Clear the line if requested
    if [[ $clear_line == true ]]; then
        printf "\r%*s" "$(tput cols)" ""
    fi

    # Print the message with color
    printf "\e[%sm%s\e[0m" "$color_code" "$message"

    # Move to the start of the line unless a new line is requested
    if [[ $new_line == true ]]; then
        printf "\n"
    else
        printf "\r"
    fi
}

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
    if ! grep -q "function in_screen()" "$bashrc_file"; then
        echo "$in_screen_function" >> "$bashrc_file"
        echo "$ps1_modification" >> "$bashrc_file"
        
        if grep -q "function in_screen()" "$bashrc_file"; then
            green_bold "OK" "in_screen function added to .bashrc"
        else
            yellow_bold "INFO" "Failed to add in_screen function to .bashrc, but do not worry"
        fi
    else
        green_bold "OK" "in_screen function already exists in .bashrc. No changes made."
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

yellow_bold "NOTE" "Shortcut to our dataset is in \033[1;32m\$VIROME\033[0m"

# First, add a string to ~/.bashrc

mkdir -p ~/bin/
if [[ -d "$VIROME"/bin ]]; then
    ln -s "$VIROME"/bin/* ~/bin/
    green_bold "OK" "Linked \$VIROME/bin to ~/bin"
fi
FILE=~/.bashrc


STRING='shopt -s direxpand'
# append STRING to FILE
if grep -q "$STRING" "$FILE"; then
    green_bold "OK" ".bashrc already updated"
else
    echo "$STRING" >> "$FILE"
    echo "export VIROME=$VIROME" >> "$FILE"
    echo "shopt -s direxpand" >> "$FILE"
    green_bold "OK" "Updated settings in $FILE"
fi

# Second, install some programs

check_sudo

# CHECK UBUNTU
if grep "DISTRIB_DESCRIPTION" /etc/lsb-release > /dev/null 2> /dev/null; then
    green_bold "OK" "You are using $(grep DISTRIB_DESCRIPTION /etc/lsb-release | cut -f 2 -d '=')"
else
    red_bold "ERROR" "Not Ubuntu?"
    exit 1
fi

#CHECK MEMORY
# Get total memory in kB
total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# Convert kB to GB
total_mem_gb=$((total_mem / 1024 / 1024))

if [ $total_mem_gb -gt 30 ]; then
    green_bold "OK" "Total memory is greater than 30GB"
else
    yellow_bold "WARN" "Total memory is less than 32GB ($total_mem_gb GB)"
fi

sudo apt update 2>/dev/null 1>/dev/null

# Write a blue line ending with \r to be erased with the text "hello"

status_print --color=blue "Installing dependencies..."
if sudo apt install -y --quiet unzip  batcat visidata pv tree mc libpcre3-dev >/tmp/ebame-apt.out 2>/tmp/ebame-apt.err; then
    ln -s /usr/bin/batcat ~/bin/bat
    green_bold "OK" "Installed requirements ()"
else
    red_bold "ERROR" "unable to install requirements (you need unzip, visidata, libpcre3-dev)"
fi

# Install seqfu
status_print --color=blue "Installing SeqFu..."
URL="https://github.com/telatin/seqfu2/releases/download/v1.22.3/SeqFu-v1.22.3-Linux-x86_64.zip"
if [[ -e ~/bin/seqfu ]]; then
    VER=$(seqfu version)
    green_bold "OK" "SeqFu already installed: $VER"
else
    if curl -sSL -o /tmp/seqfu.zip "$URL"; then
        unzip -d "$HOME"/ /tmp/seqfu.zip
        green_bold "OK" "Installed SeqFu"
    else
        red_bold "ERROR" "Could not install SeqFu"
    fi
fi

status_print --color=blue "Finalizing..."

# Set up .screenrc configuration
if [[ ! -e ~/.screenrc ]]; then
    if curl -o ~/.screenrc -sSL "https://gist.githubusercontent.com/telatin/58ba9b07765a8f30b4a06eac1a39ff5e/raw/b4c39bbac20634d66509a6b848e343919076abc6/.bashrc"; then
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

# Add screen status check to bash prompt
check_and_append_in_screen


echo -e "\033[1;32m===\t\033[0m Setup finished \033[1;32m===\t\033[0m \n"



sed -i.bak 's|\\h|EBAME|' ~/.bashrc

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
echo "To ensure all changes take effect, please restart your terminal session or run:"
echo "source ~/.bashrc"