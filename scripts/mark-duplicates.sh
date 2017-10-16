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
#SBATCH --cpus-per-task=4
#SBATCH --ntasks=1

if [ $# -lt 3 ]; then
	echo
	echo "Usage: add-MD-tag.sh <BAM> <SAMTOOLS>"
	echo
	echo "	<BAM>       - bamfile"
	echo "	<SAMTOOLS>  - the samtools module (e.g. samtools/1.3)"
	echo "	<PICARD>    - the samtools module (e.g. picard/2.9)"
	echo
	exit
fi

BAM=$1
SAMTOOLS=$2
PICARD=$3

BAMDUP=$(sed 's/_fixed\.bam/_dupmrk.bam/' <<< $BAM)
METRICS=$(sed 's/_fixed\.bam/_marked_dup_metrics.txt/' <<< $BAM)

CMD="picard MarkDuplicates \
I=$BAM \
O=$BAMDUP \
M=$METRICS \
MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=1000 \
ASSUME_SORTED=true"

module load $SAMTOOLS
module load $PICARD

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
echo 
echo "  Making index at:      " `/bin/date`
echo "samtools index ${BAMDUP}"
eval $TIME" samtools index nthreads=4 $BAMDUP"

echo "  Finished at:           " `date`
echo
# End of file
