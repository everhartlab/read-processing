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
# The picard documentation says that it will grab as many cores as is available.
#SBATCH --cpus-per-task=4
#SBATCH --ntasks=1

if [ $# -lt 3 ]; then
	echo
	echo "Usage: add-MD-tag.sh <BAM> <SAMTOOLS> <PICARD> <REFERENCE>"
	echo
	echo "	<BAM>       - the directory for the samfiles"
	echo "	<SAMTOOLS>  - the samtools module (e.g. samtools/1.3)"
	echo "	<PICARD>    - the picard module (e.g. samtools/2.9)"
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
PICARD=$3
REFERENCE=$4

BAMTMP=$(sed 's/_merged\.bam/_csort_tmp/' <<< $BAM)
BAMFIX=$(sed 's/merged/fixed/' <<< $BAM)

SORT="picard SortSam I=${BAM} O=${BAMTMP} SORT_ORDER=coordinate"
CMD="picard FixMateInformation I=${BAMTMP} O=/dev/stdout \ 
| samtools calmd -b - ${REFERENCE} \
> ${BAMFIX}"


module load ${SAMTOOLS}
module load ${PICARD}

# Run the command through time with memory and such reporting.
# warning: there is an old bug in GNU time that overreports memory usage
# by 4x; this is compensated for in the SGE_Plotdir script.
TIME='/usr/bin/env time -f " \\tFull Command:                      %C \\n\\tMemory (kb):                       %M \\n\\t# SWAP  (freq):                    %W \\n\\t# Waits (freq):                    %w \\n\\tCPU (percent):                     %P \\n\\tTime (seconds):                    %e \\n\\tTime (hh:mm:ss.ms):                %E \\n\\tSystem CPU Time (seconds):         %S \\n\\tUser   CPU Time (seconds):         %U " '

# Write details to stdout
echo "  Job: $SLURM_JOB_ID"
echo
echo "  Started on:           " `/bin/hostname -s`
echo "  Started at:           " `/bin/date`
echo ${SORT}

eval ${TIME}${SORT} # sorting the reads.
echo "  Validation:"
picard ValidateSamFile I=${BAMTMP}

echo
echo "  Fix mates at:         " `/bin/date`
echo ${CMD}

eval ${TIME}${CMD}  # fixing the mate information and adding the tag.
TEST=$(picard ValidateSamFile I=${BAMFIX})
echo ${TEST} 

# Use validation check to remove temporary file.
[ $(grep -c ERROR <<< ${TEST}) == 0 ] \
&& rm ${BAMTMP} \
&& echo "I detected no errors, so I have removed ${BAMTMP}" \
|| echo "I detected an error in ${BAMFIX}, which may indicate an error in ${BAMTMP}"

echo "  Finished at:           " `/bin/date`
echo
# End of file
