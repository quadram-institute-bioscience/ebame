#!/bin/bash

# This script is executed on the virtual machine during the Installation phase (need to be ran as root!).
# It is used to record a predefined VM-image of the appliance.
# Otherwise executed first during a cloud deployement in IFB-Biosphere

source /etc/os-release
DIST_ID=$ID
# DIST_ID=$(lsb_release -is)
export LOCUSER=$ID # Set this variable according to the used distrib: ubuntu debian centos rocky

# Installation of Ansible if needed
if command -v ansible >/dev/null 2>&1; then
    # https://stackoverflow.com/questions/592620/how-can-i-check-if-a-program-exists-from-a-bash-script
    echo Ansible is already installed.
else
    echo Installing Ansible...
    if [[ $DIST_ID = "ubuntu" || $DIST_ID = "debian" ]]; then
        DIST_CODENAME=$(lsb_release -cs)
        DIST_RELEASE=$(lsb_release -rs)
        export DEBIAN_FRONTEND=noninteractive
        
        if [[ $DIST_ID = "debian" && "$DIST_RELEASE" -lt 13 ]]; then
            # https://docs.ansible.com/projects/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-debian
            case "$DIST_CODENAME" in
                "bullseye")
                    UBUNTU_CODENAME="focal";;
                "bookworm")
                    UBUNTU_CODENAME="jammy";;
                "trixie")
                    UBUNTU_CODENAME="noble";;
            esac

            apt-get update
            apt-get install -y gpg

            wget -O- "https://keyserver.ubuntu.com/pks/lookup?fingerprint=on&op=get&search=0x6125E2A8C77F2818FB7BD15B93C4A3FD7BB9C367" | gpg --dearmour -o /usr/share/keyrings/ansible-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/ansible-archive-keyring.gpg] http://ppa.launchpad.net/ansible/ansible/ubuntu $UBUNTU_CODENAME main" | tee /etc/apt/sources.list.d/ansible.list
        elif [[ $DIST_ID != "debian" && $DIST_CODENAME != "focal" ]]; then
            apt-add-repository --yes --update ppa:ansible/ansible
        fi
        apt-get update
        apt-get install -y ansible
    elif [[ $DIST_ID = "centos" ]]; then
        yum install -y epel-release
        yum install -y python3
        python3 -m pip install --upgrade pip
        python3 -m pip install ansible
    elif [[ $DIST_ID = "rocky" ]]; then
        if [[ "$ROCKY_SUPPORT_PRODUCT" = "Rocky-Linux-8" ]]; then
            # https://forums.rockylinux.org/t/why-package-ansible-core-is-older-in-rocky-9-than-in-rocky-8/15823
            dnf install -y ansible-core
        else
            dnf install -y python3-pip
            python3 -m pip install --prefix /usr ansible
        fi
    else
        return
    fi
fi

# Biosphere commons configuration
if [[ -e /etc/profile.d/ifb.sh ]]; then
    echo System already configured with Biosphere commons.
else
    echo Installing Biosphere commons...
    ansible-playbook -c local -i 127.0.0.1, -b -e 'ansible_python_interpreter=/usr/bin/python3' ansible-commons.yaml
fi

# EBAME packages and tools
echo Installing EBAME packages...
ansible-playbook -c local -i 127.0.0.1, -b -e 'ansible_python_interpreter=/usr/bin/python3' ansible-ebame.yaml

# Optional GPU configuration
[ -n "$( lspci | grep -i nvidia )" ] && APP_ENABLE_GPU=True
if [ -n "$APP_ENABLE_GPU" ]; then
    echo Installing GPU NVIDIA drivers...
    ansible-galaxy install --roles-path /etc/ansible/roles nvidia.nvidia_driver # Install Nvidia ansible collection

    # Get latest Nvidia driver release
    NVIDIA_DRIVER_LATEST=$( apt search nvidia | egrep "^nvidia-driver.+server-" | awk -F- '{ print $3 }' | tail -1 )

    ansible-playbook -c local -i 127.0.0.1, -b -e 'ansible_python_interpreter=/usr/bin/python3' \
    -e "nvidia_driver_latest=${NVIDIA_DRIVER_LATEST}" ansible-gpu.yaml
    nvidia-persistenced # Load Nvidia kernel modules
else
    echo No GPU avalaible.
fi

# Optional Docker configuration
if [ -x "$( command -v docker )" ]; then
    echo Docker is already installed.
elif [ ! -z "${APP_ENABLE_DOCKER}" ]; then
    echo Installing Docker...
    ansible-playbook -c local -i 127.0.0.1, -b -e 'ansible_python_interpreter=/usr/bin/python3' ansible-docker.yaml
fi

# Optional install of the NVIDIA Container Toolkit
if [ -x "$( command -v docker )" ] && [ -n "$APP_ENABLE_GPU" ]; then
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
        && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    apt-get update
    apt-get install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
fi

# Optional configuration for remote desktop
if [ ! -z "${X2GO_SESSION}" ]; then
    # X2GO_SESSION is set in /etc/profile.d/x2go.sh by playbook ansible-remotedesktop.yaml
    echo A remote desktop is already installed.
elif [ ! -z "${APP_ENABLE_REMOTEDESKTOP}" ]; then
    echo Installing remote desktop...
    ansible-playbook -c local -i 127.0.0.1, -b -e 'ansible_python_interpreter=/usr/bin/python3' ansible-remotedesktop.yaml
    source /etc/profile.d/x2go.sh
fi
