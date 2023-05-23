#!/bin/csh

setenv HRRRE_DIR /scratch/wof/MODEL_DATA/HRRRE
setenv event `date  +%Y%m%d`
#setenv event 20211230

mkdir ${HRRRE_DIR}/${event}

#foreach hr ( 14 17 20 )
foreach hr ( 14 )

mkdir ${HRRRE_DIR}/${event}/${hr}00

cd ${HRRRE_DIR}/${event}/${hr}00

scp Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/NAGAPE/hpc-wof1/WOF/HRRRE/${event}/${hr}00/HRRRE_ready ./

while ( ! -e HRRRE_ready )

      sleep 60

      scp Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/NAGAPE/hpc-wof1/WOF/HRRRE/${event}/${hr}00/HRRRE_ready ./

end

foreach mem ( 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 )

echo "#\!/bin/csh" >! ${HRRRE_DIR}/${event}/${hr}00/HRRRE_mem${mem}.csh

cat >> ${HRRRE_DIR}/${event}/${hr}00/HRRRE_mem${mem}.csh << EOF

if ( ${mem} <= 9 ) then

mkdir ${HRRRE_DIR}/${event}/${hr}00/postprd_mem000${mem}

cd ${HRRRE_DIR}/${event}/${hr}00/postprd_mem000${mem}

rsync -aq Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/NAGAPE/hpc-wof1/WOF/HRRRE/${event}/${hr}00/postprd_mem000${mem}/wrfnat_hrrre_newse_mem000${mem}_01.grib2 ${HRRRE_DIR}/${event}/${hr}00/postprd_mem000${mem}

else

mkdir ${HRRRE_DIR}/${event}/${hr}00/postprd_mem00${mem}

cd ${HRRRE_DIR}/${event}/${hr}00/postprd_mem00${mem}

rsync -aq Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/NAGAPE/hpc-wof1/WOF/HRRRE/${event}/${hr}00/postprd_mem00${mem}/wrfnat_hrrre_newse_mem00${mem}_01.grib2 ${HRRRE_DIR}/${event}/${hr}00/postprd_mem00${mem}

endif

sleep 1

exit (0)

EOF

chmod +x ${HRRRE_DIR}/${event}/${hr}00/HRRRE_mem${mem}.csh
${HRRRE_DIR}/${event}/${hr}00/HRRRE_mem${mem}.csh >&! ${HRRRE_DIR}/${event}/${hr}00/HRRRE_mem${mem}.log &

sleep 1

if ( ${mem} % 9 == 0 ) then

sleep 25

endif

end

while ( `ls -f ${HRRRE_DIR}/${event}/${hr}00/postprd_mem*/wrfnat* | wc -l` != 36 )

      sleep 5
      echo "Waiting for the HRRRE members to transfer"

end

touch ${HRRRE_DIR}/${event}/${hr}00/HRRRE_ICs_ready

rsync -arq Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/NAGAPE/hpc-wof1/WOF/HRRRE/${event}/${hr}00/postprd_mem0000 .

while ( ! -e ${HRRRE_DIR}/${event}/${hr}00/postprd_mem0000/wrfnat_hrrre_newse_mem0000_01.grib2 )

      sleep 60 

      rsync -arq Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/NAGAPE/hpc-wof1/WOF/HRRRE/${event}/${hr}00/postprd_mem0000 .

end

end

exit (0)

