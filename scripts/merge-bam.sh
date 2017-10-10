#!/usr/bin/env bash
#
# Set job time
#SBATCH --time=04:00:00
#
#
# Set memory requested and max memory
#SBATCH --mem=4gb
#
# Request some processors
#SBATCH --cpus-per-task=1
#SBATCH --ntasks=1

if [ $# -lt 3 ]; then
	echo
	echo "Merge paired and unpaired bam files"
	echo
	echo "Usage: merge-bam.sh <OUT> <BASE> <SAMTOOLS>"
	echo
	echo "	<OUT>      - The output file (e.g. BAMS/SS.11.01_merged.bam)"
	echo "	<BASE>     - base name and directory for the samples (e.g. BAMS/SS.11.01)"
	echo "	<SAMTOOLS> - the samtools module (e.g. samtools/1.3)"
	echo
	exit
fi

OUT=$1
BASE=$2
SAMTOOLS=$3

PAIRED="${BASE}_P_nsort.bam"
UNPAIRED="${BASE}_U_nsort.bam"
CMD="samtools merge -c ${OUT} ${PAIRED} ${UNPAIRED}"

module load ${SAMTOOLS}

# Run the command through time with memory and such reporting.
# warning: there is an old bug in GNU time that overreports memory usage
# by 4x; this is compensated for in the SGE_Plotdir script.
TIME='/usr/bin/env time -f " \\tFull Command:                      %C \\n\\tMemory (kb):                       %M \\n\\t# SWAP  (freq):                    %W \\n\\t# Waits (freq):                    %w \\n\\tCPU (percent):                     %P \\n\\tTime (seconds):                    %e \\n\\tTime (hh:mm:ss.ms):                %E \\n\\tSystem CPU Time (seconds):         %S \\n\\tUser   CPU Time (seconds):         %U " '

# Write details to stdout
echo "  Job: ${SLURM_JOB_ID}"
echo
echo "  Started on:           " `/bin/hostname -s`
echo "  Started at:           " `/bin/date`
echo ${CMD}

eval ${TIME}${CMD} # Running the command.

echo "  Finished at:           " `date`
echo
# End of file
