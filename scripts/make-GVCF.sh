#!/usr/bin/env bash
#
# Set job time
#SBATCH --time=04:00:00
#
#
# Set memory requested and max memory
#SBATCH --mem=25gb
#
# Request some processors
#SBATCH --cpus-per-task=1
#SBATCH --ntasks=1

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
# Pain points:
# 
# GATK is very picky as far as paths go. If it sees a relative
# path, it will use pwd. On this SLURM system, this results in
# a path that's not accessible.
#
# GATK assumes that you named your dict file with the basename
# of your file and not just appended dict on the end.
#

if [ $# -lt 5 ]; then
	echo
	echo "Usage: make-GVCF.sh <BAM> <GVCF> <GATKVAR> <REFERENCE> <GATK>"
	echo
	echo "	<BAM>       - bamfile with duplicates marked"
	echo "	<GVCF>      - g.vcf.gz file to write to"
	echo "	<GATKVAR>   - environmental variable or path pointing to GATK"
	echo "	<REFERENCE> - ABSOLUTE PATH to reference fasta file"
	echo "	<GATK>      - GATK module (e.g. gatk/3.4)"
	echo
	exit
fi


BAM=$1
GVCF=$2
GATKVAR=$3
REFERENCE=$4
GATK=$5

CMD="java -Djava.io.tmpdir=$TMPDIR -jar $GATKVAR \
-T HaplotypeCaller \
-R $REFERENCE \
--emitRefConfidence GVCF \
-ploidy 1 \
-I $BAM \
-o $GVCF"

module load $GATK
# Run the command through time with memory and such reporting.
# warning: there is an old bug in GNU time that overreports memory usage
# by 4x; this is compensated for in the SGE_Plotdir script.
TIME='/usr/bin/env time -f " \\tFull Command:                      %C \\n\\tMemory (kb):                       %M \\n\\t# SWAP  (freq):                    %W \\n\\t# Waits (freq):                    %w \\n\\tCPU (percent):                     %P \\n\\tTime (seconds):                    %e \\n\\tTime (hh:mm:ss.ms):                %E \\n\\tSystem CPU Time (seconds):         %S \\n\\tUser   CPU Time (seconds):         %U " '

# Write details to stdout
echo "  Job: $SLURM_JOB_ID"
echo
echo "  Started on:           " `/bin/hostname -s`
echo "  Started at:           " `/bin/date`
echo $CMD

eval $TIME$CMD # Running the command.

echo "  Finished at:           " `date`
echo
# End of file
