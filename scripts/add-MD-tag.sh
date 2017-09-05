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
	echo "Run a file"
	echo
	echo
	echo "This script takes a file in and copies it to out"
	echo
	echo "Usage: add-MD-tag.sh <BAM> <SAMTOOLS> <REFERENCE>"
	echo
	echo "	<BAM>       - the directory for the samfiles"
	echo "	<SAMTOOLS>  - the samtools module (e.g. samtools/1.3)"
	echo "	<REFERENCE> - The indexed reference genome in fasta format"
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
#
# Fix mate information and add the MD tag.
# # http://samtools.github.io/hts-specs/
# # MD = String for mismatching positions
# # NM = Edit distance to the reference


BAM=$1
SAMTOOLS=$2
REFERENCE=$3

BAMTMP=$(sed 's/_nsort\.bam/_csort_tmp/' <<< $BAM)
BAMFIX=$(sed 's/nsort/fixed/' <<< $BAM)

CMD="samtools fixmate -O bam $BAM /dev/stdout | "
CMD=$CMD"samtools sort -O bam -o - -T $BAMTMP | "
CMD=$CMD"samtools calmd -b - $REFERENCE > $BAMFIX\n"


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