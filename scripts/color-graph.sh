#!/usr/bin/env bash

if [ $# -lt 1 ]; then
	echo
	echo "Change the default colors of make2graph for this Makefile"
	echo
	echo "Usage: make -Bnd | make2graph | color-graph.sh <SAMPLENAME>"
	echo
	echo "	<SAMPLENAME> - A common name of all your samples (assumed to be at the beginning)"
	echo
	exit
fi

SAMPLE=$1

# GrandBudapest2
pink="#E6A0C4"
purple="#C6CDF7"
brown="#D8A499"
blue="#7294D4"

unamestr=$(uname)

if [[ "$unamestr" == 'Linux' ]]; then
	EX="-r"
else
	EX="-E"
fi

cat /dev/stdin | \
sed $EX "s/^(.+label=\"all\", )color=\"[a-z]+(\".+)$/\1style=\"filled\", color=\"gray40\", fillcolor=\"white\2/" | \
sed $EX "s/^(.+label=\"[^.]+\", )color=\"[a-z]+(\".+)$/\1style=\"filled\", color=\"gray40\", fillcolor=\"gray90\2/" | \
sed $EX "s/^(.+label=\"$SAMPLE.+\", )color=\"red(\".+)$/\1style=\"filled\", color=\"gray40\", fillcolor=\"$pink\2/" | \
sed $EX "s/^(.+label=\".+\.[shpy]{2}\", )color=\"green(\".+)$/\1style=\"filled\", color=\"gray40\", fillcolor=\"$brown\2/" | \
sed $EX "s/^(.+label=\".+\.gz\", )color=\"green(\".+)$/\1style=\"filled\", fontcolor=\"white\", color=\"gray40\", fillcolor=\"$blue\2/" | \
sed $EX "s/^(.+label=\"res.vcf.gz+\", )color=\"[a-z]+(\".+)$/\1style=\"filled\", fontcolor=\"white\", color=\"gray40\", fillcolor=\"gray10\2/" | \
sed $EX "s/^(.+label=\".+\", )color=\"[a-z]+(\".+)$/\1style=\"filled\", color=\"gray40\", fillcolor=\"$purple\2/" | \
sed $EX "s/ ;/ [style=\"bold\", color=\"grey40\"];/"