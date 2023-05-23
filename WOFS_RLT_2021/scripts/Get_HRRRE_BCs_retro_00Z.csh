#!/bin/csh

setenv HRRRE_DIR /scratch/wof/MODEL_DATA/HRRRE
#setenv event `date +%Y%m%d`
setenv event 20210821

mkdir -p ${HRRRE_DIR}/${event} ; mkdir -p ${HRRRE_DIR}/${event}/0000

cd ${HRRRE_DIR}/${event}/0000

#scp Kent.Knopfmeier@dtn-jet.rdhpcs.noaa.gov:/mnt/lfs4/BMC/wrfruc/HRRRE/forecast/${event}00/HRRRE_ready ./HRRRE_ready

#while ( ! -e HRRRE_ready )

#      sleep 60

#      scp Kent.Knopfmeier@dtn-jet.rdhpcs.noaa.gov:/mnt/lfs4/BMC/wrfruc/HRRRE/forecast/${event}00/HRRRE_ready ./HRRRE_ready

#end

foreach mem ( 1 2 3 4 5 6 7 8 9 )

mkdir ${HRRRE_DIR}/${event}/0000/postprd_mem000${mem}

echo "#\!/bin/csh"                                                           >! ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh
#echo "#=================================================================="   >> ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh
#echo '#SBATCH' "-J HRRRE_mem${mem}"                                          >> ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh
#echo '#SBATCH' "-o ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.log"           >> ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh
#echo '#SBATCH' "-e ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.err"           >> ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh
#echo '#SBATCH' "-A largequeue"                                               >> ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh
#echo '#SBATCH' "-p workq"                                                    >> ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh
#echo '#SBATCH' "--ntasks-per-node=1"                                         >> ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh
#echo '#SBATCH' "-n 1"                                                        >> ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh
#echo '#SBATCH -t 2:00:00'                                                    >> ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh
#echo "#=================================================================="   >> ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh

cat >> ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh << EOF

cd ${HRRRE_DIR}/${event}/0000/postprd_mem000${mem}

#rsync -arq --include="wrfnat_mem000${mem}_0[0-9].grib2" --exclude="*" Kent.Knopfmeier@dtn-jet.rdhpcs.noaa.gov:/mnt/lfs4/NAGAPE/hpc-wof1/WOF/HRRRE/${event}/0000/postprd_mem000${mem}/ ${HRRRE_DIR}/${event}/0000/postprd_mem000${mem}

#rsync -arq --include="wrfnat_mem000${mem}_1[0-3].grib2" --exclude="*" Kent.Knopfmeier@dtn-jet.rdhpcs.noaa.gov:/mnt/lfs4/NAGAPE/hpc-wof1/WOF/HRRRE/${event}/0000/postprd_mem000${mem}/ ${HRRRE_DIR}/${event}/0000/postprd_mem000${mem}

#rsync -arq --include="wrfnat_mem000${mem}_2[0-9].grib2" --exclude="*" Kent.Knopfmeier@dtn-jet.rdhpcs.noaa.gov:/mnt/lfs4/NAGAPE/hpc-wof1/WOF/HRRRE/${event}/0000/postprd_mem000${mem}/ ${HRRRE_DIR}/${event}/0000/postprd_mem000${mem}

#rsync -arq --include="wrfnat_mem000${mem}_3[0-6].grib2" --exclude="*" Kent.Knopfmeier@dtn-jet.rdhpcs.noaa.gov:/mnt/lfs4/NAGAPE/hpc-wof1/WOF/HRRRE/${event}/0000/postprd_mem000${mem}/ ${HRRRE_DIR}/${event}/0000/postprd_mem000${mem}

rsync -arq --include="wrfnat_mem000${mem}_0[0-9].grib2" --exclude="*" Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/mnt/lfs4/BMC/wrfruc/HRRRE/forecast/${event}00/postprd_mem000${mem}/ ${HRRRE_DIR}/${event}/0000/postprd_mem000${mem}

rsync -arq --include="wrfnat_mem000${mem}_1[0-9].grib2" --exclude="*" Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/BMC/wrfruc/HRRRE/forecast/${event}00/postprd_mem000${mem}/ ${HRRRE_DIR}/${event}/0000/postprd_mem000${mem}

rsync -arq --include="wrfnat_mem000${mem}_2[0-5].grib2" --exclude="*" Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/BMC/wrfruc/HRRRE/forecast/${event}00/postprd_mem000${mem}/ ${HRRRE_DIR}/${event}/0000/postprd_mem000${mem}

#rsync -arq --include="wrfnat_mem000${mem}_3[0-6].grib2" --exclude="*" Kent.Knopfmeier@dtn-jet.boulder.rdhpcs.noaa.gov:/lfs4/BMC/wrfruc/HRRRE/forecast/${event}00/postprd_mem000${mem}/ ${HRRRE_DIR}/${event}/0000/postprd_mem000${mem}

sleep 1

exit (0)

EOF

chmod +x ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh
${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.csh >&! ${HRRRE_DIR}/${event}/0000/HRRRE_mem${mem}.log &

sleep 1

end

#while ( `ls -f ${HRRRE_DIR}/${event}/0000/postprd_mem*/wrfnat* | wc -l` != 234 )

#      sleep 10
#      echo "Waiting for the HRRRE members to transfer"

#end

#touch ${HRRRE_DIR}/${event}/0000/HRRRE_BCs_ready

exit (0)

