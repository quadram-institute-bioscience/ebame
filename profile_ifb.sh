# IFB Bioinformatics environment
export IFB_MAIN=/ifb
export IFB_BIN=$IFB_MAIN/bin
export IFB_DATADIR=$IFB_MAIN/data
export IFB_SRC=$IFB_MAIN/src
export IFB_ARCH=$IFB_MAIN/arch

export PATH=$PATH:$IFB_BIN

# Biosphere profiles
for curprofile in '/etc/profile.d/conda.sh' '/etc/profile.d/mamba.sh' '/etc/profile.d/x2go.sh' ; do
    if [ -r $curprofile ]; then
      . $curprofile 2
    fi
done
unset curprofile