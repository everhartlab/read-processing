#!/usr/bin/env bash

if [ $# -lt 2 ]; then
	echo
	echo "Submit a SLURM script"
	echo
	echo "Usage:"
	echo "	bash dummy.sh OUTDIR script.sh ARGS..."
	echo
	echo "OUTDIR	The output directory"
	echo "script.sh	The script to run"
	echo "ARGS...	arguments to go along with the script"
	echo
	exit
fi 

OUT=$1
SCRIPT=$2
ERR=$(basename ${SCRIPT} | cut -f 1 -d '.')
ARGS=${@:3}

mkdir -p "${OUT}"

sbatch -D $(pwd) \
	-J ${OUT} \
	-o ${OUT}/${ERR}.out \
	-e ${OUT}/${ERR}.err \
	${SCRIPT} ${ARGS[@]}
