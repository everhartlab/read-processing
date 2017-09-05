# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Makefile for analyzing mitochondrial genomes
#
# Author: Zhian N. Kamvar
# Licesne: MIT
#
# This makefile contains rules and recipes for mapping, filtering, and
# analyzing mitochondrial genomes of *Sclerotinia sclerotiorum* treated with
# four different fungicides to assess the impact of fungicide stress on genomic
# architecture.
#
# Since this makefile runs on a SLURM cluster, this is tailored specifically for
# the HCC cluster in UNL. For this to work, the script SLURM_Array must be in 
# your path. You can download it here: https://github.com/zkamvar/SLURM_Array
#
# The general pattern of this makefile is that each target takes two steps:
#
# 1. Run a bash script to collect the dependencies into separate lines of a
#    text file. Each line will be an identical command to run in parallel
#    across the cluster.
# 2. The text file is submitted to the cluster with SLURM_Array
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


all: $(FASTA) $(RFILES) vcf 


# Define genome directory. YOU MUST CREATE THIS DIRECTORY
FAST_DIR := mitochondria_genome
FASTA    := $(FAST_DIR)/sclerotinia_sclerotiorum_mitochondria_2_supercontigs.fasta.gz

# Reads. Make sure your PE reads end with _1.fq.gz
READS    := $(shell ls -d reads/*_1.fq.gz | sed 's/_1.fq.gz//g')
RFILES   := $(addsuffix _1.fq.gz, $(READS))

# Define Directory names
TMP      := \$$TMPDIR
ROOT_DIR := $(patsubst /lustre/%,/%,$(CURDIR)) 
ROOT_DIR := $(strip $(ROOT_DIR))
RUNFILES := runfiles
IDX_DIR  := bt2-index
PREFIX   := Ssc_mito # prefix for the bowtie2 index
TRIM_DIR := TRIM
SAM_DIR  := SAMS
BAM_DIR  := BAMS
GVCF_DIR := GVCF
REF_DIR  := REF

# Define run directories

RUNS     := runs
INT_RUN  := $(RUNS)/GATK-INTERVALS
BT2_RUN  := $(RUNS)/BOWTIE2-BUILD
TRM_RUN  := $(RUNS)/TRIM-READS
MAP_RUN  := $(RUNS)/MAP-READS
SVL_RUN  := $(RUNS)/VALIDATE-SAM
BVL_RUN  := $(RUNS)/VALIDATE-BAM


# Modules and environmental variables
BOWTIE   := bowtie/2.2
TRIMMOD  := trimmomatic/0.36
SAMTOOLS := samtools/1.3
PICARD   := picard/1.1
GATK     := gatk/3.4
gatk     := \$$GATK
PIC      := \$$PICARD
EMAIL    := $$EMAIL # Note: this gets interpreted here, so be sure to define this in the $EMAIL envvar or here

# Accounting for the expected output files
REF_FNA  := $(patsubst $(FAST_DIR)/%.fasta.gz,$(REF_DIR)/%.fasta, $(FASTA))
REF_IDX  := $(patsubst %.fasta,%.dict, $(REF_FNA))
INTERVALS:= $(patsubst %.fasta,%.intervals.txt, $(REF_FNA))
REFSIZES := $(patsubst %.fasta,%.sizes.txt, $(REF_FNA))
TR_READS := $(patsubst reads/%,$(TRIM_DIR)/%_1P.fq.gz, $(READS))
TR_PRE   := $(patsubst reads/%,$(TRIM_DIR)/%, $(READS))
IDX      := $(addprefix $(strip $(IDX_DIR)/$(PREFIX)), .1.bz2 .2.bz2 .3.bz2 .4.bz2 .rev.1.bz2 .rev.2.bz2)
SAM      := $(patsubst reads/%.sam, $(SAM_DIR)/%.sam, $(addsuffix .sam, $(READS)))
SAM_VAL  := $(patsubst %.sam, %_stats.txt.gz, $(SAM))
BAM      := $(patsubst $(SAM_DIR)/%.sam,$(BAM_DIR)/%_nsort.bam, $(SAM))
FIXED    := $(patsubst %_nsort.bam,%_fixed.bam, $(BAM))
DUPMRK   := $(patsubst %_nsort.bam, %_dupmrk.bam, $(BAM))
GVCF     := $(patsubst reads/%,$(GVCF_DIR)/%.g.vcf.gz, $(READS))
DUP_VAL  := $(patsubst %_nsort.bam, %_dupmrk_stats.txt.gz, $(BAM))
PLOT_VAL := $(patsubst %_nsort.bam, %/, $(BAM))
BAM_VAL  := $(patsubst %_fixed.bam, %_fixed_stats.txt.gz, $(FIXED))
VCF      := $(GVCF_DIR)/res.vcf.gz

joiner = reads/$(1)_1.fq.gz,\
	reads/$(1)_2.fq.gz,\
	$(SAM_DIR)/$(1).sam,\
	$(SAM_DIR)/$(1)_stats.txt.gz,\
	$(BAM_DIR)/$(1)_nsort.bam,\
	$(BAM_DIR)/$(1)_fixed.bam,\
	$(BAM_DIR)/$(1)_fixed_stats.txt.gz,\
	$(BAM_DIR)/$(1)_dupmrk.bam,\
	$(BAM_DIR)/$(1)_dupmrk_stats.txt.gz,\
	$(GVCF_DIR)/$(1).g.vcf.gz\\n

MANIFEST := $(foreach x,$(patsubst reads/%,%, $(READS)),$(call joiner,$(x)))



$(RUNS) \
$(RUNFILES) \
$(IDX_DIR) \
$(SAM_DIR) \
$(BAM_DIR) \
$(REF_DIR) \
$(GVCF_DIR) \
$(TRIM_DIR):
	-mkdir $@

$(INT_RUN) \
$(BT2_RUN) \
$(TRM_RUN) \
$(MAP_RUN) \
$(SVL_RUN) \
$(BAM_RUN) \
$(BVL_RUN): $(RUNS)
	-mkdir $@

index : $(FASTA) $(REF_FNA) $(INTERVALS) $(IDX) 
trim : $(TR_READS)
map : index trim $(SAM) $(SAM_VAL) 
bam : map $(BAM) $(FIXED) $(BAM_VAL) 
dup : bam $(DUPMRK) $(DUP_VAL) runs/GET-DEPTH/GET-DEPTH.sh
plot : $(PLOT_VAL)
vcf : dup $(REF_IDX) $(GVCF) $(VCF)
concat : runs/CONCAT-VCF/CONCAT-VCF.sh

# Unzip the reference genome --------------------------------------------------
$(REF_DIR)/%.fasta : $(FAST_DIR)/%.fasta.gz | $(REF_DIR) $(RUNFILES)
	zcat $^ | sed -r 's/[ ,]+/_/g' > $@
	
# Creates intervals for the final step ----------------------------------------
$(REF_DIR)/%.intervals.txt : $(REF_DIR)/%.fasta scripts/make-GATK-intervals.py scripts/make-GATK-intervals.sh | $(INT_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J GATK-INTERVALS \
	-o $(INT_RUN)/GATK-INTERVALS.out \
	-e $(INT_RUN)/GATK-INTERVALS.err \
	scripts/make-GATK-intervals.sh $< 10000 $@

$(REF_DIR)/%.sizes.txt : $(REF_DIR)/%.fasta scripts/make-GATK-intervals.py scripts/make-GATK-intervals.sh | $(INT_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J GATK-SIZES \
	-o $(INT_RUN)/GATK-SIZES.out \
	-e $(INT_RUN)/GATK-SIZES.err \
	scripts/make-GATK-intervals.sh $< 0 $@

# Indexing the genome for Bowtie2 ---------------------------------------------
$(BT2_RUN)/jobid.txt: scripts/make-index.sh $(REF_FNA) | $(IDX_DIR) $(BT2_RUN) 
	sbatch \
	-D $(ROOT_DIR) \
	-J BOWTIE2-BUILD \
	-o $(BT2_RUN)/BOWTIE2-BUILD.out \
	-e $(BT2_RUN)/BOWTIE2-BUILD.err \
	scripts/make-index.sh \
	   $(REF_FNA) $(addprefix $(IDX_DIR)/, $(PREFIX)) $@ $(BOWTIE) | \
	   cut -c 21- > $@ 

$(IDX) : scripts/make-index.sh $(FASTA) $(BT2_RUN)/jobid.txt

# Quality trimming the reads --------------------------------------------------
$(TRIM_DIR)/%_1P.fq.gz: reads/%_1.fq.gz scripts/trim-reads.sh | $(TRIM_DIR) $(TRM_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J TRIM-READS \
	-o $(TRM_RUN)/$*.out \
	-e $(TRM_RUN)/$*.err \
	scripts/trim-reads.sh $* $(@D) $(TRIMMOD) | cut -c 21- > $(@D)/$*.jid

$(TRM_RUN)/%.out : $(TRIM_DIR)/%_1P.fq.gz

# Mapping the reads -----------------------------------------------------------
$(SAM_DIR)/%.sam : $(TRIM_DIR)/%_1P.fq.gz scripts/make-alignment.sh $(BT2_RUN)/jobid.txt | $(SAM_DIR) $(MAP_RUN) 
	sleep 1
	sbatch \
	-D $(ROOT_DIR) \
	-J MAP-READS \
	--dependency=afterok:$$(bash scripts/get-job.sh $(BT2_RUN)/jobid.txt $(<D)/$*.jid) \
	-o $(MAP_RUN)/$*.out \
	-e $(MAP_RUN)/$*.err \
	scripts/make-alignment.sh \
	   $(addprefix $(IDX_DIR)/, $(PREFIX)) $(@D) P.fq.gz $(<D)/$* $(BOWTIE) | \
	   cut -c 21- > $@.jid

# Validating the mapping ------------------------------------------------------
$(SAM_DIR)/%_stats.txt.gz : $(SAM_DIR)/%.sam scripts/validate-sam.sh | $(SVL_RUN)
	sleep 1
	sbatch \
	-D $(ROOT_DIR) \
	-J VALIDATE-READS \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(SVL_RUN)/$*.out \
	-e $(SVL_RUN)/$*.err \
	scripts/validate-sam.sh $< $(SAMTOOLS) | cut -c 21- > $@.jid

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

# Fix mate information and add the MD tag -------------------------------------
$(BAM_DIR)/%_fixed.bam : $(BAM_DIR)/%_nsort.bam scripts/add-MD-tag.sh | $(BAM_DIR) $(BAM_RUN) 
	sbatch \
	-D $(ROOT_DIR) \
	-J ADD-MD-TAG \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(BAM_RUN)/$*_fixed.out \
	-e $(BAM_RUN)/$*_fixed.err \
	scripts/add-MD-tag.sh $< $(SAMTOOLS) $(REF_FNA) | \
	   cut -c 21- > $@.jid

# Validating the bamfiles -----------------------------------------------------
$(BAM_DIR)/%_fixed_stats.txt.gz : $(BAM_DIR)%_fixed.bam scripts/validate-sam.sh | $(BAM_DIR) $(BVL_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J VALIDATE-BAMS \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(BVL_RUN)/$*.out \
	-e $(BVL_RUN)/$*.err \
	scripts/validate-sam.sh $< $(SAMTOOLS) | cut -c 21- > $@.jid

runs/MARK-DUPS/MARK-DUPS.sh: $(FIXED)
	echo $^ | \
	sed -r 's@'\
	'([^ ]+?)_fixed.bam *'\
	'@'\
	'java -Djava.io.tmpdir=$(TMP) '\
	'-jar $(PIC) MarkDuplicates '\
	'I=\1_fixed.bam '\
	'O=\1_dupmrk.bam '\
	'MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=1000 '\
	'ASSUME_SORTED=true '\
	'M=\1_marked_dup_metrics.txt; '\
	'samtools index \1_dupmrk.bam\n'\
	'@g' > $(RUNFILES)/mark-dups.txt # end
	SLURM_Array -c $(RUNFILES)/mark-dups.txt \
		--mail $(EMAIL) \
		-r runs/MARK-DUPS \
		-l $(PICARD) $(SAMTOOLS) \
		--hold \
		-m 25g \
		-w $(ROOT_DIR)

$(DUPMRK) : $(FIXED) runs/MARK-DUPS/MARK-DUPS.sh

runs/GET-DEPTH/GET-DEPTH.sh: $(DUPMRK)
	echo 'samtools depth $^ | gzip -c > $(BAM_DIR)/depth_stats.txt.gz' > $(RUNFILES)/get-depth.txt # end
	grep '^>' $(REF_FNA) | \
	sed -r \
	's@'\
	'^>(.+?)$$'\
	'@'\
	'samtools depth -r \1 $^ | gzip -c > $(BAM_DIR)\/depth_stats_\1.txt.gz'\
	'@' > $(RUNFILES)/get-depth.txt # end  
	SLURM_Array -c $(RUNFILES)/get-depth.txt \
		--mail $(EMAIL) \
		-r runs/GET-DEPTH \
		-l $(SAMTOOLS) \
		--hold \
		-w $(ROOT_DIR)	

runs/VALIDATE-DUPS/VALIDATE-DUPS.sh: $(DUPMRK)
	echo $^ | \
	sed -r 's@'\
	'([^ ]+?)_dupmrk.bam *'\
	'@'\
	'samtools stats \1_dupmrk.bam | '\
	'gzip -c > \1_dupmrk_stats.txt.gz\n'\
	'@g' > $(RUNFILES)/validate-dups.txt # end
	SLURM_Array -c $(RUNFILES)/validate-dups.txt \
		--mail $(EMAIL) \
		-r runs/VALIDATE-DUPS \
		-l $(SAMTOOLS) \
		--hold \
		-w $(ROOT_DIR)	

$(DUP_VAL): $(DUPMRK) runs/VALIDATE-DUPS/VALIDATE-DUPS.sh

runs/PLOT-VALS/PLOT-VALS.sh: $(DUP_VAL)
	echo $^ | \
	sed -r 's@'\
	'([^ ]+?)_dupmrk_stats.txt.gz *'\
	'@'\
	'mkdir \1; '\
	'plot-bamstats -p \1/ <(zcat \1_dupmrk_stats.txt.gz)\n'\
	'@g' > $(RUNFILES)/plot-vals.txt
	SLURM_Array -c $(RUNFILES)/plot-vals.txt \
		-r runs/PLOT-VALS \
		-l $(SAMTOOLS) \
		--hold \
		-w $(ROOT_DIR)

$(PLOT_VAL): $(DUP_VAL) runs/PLOT-VALS/PLOT-VALS.sh

# https://www.broadinstitute.org/gatk/documentation/article?id=3893
# # https://www.broadinstitute.org/gatk/documentation/tooldocs/org_broadinstitute_gatk_tools_walkers_haplotypecaller_HaplotypeCaller.php
# # https://www.broadinstitute.org/gatk/documentation/tooldocs/org_broadinstitute_gatk_tools_walkers_variantutils_GenotypeGVCFs.php
#
# # Note that Haplotypecaller requires an indexed bam.
# # If yours is not, use SAMtools.
#
# # If you're dealing with legacy data you may encounter legacy quality encodings.
# # If you encounter this use:
# #
# # --fix_misencoded_quality_scores
# #
# # In your GATK call. (But only on the offending libraries.)
# # https://software.broadinstitute.org/gatk/gatkdocs/org_broadinstitute_gatk_engine_CommandLineGATK.php#--fix_misencoded_quality_scores
# # https://en.wikipedia.org/wiki/FASTQ_format
#
#
# CMD="$JAVA -Djava.io.tmpdir=/data/ -jar $GATK \
#   -T HaplotypeCaller \
#   -R $REF \
#   --emitRefConfidence GVCF \
#   -ploidy 2 \
#   -I bams/${arr[0]}_dupmrk.bam \
#   -o gvcf/${arr[0]}_2n.g.vcf.gz"
#
#
# CMD="$JAVA -Djava.io.tmpdir=/data/ -jar $GATK \
#    -T HaplotypeCaller \
#    -R $REF \
#    --emitRefConfidence GVCF \
#    -ploidy 3 \
#    -I bams/${arr[0]}_dupmrk.bam \
#    -o gvcf/${arr[0]}_3n.g.vcf.gz"
#

runs/MAKE-GATK-REF/MAKE-GATK-REF.sh: $(REF_FNA) 
	echo $^ | \
	sed -r 's@'\
	'^(.+?).fasta'\
	'@'\
	'java -jar $(PIC) CreateSequenceDictionary '\
	'R=\1.fasta '\
	'O=\1.dict; '\
	'samtools faidx \1.fasta'\
	'@g' > $(RUNFILES)/make-gatk-ref.txt # end
	SLURM_Array -c $(RUNFILES)/make-gatk-ref.txt \
		--mail $(EMAIL) \
		-r runs/MAKE-GATK-REF \
		-l $(PICARD) $(SAMTOOLS) \
		--hold \
		-w $(ROOT_DIR)

$(REF_IDX): $(FASTA) runs/MAKE-GATK-REF/MAKE-GATK-REF.sh

# Pain points:
# 
# GATK is very picky as far as paths go. If it sees a relative
# path, it will use pwd. On this SLURM system, this results in
# a path that's not accessible.
#
# GATK assumes that you named your dict file with the basename
# of your file and not just appended dict on the end.
#
runs/MAKE-GVCF/MAKE-GVCF.sh: $(DUPMRK) | $(GVCF_DIR)
	echo $^ | \
	sed -r 's@'\
	'$(BAM_DIR)/([^ ]+?)_dupmrk.bam *'\
	'@'\
	'java -Djava.io.tmpdir=$(TMP) -jar $(gatk) '\
	'-T HaplotypeCaller '\
	'-R $(ROOT_DIR)/$(REF_FNA) '\
	'--emitRefConfidence GVCF '\
	'-ploidy 1 '\
	'-I $(BAM_DIR)/\1_dupmrk.bam '\
	'-o $(GVCF_DIR)/\1.g.vcf.gz\n'\
	'@g' > $(RUNFILES)/make-gvcf.txt
	SLURM_Array -c $(RUNFILES)/make-gvcf.txt \
		--mail $(EMAIL) \
		-r runs/MAKE-GVCF \
		-l $(GATK) \
		--hold \
		-m 25g \
		-w $(ROOT_DIR)

$(GVCF) : $(DUPMRK) runs/MAKE-GVCF/MAKE-GVCF.sh


# 
# Note for this step, memory matters more than the number of cores.
#
# For example, here I'm using 50g of memory by setting the -Xmx
# and the -m flag in the SLURM_Array command. Notice that for the
# Xmx flag, the number of corse must butt up against the flag. This
# is a Java thing.
#
# I also set the number of threads with -nt and -P flags, respectively
#
runs/MAKE-VCF/MAKE-VCF.sh: $(GVCF)
	printf "java -Xmx100g -Djava.io.tmpdir=$(TMP) "\
	"-jar $(gatk) "\
	"-nt 6 "\
	"-T GenotypeGVCFs "\
	"-R $(ROOT_DIR)/$(REF_FNA) "\
	"$(addprefix -V , $^) "\
	"-o $(GVCF_DIR)/res.\$$SLURM_ARRAY_TASK_ID.vcf.gz --intervals" | \
	./scripts/prepend-to-file.sh $(INTERVALS) $(RUNFILES)/make-vcf.txt
	SLURM_Array -c $(RUNFILES)/make-vcf.txt \
		--mail $(EMAIL) \
		-r runs/MAKE-VCF \
		-l $(GATK) \
		--hold \
		-m 100g \
		-t 24:00:00 \
		-P 6 \
		-w $(ROOT_DIR)

runs/CONCAT-VCF/CONCAT-VCF.sh: 
	echo 'vcf-concat $(shell ls $(GVCF_DIR)/res.*.vcf.gz | sort -t'.' -n -k2)'\
	' | gzip -c > $(GVCF_DIR)/res.vcf.gz' > \
	$(RUNFILES)/merge-vcf.txt
	SLURM_Array -c $(RUNFILES)/merge-vcf.txt \
		-r runs/CONCAT-VCF \
		-l vcftools/0.1 \
		-w $(ROOT_DIR)

$(VCF): $(GVCF) runs/MAKE-VCF/MAKE-VCF.sh

help :
	@echo
	@echo "COMMANDS"
	@echo "============"
	@echo
	@echo "all	almost all -- Make res.n.vcf.gz files"
	@echo "concat	concatenate res.n.vcf.gz files (to run after all)"
	@echo "index	generate the bowtie2 index"
	@echo "map	map reads and validate the SAM files"
	@echo "bam	convert sam to bam and filter"
	@echo "dup	deduplicate bam files and validate"
	@echo "vcf	create g.vcf and vcf files (this is the longest step)" 
	@echo
	@echo "help	show this message" 
	@echo "burn	REMOVE ALL GENERATED FILES"
	@echo "manifest	create a manifest of all generated files per read"
	@echo "runclean.JOB_NAME	clean runfiles"
	@echo
	@echo "PARAMETERS"
	@echo "============"
	@echo
	@echo "EMAIL     : " $(EMAIL)
	@echo "ROOT DIR  : " $(ROOT_DIR)
	@echo "TEMP DIR  : " $(TMP)
	@echo "INDEX DIR : " $(IDX_DIR)
	@echo "PREFIX    : " $(PREFIX)
	@echo "SAM DIR   : " $(SAM_DIR)
	@echo "BAM DIR   : " $(BAM_DIR)
	@echo "GENOME    : " $(FASTA)
	@echo "RUNFILES  : " $(RUNFILES)
	@echo "READS     : " $(READS)
	@echo "TRIMMED READS     : " $(TR_READS)
	@echo

manifest :
	printf "READ1,"\
	"READ2,"\
	"SAM,"\
	"SAM VALIDATION,"\
	"SORTED BAM,"\
	"FIXED BAM,"\
	"FIXED BAM VALIDATION,"\
	"MARKED DUPLICATES BAM,"\
	"MARKED DUPLICATES BAM VALIDATION,"\
	"GVCF FILE\n" > manifest.csv
	printf "$(MANIFEST)" >> manifest.csv

runclean.%:
	$(RM) -r runs/$*

burn:
	$(RM) -r $(TRIM_DIR) $(IDX_DIR) $(SAM_DIR) $(BAM_DIR) $(GVCF_DIR) runs $(REF_DIR) $(RUNFILES)



.PHONY: all index help trim map bam dup vcf clean burn manifest
