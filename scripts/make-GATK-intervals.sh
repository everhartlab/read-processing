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
module load python/3.5


if [ $# -lt 3 ]; then
	echo 
	echo "Create a list of genomic intervals for use with GATK"
	echo
	echo
	echo "Usage:"
	echo
	echo "	bash make-GATK-intervals.sh <fasta> <window> <outfile>" 
	echo
	echo "	<fasta> - a fasta file of the reference"
	echo "	<window> - an integer specifying the window size"
	echo "	<outfile> - the name of a text file to write the windows"
	echo
	exit
fi

CMD="./scripts/make-GATK-intervals.py -f $1 -w $2 > $3"

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