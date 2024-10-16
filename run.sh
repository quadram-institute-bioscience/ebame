
source ~/.bashrc
mamba create -n genomad --yes \
  -c conda-forge -c bioconda \
  genomad seqfu


conda activate genomad
genomad end-to-end $VIROME/human_gut_assembly.fa.gz ~/genomad-out  $VIROME/genomad_db/ -t 8
# To make commands easier, we can use variable like:
GENOMAD_OUT=~/genomad-out/human_gut_assembly_summary/human_gut_assembly_virus.fna 

# to be recalled with $VARNAME
seqfu cat --anvio --report rename_report.txt $GENOMAD_OUT > ~/genomad-out/genomad_votus.fna

conda deactivate

#---


mamba create -n checkv -c conda-forge -c bioconda checkv
conda activate checkv

checkv end_to_end ~/genomad-out/genomad_votus.fna ~/checkv-out -d $VIROME/checkv-db-v1.5/ -t 8

conda deactivate

#----