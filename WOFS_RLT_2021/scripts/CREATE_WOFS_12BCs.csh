#!/bin/csh

source ${PWD}/WOFenv_rlt_2021
source ${TOP_DIR}/realtime.cfg.${event}

setenv ENVDIR ${PWD}    # Environment dirtory

cd $RUNDIR

#while ( ! -e ${HRRRE_DIR}/${event}/1200/HRRRE_12BCs_p1_ready)
#      echo "Waiting for HRRRE 1200 UTC BCs part 1 to download"
#      sleep 60
#end

echo "Starting the WPS for BCs1 process"
rm -f ${logWPSBCs}
${SCRIPTDIR}/Run_WPS_12BCs1.csh >>&! ${logWPSBCs}

echo "Starting the BC1 generation process"
rm -f ${SEMA4}/bc1_mem*_done

set n = 1
while ( $n <= $HRRRE_BCS )
   echo "Creating Hourly Initial Conditions/Boundary Conditions (ICBC) for Mem$n"
   ${SCRIPTDIR}/Run_BCs1.csh ${n} >>&! ${logREALBCs}
    @ n++
end

while ( `ls -f ${SEMA4}/bc1_mem*done | wc -l` != ${HRRRE_BCS} )
   sleep 5
   echo "Waiting for BC generation to finish"
end

touch ${SEMA4}/HRRRE_12BCsP1_ready

#while ( ! -e ${HRRRE_DIR}/${event}/1200/HRRRE_12BCs_p2_ready)
#      echo "Waiting for HRRRE 1200 UTC BCs part 2 to download"
#      sleep 60
#end

echo "Starting the WPS for BCs2 process"
${SCRIPTDIR}/Run_WPS_12BCs2.csh >>&! ${logWPSBCs}

echo "Starting the BC2 generation process"
rm -f ${SEMA4}/bc2_mem*_done
set n = 1
while ( $n <= $HRRRE_BCS )
  echo "Creating Hourly Initial Conditions/Boundary Conditions (ICBC) for Mem$n"
  ${SCRIPTDIR}/Run_BCs2.csh ${n} >>&! ${logREALBCs}

  @ n++
end

while ( `ls -f ${SEMA4}/bc2_mem*done | wc -l` != ${HRRRE_BCS} )
      sleep 5
      echo "Waiting for BC generation to finish"
end

touch ${SEMA4}/HRRRE_12BCsP2_ready

exit (0)
