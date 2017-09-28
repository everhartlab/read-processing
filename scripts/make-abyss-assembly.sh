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
	echo "Perform de Novo assembly with ABySS."
	echo
	echo
	echo "This assumes that the data are paired-end reads. It also assumes that K will be"
	echo "determined from the array number."
	echo
	echo "Usage:"
	echo
	echo "  bash make-abyss-assembly.sh <prefix> <outdir>"
	echo
	echo "	<indir>  The input directory"
	echo "	<prefix> the prefix of the sample, which will have _1.fq.gz appended (e.g. SS.11.01)"
	echo "	<outdir> the directory for the output files of SPAdes"
	echo
	exit
fi



INDIR=$1
PREFIX=$2
OUTDIR=$3
KDIR=${OUTDIR}/${PREFIX}/k${SLURM_ARRAY_TASK_ID}
STEM=${INDIR}/${PREFIX}


# NOTE TO FUTURE ZHIAN:
# 
# It appears as if we need to have ABYSS-P installed for the parallel version
# The way we can do that... I think... is by running the installation process
# of abyss on the cluster using openmp 
CMD="abyss-pe \
-C ${KDIR} \
name=${PREFIX} \
k=${SLURM_ARRAY_TASK_ID} \
n=8 \
G=38906597 \
np=1 \
in='$(pwd)/${STEM}_1P.fq.gz $(pwd)/${STEM}_2P.fq.gz'"

# Run the command through time with memory and such reporting.
# warning: there is an old bug in GNU time that overreports memory usage
# by 4x; this is compensated for in the SGE_Plotdir script.
TIME='/usr/bin/env time -f " \\tFull Command:                      %C \\n\\tMemory (kb):                       %M \\n\\t# SWAP  (freq):                    %W \\n\\t# Waits (freq):                    %w \\n\\tCPU (percent):                     %P \\n\\tTime (seconds):                    %e \\n\\tTime (hh:mm:ss.ms):                %E \\n\\tSystem CPU Time (seconds):         %S \\n\\tUser   CPU Time (seconds):         %U " '


module load compiler/gcc/6.1 openmpi/2.1

# Write details to stdout
echo "  Job: $SLURM_ARRAY_JOB_ID"
echo "  Task: ${SLURM_ARRAY_TASK_ID}"
echo
echo "  Started on:           " `/bin/hostname -s`
echo "  Started at:           " `/bin/date`
echo ${CMD}

# Writing to a jobfile before the command is executed allows for a hack to make
# a target for the Makefile that is older than the multiple files for output.
# printf "$SLURM_JOB_ID\n" > $JOBFILE

mkdir -p ${KDIR}
eval ${TIME}${CMD}

echo "  Finished at:           " `date`
echo
# End of file
