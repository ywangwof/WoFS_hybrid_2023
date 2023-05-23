#!/bin/bash

raddirs=(DAN1  KATX  KBYX  KDAX  KDYX  KFCX  KGLD  KHPX  KJAX  KLSX  KMLB  KNKX  KPOE  KSJT  KUEX  PACG  PHWA  TBWI  TEWR  TLVE  TORD  TTPA \
DOP1  KBBX  KCAE  KDDC  KEAX  KFDR  KGRB  KHTX  KJGX  KLTX  KMOB  KNQA  KPUX  KSOX  KVAX  PAEC  RKJK  TCLT  TFLL  TMCI  TPBI  TTUL \
FOP1  KBGM  KCBW  KDFX  KEMX  KFDX  KGRK  KICT  KJKL  KLVX  KMPX  KOAX  KRAX  KSRX  KVBX  PAHG  RKSG  TCMH  THOU  TMCO  TPHL \
KABR  KBHX  KCBX  KDGX  KENX  KFFC  KGRR  KICX  KLBB  KLWX  KMQT  KOHX  KRGX  KTBW  KVNX  PAIH  RODN  TCVG  TIAD  TMDW  TPHX \
KABX  KBIS  KCCX  KDIX  KEOX  KFSD  KGSP  KILN  KLCH  KLZK  KMRX  KOKX  KRIW  KTFX  KVTX  PAKC  ROP3  TDAL  TIAH  TMEM  TPIT \
KAKQ  KBLX  KCLE  KDLH  KEPZ  KFSX  KGWX  KILX  KLGX  KMAF  KMSX  KOTX  KRLX  KTLH  KVWX  PAPD  ROP4  TDAY  TICH  TMIA  TRDU \
KAMA  KBMX  KCLX  KDMX  KESX  KFTG  KGYX  KIND  KLIX  KMAX  KMTX  KOUN  KRTX  KTLX  KYUX  PGUA  TADW  TDCA  TIDS  TMKE  TSDF \
KAMX  KBOX  KCRP  KDOX  KEVX  KFWS  KHDX  KINX  KLNX  KMBX  KMUX  KPAH  KSFX  KTWX  NOP3  PHKI  TATL  TDEN  TJFK  TMSP  TSJU \
KAPX  KBRO  KCXX  KDTX  KEWX  KGGW  KHGX  KIWA  KLOT  KMHX  KMVX  KPBZ  KSGF  KTYX  NOP4  PHKM  TBNA  TDFW  TJUA  TMSY  TSLC \
KARX  KBUF  KCYS  KDVN  KEYX  KGJX  KHNX  KIWX  KLRX  KMKX  KMXX  KPDT  KSHV  KUDX  PABC  PHMO  TBOS  TDTW  TLAS  TOKC  TSTL)

s1="Jul 15, 2021 14:50:00"
s2="Jul 16, 2021 03:10:00"

#echo "s1=$s1; s2=$s2"
#files=$(find /work/LDM/NEXRAD2/KTLX -type f -newerct "$s1" ! -newerct "$s2" | sort)
#for fn in  ${files[@]}; do
#    ls -ltur $fn
#done
#exit 0

for rad in ${raddirs[@]}; do
    #rsync --progress --files-from=<(find /work/LDM/NEXRAD2/$rad  -mmin -30 -type f -exec basename {} \;) /work/LDM/NEXRAD2/$rad/ odin1.protect.nssl:/scratch/ywang/real_runs/NEXRAD2/$rad
    rsync --progress --files-from=<(find /work/LDM/NEXRAD2/$rad -type f -newerct "$s1" ! -newerct "$s2" -exec basename {} \;) /work/LDM/NEXRAD2/$rad/ /scratch/ywang/real_runs/NEXRAD2/$rad
done

