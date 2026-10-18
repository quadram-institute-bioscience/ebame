#!/bin/bash

source /etc/os-release
LOCUSER=${LOCUSER:-$ID}

# 2019-10-25 Add a time-out limit on miniconda installation
# 2023-07 Changement d'installateur pour Mambaforge
# https://mamba.readthedocs.io/en/latest/installation.html#fresh-install
# ubuntu-ifb#7 : Problème d'installation de `mamba`
# 2023-10 Changement d'installateur pour Miniforge
# https://github.com/conda-forge/miniforge#download
# Mambaforge (Discouraged as of September 2023)
# Latest installers with PyPy 3.9 in the base environment
# Deprecation of PyPy installer
# https://conda-forge.org/news/2024/08/14/sunsetting-pypy/
CONDA_SHELL=Miniforge3-$(uname)-$(uname -m).sh
CONDA_ROOT_PREFIX=${CONDA_ROOT_PREFIX:-/var/lib/miniforge}
curl -LJO --connect-timeout 10 "https://github.com/conda-forge/miniforge/releases/latest/download/$CONDA_SHELL"
if [ ! -e $CONDA_SHELL ]; then
   echo "Miniforge installation timed out"
   return 1
fi
timeout 1m bash $CONDA_SHELL -b -u -p $CONDA_ROOT_PREFIX
if [ $? -ne 0 ]; then
   echo "Miniforge installation timed out"
   return 1
fi
rm $CONDA_SHELL

# Configure conda environment
for conda_profile in $( ls $CONDA_ROOT_PREFIX/etc/profile.d/*.sh ); do
   cp -a $conda_profile /etc/profile.d/
   source $conda_profile
done

## Add conda channels
conda config --add channels R --system
conda config --add channels bioconda --system
# conda config --add channels conda-forge --system

chgrp -R $LOCUSER $CONDA_ROOT_PREFIX
chmod -R g+w $CONDA_ROOT_PREFIX

# Install Micromamba

# IFB_ARCH=${IFB_ARCH:-/ifb/arch}
# mkdir -p $IFB_ARCH
# curl -LJO --output-dir $IFB_ARCH "https://micro.mamba.pm/api/micromamba/linux-64/latest"
# tar -C /usr/local -xvf $( ls $IFB_ARCH/micromamba* ) bin/micromamba
# '--output-dir' was introduced in curl 7.73.0, and is unknown in old distros (e.g. ubuntu-20.04).
# https://daniel.haxx.se/blog/2020/09/10/store-the-curl-output-over-there/

curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj -C /usr/local bin/micromamba
# https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html