#!/usr/bin/env bash
#
# Set job time
#SBATCH --time=24:00:00
#
# Set memory requested and max memory
#SBATCH --mem=50gb
#
# Request some processors
#SBATCH --cpus-per-task=8
#SBATCH --ntasks=1

if [ $# -lt 3 ]; then
	echo
	echo "Perform de Novo assembly with SPAdes."
	echo
	echo
	echo "This assumes that the data are paired-end reads."
	echo
	echo "Usage:"
	echo
	echo "  bash make-denovo-assembly.sh <prefix> <outdir> <SPAdes>"
	echo
	echo "  <prefix> the prefix of the sample, which will have _1.fq.gz appended (e.g. SS.11.01)"
	echo "	<outdir> the directory for the output files of SPAdes"
	echo "	<SPAdes> the module specification for SPAdes"
	echo
	exit
fi



PREFIX=$1
OUTDIR=$2
SPADES=$3


CMD="spades.py \
-k 21,33,55,77,99 \
--careful \
--pe1-1 ${PREFIX}_1P.fq.gz \
--pe1-2 ${PREFIX}_2P.fq.gz \
-o ${OUTDIR}"

module load $SPADES
# Run the command through time with memory and such reporting.
# warning: there is an old bug in GNU time that overreports memory usage
# by 4x; this is compensated for in the SGE_Plotdir script.
TIME='/usr/bin/env time -f " \\tFull Command:                      %C \\n\\tMemory (kb):                       %M \\n\\t# SWAP  (freq):                    %W \\n\\t# Waits (freq):                    %w \\n\\tCPU (percent):                     %P \\n\\tTime (seconds):                    %e \\n\\tTime (hh:mm:ss.ms):                %E \\n\\tSystem CPU Time (seconds):         %S \\n\\tUser   CPU Time (seconds):         %U " '

# Write details to stdout
echo "  Job: $SLURM_JOB_ID"
echo
echo "  Started on:           " `/bin/hostname -s`
echo "  Started at:           " `/bin/date`
echo ${CMD}

# Writing to a jobfile before the command is executed allows for a hack to make
# a target for the Makefile that is older than the multiple files for output.
# printf "$SLURM_JOB_ID\n" > $JOBFILE

eval ${TIME}${CMD}

echo "  Finished at:           " `date`
echo
# End of file
