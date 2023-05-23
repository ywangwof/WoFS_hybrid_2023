#!/bin/sh

indir="/work/LDM/GOES16/GLM"
outdir="/scratch/ywang/real_runs/GOES16/GLM"
ncopath="/scratch/software/Odin/python/anaconda2/bin"
#ncopath="/bin"

datetime=$(date -u +%Y%m%d%H%M)

function usage {
    echo " "
    echo "    USAGE: $0 [options] EVENTDATE[,EVENTDATE] [DESTDIR]"
    echo " "
    echo "    PURPOSE: Accumulate GLM lightning FOD data within 10-minute interval"
    echo " "
    echo "    EVENTDATE - Event date in YYYYMMDDHHMM, default: current time round to 15 minute"
    echo "    DESTDIR   - Work Directory, default: $outdir"
    echo " "
    echo "    OPTIONS:"
    echo "              -h              Display this message"
    echo "              -n              Show command to be run only"
    echo "              -v              Verbose mode"
    echo " "
    echo "   DEFAULTS:"
    echo "              LDM_dir   = $indir"
    echo "              outdir    = $outdir"
    echo "              EVENTDATE = $datetime"
    echo " "
    echo "                                     -- By Y. Wang (2020.09.16)"
    echo " "
    exit $1
}

#-----------------------------------------------------------------------
#
# Default values
#
#-----------------------------------------------------------------------

show=0
verb=0
ranges=( $datetime )

#-----------------------------------------------------------------------
#
# Handle command line arguments
#
#-----------------------------------------------------------------------

while [[ $# > 0 ]]
    do
    key="$1"

    case $key in
        -h)
            usage 0
            ;;
        -n)
            show=1
            ;;
        -v)
            verb=1
            ;;
        -*)
            echo "Unknown option: $key"
            exit
            ;;
        *)
            if [[ $key =~ ^[0-9]{12}$ ]]; then
                ranges=("$key")
            elif [[ $key =~ ^[0-9]{12},[0-9]{12}$ ]]; then
               ranges=(${key//,/ })
               if [[ ${ranges[1]} -lt ${ranges[0]} ]]; then
                   echo ""
                   echo "    ERROR: a < b is required, got \$a=${ranges[0]}, \$b=${ranges[1]}."
                   usage -2
               fi
            elif [[ -d $key ]]; then
                outdir=$key
            else
                echo ""
                echo "ERROR: unknown option, get [$key]."
                usage -2
            fi
            ;;
    esac
    shift # past argument or value
done


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#
# Do the work
#
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

range1=${ranges[0]}
if [[ ${#ranges[@]} -gt 1 ]]; then
  range2=${ranges[1]}
else
  range2=$range1
fi


dts1=$(date -d "${range1:0:8} ${range1:8:4}" +%s)
dts2=$(date -d "${range2:0:8} ${range2:8:4}" +%s)

for ((i=$dts1; i<=$dts2; i+=900))
do
  #j=$((i+300))    # add 5-minute, within -5 to 10 minutes of @i, the current round to the nearest 15 minute slot
  j=i
  eventsec=$((j - j%900))     # find nearest 15-minte slot
  eventdt=$(date -d @$eventsec +%Y%j%H%M)

  datetime=$(date -d @$eventsec +%Y%m%dT%H:%M)

  ymdh=${eventdt:0:9}
  yjd=${eventdt:0:7}
  hr=${eventdt:7:2}
  min=${eventdt:9:2}

  echo "$datetime - YJDH: $ymdh, YJD: $yjd, Time: $hr:$min "

  if [[ ${min} -eq "15" ]];then
     files=($(ls $indir/OR_GLM-L2-LCFA_G16_s${yjd}${hr}0[5-9]* $indir/OR_GLM-L2-LCFA_G16_s${yjd}${hr}1[0-4]*))
  elif [[ ${min} -eq "30" ]];then
     files=($(ls $indir/OR_GLM-L2-LCFA_G16_s${yjd}${hr}2*))
  elif [[ ${min} -eq "45" ]];then
     files=($(ls $indir/OR_GLM-L2-LCFA_G16_s${yjd}${hr}3[5-9]* $indir/OR_GLM-L2-LCFA_G16_s${yjd}${hr}4[0-4]*))
  elif [[ ${min} -eq "00" ]];then
     j=$((i-3600))
     prehr=$(date -d @$j +%Y%j%H%M)
     pyjd=${prehr:0:7}
     phr=${prehr:7:2}
     files=($(ls $indir/OR_GLM-L2-LCFA_G16_s${pyjd}${phr}5*))
  else
     echo "YMDH: $ymdh, YJD: $yjd, Hour: $hr, Minute: $min "
     usage 0
  fi

  if [[ ${#files[@]} -gt 0 ]]; then
     echo "Found ${#files[@]} files for ${ymdh}${min}_glm.nc"
     if [[ $verb -eq 1 ]]; then
       printf '%s\n' "${files[@]}"
     fi
     cmdstr="${ncopath}/ncrcat -O -v flash_lat,flash_lon ${files[@]} ${outdir}/${ymdh}${min}_glm.nc"
  else
     echo "find no GLM file for ${ymdh}${min}_glm.nc"
     usage 0
  fi
  echo " "
  if [[ $verb -eq 1 ]]; then
    echo "$cmdstr"
  fi
  if [[ $show -ne 1 ]]; then
    $cmdstr
    #if [[ $? -eq 0 ]]; then
    #  echo "Sending ${outdir}/${ymdh}${min}_glm.nc to Odin ..."
    #  rsync ${outdir}/${ymdh}${min}_glm.nc odin1.protect.nssl:/scratch/ywang/real_runs/GOES16/GLM
    #fi
  fi
done

exit 0
