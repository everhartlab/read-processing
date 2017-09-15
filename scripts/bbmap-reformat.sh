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
if [ $# -lt 3 ]; then
	echo
	echo "Validate samfiles OR bamfiles with samtools stats"
	echo
	echo "Usage: bash bbmap-reformat.sh <prefix> ARGS..."
	echo
	echo "	<dir>	directory containing the reads"
	echo "	<prefix> The prefix of the sample for paired-end reads"
	echo "	ARGS... arguments to be passed to reformat.sh"
	echo
	exit
fi

IN=${1}/${2}
OUT=${1}/sub.${2}
ARGS=${@:3}
CMD="reformat.sh  in1=${IN}_1.fq.gz   in2=${IN}_2.fq.gz \
                 out1=${OUT}_1.fq.gz out2=${OUT}_2.fq.gz \
                 ${ARGS[@]}"
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
