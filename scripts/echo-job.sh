#!/usr/bin/env bash
#
# Set job time
#SBATCH --time=00:01:00
#SBATCH --output=/dev/null
#SBATCH --error=/dev/null
#SBATCH --job-name=JOBJOB
#SBATCH --mem=20M

printf "$SLURM_JOB_ID\n" > .fakejob
