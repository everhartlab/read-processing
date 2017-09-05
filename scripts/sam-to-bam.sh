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

if [ $# -lt 4 ]; then
	echo
	echo "Usage: sam-to-bam.sh <SAMDIR> <BAMDIR> <BASE> <SAMTOOLS>"
	echo
	echo "	<SAMDIR> - the directory for the samfiles"
	echo "	<BAMDIR> - the directory for the bamfiles"
	echo "	<BASE>   - base name for the sample (e.g. SS.11.01)"
	echo "	<SAMTOOLS> - the samtools module (e.g. samtools/1.3)"
	echo
	exit
fi


# SAMTOOLS SPECIFICATIONS
#
# http://www.htslib.org/doc/
# view
# # -b       output BAM
# # -S       ignored (input format is auto-detected)
# # -u       uncompressed BAM output (implies -b)
#
# sort
# # -n         Sort by read name
# # -o FILE    output file name [stdout]
# # -O FORMAT  Write output as FORMAT ('sam'/'bam'/'cram')   (either -O or
# # -T PREFIX  Write temporary files to PREFIX.nnnn.bam       -T is required)
#
# calmd
# # -u         uncompressed BAM output (for piping)

SAMDIR=$1
BAMDIR=$2
BASE=$3
SAMTOOLS=$4

SAM=$SAMDIR/$BASE".sam"
BAM=$BAMDIR/$BASE"_nsort"
BAMTMP=$BAM"_tmp"

CMD="samtools view -bSu $SAM | samtools sort -n -O bam -o $BAM.bam -T $BAMTMP"

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
