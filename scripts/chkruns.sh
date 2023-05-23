#!/bin/bash

rootdir="/scratch/ywang/real_runs"
evtdate="${1-20220422}"
runtimes=(1700 1800 1900 2000 2100 2200 2300 0000 0100 0200 0300)
run="hyb"

subcom="${2-run}"

fcst_dir="$rootdir/$evtdate"
summy_dir="$rootdir/summary_files_${run}/$evtdate"
image_dir="$rootdir/images_${run}/$evtdate"

fcstfhead="wrf${run}_d01"
summyheads=("wofs_ENV" "wofs_ENS" "wofs_SWT" "wofs_30M" "wofs_60M" )
summynames=("ENV"      "ENS"      "SWT"      "30M"      "60M" )
imageheads=("time_comp_dz" "track_hailcast" "track_uh_2to5" "track_ws_80")
imagenames=("comp_dz"      "hailcast"       "uh_2to5"       "ws_80")

for ctime in ${runtimes[@]}; do
    echo -n "$ctime : "

    # check model forecast
    filehead=${fcstfhead}
    timedir="${ctime}Z/dom20/wrf5"
    rundir="$fcst_dir/$timedir"
    #echo "$rundir"
    if [[ ! -e $rundir ]]; then
         #echo -n "; $cmem2 not exist"
        count=0
    else
        count=$(ls ${rundir}/${filehead}* 2>/dev/null | wc -l)
        #echo -n "; $cmem2 found $count"
    fi
    echo -n " FCST # $count"
    echo -n "   | "

    # Check summary files
    for idx in ${!summyheads[@]}; do
        filehead=${summyheads[$idx]}
        timedir="${ctime}Z"
        rundir="$summy_dir/$timedir"

        #echo "$rundir"
        if [[ ! -e $rundir ]]; then
            #echo -n "; $cmem2 not exist"
            count=0
        else
            count=$(ls ${rundir}/${filehead}* 2>/dev/null | wc -l)
            #echo -n "; $cmem2 found $count"
        fi
        echo -n "  ${summynames[$idx]} # $count;"
    done

    #echo " "
    #echo -n "$(printf '%*s' ${#ctime}) "
    echo -n "   | "

    # check images
    for idx in ${!imageheads[@]}; do
        filehead=${imageheads[$idx]};
        timedir="${ctime}Z"
        rundir="$image_dir/$timedir"

        #echo "$rundir"
        if [[ ! -e $rundir ]]; then
            #echo -n "; $cmem2 not exist"
            count=0
        else
            count=$(ls ${rundir}/${filehead}* 2>/dev/null | wc -l)
            #echo -n "; $cmem2 found $count"
        fi
        echo -n "  ${imagenames[$idx]} # $count;"
    done
    echo ""
    #echo ""
done

exit 0
