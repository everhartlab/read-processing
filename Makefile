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




.PHONY: all index help trim map bam dup vcf clean burn manifest validate

# Define genome directory. YOU MUST CREATE THIS DIRECTORY
FAST_DIR := genome
FASTA    := $(wildcard $(FAST_DIR)/*.f*a.gz)

# Reads. Make sure your PE reads end with _1.fq.gz
READS    := $(shell ls -d reads/*_1.fq.gz | sed 's/_1.fq.gz//g')
RFILES   := $(addsuffix _1.fq.gz, $(READS))

# Define Directory names
TMP      := \$$TMPDIR
ROOT_DIR := $(patsubst /lustre/%,/%,$(CURDIR)) 
ROOT_DIR := $(strip $(ROOT_DIR))
RUNFILES := runfiles
IDX_DIR  := bt2-index
PREFIX   := Ssc # prefix for the bowtie2 index
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
BAM_RUN  := $(RUNS)/SAM-TO-BAM
MKD_RUN  := $(RUNS)/MARK-DUPS
DVL_RUN  := $(RUNS)/VALIDATE-DUPS
DCT_RUN  := $(RUNS)/GATK-REF
GCF_RUN  := $(RUNS)/MAKE-GVCF
VCF_RUN  := $(RUNS)/MAKE-VCF

# Modules and environmental variables
BOWTIE   := bowtie/2.2
TRIMMOD  := trimmomatic/0.36
SAMTOOLS := samtools/1.3
VCFTOOLS := vcftools/0.1
PICARD   := picard/2.9
GATK     := gatk/3.4
gatk     := \$$GATK
PIC      := \$$PICARD
EMAIL    := $$EMAIL # Note: this gets interpreted here, so be sure to define this in the $EMAIL envvar or here

# Accounting for the expected output files
REF_FNA  := $(addsuffix /genome.fasta,$(REF_DIR))
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


all: $(VCF) 
index : $(FASTA) $(REF_FNA) $(INTERVALS) $(IDX) 
trim : $(TR_READS)
map : index trim $(SAM) 
bam : map $(BAM) $(FIXED) $(DUPRMK)
# dup : bam $(DUPMRK) # runs/GET-DEPTH/GET-DEPTH.sh
vcf : bam $(REF_IDX) $(GVCF) $(VCF)
validate : $(SAM_VAL) $(BAM_VAL) $(DUP_VAL)
plot : $(PLOT_VAL)

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
	-mkdir -p $@

$(INT_RUN) \
$(BT2_RUN) \
$(TRM_RUN) \
$(MAP_RUN) \
$(SVL_RUN) \
$(BAM_RUN) \
$(MKD_RUN) \
$(DVL_RUN) \
$(DCT_RUN) \
$(GCF_RUN) \
$(VCF_RUN) \
$(BVL_RUN): $(RUNS)
	-mkdir -p $@



# Unzip the reference genome --------------------------------------------------
$(REF_DIR)/genome.fasta : $(FASTA) | $(REF_DIR) $(RUNFILES)
	zcat $^ | sed -r 's/[ ,]+/_/g' > $@

# Create dictionary for reference
$(REF_DIR)/%.dict : $(REF_DIR)/%.fasta | $(DCT_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J MAKE-GATK-REF \
	-o $(INT_RUN)/GATK-REF.out \
	-e $(INT_RUN)/GATK-REF.err \
	scripts/make-GATK-ref-dict.sh $< $(SAMTOOLS) $(PICARD) | cut -c 21- > $@.jid
		
# Creates intervals for the final step ----------------------------------------
$(REF_DIR)/%.intervals.txt : $(REF_DIR)/%.fasta scripts/make-GATK-intervals.py scripts/make-GATK-intervals.sh | $(INT_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J GATK-INTERVALS \
	-o $(INT_RUN)/GATK-INTERVALS.out \
	-e $(INT_RUN)/GATK-INTERVALS.err \
	scripts/make-GATK-intervals.sh $< 100000 $@ | cut -c 21- > $@.jid

$(REF_DIR)/%.sizes.txt : $(REF_DIR)/%.fasta scripts/make-GATK-intervals.py scripts/make-GATK-intervals.sh | $(INT_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J GATK-SIZES \
	-o $(INT_RUN)/GATK-SIZES.out \
	-e $(INT_RUN)/GATK-SIZES.err \
	scripts/make-GATK-intervals.sh $< 0 $@ | cut -c 21- > $@.jid

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
$(BAM_DIR)/%_fixed.bam : $(BAM_DIR)/%_nsort.bam scripts/add-MD-tag.sh 
	sbatch \
	-D $(ROOT_DIR) \
	-J ADD-MD-TAG \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(BAM_RUN)/$*_fixed.out \
	-e $(BAM_RUN)/$*_fixed.err \
	scripts/add-MD-tag.sh $< $(SAMTOOLS) $(REF_FNA) | \
	   cut -c 21- > $@.jid

# Validating the bamfiles -----------------------------------------------------
$(BAM_DIR)/%_fixed_stats.txt.gz : $(BAM_DIR)/%_fixed.bam scripts/validate-sam.sh | $(BVL_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J VALIDATE-BAMS \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(BVL_RUN)/$*.out \
	-e $(BVL_RUN)/$*.err \
	scripts/validate-sam.sh $< $(SAMTOOLS) | cut -c 21- > $@.jid

# Marking optical duplicates with picard --------------------------------------
$(BAM_DIR)/%_dupmrk.bam : $(BAM_DIR)/%_fixed.bam scripts/mark-duplicates.sh | $(MKD_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J MARK-DUPS \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(MKD_RUN)/$*.out \
	-e $(MKD_RUN)/$*.err \
	scripts/mark-duplicates.sh $< $(SAMTOOLS) $(PICARD) | cut -c 21- > $@.jid

# Validating the optical duplicate filtering ----------------------------------
$(BAM_DIR)/%_dupmrk_stats.txt.gz : $(BAM_DIR)/%_dupmrk.bam scripts/validate-sam.sh | $(DVL_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J VALIDATE-BAMS \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(DVL_RUN)/$*.out \
	-e $(DVL_RUN)/$*.err \
	scripts/validate-sam.sh $< $(SAMTOOLS) | cut -c 21- > $@.jid

# Make the GVCF files to use for variant calling later ------------------------
$(GVCF_DIR)/%.g.vcf.gz : $(BAM_DIR)/%_dupmrk.bam scripts/make-GVCF.sh $(REF_IDX) | $(GVCF_DIR) $(GCF_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J MAKE-GVCF \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid $(REF_IDX).jid) \
	-o $(GCF_RUN)/$*.out \
	-e $(GCF_RUN)/$*.err \
	scripts/make-GVCF.sh \
	   $< $@ $(gatk) $(ROOT_DIR)/$(REF_FNA) $(GATK) | cut -c 21- > $@.jid

# Call variants in separate windows and concatenate ---------------------------
$(VCF) : $(GVCF) | $(INTERVALS) scripts/make-VCF.sh scripts/CAT-VCF.sh $(VCF_RUN)
	for i in $$(cat $(INTERVALS)); \
	do \
		sbatch \
		-D $(ROOT_DIR) \
		-J MAKE-VCF \
		--dependency=afterok:$$(bash scripts/get-job.sh $(addsuffix .jid, $(GVCF))) \
		-o $(VCF_RUN)/$*.out \
		-e $(VCF_RUN)/$*.err \
		scripts/make-VCF.sh \
		   $(GVCF_DIR)/res $(gatk) $(ROOT_DIR)/$(REF_FNA) \
		   $(GATK) $$i $(addprefix -V , $^) | \
		   cut -c 21- > $(GVCF_DIR)/res.jid; \
		mv $(GVCF_DIR)/res.jid $(GVCF_DIR)/res.$$(cat $(GVCF_DIR)/res.jid).jid; \
	done;
	sbatch \
	-D $(ROOT_DIR) \
	-J MAKE-VCF \
	--dependency=afterok:$$(bash scripts/get-job.sh $(GVCF_DIR)/*.jid) \
	-o $(VCF_RUN)/$*.out \
	-e $(VCF_RUN)/$*.err \
	scripts/CAT-VCF.sh $(GVCF_DIR) $(VCFTOOLS)






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



