# Viromics workshop 

Welcome to the EBAME9 viromics workshop. The workshop is using a simplified workflow for viromics, starting from pre-made assemblies provided by the [QIB Viromics team](#Acknowledgements). QC of reads and assembly is not covered. We will use the EBAME VMs that will not continue to exist after the workshop is over. 

In this workshop you will try to run:

1. **geNomad**, a virus mining tool (a program which aims at identifying viral contigs from a metagenome assembly)
2. Assess the quality of the predicted viruses with **checkv**
3. Dereplicate the viral contigs (vOTUs). This step is particularly important when you want to combine the output of multiple miners, which will likely independently identify a set oc contigs as viral
  
There are many other great virus mining tools which are constantly developed and updated, some focused on only specific sections of the virosphere. You will have to do your own research or look into [tool benchmarks]() on which tools are the best fit for your purpose. 

:warning: A FigShare repository contains intermediate and final expected outputs for this tutorial: [Check it out](https://doi.org/10.6084/m9.figshare.27231678)

### Setup your VM




//genomad
### CheckV

Now that we have some predicted viruses, let's look at their completeness!
[CheckV](https://bitbucket.org/berkeleylab/checkv/src/master/) is a tool developed to assess the quality and completeness of viral genomes assembled from viromes/metagenomes.

CheckV is also a pipeline we will run end-to-end to:

* Remove host contamination on proviruses (uses HMMs),
* Estimate genome completeness
* Predict full genomes (Direct terminal repeats, Proviruses, Inverted terminal repeats)

We can once again install using mamba/conda as below:
  
```bash
mamba create -n checkv -c conda-forge -c bioconda checkv seqfu
conda activate checkv
```

<details>
  <summary>:information_source: [SKIP] I am not using the EBAME VM: How to download the checkV database ?</summary>
  
  If you are running this tutorial outside of EBAME VM, you will need to download the checkV database

  ```bash
  checkv download_database ./
  ```

  Don't forget to update your checkV script to point to your database localisation!

</details>

Now remember to activate the environment and invoke the help message (similar to geNomad above...).

:pencil2: Try to create to run checkV on the predicted viruses from geNomad.

<details>
  <summary>:green_book: Answer</summary>
  
  ```bash
  checkv end_to_end ~/genomad-out/genomad_votus.fna ~/checkv-out -d $VIROME/checkv-db-v1.5/ -t 8
  ```

  The parameters are `<ASSEMBLY>`, `<OUTPUT_DIR>`, `-d <DB_DIR>`, `-t` for the number of threads.

</details>

Now you can check the [output files](https://bitbucket.org/berkeleylab/checkv/src/master/README.md#markdown-header-output-files).
With `ls` and `find` you can list them, and if you find a table you can inspect it interactively with `vd` (visidata, press `q` to quit).

In the summary columns, AAI stands for "average amino acid identity", 

<details>
  <summary>:green_book: Example</summary>
  
  To list the files

  ```bash
  ls -lh ~/checkv-out/
  ```

  To inspect the summary table:

  ```bash
  vd checkv-out/quality_summary.tsv 
  ```

  Similarily, you can check the other TSV files


</details>

### [SKIP] De-replication to vOTUs

> :warning: Do not do this section at EBAME9. This step is useful if you process independent assemblies (we have a co-assembly here), or if you run multiple miners (for example geNomad and VirSorter2...)

It is commonplace in virome analyses to cluster similar sequences together at the approximate level of species. These clustered sequences are referred to as viral operational taxonomic units (vOTUs). To do this, we're going to use a combination of [BLAST](https://www.ncbi.nlm.nih.gov/books/NBK279690/) and python scripts that are available alongside [CheckV](https://bitbucket.org/berkeleylab/checkv/src/master/). 

To download these scripts you can run the following: 

```bash
# DO NOT COPY THIS COMMAND
wget https://bitbucket.org/berkeleylab/checkv/raw/51a5293f75da04c5d9a938c9af9e2b879fa47bd8/scripts/aniclust.py
wget https://bitbucket.org/berkeleylab/checkv/raw/51a5293f75da04c5d9a938c9af9e2b879fa47bd8/scripts/anicalc.py
```

:bulb: In EBAME9 you have the scripts in your path.

This might look daunting, but let's work through it one command at a time:

First, create a blast+ database:

```bash
# DO NOT COPY THIS COMMAND
makeblastdb -in <my_seqs.fna> -dbtype nucl -out <my_db>
# example : makeblastdb -in genomad-out/genomad_votus.fna -dbtype nucl -out genomad_votus.db
```

Next, use megablast from blast+ package to perform all-vs-all blastn of sequences:

```bash
# DO NOT COPY THIS COMMAND
blastn -query <my_seqs.fna> -db <my_db> \
  -outfmt '6 std qlen slen' -max_target_seqs 10000 \
  -out <my_blast.tsv> -num_threads 8
# example : blastn -query genomad-out/genomad_votus.fna -db genomad_votus.db -outfmt '6 std qlen slen' -max_target_seqs 10000 -out genomad_blast.tsv -num_threads 8
```

Next, calculate pairwise ANI by combining local alignments between sequence pairs:

```bash
# DO NOT COPY THIS COMMAND
anicalc.py -i <my_blast.tsv> -o <my_ani.tsv>
# example python scripts/anicalc.py -i genomad_blast.tsv -o genomad_ani.tsv
```

Finally, perform UCLUST-like clustering using the [MIUVIG recommended-parameters](https://www.nature.com/articles/nbt.4306) (95% ANI + 85% AF):

```bash
# DO NOT COPY THIS COMMAND
aniclust.py --fna <my_seqs.fna> --ani <my_ani.tsv> \
  --out <my_clusters.tsv> \
  --min_ani 95 --min_tcov 85 --min_qcov 0
# example : python scripts/aniclust.py --fna genomad-out/genomad_votus.fna --ani genomad_ani.tsv --out vOTU_genomad_c95.tsv --min_ani 95 --min_tcov 85 --min_qcov 0
```

Take a look at the `my_clusters.tsv` file, this contains two tab-delimitied columns (i.e. separated by tabs). The first is a representative sequence for each cluster, this is what we're interested in. To get them, we'll use an awk command to get the first column and write it to a new file called `my_vOTUs.txt`:

```bash
# DO NOT COPY THIS COMMAND
awk '{print $1}' <my_clusters.tsv> > <my_vOTUs.txt>
example : awk '{print $1}' vOTU_genomad_c95.tsv > vOTU_genomad_representatives.tsv
```

We can then use a handy utility in `seqfu` called `seqfu list`, which is already installed! This will take a list of sequence IDs and extract the matching seqs from a fasta file:

```{bash}
# DO NOT COPY THIS COMMAND
seqfu list my_vOTUs.txt <genomad_viruses.fna> > <my_vOTUs.fa>
# seqfu list vOTU_genomad_representatives.tsv genomad-out/genomad_viruses.fna > vOTUs_representatives.fa
```

### Minimap2 and Samtools

The easiest way to define presence/absence of vOTUs within a sample and then estimate their abundance, 
is by mapping the reads back to the assembly. 

:pencil2: How can we use the BAM files?  We can use automatic tools (like MetaPop) or ... create an Anvi'o database!

There are loads of mappers/aligners available ([BWA](https://github.com/lh3/bwa), [bowtie2](https://github.com/BenLangmead/bowtie2), and [bbmap](https://jgi.doe.gov/data-and-tools/software-tools/bbtools/bb-tools-user-guide/bbmap-guide/) to name a few), 
but we're going to use [Minimap2](https://github.com/lh3/minimap2). 
Whatever mapper you use, it's very likely that you'll use [samtools](https://github.com/samtools/samtools) to process the output. 

Here you can create an environment with both minimap2 and samtools installed:

:bulb: When mapping against a subset of contigs, you might want to increase the stringency of the mapping. We won't change the defaults in this tutorial.

```bash
mamba create -n mapping \
  -c conda-forge -c bioconda\
  minimap2 samtools
```

Remember to activate the environment and invoke the help menus as we have done previously. This is a great way to test that you're in the correct environment and your programmes have installed successfully.

A typical minimap2 command looks like this:

```bash
# DO NOT COPY THIS COMMAND
minimap2 -x sr -a -t 8 <MY_VOTUS.fa> <reads-R1.fq.gz> <reads-R2.fq.gz>  > output.sam 
```

To produce the sorted bam file, we can pipe the output directly to samtools:

```bash
minimap2 -x sr -a -t 8 <MY_VOTUS.fa> <sample_X_R1.fq.gz> <sample_X_R2.fq.gz> | samtools view -bS -F4 - | samtools sort -@ 8 -o <sample_X.bam> -
```

There's a lot going on in this command (because it's actually three commands separated by pipes (`|`) :open_mouth:),
be sure to look up what pipes are, and what the minimap2 parameters might be doing.

The alignments will be saved in BAM files. You should look up what BAM files are and what the difference is between BAM and SAM...

For the bam file to be usable in anvio, you will need to index your bam file. You can use Samtools to do this:

```bash
samtools index -b <sample_X.bam> 
```

:pencil2: Now try yourself

* Create a directory where to store the alignments (eg. `~/bams/`)
* Use the structure of the above command to map the reads from sample_01 to the vOTUs you created earlier.
* Optionally, map all the other samples



<details>
  <summary>:green_book: Answers</summary>
  
  You can process the files manually:
  ```bash
  mkdir -p ~/bams/
  VOTUS=vOTUs_representatives.fa
  minimap2 -x sr -a -t 8 $VOTUS $VIROME/ERR6797443_{1,2}.fastq.gz | samtools view -bS -F4 - | samtools sort -@ 8 -o ~/bams/sample_1.bam -
  minimap2 -x sr -a -t 8 $VOTUS $VIROME/ERR6797444_{1,2}.fastq.gz | samtools view -bS -F4 - | samtools sort -@ 8 -o ~/bams/sample_2.bam -
  minimap2 -x sr -a -t 8 $VOTUS $VIROME/ERR6797443_{1,2}.fastq.gz | samtools view -bS -F4 - | samtools sort -@ 8 -o ~/bams/sample_3.bam -
  ```

  To index your bam file: 

  ```bash
  samtools index -b ~/bams/sample_1.bam
  samtools index -b ~/bams/sample_2.bam
  samtools index -b ~/bams/sample_3.bam
  ```

</details>
  
## Exploring your data with Anvi'o
You can do the Anvi'o data processing yourself on your own computer using the anvio install that you have used earlier in the week. We will provide the necessary files for you to download from Dropbox so you don't have to worry about downloading your files from the VM.

:warning: The filenames in the dropbox download might be slightly different, but the content will be the same

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

## Acknowledgements

This workshop was made for you by:

- Evelien Adriaenssens
- Andrea Telatin
- Ryan Cook
- Claire Elek
- Hannah Pye 

---

## Footnotes

### EBAME7 Virome workshop

Two years ago we used completely different tools (see [Ebame7 virome](https://telatin.github.io/microbiome-bioinformatics/virome-ebame/)). This is a proof that the field is moving fast!

### Package and environment managers

> :warning: At **EBAME9** we will use a Virtual Machine which comes with conda/mamba preinstalled. You can skipt this paragraph. 

We will use `conda` (or `mamba`) to install and manage software packages. Conda is a package manager that can install, build, and manage software written in any language. It can also manage libraries and tools that are required by the software. Conda is considered a package manager, system, and environment manager, dependency manager, and Python distribution. [see a [tutorial on installing and using miniconda](https://telatin.github.io/microbiome-bioinformatics/Install-Miniconda/)].