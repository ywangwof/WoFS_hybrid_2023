#!/bin/bash

scpdir="/oldscratch/ywang/NEWSVAR/news3dvar.2022/WoF_post"
realdir="/scratch/ywang/real_runs"
summarydir="/scratch/ywang/real_runs/summary_files_hyb"


run="hyb"
eventdt=$(date +%Y%m%d)
eventhr=$(date +%H)
if [[ ${eventhr#0} -lt 20 ]]; then
  eventdt=$(date -d "1 day ago" +%Y%m%d)
fi

function usage {
    echo " "
    echo "    USAGE: $0 [options] EVENTDATE [DESTDIR]"
    echo " "
    echo "    PURPOSE: Run post-plotting python jobs"
    echo " "
    echo "    EVENTDATE - Event date in YYYYMMDD"
    echo "    DESTDIR   - Work Directory, default: $realdir"
    echo " "
    echo "    OPTIONS:"
    echo "              -h              Display this message"
    echo "              -n              Show command to be run only"
    echo "              -v              Verbose mode"
    echo "              -c              Clean flags"
    echo "              -r   hyb/var    Run type"
    echo "              -j   jobname    Job script to run, default: newsvar, or clean or check"
    echo "                              Or one in (time swat rain swah bmap) or all"
    echo "              -t   1700-0300  Time range for newsvar plot"
    echo " "
    echo "   DEFAULTS:"
    echo "              scpdir    = $scpdir"
    echo "              destdir   = $realdir"
    echo "              summarydir= $summarydir"
    echo "              run       = $run"
    echo "              EVENTDATE = $eventdt"
    echo " "
    echo "                                     -- By Y. Wang (2020.04.22)"
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
clean=0
sjob="newsvar"
stime="1700"
etime="0300"

fcstintvl=3600
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
        -c)
            clean=1
            ;;
        -r)
            run=$2
            shift
            ;;
        -j)
            sjob=$2
            shift
            ;;
        -t)
            times=$2
            if [[ $times =~ ^[0-9]{4}-[0-9]{4}$ ]]; then
              ranges=(${times//-/ })
              stime=${ranges[0]}
              etime=${ranges[1]}
            elif [[ $times =~ ^[0-9]{4}$ ]]; then
              stime=$times
              etime=$times
            else
              echo "ERROR: unacceptable arg for option '-t', got $times."
              usage 1
            fi
            shift
            ;;
        -*)
            echo "Unknown option: $key"
            exit
            ;;
        *)
            if [[ $key =~ ^[0-9]{8}$ ]]; then
                eventdt="$key"
            elif [[ -d $key ]]; then
                realdir=$key
            else
                echo ""
                echo "ERROR: unknown option, get [$key]."
                usage -2
            fi
            ;;
    esac
    shift # past argument or value
done

if [[ "$run" =~ "var" ]]; then
  #fcstroot="/scratch/sijie.pan/NEWSVAR_CONVTEST/runs"
  #summarydir=/scratch/brian.matilla/WoFS_2020/summary_files/VAR_RLT
  fcstroot="/scratch/ywang/real_runs"
  summarydir="$fcstroot/summary_files_var"
else
  #summarydir=/scratch/brian.matilla/WoFS_2020/summary_files/HYBRID_RLT
  #summarydir=/scratch/brian.matilla/WOFS_2021/summary_files/HYBRID_RLT/
  fcstroot="/scratch/ywang/real_runs"
  summarydir=$fcstroot/summary_files_hyb
fi

if [[ "$sjob" == "check" ]]; then
  sjob="clean"
  show=1
fi

scriptdir="$scpdir"
imagedir=$realdir/images_${run}
flagdir=$imagedir/flags

echo "run     = $run"
echo "EVENTDT = $eventdt"
echo "scpdir  = $scpdir"
echo "destdir = $realdir/$eventdt"
echo "rundir  = $fcstroot/$eventdt"
echo "summary = $summarydir/$eventdt"
echo " "
#-----------------------------------------------------------------------
#
# Clean WRF run-time file to save disk space
#
#-----------------------------------------------------------------------
if [[ $sjob == "clean" ]]; then
  step_interval=10
  fcsthour=6

  #imgnames["hyb"]="hybrid"
  #imgnames["var"]="var"
  #imagedir="/www/wof.nssl.noaa.gov/wof_${imgnames[${run,,}]}_images"
  #imgvars=(comp_dz   uh_0to2  uh_2to5 ws_80  rain  hailcast  \
  #         wz_0to2                           w_up
  #         )

  if [[ $show -eq 0 ]]; then
    echo -n "Really want to clean all WRF runs in $fcstroot/$eventdt from ${stime}Z-${etime}Z [y,n]? "
    read cleanwrf
    echo " "
  fi

  if [[ ${cleanwrf,,} != "y" ]]; then
     show=1
  fi

  if [[ "$stime" -lt "1000" ]]; then
    startday="1 day"
  fi
  if [[ "$etime" -lt "1000" ]]; then
    endday="1 day"
  fi
  secstart=$(date -d "${eventdt} $stime $startday" +%s)
  secend=$(date -d "${eventdt} $etime $endday" +%s)
  times_str=""
  for sec in $(seq $secstart $fcstintvl $secend); do
    dirtime=$(date -d @$sec +%H%M)

    if [[ "${dirtime:2:2}" == "30" ]]; then
       nt=$(( (fcsthour/2)*60/step_interval+1 ))
    else
       nt=$(( fcsthour*60/step_interval+1 ))
    fi

    donesummary=0
    nensfiles=$(ls ${summarydir}/${eventdt}/${dirtime}Z/wofs_ENS_* 2> /dev/null | wc -l )
    nenvfiles=$(ls ${summarydir}/${eventdt}/${dirtime}Z/wofs_ENV_* 2> /dev/null | wc -l )
    nswtfiles=$(ls ${summarydir}/${eventdt}/${dirtime}Z/wofs_SWT_* 2> /dev/null | wc -l )
    n30Mfiles=$(ls ${summarydir}/${eventdt}/${dirtime}Z/wofs_30M_* 2> /dev/null | wc -l )
    n60Mfiles=$(ls ${summarydir}/${eventdt}/${dirtime}Z/wofs_60M_* 2> /dev/null | wc -l )
    nrunfiles=$(ls ${fcstroot}/${eventdt}/${dirtime}Z/dom20/wrf5/wrf${run}_d01_* 2> /dev/null | wc -l )
    echo "${dirtime}Z: ENS - $nensfiles/$nt; ENV - $nenvfiles/$nt; SWT - $nswtfiles/$nt; 60M - $n60Mfiles/6; RUN - $nrunfiles/$nt"

    #
    # Check real-time images
    #
    #varstr=""
    #ivar=0
    #for var in ${imgvars[@]}; do
    #  nvar=$(ls ${imagedir}/${eventdt}/${dirtime}/${var}_f*.png 2> /dev/null | wc -l)
    #  varstr+="${var} - $nvar;\t"
    #  let ivar+=1
    #  if [[ $ivar -eq 4 ]]; then
    #    echo -e "images: $varstr"
    #    varstr=""
    #    ivar=0
    #  fi
    #done

    if [[ $nensfiles -eq $nt && $nenvfiles -eq $nt ]]; then
      donesummary=1
    else
      if [[ $verb -eq 1 ]]; then echo "${dirtime}Z: Summary files incomplete. Skipped. "; fi
    fi

    if [[ $donesummary -eq 1 ]]; then
      wrkdir="$fcstroot/$eventdt/${dirtime}Z/dom20/wrf5"
      cd $wrkdir
      cmd="rm -rf rsl.* wrf${run,,}_d01_* wrfout_d01_* wrfoutReady_d01_*"
      #echo "${dirtime}Z: $cmd"
      if [[ $show -eq 0 ]]; then
        if [[ $verb -eq 1 ]]; then echo "${dirtime}Z: Executing - $cmd"; fi
        $cmd
      else
        if [[ $verb -eq 1 ]]; then echo "${dirtime}Z: Clean command - $cmd"; fi
      fi
    fi
  done
  exit 0

fi

#-----------------------------------------------------------------------
#
# Jobs to be run
#
#-----------------------------------------------------------------------
declare -A jobfiles
jobfiles["time"]=wofsvar_plot_timestep.job
jobfiles["swat"]=wofsvar_plot_swath.job
jobfiles["rain"]=wofsvar_plot_swath_rain.job
jobfiles["swah"]=wofsvar_plot_swath_hourly.job
jobfiles["bmap"]=wofsvar_basemap.job
jobfiles["newsvar"]=run_newsvar_plot.csh

if [[ ${sjob} == "all" ]]; then
  jobnames=(time swat rain swah)
else
  jobnames=(${sjob,,})
fi

#-----------------------------------------------------------------------
#
# Run old newsvar script for visulization on desktop
#
#-----------------------------------------------------------------------

currscript=$(realpath $0)
scriptdir="$(dirname $(dirname $currscript))"

if [[ ! -e ${imagedir} ]]; then
  mkdir -p ${imagedir}
fi

wrkdir=${imagedir}
cd ${wrkdir}

if [[ "newsvar" == "${jobnames[0]}" ]]; then

  scriptdir="$scriptdir/python_newsvar"
  script="run_newsvar_plot.job"

  echo "${scriptdir}/run_plot.job, $stime-$etime"
  if [[ "$stime" -lt "1000" ]]; then
    startday="1 day"
  fi
  if [[ "$etime" -lt "2000" ]]; then
    endday="1 day"
  fi

  secstart=$(date -d "${eventdt} $stime $startday" +%s)
  secend=$(date -d "${eventdt} $etime $endday" +%s)
  times_str=""
  for sec in $(seq $secstart $fcstintvl $secend); do
    times1=$(date -d @$sec +%H%M)
    times_str="$times_str $times1"
    #echo ${times_str}
  done

  eventdir="${imagedir}/${eventdt}"
  if [[ ! -f $eventdir ]]; then
    mkdir -p $eventdir
  fi

  srptfile=${eventdt:2:6}_rpts.csv
  if [[ ! -f $eventdir/${srptfile} ]]; then
    cd $eventdir
    wget http://www.spc.noaa.gov/climo/reports/${srptfile}
    cd ${wrkdir}
  fi

  cp ${scriptdir}/run_plot.job ${script}
  sed -i "/event/s/YYYYmmdd/${eventdt}/"                      ${script}
  sed -i "s/fcstimes=.*/fcstimes=(${times_str})/"             ${script}
  sed -i "s#SCRPDIR#${scriptdir}#;s#WRKDIR#${wrkdir}#"        ${script}
  sed -i "s#summary=.*#summary=\"${summarydir}/${eventdt}\"#" ${script}
  sed -i "s#image=.*#image=\"$eventdir\"#"                    ${script}
  sed -i "s#SBATCH -J .*#SBATCH -J plt_${run}_${eventdt:4:4}#"       ${script}
  sed -i "s#SBATCH -o .*#SBATCH -o ${imagedir}/plt_${eventdt:4:4}_%j.out#" ${script}
  sed -i "s#SBATCH -e .*#SBATCH -e ${imagedir}/plt_${eventdt:4:4}_%j.err#" ${script}
  sed -i "s#runtype=.*#runtype=\"WoF-$run\"#" ${script}

  echo "sbatch ${wrkdir}/${script}"
  if [[ $show -eq 0 ]];then
    sbatch ${script}
  fi

else
#-----------------------------------------------------------------------
#
# Prepare configuration file
#
#-----------------------------------------------------------------------

  for dir in ${summarydir} ${imagedir} ${flagdir}; do
    if [[ ! -e ${dir} ]]; then
      mkdir -p ${dir}
    fi
  done

  confile="${wrkdir}/plot_config_${eventdt}.yaml"

  cp ${scpdir}/conf/summary_file_config_hyb.yaml ${confile}
  sed -i "/eventdate/s/[0-9]\+/$eventdt/" $confile
  sed -i "/file_start :/s/: .*/: 'wrf${run}_d01'/" $confile
  for dir in scriptdir fcstroot summarydir imagedir flagdir; do       # working dirs
    sed -i "/${dir}:/s#: .*#: ${!dir}#" $confile
  done

  if [[ $verb -eq 1 ]]; then
    echo "wrkdir      = $wrkdir"
    echo "Config file = $confile "
    echo "scriptdir   = ${scriptdir}"
    echo "fcstroot    = ${fcstroot}"
    echo "summarydir  = ${summarydir}"
    echo "imagedir    = ${imagedir}"
    echo "flagdir     = ${flagdir}"
    echo " "
  fi

  #---------------------------------------------------------------------
  #
  # Clean flags
  #
  #---------------------------------------------------------------------

  if [[ $clean -eq 1 ]]; then
    flagdir=${flagdir}
    for job in ${jobnames[@]}; do
      rm -rf $flagdir/$eventdt/*_plt_${job}.txt
    done
  fi

  #---------------------------------------------------------------------
  #
  # submit jobs
  #
  #---------------------------------------------------------------------

  for job in ${jobnames[@]}; do
    fn=${jobfiles[$job]}
    sname=plt_${job}_${run}_${eventdt:4:4}

    echo "${wrkdir}/$fn ....."
    cp ${scpdir}/jobs/$fn .
    sed -i "/#SBATCH/s#/scratch/ywang/real_runs/flags#${flagdir}#" $fn    # Job output dir
    sed -i "/#SBATCH/s/0420/${eventdt:4:4}/" $fn                          # Job output file
    sed -i "/SBATCH -J/s/.*/#SBATCH -J ${sname}/;/SBATCH -t/s/.*/#SBATCH -t 10:00:00/" $fn # job name
    sed -i "/confl=/s#\".*\"#$confile#" $fn                               # config file
    #sed -i "/^cd /s#../scripts/post#$scpdir/scripts/post#" $fn            # script dir
    #sed -i "/wrf_path=/s#/\"#/dom20/wrf5/\"#" $fn
    if [[ $show -ne 1 ]]; then
      sbatch $fn
    fi
  done

fi

exit 0

