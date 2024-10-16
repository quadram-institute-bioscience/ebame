# Viromics workshop 

Welcome to the EBAME9 viromics workshop. The workshop is using a simplified workflow for viromics, starting from pre-made assemblies provided by the [QIB Viromics team](#Acknowledgements). QC of reads and assembly is not covered. We will use the EBAME VMs that will not continue to exist after the workshop is over. 

In this workshop you will try to run:

1. **geNomad**, a virus mining tool (a program which aims at identifying viral contigs from a metagenome assembly)
2. Assess the quality of the predicted viruses with **checkv**
3. Dereplicate the viral contigs (vOTUs). This step is particularly important when you want to combine the output of multiple miners, which will likely independently identify a set oc contigs as viral
  
There are many other great virus mining tools which are constantly developed and updated, some focused on only specific sections of the virosphere. You will have to do your own research or look into [tool benchmarks]() on which tools are the best fit for your purpose. 

:warning: A FigShare repository contains intermediate and final expected outputs for this tutorial: [Check it out](https://doi.org/10.6084/m9.figshare.27231678)


### CheckV

### [SKIP] 

### Minimap2 and Samtools

### Running the Anvi'o metagenomics workflow on the virome

In the first step you will make the contigs database from the vOTU file and annotate it with information from the default hmms, the COGs database and identify tRNAs.  

```bash
# CHANGE FILENAMES, PATHS AND THREADS AS APPROPRIATE FOR YOUR OWN COMPUTER
anvi-gen-contigs-database -f votus.fna -o anvio/CONTIGS.db -T 4
anvi-run-hmms -c anvio/CONTIGS.d -T 4
anvi-run-ncbi-cogs -c anvio/CONTIGS.db -T 4
anvi-scan-trnas -c anvio/CONTIGS.db
```
Check the anvio warnings. What do you see for the `anvi-run-hmms` output?

<details>
  <summary>:green_book: Answer</summary>
  
There are not that many hmms that return genes. But don't worry, that means that our virus predictions are of good quality, because we don't want the bacterial, archaeal and eukaryotic gene markers.   
</details>

In the second step, you will create the anvio profiles from the read mapping files. We have provided subsampled files to limit download and computational time. 

```bash
# CHANGE FILENAMES, PATHS AND THREADS AS APPROPRIATE FOR YOUR OWN COMPUTER
anvi-profile -i sample_1.bam -c anvio/CONTIGS.db -T 4
anvi-profile -i sample_2.bam -c anvio/CONTIGS.db -T 4
anvi-profile -i sample_3.bam -c anvio/CONTIGS.db -T 4
```
Merge profiles to generate the profile database.
```bash
anvi-merge */PROFILE.db -o SAMPLES-MERGED -c CONTIGS.db   
````
Now you can look at your samples with `anvi-interactive`. 

### Skipping processing and just looking at the files in Anvi'o
Use the `CONTIGS.db`, `PROFILE.db` and `AUXILIARY-DATA.db` as provided in the download folder. 
