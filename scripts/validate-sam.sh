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
#
#
if [ $# -lt 2 ]; then
	echo
	echo "Validate samfiles OR bamfiles with samtools stats"
	echo
	echo "Usage: bash validate-sam.sh <samfile> <samtools-module>"
	echo
	echo "	<samfile> a sam file with the extension .sam"
	echo "	<samtools-module> the samtools module (e.g. samtools/1.3)"
	echo
	exit
fi

SAM=$1
SAMTOOLS=$2
OUT=$(sed 's/\..am$/_stats.txt.gz/' <<< $SAM)
CMD="samtools stats $SAM | gzip -c > $OUT"

module load $SAMTOOLS

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