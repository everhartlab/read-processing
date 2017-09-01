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
# -----------------------------------------------------------------------------
# 	This file makes a copy of one file to another on a SLURM Array.
#
# -----------------------------------------------------------------------------
#
#
if [ $# -lt 2 ]; then
	echo
	echo "Run a file"
	echo
	echo
	echo "This script takes a file in and copies it to out"
	echo
	echo "Usage:"
	echo
	echo "	sbatch -J JOBNAME \\"
	echo "	       -o PATH/TO/outfile.out \\"
	echo "	       -e PATH/TO/errorfile.err \\"
	echo "	       run.sh <in> <out>
	echo
	exit
fi

IN=$1
OUT=$2
CMD="cp $IN $OUT"

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