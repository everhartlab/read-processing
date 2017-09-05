#!usr/bin/env bash

if [ $# -lt 1 ]; then
	echo 
	echo "Usage: bash get-job.sh file.out"
	echo
	echo "	file.out : an output file where the first line contains a Job ID"
	echo "	           specified as '  Job: XXXXXXX'"
	exit
fi

head -n 1 $1 | sed -e 's/.*  Job: //'