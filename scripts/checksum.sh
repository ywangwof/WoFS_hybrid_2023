#!/bin/bash

evntdate="20210428"  #$(date +%Y%m%d)

sumdir="/scratch/ywang/test_runs/hyb3.0km/summary_files"
flagdir="/scratch/ywang/test_runs/hyb3.0km/post_logs/flags"

function usage {
    echo " "
    echo "    USAGE: $0 [options] EVENTDATE [DESTDIR]"
    echo " "
    echo "    PURPOSE: count generated summary files"
    echo " "
    echo "    EVENTDATE - Event date in YYYYMMDD"
    echo "    DESTDIR   - Work Directory, default: $sumdir"
    echo " "
    echo "    OPTIONS:"
    echo "              -h              Display this message"
    echo "              -n              Show command to be run only"
    echo "              -v              Verbose mode"
    echo "              -c              Clean summary file flags if not done completely "
    echo "              -t   1700-0300  Time ranges to be checked"
    echo "              -f   flag_dir   Flags file directory "
    echo " "
    echo "   DEFAULTS:"
    echo "              destdir   = $sumdir"
    echo "              flagdir   = $flagdir"
    echo "              EVENTDATE = $evntdate"
    echo " "
    echo "                                     -- By Y. Wang (2021.06.23)"
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
stime="1700"
etime="0300"

fcstintvl=3600  # in seconds
outintvl=10     # in minutes
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
        -f)
            flagdir=$2
            if [[ ! -d $flagdir ]]; then
                echo ""
                echo "ERROR: $flagdir does not exists."
                usage -2
            fi
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
                evntdate="$key"
            elif [[ -d $key ]]; then
                sumdir=$key
            else
                echo ""
                echo "ERROR: unknown option, get [$key]."
                usage -2
            fi
            ;;
    esac
    shift # past argument or value
done

if [[ ! -r $sumdir ]]; then
    echo "$sumdir does not exist."
    exit 0
fi

#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#
# Do checking
#
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


#starttimes=('1700' '1800' '1900' '2000'  '2100'  '2200'  '2300'  '0000'  '0100'  '0200'  '0300')
if [[ "$stime" -lt "1000" ]]; then
  startday="1 day"
fi
if [[ "$etime" -lt "1000" ]]; then
  endday="1 day"
fi

secstart=$(date -d "${evntdate} $stime $startday" +%s)
secend=$(date -d "${evntdate} $etime $endday" +%s)

dsumdir="$sumdir/$evntdate"
dflagdir="$flagdir/$evntdate"

envcnt_e=$((6*60/outintvl+1))
m30cnt_e=$((envcnt_e-3))
m60cnt_e=6

echo "EVENT: $evntdate, $dsumdir"

for ts in $(seq $secstart $fcstintvl $secend); do

    tm=$(date -d @$ts +%H%M)

    envcnt=$(ls $dsumdir/${tm}Z/wofs_ENV* 2> /dev/null | wc -l )
    enscnt=$(ls $dsumdir/${tm}Z/wofs_ENS* 2> /dev/null | wc -l )
    swtcnt=$(ls $dsumdir/${tm}Z/wofs_SWT* 2> /dev/null | wc -l )
    m30cnt=$(ls $dsumdir/${tm}Z/wofs_30M* 2> /dev/null | wc -l )
    m60cnt=$(ls $dsumdir/${tm}Z/wofs_60M* 2> /dev/null | wc -l )

    echo "$tm: ENV: $envcnt; ENS: $enscnt; SWT: $swtcnt; 30M: $m30cnt; 60M: $m60cnt"

    if [[ $clean -ne 1 ]]; then
        continue
    fi

    if [[ $envcnt -lt $envcnt_e ]]; then
        rm -rf $dflagdir/${tm}Z_env_hyb.txt
    fi

    if [[ $enscnt -lt $envcnt_e ]]; then
        rm -rf $dflagdir/${tm}Z_ens_hyb.txt
    fi

    if [[ $swtcnt -lt $envcnt_e ]]; then
        rm -rf $dflagdir/${tm}Z_swt_hyb.txt
    fi

    if [[ $m30cnt -lt $m30cnt_e ]]; then
        rm -rf $dflagdir/${tm}Z_30M_hyb.txt
    fi

    if [[ $m60cnt -lt $m60cnt_e ]]; then
        rm -rf $dflagdir/${tm}Z_60M_hyb.txt
    fi

done

exit 0
