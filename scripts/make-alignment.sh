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
	echo "	<suffix>  - suffix for the reads (e.g.: P.fq.gz)"
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

CMD="bowtie2 -x $IDX -S $DIR/"

# Create named pipes because bowtie2 is stupid and can't handle gzipped files >:(
# Note that I have to make four of these, two for the paired reads and two for the
# unpaired reads.
MKFIFO="mkfifo \
\$TMPDIR/M1.fifo \
\$TMPDIR/M2.fifo \
\$TMPDIR/U1.fifo \
\$TMPDIR/U2.fifo"

M1=$SAMPLE"_1$SUF"
M2=$SAMPLE"_2$SUF"
U1=$SAMPLE"_1U.fq.gz"
U2=$SAMPLE"_2U.fq.gz"

WFIFO="zcat $M1 > \$TMPDIR/M1.fifo \
& zcat $M2 > \$TMPDIR/M2.fifo \
& zcat $U1 > \$TMPDIR/U1.fifo \
& zcat $U2 > \$TMPDIR/U2.fifo \
&"

# Info Line: 
#          0	     1	          2	      3	      4	5	   6	       7	         8
# INSTRUMENT	RUN_NO	FLOWCELL_ID	LANE_NO	TILE_ID	X	Y	READ	FILTERED	CONTROL_NO
INFO=($(zcat $M1 | head -n 1 | sed 's/:/ /g'))

# Setting arguments
ARGS="-1 \$TMPDIR/M1.fifo,\$TMPDIR/U1.fifo \
-2 \$TMPDIR/M2.fifo,\$TMPDIR/U2.fifo \
--maxins 800 \
--fr"
BASE=$(basename $SAMPLE)

# Setup read group information for GATK
RGID="--rg-id ${INFO[2]}.${INFO[3]}"
RG="--rg SM:$BASE \
--rg PL:ILLUMINA \
--rg LB:RUN.${INFO[1]}"

# Run the command through time with memory and such reporting.
# warning: there is an old bug in GNU time that overreports memory usage
# by 4x; this is compensated for in the SGE_Plotdir script.
TIME='/usr/bin/env time -f " \\tFull Command:                      %C \\n\\tMemory (kb):                       %M \\n\\t# SWAP  (freq):                    %W \\n\\t# Waits (freq):                    %w \\n\\tCPU (percent):                     %P \\n\\tTime (seconds):                    %e \\n\\tTime (hh:mm:ss.ms):                %E \\n\\tSystem CPU Time (seconds):         %S \\n\\tUser   CPU Time (seconds):         %U " '
CMD="$MKFIFO; $WFIFO $TIME $CMD$BASE.sam $ARGS $RGID $RG"


# Write details to stdout
echo "  Job: $SLURM_JOB_ID"
echo
echo "  Started on:           " `/bin/hostname -s`
echo "  Started at:           " `/bin/date`
echo $CMD

# Writing to a jobfile before the command is executed allows for a hack to make
# a target for the Makefile that is older than the multiple files for output.
# printf "$SLURM_JOB_ID\n" > $JOBFILE

eval $CMD

echo "  Finished at:           " `date`
echo
# End of file
