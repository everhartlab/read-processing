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
	echo "Usage: make-GATK-ref-dict.sh <REFERENCE> <SAMTOOLS> <PICARD>"
	echo
	echo "	<REFERENCE> - Reference FASTA file"
	echo "	<SAMTOOLS>  - the samtools module (e.g. samtools/1.3)"
	echo "	<PICARD>    - the samtools module (e.g. picard/2.9)"
	echo
	exit
fi

REF=$1
SAMTOOLS=$2
PICARD=$3

DICT=$(sed 's/fasta/dict/' <<< $REF)

CMD="picard CreateSequenceDictionary REFERENCE=$REF OUTPUT=$DICT"


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
eval $TIME" samtools faidx $REF"

echo "  Finished at:           " `date`
echo
# End of file
