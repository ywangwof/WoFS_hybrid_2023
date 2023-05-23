#!/bin/bash

#set -x

eventdate=${1-20220520}
year=${eventdate:0:4}
mon=${eventdate:4:2}
day=${eventdate:6:2}

nextday=$(date -d "$eventdate 1 day" +%Y%m%d)
year2=${nextday:0:4}
mon2=${nextday:4:2}
day2=${nextday:6:2}

radars=(KATX  KBYX  KDAX  KDYX  KFCX  KGLD  KHPX  KJAX  KLSX  KMLB  KNKX  KPOE  KSJT  KUEX  PACG  PHWA  TBWI  TEWR  TLVE  TORD  TTPA \
        DOP1  KBBX  KCAE  KDDC  KEAX  KFDR  KGRB  KHTX  KJGX  KLTX  KMOB  KNQA  KPUX  KSOX  KVAX  PAEC  RKJK  TCLT  TFLL  TMCI  TPBI  TTUL \
        FOP1  KBGM  KCBW  KDFX  KEMX  KFDX  KGRK  KICT  KJKL  KLVX  KMPX  KOAX  KRAX  KSRX  KVBX  PAHG  RKSG  TCMH  THOU  TMCO  TPHL \
        KABR  KBHX  KCBX  KDGX  KENX  KFFC  KGRR  KICX  KLBB  KLWX  KMQT  KOHX  KRGX  KTBW  KVNX  PAIH  RODN  TCVG  TIAD  TMDW  TPHX \
        KABX  KBIS  KCCX  KDIX  KEOX  KFSD  KGSP  KILN  KLCH  KLZK  KMRX  KOKX  KRIW  KTFX  KVTX  PAKC  TDAL  TIAH  TMEM  TPIT \
        KAKQ  KBLX  KCLE  KDLH  KEPZ  KFSX  KGWX  KILX  KLGX  KMAF  KMSX  KOTX  KRLX  KTLH  KVWX  PAPD  TDAY  TICH  TMIA  TRDU \
        KAMA  KBMX  KCLX  KDMX  KESX  KFTG  KGYX  KIND  KLIX  KMAX  KMTX  KRTX  KTLX  KYUX  PGUA  TADW  TDCA  TIDS  TMKE  TSDF \
        KAMX  KBOX  KCRP  KDOX  KEVX  KFWS  KHDX  KINX  KLNX  KMBX  KMUX  KPAH  KSFX  KTWX  PHKI  TATL  TDEN  TJFK  TMSP       \
        KAPX  KBRO  KCXX  KDTX  KEWX  KGGW  KHGX  KIWA  KLOT  KMHX  KMVX  KPBZ  KSGF  KTYX  PHKM  TBNA  TDFW  TJUA  TMSY  TSLC \
        KARX  KBUF  KCYS  KDVN  KEYX  KGJX  KHNX  KIWX  KLRX  KMKX  KMXX  KPDT  KSHV  KUDX  PABC  PHMO  TBOS  TDTW  TLAS  TOKC  TSTL)
#DAN1 ROP3 ROP4 KOUN NOP3 NOP4 TSJU
#radars=( KLSX KFSD KBIS KMPX KDLH KTWX KUDX KGLD KOAX KARX KDVN KDMX KLNX KUEX KEAX KMVX KABR )

#mkdir /scratch/ywang/NEXRAD/${year}${mon}${day}; cd /scratch/ywang/NEXRAD/${year}${mon}${day}

dest_dir="/scratch/ywang/test_runs/NEXRAD2"
for hr in  15 16 17 18 19 20 21 22 23; do

  for radar in ${radars[@]}; do

    if [[ ! -d $dest_dir/$radar ]]; then
        mkdir -p $dest_dir/$radar
    fi

    cd $dest_dir/$radar
    echo "$year/$mon/$day/$radar/${radar}${year}${mon}${day}_${hr}{0,1,2,3,4,5}{0,1,2,3,4,5,6,7,8,9}{0,1,2,3,4,5}{0,1,2,3,4,5,6,7,8,9}_V06"

    wget -c https://noaa-nexrad-level2.s3.amazonaws.com/$year/$mon/$day/$radar/${radar}${year}${mon}${day}_${hr}{0,1,2,3,4,5}{0,1,2,3,4,5,6,7,8,9}{0,1,2,3,4,5}{0,1,2,3,4,5,6,7,8,9}_V06 &>> $dest_dir/$radar/${radar}1.log   &

  done

  sleep 900

done

for hr in  $(seq 0 9) ; do

  hr2=$(printf "%02d" $hr)

  for radar in ${radars[@]}; do

    cd $dest_dir/$radar
    echo "$year2/$mon2/$day2/$radar/${radar}${year2}${mon2}${day2}_${hr2}{0,1,2,3,4,5}{0,1,2,3,4,5,6,7,8,9}{0,1,2,3,4,5}{0,1,2,3,4,5,6,7,8,9}_V06 "

    wget -c https://noaa-nexrad-level2.s3.amazonaws.com/$year2/$mon2/$day2/$radar/${radar}${year2}${mon2}${day2}_${hr2}{0,1,2,3,4,5}{0,1,2,3,4,5,6,7,8,9}{0,1,2,3,4,5}{0,1,2,3,4,5,6,7,8,9}_V06  &>> $dest_dir/$radar/${radar}2.log  &

  done

  sleep 900

done

exit 0

