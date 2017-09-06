#!/usr/bin/env bash
#
# Set job time
#SBATCH --time=24:00:00
#
#
# Set memory requested and max memory
#SBATCH --mem=100g
#
# Request some processors
#SBATCH --cpus-per-task=6
#SBATCH --ntasks=1

if [ $# -lt 6 ]; then
	echo
	echo "Usage: make-VCF.sh <PREFIX> <GATKVAR> <REFERENCE> <GATK> <INTERVAL> SAMPLES..."
	echo
	echo "	<PREFIX>       - bamfile with duplicates marked"
	echo "	<GATKVAR>   - environmental variable or path pointing to GATK"
	echo "	<REFERENCE> - ABSOLUTE PATH to reference fasta file"
	echo "	<GATK>      - GATK module (e.g. gatk/3.4)"
	echo "	<INTERVAL>  - a string representing the interval on which to find genotypes"
	echo "  SAMPLES...  - a list of samples appended by -V "
	echo
	exit
fi


$PREFIX=$1
$GATKVAR=$2
$REFERENCE=$3
$GATK=$4
$INTERVAL=$5
# Slice the array from the 6th position to the end
# http://stackoverflow.com/a/9057392
SAMPLES="${@:6}"


CMD="java -Xmx100g -Djava.io.tmpdir=$TMPDIR "
CMD=$CMD"-jar $GATKVAR "
CMD=$CMD"-nt 6 "
CMD=$CMD"-T GenotypeGVCFs "
CMD=$CMD"-R $REFERENCE "
CMD=$CMD"${SAMPLES[@]} "
CMD=$CMD"-o $PREFIX.$SLURM_JOB_ID.vcf.gz --intervals $INTERVAL"

module load $GATK
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
