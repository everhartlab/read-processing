Read Processing for paired-end Illumina reads
==============================================

This repository contains a Makefile to process paired-end illumina data 
with bowtie2, samtools, picard, and gatk. Much of the analyses are based
on @knausb's [bam processing workflow][brianflow], but tweaked for a
haploid plant pathogen with an available genome (here we use it for 
*Sclerotinia sclerotiorum*). **This is designed to run on the [HCC SLURM
Cluster][HCC].** There are no guarantees that this will work anywhere else.

Running the workflow
--------------------

To build your analysis, add your data to directories called **reads/** and
**genome/**. In your shell, type:

```
make
```

This will generate the genome index, sam files, bam files, g.vcf files
and a final `GATK/res.vcf.gz`. 

### Makefile options

You can find all of the makefile options by typing `make help`:

```
$ make help

COMMANDS
============

all		makes everything: res.vcf.gz
index		generate the bowtie2 index
trim		trims reads with trimmomatic
map		map reads with samtools
bam		convert sam to bam, filter, and remove duplicates
validate	run validation stats on the bam and sam files
gvcf		create g.vcf files from HaplotypeCaller
vcf		create vcf files (this is the longest step)

help		show this message
clean		remove all *.jid files
cleanall	REMOVE ALL GENERATED FILES

PARAMETERS
============

ROOT DIR  :  /work/everhartlab/kamvarz/test/read-processing
TEMP DIR  :  $TMPDIR
INDEX DIR :  bt2-index
PREFIX    :  Ssc
GENOME    :  genome/GCA_001857865.1_ASM185786v1_genomic.fna.gz genome/sclerotinia_sclerotiorum_mitochondria_2_contigs.fasta.gz
READS     :  reads/SS.11.01 reads/SS.11.02

Modules
============

BOWTIE   :  bowtie/2.2
TRIMMOD  :  trimmomatic/0.36
SAMTOOLS :  samtools/1.3
VCFTOOLS :  vcftools/0.1
PICARD   :  picard/2.9
GATK     :  gatk/3.4

```


Adding steps to the workflow
----------------------------

If you want to add steps/rules to the workflow, you should first be familiar
or comfortable with Makefiles. Here are some helpful guides:

 - [Vince Buffalo's Makefiles in Bioinformatics][buffalo-make]
 - [Makefile Style Guide][make-style]

Many of the recipes in the makefile take the form of:

```make
# Converting In to Out --------------------------------------------------------
$(OUT_DIR)/%.out : $(FROM_DIR)/%.in scripts/in-to-out.sh | $(OUT_DIR) $(OUT_RUN)
    sbatch \
    -D $(ROOT_DIR) \
    -J IN-TO-OUT \
    --dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
    -o $(OUT_RUN)/$*.out \
    -e $(OUT_RUN)/$*.err \
    scripts/in-to-out.sh $< | cut -c 21- > $@.jid
```

Where [`sbatch`](https://slurm.schedmd.com/sbatch.html) is being used on the
HCC to submit a custom SLURM script `scripts/in-to-out.sh`, which will convert
`.in` files to `.out` files. One of the first things to note are the trailing
backslashes. These are continuation lines for BASH, so when it runs it will run
like this:

```
sbatch -D $(ROOT_DIR) -J IN-TO-OUT --dependency=afterok:$$(bash scripts/get-job.sh $<.jid) -o $(OUT_RUN)/$*.out -e $(OUT_RUN)/$*.err scripts/in-to-out.sh $< | cut -c 21- > $@.jid
```

All jobs run from `sbatch` will return the following:

```
Submitted batch job XXXXX
```

where `XXXXX` is the JOBID. Since *make* does not know anything about jobs
running on SLURM, we need to tell SLURM to hold off on running a given job
until the dependent jobs are done. We take advantage of this by piping this to
`cut -c 21- > $@.jid`, which creates a file with the JOBID that we can use in a
downstream process.

The arguments to `sbatch` are:

 - **D** Root directory for the system
 - **J** jobname (we try to make them match the script names)
 - **--dependency** This stipulates that this job can only run if the the
   dependency from the .jid file has been fulfilled. Note that multiple jid
   files can be specified. Note that because `$` is special in *make*, we have
   to use another `$` to escape it. 
 - **-o,-e** the stdout and stderr files, respectively.

You may have noticed that this uses [automatic makefile variables](https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html) such as `$<` and `$@`, which stand for the first dependency and target, respectively. Depending on the needs of various scripts, we need different variables. It would be a good idea to keep that page open as a reference when creating new
steps. 

Here's an example from the script: 

```make
# Sorting and Converting to BAM files -----------------------------------------
$(BAM_DIR)/%_nsort.bam : $(SAM_DIR)/%.sam scripts/sam-to-bam.sh | $(BAM_DIR) $(BAM_RUN)
    sbatch \
    -D $(ROOT_DIR) \
    -J SAM-TO-BAM \
    --dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
    -o $(BAM_RUN)/$*_nsort.out \
    -e $(BAM_RUN)/$*_nsort.err \
    scripts/sam-to-bam.sh $(<D) $(@D) $* $(SAMTOOLS) | \
       cut -c 21- > $@.jid
```

In this example, we are using the [`sam-to-bam.sh`](scripts/sam-to-bam.sh)
script to convert sam files to bam files. If you run the script by itself, it
will tell you the requirements:

```
Usage: sam-to-bam.sh <SAMDIR> <BAMDIR> <BASE> <SAMTOOLS>

    <SAMDIR> - the directory for the samfiles
    <BAMDIR> - the directory for the bamfiles
    <BASE>   - base name for the sample (e.g. SS.11.01)
    <SAMTOOLS> - the samtools module (e.g. samtools/1.3)
```


 
[make-style]: http://clarkgrubb.com/makefile-style-guide
[buffalo-make]: https://github.com/vsbuffalo/makefiles-in-bioinfo
[brianflow]: https://github.com/knausb/bam_processing
[HCC]: http://hcc.unl.edu/
[sarray]: https://github.com/zkamvar/SLURM_Array
[arrayjob]: https://slurm.schedmd.com/job_array.html
 
 
 Generated directories
 ---------------------
 
 - *bt2-index/*: genome index files generated via `make index`
 - *TRIM/*: home for the trimmed reads via trimmomatic
 - *SAMS/*: mapped sam files generated via `make map`
 - *BAMS/*: filtered bam files
 - *GVCF/*: `*.g.vcf` and `*.vcf` files generated via GATK
 - *runs/*: std out and std err of runs
