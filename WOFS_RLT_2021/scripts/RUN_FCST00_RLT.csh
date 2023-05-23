#!/bin/csh
#
#-----------------------------------------------------------------------
# Script to Run WoFS Forecasts at :00 past the hour
#-----------------------------------------------------------------------

set scrptdir=$0:h
set scrptdir=`realpath ${scrptdir}`
set parentdir=${scrptdir:h}

if ($#argv >= 1 ) then
    set realconfig = `realpath $argv[1]`
else
    set realconfig = ${parentdir}/WOFenv_rlt_2021
endif

echo "Realtime configuration file: $realconfig"
source ${realconfig}

#source ${PWD}/WOFenv_rlt_2021
set ENVFILE = ${TOP_DIR}/realtime.cfg.${event}
source $ENVFILE
#set echo

#setenv ENVDIR ${realconfig:h}

setenv pcp 5

if ( $cycle_start == "00" ) then
   set times = (0200 0300 0400 0500 0600 0700 0800 0900 1000 1100 1200 1300 1400 1500)
endif

if ( $cycle_start == "12" ) then
   set times = (1400 1500 1600 1700 1800 1900 2000 2100 2200 2300 0000 0100 0200 0300 0400 0500)
endif

if ( $cycle_start == "15" ) then
    set times = (1700 1800 1900 2000 2100 2200 2300 0000 0100 0200 0300)
#   set times = (1700 1800 1900 2000 2100 2200 2300 0000 0100 0200 0300 0400 0500 0600)
#   set times = (0300 0400 0500 0600 0700 0800 0900 1000 1100 1200 1300 1400 1500)
endif

if ( $cycle_start == "18" ) then
   set times = (1900 2000 2100 2200 2300 0000 0100 0200 0300 0400 0500 0600)
endif

if ( $cycle_start == "21" ) then
   set times = (2300 0000 0100 0200 0300 0400 0500 0600)
endif

########## LOOP THROUGH FORECAST START TIMES
foreach btime ( ${times} )

    if ( $btime == "2000" ) then
   while ( ! -e ${SEMA4}/BCs_ready)
             sleep 60
       end
    endif

    set hhh  = `echo $btime | cut -c1`
    set mmm  = `echo $btime | cut -c3`

    setenv fcst_start ${runDay}${btime}

    if ( ${hhh} == 0) then
       setenv fcst_start ${nxtDay}${btime}
    endif

    #if ( ${hhh} == 1) then
    #   setenv fcst_start ${nxtDay}${btime}
    #endif

    ### WAIT TO SEE IF THIS ANALYSIS TIME IS COMPLETE
    while ( ! -e ${FCST_DIR}/analysis_${fcst_start}_done )
          echo "WAITING FOR ANALYSIS TO FINISH:" ${fcst_start}
          sleep 30
    end

    source $ENVFILE

    touch ${FCST_DIR}/fcst_${fcst_start}_start

    setenv FCSTHR_DIR ${FCST_DIR}/${btime}
    mkdir ${FCSTHR_DIR}
    cd ${FCSTHR_DIR}

    ####################################################################
    # SET UP TIME CONSTRUCTS/VARIABLES
    ####################################################################

    cp ${RUNDIR}/input.nml ./input.nml

    set fcst_cut = `echo $fcst_start | cut -c1-10`

    set START_YEAR  = `echo $fcst_start | cut -c1-4`
    set START_MONTH = `echo $fcst_start | cut -c5-6`
    set START_DAY   = `echo $fcst_start | cut -c7-8`
    set START_HOUR  = `echo $fcst_start | cut -c9-10`
    set START_MIN   = `echo $fcst_start | cut -c11-12`

    #if ( ${mmm} == 0 ) then
    #   if ( $btime == "0700" ) then
    setenv tfcst_min 360
    setenv hst 360
    #      setenv flen 54000
    set END_STRING = `echo ${fcst_start} 21600s -w | ${RUNDIR}/advance_time`
    #   else
    #      @ tfcst_min = ${tfcst_min} - 60
    #      @ hst = ${hst} - 60
    #      @ flen = ${flen} - 3600
    #      set END_STRING = `echo ${fcst_start} ${flen}s -w | ${RUNDIR}/advance_time`
    #   endif
    #else
    #   setenv tfcst_min 180
    #   setenv hst 180
    #   set END_STRING = `echo ${fcst_start} 10800s -w | ${RUNDIR}/advance_time`
    #endif

    set END_YEAR  = `echo $END_STRING | cut -c1-4`
    set END_MONTH = `echo $END_STRING | cut -c6-7`
    set END_DAY   = `echo $END_STRING | cut -c9-10`
    set END_HOUR  = `echo $END_STRING | cut -c12-13`
    set END_MIN   = `echo $END_STRING | cut -c15-16`

    #
    set member = 1
    while($member <= ${FCST_SIZE})
        if ( $member <= 9 ) then
           ${REMOVE} -fr ENS_MEM_0${member}
           mkdir ENS_MEM_0${member}
           cd ENS_MEM_0${member}/
        else
           ${REMOVE} -fr ENS_MEM_${member}
           mkdir ENS_MEM_${member}
           cd ENS_MEM_${member}/
        endif

        if ( -e namelist.input) ${REMOVE} namelist.input
        ${REMOVE} rsl.* fcstModel.sed

        cat >! fcstModel.sed << EOF
         /run_minutes/c\
         run_minutes                = ${tfcst_min},
         /start_year/c\
         start_year                 = 2*${START_YEAR},
         /start_month/c\
         start_month                = 2*${START_MONTH},
         /start_day/c\
         start_day                  = 2*${START_DAY},
         /start_hour/c\
         start_hour                 = 2*${START_HOUR},
         /start_minute/c\
         start_minute               = 2*${START_MIN},
         /start_second/c\
         start_second               = 2*00,
         /end_year/c\
         end_year                   = 2*${END_YEAR},
         /end_month/c\
         end_month                  = 2*${END_MONTH},
         /end_day/c\
         end_day                    = 2*${END_DAY},
         /end_hour/c\
         end_hour                   = 2*${END_HOUR},
         /end_minute/c\
         end_minute                 = 2*${END_MIN},
         /end_second/c\
         end_second                 = 2*00,
         /fine_input_stream/c\
         fine_input_stream          = 2*0,
         /history_interval/c\
         history_interval           = ${hst},
         /frames_per_outfile/c\
         frames_per_outfile         = 2*1,
         /reset_interval1/c\
         reset_interval1            = ${pcp},
         /time_step_fract_num/c\
         time_step_fract_num        = 0,
         /time_step_fract_den/c\
         time_step_fract_den        = 1,
         /max_dom/c\
         max_dom                    = ${domains},
         /e_we/c\
         e_we                       = ${grdpts_ew}, 1,
         /e_sn/c\
         e_sn                       = ${grdpts_ns}, 1,
         /ishallow/c\
         ishallow                   = 0,
         /i_parent_start/c\
         i_parent_start             = 1, 1,
         /j_parent_start/c\
         j_parent_start             = 1, 1,
         /parent_time_step_ratio/c\
         parent_time_step_ratio     = 1, 5,
         /time_step/c\
         time_step                  = ${fts},
         /numtiles/c\
         numtiles                   = ${tilesf},
         /nproc_x/c\
         nproc_x                    = ${procxf},
         /nproc_y/c\
         nproc_y                    = ${procyf},
         /radt/c\
         radt                       = ${radt1},
         /prec_acc_dt/c\
         prec_acc_dt                = ${pcp},
EOF
        sed -f fcstModel.sed ${TEMPLATE_DIR}/namelists.WOFS.fcst.RLT2021/namelist.input.member${member} >! namelist.input
        #sed -f fcstModel.sed ${TEMPLATE_DIR}/namelists.WOFS.fcst/namelist.input.member6 >! namelist.input

        ln -sf ${RUNDIR}/WRF_RUN/* .
        ${COPY} ${RUNDIR}/input.nml .

        @ member++
        cd ../

    end

    sleep 1

    #
    #  Run wrf.exe to generate forecast
    #
    echo "#\!/bin/csh"                                                          >! ${FCSTHR_DIR}/WoFS_FCST.job
    echo "#=================================================================="  >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH' "-J wofs_fcst$btime"                                         >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH' "-o ${FCSTHR_DIR}/wofs_fcst\%a.log"                          >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH' "-e ${FCSTHR_DIR}/wofs_fcst\%a.err"                          >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH' "-p batch"                                                   >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH' "--ntasks-per-node=24"                                       >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH' "-n ${WRF_FCORES}"                                           >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH -t 1:00:00'                                                   >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo "#=================================================================="  >> ${FCSTHR_DIR}/WoFS_FCST.job

    cat >> ${FCSTHR_DIR}/WoFS_FCST.job << EOF

   source ${realconfig}
   source ${TOP_DIR}/realtime.cfg.${event}
   set echo

   if ( \${SLURM_ARRAY_TASK_ID} <= 9 ) then
      cd ${FCSTHR_DIR}/ENS_MEM_0\${SLURM_ARRAY_TASK_ID}
      setenv MPICH_MPIIO_HINTS "${FCSTHR_DIR}/ENS_MEM_0\${SLURM_ARRAY_TASK_ID}/wrfout*:striping_factor=4,cb_nodes=4"
   else
      cd ${FCSTHR_DIR}/ENS_MEM_\${SLURM_ARRAY_TASK_ID}
      setenv MPICH_MPIIO_HINTS "${FCSTHR_DIR}/ENS_MEM_\${SLURM_ARRAY_TASK_ID}/wrfout*:striping_factor=4,cb_nodes=4"
   endif

   setenv OMP_NUM_THREADS 1

   ${COPY} ${RUNDIR}/mem\${SLURM_ARRAY_TASK_ID}/wrfbdy_d01.\${SLURM_ARRAY_TASK_ID} ./wrfbdy_d01
   ${COPY} ${RUNDIR}/${fcst_start}/wrfinput_d01.\${SLURM_ARRAY_TASK_ID} ./wrfinput_d01
   #${COPY} ${RUNDIR}/ic\${SLURM_ARRAY_TASK_ID}/wrfinput_d01_ic ./wrfinput_d01
   ${COPY} ${TEMPLATE_DIR}/forecast_vars_d01.txt ./

   sleep 2
   srun -n 1 ./update_wrf_bc > ./update_wrf_bc.output.\${SLURM_ARRAY_TASK_ID}
   sleep 2

   srun --mpi=pmi2 ${RUNDIR}/WRF_RUN/wrf.exe

EOF

    #SUBMIT ALL FORECAST MEMBERS AT ONCE
    sbatch --array=1-${FCST_SIZE} ${FCSTHR_DIR}/WoFS_FCST.job

    sleep 10

    set member = 1
    while ($member <= ${FCST_SIZE})
        if ( $member <= 9 ) then
           cd ${FCSTHR_DIR}/ENS_MEM_0${member}
        else
           cd ${FCSTHR_DIR}/ENS_MEM_${member}
        endif
        set keep_trying = true

        while ($keep_trying == 'true')

            set SUCCESS = `grep "wrf: SUCCESS COMPLETE WRF" rsl.out.0000 | cat | wc -l`
            if ($SUCCESS == 1) then

               set keep_trying = false
               break

            endif

            sleep 30
        end

        echo "Done with Forecast for Ensemble Member ${member}"

        @ member++
        cd ..
    end

    touch ${FCST_DIR}/fcst_${fcst_start}_done

end

##########################################################################################
echo '       ************* RUN IS COMPLETE **************       '
##########################################################################################
exit (0)
##########################################################################################
