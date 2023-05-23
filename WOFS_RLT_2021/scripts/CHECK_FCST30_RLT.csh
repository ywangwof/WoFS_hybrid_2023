#!/bin/csh 
#
#-----------------------------------------------------------------------
# Script to Check if Forecast is Done
#-----------------------------------------------------------------------

source ~/WOFenv_rlt_2019
source ${TOP_DIR}/cfg_files/realtime.cfg.${event}
set echo

foreach btime (1930 2030 2130 2230 2330 0030 0130 0230)

  set hhh  = `echo $btime | cut -c1`

  setenv fcst_start ${runDay}${btime}
  if ( ${hhh} == 0) then
   setenv fcst_start ${nxtDay}${btime}
  endif

  while ( ! -d ${FCST_DIR}/${btime} )

     sleep 60

  end

  cd ${FCST_DIR}/${btime}

  set member = 1
  while ( ${member} <= ${FCST_SIZE} )
     
     cd ENS_MEM_${member}
     set keep_trying = true

     while ($keep_trying == 'true')

        set SUCCESS = `grep "wrf: SUCCESS COMPLETE WRF" rsl.out.0000 | cat | wc -l`
        if ($SUCCESS == 1) then

          set keep_trying = false
          break

        endif

        sleep 60
     end
##
    echo Done with WRF Forecast for Ensemble Member ${member}

    set rmlist = ( `ls -f | grep -v 'wrfout_d01*' | grep -v 'wrfinput_d01' | grep -v 'wrfbdy_d01' | grep -v 'wrfwof_d01*'` )
    rm -f $rmlist

    @ member++
    cd ..
  end

  #touch ${FCST_DIR}/fcst_${fcst_start}_done

end

exit (0)

