#!/bin/bash

filename=$(basename `pwd`)
basedir=${filename%%_*}
mem=${filename##*_}
echo "job: $basedir, mem: $mem"

cp ../${basedir}_0/*.slurm .
sed -i "s/_%a/_$mem/g;s/\${SLURM_ARRAY_TASK_ID}/$mem/g" *.slurm

ls *.slurm

exit 0