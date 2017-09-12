#!/usr/bin/env bash
# This ridiculous script will take in a file as input and spit out comma-separated text for easier parsing.
# Usage: 
# $ gvcf2csv.sh GVCF.err | column -t -s,
if [ $# -lt 1 ]; then
	echo
	echo "Usage: bash gvcf2csv.sh GVCF.err | column -t -s"
	echo
	exit
fi

grep ProgressMeter $1 | \
awk -F" - " '{print $2}' | \
tail -n +2 | \
sed -E 's/[ ]\|[ ]/,/g' | \
sed -E "s/([0-9hmsw%])[ ]{3,}([0-9])/\1,\2/g"
