#!/bin/csh
#
#-----------------------------------------------------------------------
# Script to Run WoFS Forecasts at :00 past the hour
#-----------------------------------------------------------------------

source ${PWD}/WOFenv_rlt_2021
set ENVFILE = ${TOP_DIR}/realtime.cfg.${event}
source $ENVFILE
set echo

setenv ENVDIR ${PWD}

setenv pcp 15           # output interval

set times = (1500)
set FCST_SIZE = 1
set member = 6

########## LOOP THROUGH FORECAST START TIMES
foreach btime ( ${times} )

    if ( $btime == "2000" ) then
       while ( ! -e ${SEMA4}/HRRRE_12BCsP2_ready)
             sleep 60
       end
    endif

    set hhh  = `echo $btime | cut -c1`
    set mmm  = `echo $btime | cut -c3`

    setenv fcst_start ${runDay}${btime}

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

    setenv tfcst_min 900
    setenv hst 900          # no output in between

    set END_STRING = `echo ${fcst_start} 21600s -w | ${RUNDIR}/advance_time`

    set END_YEAR  = `echo $END_STRING | cut -c1-4`
    set END_MONTH = `echo $END_STRING | cut -c6-7`
    set END_DAY   = `echo $END_STRING | cut -c9-10`
    set END_HOUR  = `echo $END_STRING | cut -c12-13`
    set END_MIN   = `echo $END_STRING | cut -c15-16`

    #
    #while($member <= ${FCST_SIZE})
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
        sed -f fcstModel.sed ${TEMPLATE_DIR}/namelists.WOFS.fcst/namelist.input.member${member} >! namelist.input

        ln -sf ${RUNDIR}/WRF_RUN/* .
        ${COPY} ${RUNDIR}/input.nml .

        cd ../

    #end

    sleep 1

    #
    #  Run wrf.exe to generate forecast
    #
    echo "#\!/bin/csh"                                                          >! ${FCSTHR_DIR}/WoFS_FCST.job
    echo "#=================================================================="  >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH' "-J wofs_fcst$btime"                                         >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH' "-o ${FCSTHR_DIR}/wofs_fcst\%a.log"                          >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH' "-e ${FCSTHR_DIR}/wofs_fcst\%a.err"                          >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH' "-p workq"                                                   >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH' "-A largequeue"                                              >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH' "--ntasks-per-node=24"                                       >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH' "-n ${WRF_FCORES}"                                           >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo '#SBATCH -t 3:00:00'                                                   >> ${FCSTHR_DIR}/WoFS_FCST.job
    echo "#=================================================================="  >> ${FCSTHR_DIR}/WoFS_FCST.job

    cat >> ${FCSTHR_DIR}/WoFS_FCST.job << EOF

source ${ENVDIR}/WOFenv_rlt_2021
source ${TOP_DIR}/realtime.cfg.${event}
set echo

if ( \${SLURM_ARRAY_TASK_ID} <= 9 ) then
   cd ${FCSTHR_DIR}/ENS_MEM_0\${SLURM_ARRAY_TASK_ID}
   setenv MPICH_MPIIO_HINTS "${FCSTHR_DIR}/ENS_MEM_0\${SLURM_ARRAY_TASK_ID}/wrfout*:striping_factor=4,cb_nodes=4"
else
   cd ${FCSTHR_DIR}/ENS_MEM_\${SLURM_ARRAY_TASK_ID}
   setenv MPICH_MPIIO_HINTS "${FCSTHR_DIR}/ENS_MEM_\${SLURM_ARRAY_TASK_ID}/wrfout*:striping_factor=4,cb_nodes=4"
endif

setenv I_MPI_PMI_LIBRARY /opt/cray/pe/pmi/5.0.17/lib64/libpmi.so
setenv MPICH_VERSION_DISPLAY 1
setenv MPICH_ENV_DISPLAY 1
setenv MPICH_MPIIO_HINTS_DISPLAY 1
setenv MALLOC_MMAP_MAX 0
setenv MALLOC_TRIM_THRESHOLD 536870912
setenv MPICH_GNI_RDMA_THRESHOLD 2048
setenv MPICH_GNI_DYNAMIC_CONN disabled
setenv MPICH_CPUMASK_DISPLAY 1

setenv OMP_NUM_THREADS 1

${COPY} ${RUNDIR}/mem\${SLURM_ARRAY_TASK_ID}/wrfbdy_d01.\${SLURM_ARRAY_TASK_ID} ./wrfbdy_d01
#${COPY} ${RUNDIR}/${fcst_start}/wrfinput_d01.\${SLURM_ARRAY_TASK_ID} ./wrfinput_d01
${COPY} ${RUNDIR}/ic\${SLURM_ARRAY_TASK_ID}/wrfinput_d01_ic ./wrfinput_d01
${COPY} ${TEMPLATE_DIR}/forecast_vars_d01.txt ./

srun ${RUNDIR}/WRF_RUN/wrf.exe

EOF

    #SUBMIT ALL FORECAST MEMBERS AT ONCE
    sbatch --array=$member ${FCSTHR_DIR}/WoFS_FCST.job

    sleep 10

    #while ($member <= ${FCST_SIZE})
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

        cd ..
    #end

    touch ${FCST_DIR}/fcst_${fcst_start}_done

end

echo '       ************* RUN IS COMPLETE **************       '

exit (0)
