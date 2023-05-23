#!/bin/bash
#
# Purpose: retrieve experimental HRRRX runs from Jet, which has P_TOP at 15 mb
# just as HRRRE
# /mnt/lfs1/BMC/nrtrr/HRRR/run
#

scpdir=$(dirname $0)       # To ensure to use the same dir as this script
#scpdir="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

destdir=/work/ywang/saved_data/HRRRX
srcdir=/mnt/lfs4/BMC/nrtrr/HRRR/run
#srcdir=/misc/whome/rtrr/hrrr

function usage {
    echo " "
    echo "    USAGE: $0 [options] DATETIME [DESTDIR]"
    echo " "
    echo "    PURPOSE: Retrieve HRRRx forecast from Jet."
    echo "       NOTE: must run on Odin."
    echo " "
    echo "    DATETIME - Case date and time in YYYYMMDDHH"
    echo "               empty for current time (now) round to earliest whole hour"
    echo "    DESTDIR   - Work Directory"
    echo " "
    echo "    OPTIONS:"
    echo "              -h              Display this message"
    echo "              -n              Show command to be run only"
    echo "              -v              Verbose mode"
    echo "              -r  3           How many hours to trace back"
    echo " "
    echo "   DEFAULTS:"
    echo "              scpdir  = $scpdir"
    echo "              destdir = $destdir"
    echo "              srcdir  = $srcdir"
    echo " "
    echo "                                     -- By Y. Wang (2020.03.27)"
    echo " "
    exit $1
}

#-----------------------------------------------------------------------
#
# Default values
#
#-----------------------------------------------------------------------

show=0
verb=""
thr=3

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
            verb="-v"
            ;;
        -r)
            thr=$2
            shift
            ;;
        -*)
            echo "Unknown option: $key"
            exit
            ;;
        *)
            if [[ $key =~ ^[0-9]{10}$ ]]; then
                eventdt="$key"
            elif [[ -d $key ]]; then
                destdir=$key
            else
                echo ""
                echo "ERROR: unknown option, get [$key]."
                usage -2
            fi
            ;;
    esac
    shift # past argument or value
done

if [[ ! $eventdt =~ ^[0-9]{10}$ ]]; then
  eventdt=$(date -u  -d "1 hour ago" +%Y%m%d%H)
  #echo "ERROR: unknow event date and hour: $eventdt"
  #usage -2
fi

filesizeCheck=629145600    # 610M
filesizeKeep=661202895     # 630M

echo "DATETIME: $eventdt"
echo "destdir = $destdir"
echo "srcdir  = $srcdir"
echo " "

#-----------------------------------------------------------------------
#
# retrieve data from Jet
#
#-----------------------------------------------------------------------

for fcsth in $(seq 0 1 $(($thr-1)) ); do
  cd $destdir

  hrdatetime=$(date -d "${eventdt:0:8} ${eventdt:8:2}:00 ${fcsth} hours ago" +%Y%m%d%H)

  if [[ ! -r $hrdatetime ]]; then
    mkdir -p $hrdatetime
  fi

  cd $hrdatetime

  hrhour=${hrdatetime:8:2}
  hrhour=${hrhour#0}      # remove leading 0

  if [[ $hrhour -le 5 ]]; then
    hrhour=$((hrhour+24))
  fi

  if [[ $hrhour -le 15 ]]; then
    flength=18
  else
    flength=$(( 18-($hrhour-15) ))
  fi

  echo "Downloading $hrdatetime ($flength) to  $destdir/$hrdatetime ..."

  for hr in $(seq 0 1 $flength); do
    fhr=$(printf "%02d" $hr)
    hrfile="wrfnat_hrconus_${fhr}.grib2"
    files="$srcdir/$hrdatetime/postprd/${hrfile}"

    echo "dtn:$files"
    if [[ $show -ne 1 ]]; then
      if [[ -f $hrfile ]]; then
        hrfilesize=$(stat -c %s $hrfile)
        if [[ $hrfilesize -gt $filesizeKeep ]]; then
          continue
        fi
      fi
      scp dtn:"$files" .
      hrfilesize=$(stat -c %s $hrfile)
      if [[ $hrfilesize -lt $filesizeCheck ]]; then
        rm -rf $hrfile
      fi
    fi
  done
done

exit 0
