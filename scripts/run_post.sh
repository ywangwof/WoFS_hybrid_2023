#!/bin/bash

scpdir="/oldscratch/ywang/NEWSVAR/news3dvar.2022/scripts"
realdir="/scratch/ywang/real_runs"

run="hyb"
eventdt=$(date +%Y%m%d)

function usage {
    echo " "
    echo "    USAGE: $0 [options] EVENTDATE [DESTDIR]"
    echo " "
    echo "    PURPOSE: Run post-processing python jobs"
    echo " "
    echo "    EVENTDATE - Event date in YYYYMMDD"
    echo "    DESTDIR   - Work Directory, default: $realdir"
    echo " "
    echo "    OPTIONS:"
    echo "              -h              Display this message"
    echo "              -n              Show command to be run only"
    echo "              -v              Verbose mode"
    echo "              -c              Clean early flags"
    echo "              -r   hyb/var    Run type"
    echo "              -j   jobname    Job script to run, in (ENV ENS SWT 30M 60M)"
    echo " "
    echo "   DEFAULTS:"
    echo "              scpdir    = $scpdir"
    echo "              destdir   = $realdir"
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
sjob=""

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

#if [[ "$run" =~ "var" ]]; then
#  #fcstroot="/scratch/sijie.pan/NEWSVAR_CONVTEST/runs/"
#  fcstroot="/scratch/ywang/test_runs/"
#else
#  fcstroot="/scratch/ywang/real_runs/"
#fi
fcstroot="/scratch/ywang/real_runs"

scriptdir="/oldscratch/ywang/NEWSVAR/news3dvar.2022/WoF_post/"
summarydir="$realdir/summary_files_${run}/"
imagedir="$realdir/images_${run}/"
flagdir="$realdir/summary_files_${run}/flags/"
logdir="${summarydir}"

echo "scpdir  = $scpdir"
echo "destdir = $realdir"
echo "EVENTDT = $eventdt"
echo "run     = $run"
echo "fcstroot= $fcstroot"
echo " "

#-----------------------------------------------------------------------
#
# Jobs to be run
#
#-----------------------------------------------------------------------
declare -A jobfiles
jobfiles["ENV"]=wofs_hybrid_environment_summary_files.job
jobfiles["ENS"]=wofs_hybrid_storm_summary_files.job
jobfiles["SWT"]=wofs_hybrid_swath_summary_files.job
jobfiles["30M"]=wofs_hybrid_30M_discrete_swaths.job
jobfiles["60M"]=wofs_hybrid_60M_discrete_swaths.job

if [[ ${sjob} == "" ]]; then
  jobnames=(ENV ENS SWT 30M 60M)
else
  jobnames=(${sjob^^})
fi

wrkdir=${realdir}/summary_files_${run}
if [[ ! -r ${wrkdir} ]]; then
  mkdir -p ${wrkdir}
fi
cd ${wrkdir}

#-----------------------------------------------------------------------
#
# Prepare configuration file
#
#-----------------------------------------------------------------------

for dir in ${summarydir} ${imagedir} ${flagdir} ${logdir}; do
  if [[ ! -e ${dir} ]]; then
    mkdir -p ${dir}
  fi
done

confile="${wrkdir}/post_config_${eventdt}.yaml"

cp ${scpdir}/wofs_hybrid_config.yaml ${confile}
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

#-----------------------------------------------------------------------
#
# Clean flags
#
#-----------------------------------------------------------------------

if [[ $clean -eq 1 ]]; then
  flagdir=${flagdir}
  for job in ${jobnames[@]}; do
    rm -rf $flagdir/$eventdt/*_${job}.txt
  done
fi

#-----------------------------------------------------------------------
#
# submit jobs
#
#-----------------------------------------------------------------------

for job in ${jobnames[@]}; do
  fn=${jobfiles[$job]}
  sname=${job}_${run}_${eventdt:4:4}

  echo "${wrkdir}/$fn ....."
  cp ${scpdir}/$fn .
  sed -i "/#SBATCH/s#LOGDIR#${logdir}#" $fn    # Job output dir
  sed -i "s/JOBNAME/${sname}/"           $fn    # job name
  sed -i "/SBATCH -t/s/.*/#SBATCH -t 10:00:00/" $fn # job time
  sed -i "/confl=/s#\".*\"#$confile#" $fn           # config file
  if [[ $show -ne 1 ]]; then
    sbatch $fn
  fi
done

