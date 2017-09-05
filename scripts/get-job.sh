#!usr/bin/env bash

if [ $# -lt 1 ]; then
	echo 
	echo "Usage: bash get-job.sh FILES..."
	echo
	echo "	FILES : output files where the first line contains a Job ID"
	echo "	        specified as '  Job: XXXXXXX'"
	echo
	echo "The output will be a string of job numbers separated by colons:"
	echo
	echo "	24642:23890:31190"
	exit
fi

OUT=()
counter=0

for i in $@
do
	OUT[counter++]=$(head -n 1 $i | sed -e 's/.*  Job: //' | tr '\n' ':')
done

tr -d " " <<< $(rev <<< ${OUT[@]} | cut -c 2- | rev)
