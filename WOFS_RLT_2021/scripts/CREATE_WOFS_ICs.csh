#!/bin/csh

source ${PWD}/WOFenv_rlt_2021
source ${TOP_DIR}/realtime.cfg.${event}

setenv ENVDIR ${PWD}    # Environment dirtory

cd $RUNDIR

@ anlys_hr = ${cycle_start} - 1

while ( ! -e ${RUNDIR}/geo_em.d01.nc )
      echo "Waiting for the geo_em.d01.nc file to be generated"
      sleep 30
end

while ( ! -e ${HRRRE_DIR}/${event}/${anlys_hr}00/HRRRE_ICs_ready)

      echo "Waiting for HRRRE ICs to download"
      sleep 20

end

echo "Starting the WPS for ICs process"
rm -rf ${logWPSICs}
${SCRIPTDIR}/Run_WPS_ICs.csh >>&! ${logWPSICs}

echo "Starting the IC generation process"
rm -f ${SEMA4}/ic_mem*_done
set n = 1
while ( $n <= $ENS_SIZE )
  echo "Creating Initial Conditions (ICs) for Mem$n"
  rm -rf ${logREALICs}
  ${SCRIPTDIR}/Run_ICs.csh ${n} >>&! ${logREALICs}

  @ n++
end

while ( `ls -f ${SEMA4}/ic_mem* | wc -l` != $ENS_SIZE )
      sleep 5
      echo "Waiting for IC generation to finish"
end

#Clean up files from IC Generation
${REMOVEDIR} ic*/cycle*

#Indicate ICs are generatated
touch ${SEMA4}/ICs_done

exit (0)

