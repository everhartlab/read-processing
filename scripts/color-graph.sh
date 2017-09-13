#!/usr/bin/env bash

SAMPLE=$1

# GrandBudapest2
#  Pink       Purple     Brown      Blue
# "#E6A0C4", "#C6CDF7", "#D8A499", "#7294D4"
unamestr=$(uname)
if [[ "$unamestr" == 'Linux' ]]; then
	EX="-r"
else
	EX="-E"
fi

cat /dev/stdin | \
sed $EX "s/^(.+label=\"$SAMPLE.+\", )color=\"red(\".+)$/\1style=\"filled\", color=\"gray40\", fillcolor=\"#E6A0C4\2/" | \
sed $EX "s/^(.+label=\".+\.[shpy]{2}\", )color=\"green(\".+)$/\1style=\"filled\", color=\"gray40\", fillcolor=\"#D8A499\2/" | \
sed $EX "s/^(.+label=\".+\.gz\", )color=\"green(\".+)$/\1style=\"filled\", fontcolor=\"white\", color=\"gray40\", fillcolor=\"#7294D4\2/" | \
sed $EX "s/^(.+label=\".+\", )color=\"[a-z]+(\".+)$/\1style=\"filled\", color=\"gray40\", fillcolor=\"#C6CDF7\2/" | \
sed $EX "s/ ;/ [style=\"bold\", color=\"grey40\"];/"