#!/bin/bash

#eventdate=20220520
#src_dir=${1-/work2/home/jidong.gao/test_runs/hyb22/exp1/wofs_run}
eventdate=20210503
src_dir=${1-/work2/wof/realtime/2021}
des_dir=${2-/scratch/ywang/test_runs/hyb23/wofs_run}

for mem in $(seq 1 36); do

    memdes="$des_dir/$eventdate/mem$mem"
    memsrc="$src_dir/$eventdate/mem$mem"

    if [[ ! -d $memdes ]]; then
        mkdir -p $memdes
    fi

    cd $memdes

    if [[ ! -e $memsrc/wrfbdy_d01.$mem ]]; then
        echo "File not exist: $memsrc/wrfbdy_d01.$mem"
        #filebase=$(readlink $memsrc/wrfbdy_d01.$mem)
        #filebasenow=${filebase//\/scratch\/ywang\/test_runs\/hyb22\/exp1/\/scratch\/ywang\/test_runs\/hyb23}
        #echo $filebase
        #echo $filebasenow
        #ln -sf $filebasenow wrfbdy_d01.$mem
        break
    else
        cp $memsrc/wrfbdy_d01.$mem $memdes
    fi


    icdes="$des_dir/$eventdate/ic$mem"
    icsrc="$src_dir/$eventdate/ic$mem"
    if [[ ! -e $icsrc/wrfinput_d01_ic ]]; then
        echo "File not exist: $icsrc/wrfinput_d01_ic"
        break
    fi

    if [[ ! -d $icdes ]]; then
        mkdir -p $icdes
    fi
    cp $icsrc/wrfinput_d01_ic $icdes

done

exit 0
