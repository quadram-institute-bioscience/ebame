# Viromics workshop 

Welcome to the EBAME9 viromics workshop. The workshop is using a simplified workflow for viromics, starting from pre-made assemblies provided by the [QIB Viromics team](#Acknowledgements). QC of reads and assembly is not covered. We will use the EBAME VMs that will not continue to exist after the workshop is over. 

In this workshop you will try to run:

1. **geNomad**, a virus mining tool (a program which aims at identifying viral contigs from a metagenome assembly)
2. Assess the quality of the predicted viruses with **checkv**
3. Dereplicate the viral contigs (vOTUs). This step is particularly important when you want to combine the output of multiple miners, which will likely independently identify a set oc contigs as viral
  
There are many other great virus mining tools which are constantly developed and updated, some focused on only specific sections of the virosphere. You will have to do your own research or look into [tool benchmarks]() on which tools are the best fit for your purpose. 

### Setup your VM

Using Ubuntu 22 image, we can install some utilities with the following command:

```bash
# Execute a script to install some dependencies and configure variables and screen
curl -sSL https://gist.githubusercontent.com/telatin/593b5b7ce54fc644725e0ecc02394d34/raw/425aa2c09ca4cfcbf3bc341dcf4fa67663fb1dd5/setup_vm.sh | bash

# Make conda ready to work
conda init bash

# Apply modified settings
source ~/.bashrc
```

<details>
  <summary>What is this script doing?</summary>
  
  The script will:
  1. Check you are on an EBAME VM
  2. Install some packages with apt, including `visidata` is a tool to visualise tabular data (tsv, csv).
  3. Install a configuration profile for GNU Screen
  4. Make a `$VIROME` variable to quickly find our data

</details>


:warning: if the connection to a remote machine drops, the running programs will be terminated. 
See a small tutorial on [GNU screen :link:](https://github.com/telatin/learn_bash/wiki/Using-%22screen%22) on how to manage this problem.

### Our dataset

All the files required for this workshop are in the `/ifb/data/public/teachdata/ebame-2024/virome/` directory (or a different path if you used a secondary site to host your VM).
The `$VIROME` variable is already set to this directory, so you can use it to quickly access the data. 

<details>
  <summary>:information_source: [SKIP] I am not using the EBAME VM: How do I download the files locally?</summary>
  
  To download the files to your computer you need to download the raw sequences from [NCBI](https://www.ncbi.nlm.nih.gov/bioproject/PRJEB47625) and the assembly file 'illumina_sample_pool_megahit.fa.gz' from the [Zenodo archive](https://doi.org/10.5281/zenodo.10650983). You can either go manually download these files or you can run the following script:

  ```bash
  wget https://zenodo.org/api/records/10650983/files/illumina_sample_pool_megahit.fa.gz/content -O illumina_sample_pool_megahit.fa.gz
  curl -L ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR679/005/ERR6797445/ERR6797445_1.fastq.gz -o ERR6797445_1.fastq.gz
  curl -L ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR679/005/ERR6797445/ERR6797445_2.fastq.gz -o ERR6797445_2.fastq.gz
  curl -L ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR679/004/ERR6797444/ERR6797444_1.fastq.gz -o ERR6797444_1.fastq.gz
  curl -L ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR679/004/ERR6797444/ERR6797444_2.fastq.gz -o ERR6797444_2.fastq.gz
  curl -L ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR679/003/ERR6797443/ERR6797443_1.fastq.gz -o ERR6797443_1.fastq.gz
  curl -L ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR679/003/ERR6797443/ERR6797443_2.fastq.gz -o ERR6797443_2.fastq.gz
  ```

</details>

Try:
```bash
# View the content of the variable
echo $VIROME

# List what's inside it
ls -l $VIROME
```

We have three Illumina shotgun sequencing experiments from VLP enriched samples coming from human guts.
We performed a co-assembly (from [this study :link:](https://doi.org/10.1099/mgen.0.001236)).

You have three paired-end Illumina FASTQ files in this directory:

* `$VIROME/ERR679744*`

And a single co-assembly of them:

* `$VIROME/human_gut_assembly.fa`

:pencil2: Some questions:

* How many sequences are there in the assembly? What is its N50?
* How many reads do we have in our samples?

<details>
  <summary>:green_book: Answers</summary>
  
  ### How many sequences in a FASTA file
  With bash, you can count the ">" like:
  ```bash
  grep -c ">" ${my_assembly.fa
  ```

  but since we have a gzip file for our assembly we can use a similar command "zgrep"
  ```bash
  zgrep -c ">" $VIROME/human_gut_assembly.fa.gz
  ```

  Or we can use a dedicated tool, called [SeqFu stats](https://telatin.github.io/seqfu2/tools/stats.html) :
  ```bash
  seqfu cnt $VIROME/human_gut_assembly.fa.gz
  ```

  ### How many reads in FASTQ files?
  A quick way is to count the lines and divide them by four, or count the lines being "+":
  ```bash
  cat $VIROME/ERR6797443_1.fastq.gz | gzip -dc | grep -cw "+"
  ```
</details>

### geNomad

We will be using geNomad to identify bacteriophages and plasmids in genome/microbiome/virome assemblies. 
The tool is very easy to install, check the documentation [here](https://portal.nersc.gov/genomad/installation.html).

GeNomad utilizes an alignment-free and gene-based classifier hybrid approach to identify mobile genetic elements in a dataset and more information on how the tool works can be found in the [publication](https://www.nature.com/articles/s41587-023-01953-y).

This section will also use ~~the best tool on the planet~~ [SeqFu](https://telatin.github.io/seqfu2/) for the sequences manipulation.

#### Installation

GeNomad can be installed as follows:

```bash
# Note the multiline command using trailing backslashes:
mamba create -n genomad --yes \
  -c conda-forge -c bioconda \
  genomad seqfu
```

As with any conda/mamba environment, you will need to activate the environment to use the programmes within: 

```bash
conda activate genomad
```

You can now check whether the programme was installed well and is functioning by invoking the help message.

```bash
genomad --help
```

First, you should download the database, but we already have it in our VMs at `$VIROME/db/genomad_db/`.

<details>
  <summary>:information_source: [SKIP] I am not using the EBAME VM: How to download the Genomad database?</summary>
  
  If you install geNomad on your own computer, you can download the database with the following command:

  ```bash
  genomad download-database .
  ```

  The `.` means "download the database in the current directory": you can change it to a different path if you want.
</details>


geNomad has a set of modules, which combined compose the whole workflow. The modules are:

*  **geNomad annotate** will perform gene calling in the input sequences and annotate the predicted proteins with geNomad's markers.    
*  **geNomad find-proviruses** will find putative proviral regions within the input sequences.
*  **geNomad marker-classification** will classify the input sequences into chromosome, plasmid, or virus based on the presence of geNomad markers and other gene-related features. 
*  **geNomad nn-classification** will classify the input sequences into chromosome, plasmid, or virus based on the nucleotide sequence.   
*  **geNomad aggregated-classification** will aggregate the results of the *marker-classification* and *nn-classification*  modules to classify the input sequences into chromosome, plasmid, or virus. 
*  **geNomad summary** will summarize the results across modules into a classification report.


We will use the `end-to-end` command to run the full geNomad pipeline
(remember to use `genomad --help` to look at the options/parameters you can choose,
and remember to modify the command to suit your own inputs, outputs and desired options).

To run genomad you will need:

1. The assembly (FASTA file)
2. The database directory

and you need to specify the output directory of course. 


:pencil2: Try to create the command using `genomad end-to-end --help` to see the manual

<details>
  <summary>:green_book: Answer</summary>
  
  ```bash
  genomad end-to-end $VIROME/human_gut_assembly.fa.gz ~/genomad-out  $VIROME/genomad_db/ -t 8
  ```

  The parameters are `<ASSEMBLY>`, `<OUTPUT_DIR>`, `<DB_DIR>`, `-t` for the number of threads.

</details>

:eyes: Check the information printed on the screen. At the end geNomad will tell where the important files are!


:pencil2: What file contains the predicted viral genomes? How many sequences are there?

<details>
  <summary>:green_book: Answer</summary>
  
  ```bash
  seqfu stats -nbt ~/genomad-out/human_gut_assembly_summary/human_gut_assembly_virus.fna
  ```

</details>

When we're finished using this programme, we can deactivate the conda environment:

```bash
conda deactivate
```

Note that when deactivating an environment you do not need to specify the name, this is only true when activating an environment.

### Renaming a FASTA file

This section will require to use SeqFu, so let's activate the environment where we installed our favorite tool:

```bash
conda activate genomad
```

The sequence names given by geNomad are not the favourite for some tools like Anvi'o.

Let's have a look at the sequence names first. We can use `seqfu cat` to print the fasta file as a list of identifiers.

```bash
# This will extract the list of sequence names from the fasta file
seqfu cat --list  ~/genomad-out/human_gut_assembly_summary/human_gut_assembly_virus.fna > ~/genomad-out/raw_list.txt

# Let's see the last sequence names: they contain a character not allowed in Anvi'o
tail ~/genomad-out/raw_list.txt
```

Now we can use SeqFu to rename the sequences: we will ask to add a prefix (`-p`) and remove the original name (`-z`):

```bash
# Note the multiline command again
# This will rename the sequences using "votu_" as prefix, and removing the original sequence name
seqfu cat --anvio ~/genomad-out/human_gut_assembly_summary/human_gut_assembly_virus.fna > ~/genomad-out/genomad_votus.fna
```

We will now consider `~/genomad-out/genomad_votus.fna` to be our final output of geNomad.

:bulb: Optionally we can make a "mapping" file to associate the old name with the new name...

<details>
  <summary>:green_book: How to do the mapping file</summary>
  
  ```bash
  # We can list the renamed file
  seqfu cat --list ~/genomad-out/genomad_votus.fna > ~/genomad-out/final_list.txt

  # And create  a mapping file with two columns:
  paste ~/genomad-out/raw_list.txt ~/genomad-out/final_list.txt > map.tsv

  head map.tsv
  ```
  
</details>

When we're finished using this programme, we can deactivate the conda environment:

```bash
conda deactivate
```

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