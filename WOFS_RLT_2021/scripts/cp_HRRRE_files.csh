#!/bin/csh

set echo
source ~/WOFenv_rlt_2021
source ${TOP_DIR}/realtime.cfg.${event}

cd ${HRRRE_DIR}/${event}/1200

#foreach hr ( 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 )
#  cp postprd_mem0001/wrfnat_mem0001_${hr}.grib2 postprd_mem0003/wrfnat_mem0003_${hr}.grib2
#  cp postprd_mem0008/wrfnat_mem0008_${hr}.grib2 postprd_mem0009/wrfnat_mem0009_${hr}.grib2
#end

foreach hr ( 15 16 17 18 19 20 21 22 23 24 25 )
  cp postprd_mem0001/wrfnat_mem0001_${hr}.grib2 postprd_mem0003/wrfnat_mem0003_${hr}.grib2
  #cp postprd_mem0008/wrfnat_mem0008_${hr}.grib2 postprd_mem0009/wrfnat_mem0009_${hr}.grib2
end

exit (0)

