#!/bin/bash

rm -rf slurm_out;mkdir -p slurm_out
rm -rf data;mkdir -p data

sbatch --output="slurm_out/slurm-%A_%a.out" \
       --error="slurm_out/slurm-%A_%a.err" \
       --array 1-3000 getData.sh
