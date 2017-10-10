# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Makefile for calling variants from whole genome sequences of *Sclerotinia
# sclerotiorum* isolates against the whole genome.
#
# Author: Zhian N. Kamvar
# License: MIT
#
# This makefile contains rules and recipes for mapping, filtering, and
# analyzing genomes of *Sclerotinia sclerotiorum* treated with
# four different fungicides to assess the impact of fungicide stress on genomic
# architecture.
#
# Since this makefile runs on a SLURM cluster, this is tailored specifically for
# the HCC cluster in UNL.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.PHONY: all index help trim denovo map bam gvcf vcf clean cleanall validate abyss

# Define genome directory. YOU MUST CREATE THIS DIRECTORY
FAST_DIR := genome
FASTA    := $(wildcard $(FAST_DIR)/*.f*a.gz)

# Reads. Make sure your PE reads end with _1.fq.gz and _2.fq.gz
READS    := $(shell ls -d reads/*_1.fq.gz | sed 's/_1.fq.gz//g')
RFILES   := $(addsuffix _1.fq.gz, $(READS))
NAMES    := $(patsubst reads/%,%,$(READS))

# Define Directory names
TMP      := \$$TMPDIR
ROOT_DIR := $(patsubst /lustre/%,/%,$(CURDIR)) 
ROOT_DIR := $(strip $(ROOT_DIR))
IDX_DIR  := bt2-index
PREFIX   := Ssc # prefix for the bowtie2 index
TRIM_DIR := TRIM
SAM_DIR  := SAMS
BAM_DIR  := BAMS
GVCF_DIR := GVCF
CHR_JOBS := GVCF/CHROM_JOBS
REF_DIR  := REF
DEN_DIR  := DENOVO
ABY_DIR  := ABYSS

# Define run directories
RUNS     := runs
INT_RUN  := $(RUNS)/GATK-INTERVALS
BT2_RUN  := $(RUNS)/BOWTIE2-BUILD
TRM_RUN  := $(RUNS)/TRIM-READS
MAP_RUN  := $(RUNS)/MAP-READS
SVL_RUN  := $(RUNS)/VALIDATE-SAM
BVL_RUN  := $(RUNS)/VALIDATE-BAM
BAM_RUN  := $(RUNS)/SAM-TO-BAM
MRG_RUN  := $(RUNS)/MERGE-BAMS
MKD_RUN  := $(RUNS)/MARK-DUPS
DVL_RUN  := $(RUNS)/VALIDATE-DUPS
DCT_RUN  := $(RUNS)/GATK-REF
GCF_RUN  := $(RUNS)/MAKE-GVCF
VCF_RUN  := $(RUNS)/MAKE-VCF
CHR_RUN  := $(RUNS)/CHROM_RUN
DEN_RUN  := $(RUNS)/DENOVO_RUN
ABY_RUN  := $(RUNS)/ABYSS_RUN

# Modules and environmental variables
BOWTIE   := bowtie/2.2
TRIMMOD  := trimmomatic/0.36
SPADES   := spades/3.11
SAMTOOLS := samtools/1.3
VCFTOOLS := vcftools/0.1
PICARD   := picard/2.9
GATK     := gatk/3.4
gatk     := \$$GATK
PIC      := \$$PICARD # This is only needed for picard versions < 2

# Accounting for the expected output files
REF_FNA  := $(addsuffix /genome.fasta,$(REF_DIR))
REF_IDX  := $(patsubst %.fasta,%.dict, $(REF_FNA))
INTERVALS:= $(patsubst %.fasta,%.intervals.txt, $(REF_FNA))
REFSIZES := $(patsubst %.fasta,%.sizes.txt, $(REF_FNA))
TRIMMED  := $(addprefix $(TRIM_DIR)/, $(NAMES))
P1_READS := $(addsuffix _1P.fq.gz, $(TRIMMED))
P2_READS := $(addsuffix _2P.fq.gz, $(TRIMMED))
U1_READS := $(addsuffix _1U.fq.gz, $(TRIMMED))
U2_READS := $(addsuffix _2U.fq.gz, $(TRIMMED))
IDX      := $(addprefix $(strip $(IDX_DIR)/$(PREFIX)), .1.bt2 .2.bt2 .3.bt2 .4.bt2 .rev.1.bt2 .rev.2.bt2)
# ------- The sam files are created in paired and unpaired varieties
SAM      := $(addprefix $(SAM_DIR)/, $(NAMES))
USAM     := $(addsuffix _U.sam, $(SAM))
PSAM     := $(addsuffix _P.sam, $(SAM))
# ------- The bam files are similar 
BAM      := $(addprefix $(BAM_DIR)/, $(NAMES))
UBAM     := $(addsuffix _U_nsort.bam, $(BAM))
PBAM     := $(addsuffix _P_nsort.bam, $(BAM))
# ------ The pairs are then merged.
MERGED   := $(addsuffix _merged.bam, $(BAM))
FIXED    := $(addsuffix _fixed.bam, $(BAM))
DUPMRK   := $(addsuffix _dupmrk.bam, $(BAM))
# ------ GVCF files are created from the BAMs
GVCF     := $(addsuffix .g.vcf.gz, $(NAMES))
GVCF     := $(addprefix $(GVCF_DIR)/, $(GVCF))
VCF      := $(GVCF_DIR)/res.vcf.gz
# ------ Validation steps
SAM_VAL  := $(patsubst %.sam, %_stats.txt.gz, $(PSAM) $(USAM))
DUP_VAL  := $(patsubst %.bam, %_stats.txt.gz, $(DUPMRK))
PLOT_VAL := $(patsubst %_nsort.bam, %/, $(BAM))
BAM_VAL  := $(patsubst %.bam, %_stats.txt.gz, $(FIXED))

# Denovo assembly via ABYSS
K        := k24 k32 k40 k48 k56 k64 k72 k80 k88 k96
K        := $(addprefix $(ABY_DIR)/,$K)
# --- Here I have to loop over K in order to add the samples to the end
ABYS     := $(foreach k, $K, $(addprefix $k/, $(addsuffix -scaffolds.fa,$(NAMES))))
# --- Since I'm using an array job to submit all values of K per sample, having this
#     run for each value of K is unnecessary. To avoid this, I'm going to set the target
#     to be k24 and have all other Ks be dependent on that.
#     This may seem unnecessary, but this allows me to track these important files as opposed to
#     tracking jobfiles or something like that.
TARGET_K := $(filter $(ABY_DIR)/k24/%, $(ABYS))
OTHER_K  := $(filter-out $(ABY_DIR)/k24/%, $(ABYS))
DENOVOS  := $(strip $(patsubst reads/%,$(DEN_DIR)/%/scaffolds.fasta,$(READS)))

all   : $(VCF) # Everything is dependent on the VCF output. 

index : $(IDX) 
trim  : $(P1_READS) $(P2_READS) $(U1_READS) $(U2_READS)
map   : $(USAM) $(PSAM)
bam   : $(DUPMRK) # runs/GET-DEPTH/GET-DEPTH.sh
gvcf  : $(GVCF)
vcf   : $(VCF)
denovo: $(DENOVOS)
# All k > 24 are dependent on k24
$(OTHER_K) : $(TARGET_K)
abyss : $(ABYS)
graph.dot :
	$(MAKE) -Bnd | make2graph -b > graph.dot

%.pdf : %.dot scripts/color-graph.sh
	cat $< | ./scripts/color-graph.sh SS | dot -Tpdf -o $@ 

%.png : %.dot scripts/color-graph.sh
	cat $< | ./scripts/color-graph.sh SS | dot -Tpng -o $@ 

# Validate mapping by using samtools stats
validate : $(SAM_VAL) $(BAM_VAL) $(DUP_VAL)
# plot     : $(PLOT_VAL)

.PHONY: debug

debug :
	@echo "TRIM -----"
	@echo $(P1_READS)
	@echo $(P2_READS)
	@echo $(U1_READS)
	@echo $(U2_READS)
	@echo "MAP ------"
	@echo $(USAM)
	@echo $(PSAM)
	@echo "BAM ------"
	@echo $(UBAM)
	@echo $(PBAM)
	@echo $(MERGED)
	@echo $(FIXED)
	@echo $(DUPMRK)

# Create Output Directories 
$(RUNS) \
$(IDX_DIR) \
$(SAM_DIR) \
$(DEN_DIR) \
$(ABY_DIR) \
$K         \
$(ABY_RUN) \
$(BAM_DIR) \
$(REF_DIR) \
$(GVCF_DIR) \
$(TRIM_DIR) \
$(INT_RUN) \
$(BT2_RUN) \
$(TRM_RUN) \
$(DEN_RUN) \
$(MAP_RUN) \
$(MRG_RUN) \
$(SVL_RUN) \
$(BAM_RUN) \
$(MKD_RUN) \
$(DVL_RUN) \
$(DCT_RUN) \
$(CHR_RUN) \
$(GCF_RUN) \
$(VCF_RUN) \
$(BVL_RUN) :
	-mkdir -p $@


# ==== GENOME PROCESSING ======================================================

# Unzip the reference genome --------------------------------------------------
$(REF_DIR)/genome.fasta : $(FASTA) | $(REF_DIR) $(RUNS) 
	-mkdir -p runs/CAT-GENOME/
	sbatch \
	-D $(ROOT_DIR) \
	-J CAT-GENOME \
	-o runs/CAT-GENOME/CAT-GENOME.out \
	-e runs/CAT-GENOME/CAT-GENOME.out \
	scripts/cat-genome.sh $@ $^ \
	   | cut -c 21- > $@.jid

# Create dictionary for reference
$(REF_DIR)/%.dict : $(REF_DIR)/%.fasta | $(DCT_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J MAKE-GATK-REF \
	-o $(DCT_RUN)/GATK-REF.out \
	-e $(DCT_RUN)/GATK-REF.err \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	scripts/make-GATK-ref-dict.sh $< $(SAMTOOLS) $(PICARD) \
	   | cut -c 21- > $@.jid
		
# Creates intervals for the final step ----------------------------------------
$(REF_DIR)/%.intervals.txt : $(REF_DIR)/%.fasta scripts/make-GATK-intervals.py scripts/make-GATK-intervals.sh | $(INT_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J GATK-INTERVALS \
	-o $(INT_RUN)/GATK-INTERVALS.out \
	-e $(INT_RUN)/GATK-INTERVALS.err \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	scripts/make-GATK-intervals.sh $< 100000 $@ \
	   | cut -c 21- > $@.jid

$(REF_DIR)/%.sizes.txt : $(REF_DIR)/%.fasta scripts/make-GATK-intervals.py scripts/make-GATK-intervals.sh | $(INT_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J GATK-SIZES \
	-o $(INT_RUN)/GATK-SIZES.out \
	-e $(INT_RUN)/GATK-SIZES.err \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	scripts/make-GATK-intervals.sh $< 0 $@ \
	   | cut -c 21- > $@.jid

# Indexing the genome for Bowtie2 ---------------------------------------------
$(BT2_RUN)/jobid.txt: $(REF_FNA) scripts/make-index.sh | $(IDX_DIR) $(BT2_RUN) 
	sbatch \
	-D $(ROOT_DIR) \
	-J BOWTIE2-BUILD \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(BT2_RUN)/BOWTIE2-BUILD.out \
	-e $(BT2_RUN)/BOWTIE2-BUILD.err \
	scripts/make-index.sh \
	   $< $(addprefix $(IDX_DIR)/, $(PREFIX)) $@ $(BOWTIE) \
	   | cut -c 21- > $@ 

# Accounting for BOWTIE2 index files
$(IDX) : $(BT2_RUN)/jobid.txt

# Quality trimming the reads --------------------------------------------------
# 	Note: the second read is implied here. Because of the way makefiles
# 	work, it would attempt to run this twice to account for the second
# 	read if I were to include it in here. 
$(TRIM_DIR)/%_1P.fq.gz: reads/%_1.fq.gz scripts/trim-reads.sh | $(TRIM_DIR) $(TRM_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J TRIM-READS \
	-o $(TRM_RUN)/$*.out \
	-e $(TRM_RUN)/$*.err \
	scripts/trim-reads.sh $* $(@D) $(TRIMMOD) \
	   | cut -c 21- > $(@D)/$*.jid

$(P2_READS) $(U1_READS) $(U2_READS) : $(P1_READS)

# Mapping the reads -----------------------------------------------------------
# 	Note: The paired reads and unpaired reads need to be mapped separately
# 	It's a bit irritating, but that's the way it is.
#
# ---- Paired Reads -----------------------------------------------------------
$(SAM_DIR)/%_P.sam : $(TRIM_DIR)/%_1P.fq.gz scripts/make-alignment.sh $(IDX) $(P2_READS) | $(SAM_DIR) $(MAP_RUN) 
	sbatch \
	-D $(ROOT_DIR) \
	-J MAP-READS \
	--dependency=afterok:$$(bash scripts/get-job.sh $(BT2_RUN)/jobid.txt $(<D)/$*.jid) \
	-o $(MAP_RUN)/$*_P.out \
	-e $(MAP_RUN)/$*_P.err \
	scripts/make-alignment.sh \
	   $(addprefix $(IDX_DIR)/, $(PREFIX)) $(@D) P.fq.gz $(<D)/$* $(BOWTIE) \
	   | cut -c 21- > $@.jid

# ---- Unpaired Reads ---------------------------------------------------------
$(SAM_DIR)/%_U.sam : $(TRIM_DIR)/%_1U.fq.gz scripts/make-alignment.sh $(IDX) $(U2_READS) | $(SAM_DIR) $(MAP_RUN) 
	sbatch \
	-D $(ROOT_DIR) \
	-J MAP-READS \
	--dependency=afterok:$$(bash scripts/get-job.sh $(BT2_RUN)/jobid.txt $(<D)/$*.jid) \
	-o $(MAP_RUN)/$*_U.out \
	-e $(MAP_RUN)/$*_U.err \
	scripts/make-alignment.sh \
	   $(addprefix $(IDX_DIR)/, $(PREFIX)) $(@D) U.fq.gz $(<D)/$* $(BOWTIE) \
	   | cut -c 21- > $@.jid

# Sorting and Converting to BAM files -----------------------------------------
$(BAM_DIR)/%_nsort.bam : $(SAM_DIR)/%.sam scripts/sam-to-bam.sh | $(BAM_DIR) $(BAM_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J SAM-TO-BAM \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(BAM_RUN)/$*_nsort.out \
	-e $(BAM_RUN)/$*_nsort.err \
	scripts/sam-to-bam.sh $(<D) $(@D) $* $(SAMTOOLS) \
	   | cut -c 21- > $@.jid

# Merging sorted BAM files
$(BAM_DIR)/%_merged.bam : $(BAM_DIR)/%_P_nsort.bam scripts/merge-bam.sh $(UBAM) | $(MRG_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J MERGE \
	--dependency=afterok:$$(bash scripts/get-job.sh $(<D)/$*_P_nsort.bam.jid $(<D)/$*_U_nsort.bam.jid) \
	-o $(MRG_RUN)/$*_merged.out \
	-e $(MRG_RUN)/$*_merge.err \
	scripts/merge-bam.sh $@ $(<D)/$* $(SAMTOOLS) \
	   | cut -c 21- > $@.jid

# Fix mate information and add the MD tag -------------------------------------
$(BAM_DIR)/%_fixed.bam : $(BAM_DIR)/%_merged.bam scripts/add-MD-tag.sh 
	sbatch \
	-D $(ROOT_DIR) \
	-J ADD-MD-TAG \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(BAM_RUN)/$*_fixed.out \
	-e $(BAM_RUN)/$*_fixed.err \
	scripts/add-MD-tag.sh $< $(SAMTOOLS) $(REF_FNA) \
	   | cut -c 21- > $@.jid

# Marking optical duplicates with picard --------------------------------------
$(BAM_DIR)/%_dupmrk.bam : $(BAM_DIR)/%_fixed.bam scripts/mark-duplicates.sh | $(MKD_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J MARK-DUPS \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(MKD_RUN)/$*.out \
	-e $(MKD_RUN)/$*.err \
	scripts/mark-duplicates.sh $< $(SAMTOOLS) $(PICARD) \
	   | cut -c 21- > $@.jid

# Make the GVCF files to use for variant calling later ------------------------
$(GVCF_DIR)/%.g.vcf.gz : $(BAM_DIR)/%_dupmrk.bam scripts/make-GVCF.sh $(REF_IDX) | $(GVCF_DIR) $(GCF_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J MAKE-GVCF \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid $(REF_IDX).jid) \
	-o $(GCF_RUN)/$*.out \
	-e $(GCF_RUN)/$*.err \
	scripts/make-GVCF.sh \
	   $< $@ $(gatk) $(ROOT_DIR)/$(REF_FNA) $(GATK) \
	   | cut -c 21- > $@.jid

# Call variants in separate windows and concatenate ---------------------------
#
# 	This is a slightly difficult task because we don't want to flood the 
#	scheduler with so many jobs. Plus, these jobs need so many resources that
#	they end up running one at a time. So, we split these jobs by chromosome and
#	create the contingency that all of the GVCF jobs must be finished before the
# 	windows can even be submitted. 
#
#	NOTE:
# 	- This assumes that the first 8 characters of your FASTA headers are unique
# 	  identifiers. If not, change the `cut -c 1-8` command to the proper range
#
$(CHR_JOBS) : $(GVCF) | $(INTERVALS) scripts/make-VCF.sh scripts/CAT-VCF.sh scripts/chromosome-jobs.sh $(VCF_RUN) $(CHR_RUN)
	mkdir -p $(CHR_JOBS)
	sleep 10 # to allow the intervals enough time to be computed
	for i in $$(grep '>' $(REF_FNA) | sed 's/>//' | cut -c 1-8); \
	do \
		sbatch \
		-D $(ROOT_DIR) \
		-J $$i \
		--dependency=afterok:$$(bash scripts/get-job.sh $(addsuffix .jid, $(GVCF))) \
		-o $(CHR_RUN)/$$i.out \
		-e $(CHR_RUN)/$$i.err \
		scripts/chromosome-jobs.sh $(CHR_JOBS)/$$i.jobid | cut -c 21- > $(CHR_JOBS)/$$i.jid; \
	done;

$(GVCF_DIR)/res.vcf.jid :
	sbatch \
	-D $(ROOT_DIR) \
	-J MAKE-VCF \
	-o $(VCF_RUN)/cat-vcf.out \
	-e $(VCF_RUN)/cat-vcf.err \
	--dependency=afterok:$$(bash scripts/get-job.sh $(GVCF_DIR)/*jid) \
	scripts/CAT-VCF.sh $(GVCF_DIR) $(VCFTOOLS) \
	   | cut -c 21- > $@

$(VCF) : $(CHR_JOBS)
	printf '#!/usr/bin/env bash\nmake $(GVCF_DIR)/res.vcf.jid\n' > $(GVCF_DIR)/schedule.vcf.jid
	sbatch \
	-D $(ROOT_DIR) \
	-J VCF-SCHEDULE \
	-o $(VCF_RUN)/schedule-vcf.out \
	-e $(VCF_RUN)/schedule-vcf.err \
	--hold \
	$(GVCF_DIR)/schedule.vcf.jid \
	   | cut -c 21- > $(GVCF_DIR)/res.vcf.tmp.jid
	sbatch \
	-D $(ROOT_DIR) \
	-J VCF \
	--dependency=afterok:$$(bash scripts/get-job.sh $(CHR_JOBS)/*jid) \
	-o $(VCF_RUN)/release-vcf.out \
	-e $(VCF_RUN)/release-vcf.err \
	scripts/release-job.sh 10 $(GVCF_DIR)/res.vcf.tmp.jid
	
# ---- Call variants in intervals within a given chromosome -------------------
#
#	This works by taking the chromosome name and getting all the intervals
#	within the interval file. The error and out files will be the chromosome
#	identifier with the range.
#	The resulting vcf.gz file will be res.JOBID.vcf.gz
#
$(CHR_JOBS)/%.jobid : $(CHR_JOBS)/%.jid
	for i in $$(grep $* $(INTERVALS)); \
	do \
		suffix=$$(awk -F: '{print $$2}' <<< $$i); \
		sbatch \
		-D $(ROOT_DIR) \
		-J $*-$$suffix \
		--dependency=afterok:$$(bash scripts/get-job.sh $(addsuffix .jid, $(GVCF))) \
		-o $(VCF_RUN)/$*-$$suffix.out \
		-e $(VCF_RUN)/$*-$$suffix.err \
		scripts/make-VCF.sh \
		   $(GVCF_DIR)/res $(gatk) $(ROOT_DIR)/$(REF_FNA) \
		   $(GATK) $$i $(addprefix -V , $(GVCF)) | \
		   cut -c 21- > $(GVCF_DIR)/res.$*-$$suffix.jid; \
	done
	cp $< $@

# DE-NOVO ALIGNMENT ===========================================================

# Mapping the reads -----------------------------------------------------------
$(DEN_DIR)/%/scaffolds.fasta : $(TRIM_DIR)/%_1P.fq.gz scripts/make-denovo-assembly.sh | $(DEN_DIR) $(DEN_RUN) 
	mkdir -p $(DEN_DIR)/$*
	sbatch \
	-D $(ROOT_DIR) \
	-J $*-DENOVO \
	--dependency=afterok:$$(bash scripts/get-job.sh $(<D)/$*.jid) \
	-o $(DEN_RUN)/$*.out \
	-e $(DEN_RUN)/$*.err \
	scripts/make-denovo-assembly.sh \
	   $(<D)/$* $(DEN_DIR)/$* $(SPADES) | \
	   cut -c 21- > $@.jid

# Runinning abyss on different values of K
$(ABY_DIR)/k24/%-scaffolds.fa: $(TRIM_DIR)/%_1P.fq.gz scripts/make-abyss-assembly.sh | $(ABY_DIR) $(ABY_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J $*-ABYSS \
	--array=24-96:8 \
	--dependency=afterok:$$(bash scripts/get-job.sh $(<D)/$*.jid) \
	-o $(ABY_RUN)/%x-k%a.out \
	-e $(ABY_RUN)/%x-k%a.err \
	scripts/make-abyss-assembly.sh \
	   $(<D) $* $(ABY_DIR) | \
	   cut -c 21- > $(ABY_DIR)/$*.jid
# ==== VALIDATION STEPS =======================================================

# Validating the mapping ------------------------------------------------------
$(SAM_DIR)/%_stats.txt.gz : $(SAM_DIR)/%.sam scripts/validate-sam.sh | $(SVL_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J VALIDATE-READS \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(SVL_RUN)/$*.out \
	-e $(SVL_RUN)/$*.err \
	scripts/validate-sam.sh $< $(SAMTOOLS) | cut -c 21- > $@.jid

# Validating the bamfiles -----------------------------------------------------
$(BAM_DIR)/%_fixed_stats.txt.gz : $(BAM_DIR)/%_fixed.bam scripts/validate-sam.sh | $(BVL_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J VALIDATE-BAMS \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(BVL_RUN)/$*.out \
	-e $(BVL_RUN)/$*.err \
	scripts/validate-sam.sh $< $(SAMTOOLS) | cut -c 21- > $@.jid

# Validating the optical duplicate filtering ----------------------------------
$(BAM_DIR)/%_dupmrk_stats.txt.gz : $(BAM_DIR)/%_dupmrk.bam scripts/validate-sam.sh | $(DVL_RUN)
	sbatch \
	-D $(ROOT_DIR) \
	-J VALIDATE-BAMS \
	--dependency=afterok:$$(bash scripts/get-job.sh $<.jid) \
	-o $(DVL_RUN)/$*.out \
	-e $(DVL_RUN)/$*.err \
	scripts/validate-sam.sh $< $(SAMTOOLS) | cut -c 21- > $@.jid


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
	@echo "all		makes everything: res.vcf.gz"
	@echo "index		generate the bowtie2 index"
	@echo "trim		trims reads with trimmomatic"
	@echo "map		map reads with samtools"
	@echo "bam		convert sam to bam, filter, and remove duplicates"
	@echo "validate	run validation stats on the bam and sam files"
	@echo "gvcf		create g.vcf files from HaplotypeCaller"
	@echo "vcf		create vcf files (this is the longest step)" 
	@echo
	@echo "help		show this message" 
	@echo "clean		remove all *.jid files"
	@echo "cleanall	REMOVE ALL GENERATED FILES"
	@echo
	@echo "PARAMETERS"
	@echo "============"
	@echo
	@echo "ROOT DIR  : " $(ROOT_DIR)
	@echo "TEMP DIR  : " $(TMP)
	@echo "INDEX DIR : " $(IDX_DIR)
	@echo "PREFIX    : " $(PREFIX)
	@echo "GENOME    : " $(FASTA)
	@echo "READS     : " $(READS)
	@echo
	@echo "Modules"
	@echo "============"
	@echo
	@echo "BOWTIE   : " $(BOWTIE)
	@echo "TRIMMOD  : " $(TRIMMOD)
	@echo "SAMTOOLS : " $(SAMTOOLS)
	@echo "VCFTOOLS : " $(VCFTOOLS)
	@echo "PICARD   : " $(PICARD)
	@echo "GATK     : " $(GATK)
	@echo

cleanall:
	$(RM) -r $(TRIM_DIR) \
	         $(IDX_DIR) \
	         $(SAM_DIR) \
	         $(BAM_DIR) \
	         $(GVCF_DIR) runs \
	         $(REF_DIR) 

clean:
	$(RM) $(IDX_DIR)/*.jid \
		  $(SAM_DIR)/*.jid \
		  $(BAM_DIR)/*.jid \
		  $(REF_DIR)/*.jid \
		  $(GVCF_DIR)/*.jid \
	          $(CHROM_DIR)/*.jid \
		  $(TRIM_DIR)/*.jid \
	          $(GVCF_DIR)/res.*.vcf.gz*
