
set -euxo pipefail

. "/var/lib/miniforge/etc/profile.d/conda.sh"
mamba create -n genomad --yes \
  -c conda-forge -c bioconda \
  genomad seqfu
mamba create -n checkv -c conda-forge -c bioconda --yes \
  checkv

conda activate genomad

if [[ ! -d ~/genomad-out ]]; then
    genomad end-to-end "$VIROME"/human_gut_assembly.fa.gz ~/genomad-out  "$VIROME"/genomad_db/ -t 8
    # To make commands easier, we can use variable like:
    GENOMAD_OUT=~/genomad-out/human_gut_assembly_summary/human_gut_assembly_virus.fna 

    # to be recalled with $VARNAME
    seqfu cat --anvio --report rename_report.txt $GENOMAD_OUT > ~/genomad-out/genomad_votus.fna

    conda deactivate
fi
#---
# To make commands easier, we can use variable like:
GENOMAD_OUT=~/genomad-out/human_gut_assembly_summary/human_gut_assembly_virus.fna 

# to be recalled with $VARNAME
seqfu cat --anvio --report rename_report.txt "$GENOMAD_OUT" > ~/genomad-out/genomad_votus.fna

if [[ ! -d ~/checkv-out ]]; then
    conda activate checkv
    checkv end_to_end ~/genomad-out/genomad_votus.fna ~/checkv-out -d "$VIROME"/checkv-db-v1.5/ -t 8
    conda deactivate
fi
#----