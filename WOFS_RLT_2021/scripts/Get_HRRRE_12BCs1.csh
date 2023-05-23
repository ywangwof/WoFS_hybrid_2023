#!/bin/csh

setenv HRRRE_DIR /scratch/wof/MODEL_DATA/HRRRE
#setenv event `date +%Y%m%d`
setenv event 20210527

mkdir -p ${HRRRE_DIR}/${event} ; mkdir -p ${HRRRE_DIR}/${event}/1200

cd ${HRRRE_DIR}/${event}/1200

#scp Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/BMC/wrfruc/HRRRE/forecast_retro/${event}12/HRRRE_ready_part1 ./HRRRE_ready_part1

#while ( ! -e HRRRE_ready_part1 )

#      sleep 60

#      scp Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/BMC/wrfruc/HRRRE/forecast_retro/${event}12/HRRRE_ready_part1 ./HRRRE_ready_part1

#end

foreach mem ( 1 2 3 4 5 6 7 8 9 )

mkdir ${HRRRE_DIR}/${event}/1200/postprd_mem000${mem}

echo "#\!/bin/csh" >! ${HRRRE_DIR}/${event}/1200/HRRRE_mem${mem}.csh

cat >> ${HRRRE_DIR}/${event}/1200/HRRRE_mem${mem}.csh << EOF

cd ${HRRRE_DIR}/${event}/1200/postprd_mem000${mem}

rsync -arq --include="wrfnat_mem000${mem}_0[0-9].grib2" --exclude="*" Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/BMC/wrfruc/HRRRE/forecast_retro/${event}12/postprd_mem000${mem}/ ${HRRRE_DIR}/${event}/1200/postprd_mem000${mem}

rsync -arq --include="wrfnat_mem000${mem}_1[0-9].grib2" --exclude="*" Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/BMC/wrfruc/HRRRE/forecast_retro/${event}12/postprd_mem000${mem}/ ${HRRRE_DIR}/${event}/1200/postprd_mem000${mem}

rsync -arq --include="wrfnat_mem000${mem}_2[0-5].grib2" --exclude="*" Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/BMC/wrfruc/HRRRE/forecast_retro/${event}12/postprd_mem000${mem}/ ${HRRRE_DIR}/${event}/1200/postprd_mem000${mem}

#rsync -arq --include="wrfnat_mem000${mem}_3[0-6].grib2" --exclude="*" Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/BMC/wrfruc/HRRRE/forecast_retro/${event}12/postprd_mem000${mem}/ ${HRRRE_DIR}/${event}/1200/postprd_mem000${mem}

sleep 1

exit (0)

EOF

chmod +x ${HRRRE_DIR}/${event}/1200/HRRRE_mem${mem}.csh
${HRRRE_DIR}/${event}/1200/HRRRE_mem${mem}.csh >&! ${HRRRE_DIR}/${event}/1200/HRRRE_mem${mem}.log &

sleep 1

end

while ( `ls -f ${HRRRE_DIR}/${event}/1200/postprd_mem*/wrfnat* | wc -l` != 234 )

      sleep 10
      echo "Waiting for the HRRRE members to transfer"

end

touch ${HRRRE_DIR}/${event}/1200/HRRRE_12BCs_p1_ready
touch ${HRRRE_DIR}/${event}/1200/HRRRE_12BCs_p2_ready

exit (0)

