#!/usr/bin/env bash


module load python/3.5


if [ $# -lt 3 ]; then
	echo 
	echo "Create a list of genomic intervals for use with GATK"
	echo
	echo
	echo "Usage:"
	echo
	echo "	bash make-GATK-intervals.sh <fasta> <window> <outfile>" 
	echo
	echo "	<fasta> - a fasta file of the reference"
	echo "	<window> - an integer specifying the window size"
	echo "	<outfile> - the name of a text file to write the windows"
	echo
	exit
fi

./scripts/make-GATK-intervals.py -f $1 -w $2 > $3
