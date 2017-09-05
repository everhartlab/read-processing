#!/usr/bin/env bash
#
# Set job time
#SBATCH --time=04:00:00
#
# Set memory requested and max memory
#SBATCH --mem=4gb
#
# Request some processors
#SBATCH --cpus-per-task=1
#SBATCH --ntasks=1


if [ $# -lt 3 ]; then
	echo 
	echo "Trim reads with trimmomatic"
	echo
	echo
	echo "This script takes in the name of the first read file of a pair and the"
	echo "output directory. It assumes that the reads are in a pair."
	echo
	echo "Usage:"
	echo
	echo "	bash trim-reads.sh <readpair> <trim_dir> <trimmomatic>" 
	echo
	echo "	<readpair>    - prefix to pair of gzipped fasta files"
	echo "	<trim_dir>    - the directory to store the outupt"
	echo "	<trimmomatic> - module for trimmomatic (e.g. trimmomatic/0.36)"
	echo
	echo "Output consists of four files in the trim_dir:"
	echo
	echo "	readpair_1P.fq.gz"
	echo "	readpair_1U.fq.gz"
	echo "	readpair_2P.fq.gz"
	echo "	readpair_2U.fq.gz"
	exit
fi

READ_PREFIX=$1
TRIM_DIR=$2
TRIMMOMATIC=$3

CMD="trimmomatic PE -phred33 reads/${READ_PREFIX}_1.fq.gz reads/${READ_PREFIX}_2.fq.gz"
CMD=$CMD" -baseout ${TRIM_DIR}/${READ_PREFIX}.fq.gz"
CMD=$CMD" ILLUMINACLIP:/util/opt/anaconda/2.0/envs/trimmomatic-0.36/share/trimmomatic/adapters/TruSeq3-PE.fa:2:30:10"
CMD=$CMD" LEADING:28"
CMD=$CMD" TRAILING:28"
CMD=$CMD" SLIDINGWINDOW:4:28"
CMD=$CMD" MINLEN:36"

module load $TRIMMOMATIC

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

# Writing to a jobfile before the command is executed allows for a hack to make
# a target for the Makefile that is older than the multiple files for output.
# printf "$SLURM_JOB_ID\n" > $JOBFILE

eval $TIME$CMD # Running the command.

echo "  Finished at:           " `date`
echo
# End of file
