#!/usr/bin/env bash
#
# Set job time
#SBATCH --time=04:00:00
#
# Set memory requested and max memory
#SBATCH --mem=4gb
#
# Request some processors
#SBATCH --cpus-per-task=4
#SBATCH --ntasks=1

if [ $# -lt 5 ]; then
	echo
	echo "Align samples to indexed genome output."
	echo
	echo
	echo "This assumes that the data are paired-end reads."
	echo
	echo "Usage:"
	echo
	echo "  bash make-index.sh <bt2-idx> <dir> <sample> <bt2mod>"
	echo
	echo "	<bt2-idx> - basename of reference (with path)"
	echo "	<dir>     - directory in which to place the SAM files"
	echo "	<suffix>  - suffix for the reads to determine if these are paired" 
	echo "	            or unpaired (e.g.: P.fq.gz indicated paired and U.fq.gz"
	echo "	            indicates unpaired)"
	echo "	<sample>  - a sample without the suffix (e.g.: TRIM/SS.11.01)"
	echo "  <bt2mod>  - bowtie2 module (bowtie/2.2)"
	echo
	exit
fi

IDX=$1
DIR=$2
SUF=$3
SAMPLE=$4
BT2MOD=$5

module load $BT2MOD


# Create named pipes because bowtie2 is stupid and can't handle gzipped files >:(
MKFIFO="mkfifo \
\$TMPDIR/S1.fifo \
\$TMPDIR/S2.fifo"

S1=${SAMPLE}"_1${SUF}"
S2=${SAMPLE}"_2${SUF}"

WFIFO="zcat ${S1} > \$TMPDIR/S1.fifo \
& zcat ${S2} > \$TMPDIR/S2.fifo \
& "

# Info Line: 
#          0	     1	          2	      3	      4	5	   6	       7	         8
# INSTRUMENT	RUN_NO	FLOWCELL_ID	LANE_NO	TILE_ID	X	Y	READ	FILTERED	CONTROL_NO
INFO=($(zcat ${S1} | head -n 1 | sed 's/:/ /g'))
BASE="$(basename ${SAMPLE})"

# Catch paired or unpaired reads
if [ "${SUF}" = "P.fq.gz" ]; then
	ONE="-1"
	TWO="-2"
	FILE="${BASE}_P"
else # unpaired reads need no special identifier
	ONE="-U"
	TWO="-U"
	FILE="${BASE}_U"
fi

CMD="bowtie2 -x ${IDX} -S ${DIR}/${FILE}.sam"
# Setting arguments
ARGS="-p 2 \
-t \
--maxins 800 \
--fr \
${ONE} \$TMPDIR/S1.fifo \
${TWO} \$TMPDIR/S2.fifo"

# Setup read group information for GATK
RGID="--rg-id ${INFO[2]}.${INFO[3]}"
RG="--rg SM:${BASE} \
--rg PL:ILLUMINA \
--rg LB:RUN.${INFO[1]}"

# Run the command through time with memory and such reporting.
# warning: there is an old bug in GNU time that overreports memory usage
# by 4x; this is compensated for in the SGE_Plotdir script.
TIME='/usr/bin/env time -f " \\tFull Command:                      %C \\n\\tMemory (kb):                       %M \\n\\t# SWAP  (freq):                    %W \\n\\t# Waits (freq):                    %w \\n\\tCPU (percent):                     %P \\n\\tTime (seconds):                    %e \\n\\tTime (hh:mm:ss.ms):                %E \\n\\tSystem CPU Time (seconds):         %S \\n\\tUser   CPU Time (seconds):         %U " '
CMD="${MKFIFO}; ${WFIFO} ${TIME} ${CMD} ${ARGS} ${RGID} ${RG}"


# Write details to stdout
echo "  Job: ${SLURM_JOB_ID}"
echo
echo "  Started on:           " `/bin/hostname -s`
echo "  Started at:           " `/bin/date`
echo ${CMD}

# Writing to a jobfile before the command is executed allows for a hack to make
# a target for the Makefile that is older than the multiple files for output.
# printf "$SLURM_JOB_ID\n" > $JOBFILE

eval ${CMD}

echo "  Finished at:           " `date`
echo
# End of file
