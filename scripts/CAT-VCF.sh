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

if [ $# -lt 2 ]; then
	echo
	echo "Usage: CAT-VCF.sh <GVCF_DIR> <VCFTOOLS>"
	echo
	echo "	<GVCF_DIR> - directory to the VCF files"
	echo "	<VCFTOOLS> - vcftools module (e.g. vcftools/0.1"
	echo
	exit
fi

$GVCF_DIR=$1
$VCFTOOLS=$2

CMD="vcf-concat $(ls $GVCF_DIR/res.*.vcf.gz | sort -t'.' -n -k2) | gzip -c > $GVCF_DIR/res.vcf.gz"

module load $VCFTOOLS

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
