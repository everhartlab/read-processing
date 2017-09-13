#!/usr/bin/env bash

SAMPLE=$1

# GrandBudapest2
#  Pink       Purple     Brown      Blue
# "#E6A0C4", "#C6CDF7", "#D8A499", "#7294D4"
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