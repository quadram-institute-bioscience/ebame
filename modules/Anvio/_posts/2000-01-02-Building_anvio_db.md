---
title: Add Links to the Top Menu
---

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

## For the imatients

You can use the `CONTIGS.db`, `PROFILE.db` and `AUXILIARY-DATA.db` as provided in the [FigShare](https://doi.org/10.6084/m9.figshare.27231678) folder!
