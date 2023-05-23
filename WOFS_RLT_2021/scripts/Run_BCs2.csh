#!/bin/csh
#
#set echo

source ${ENVDIR}/WOFenv_rlt_2021
source ${TOP_DIR}/realtime.cfg.${event}

set emember = ${1}
@ emember2 = $emember + 9
@ emember3 = $emember + 18
@ emember4 = $emember + 27
#@ emember5 = $emember + 36
#@ emember6 = $emember + 45
#@ emember7 = $emember + 54
#@ emember8 = $emember + 63

cd ${RUNDIR}/mem${emember}
rm -f namelist.input.template
${LINK} ${RUNDIR}/input.nml ${RUNDIR}/mem${emember}/input.nml
#
echo ${PWD}

set start_year    = `echo $edate1_12 |cut -c1-4`
set start_month   = `echo $edate1_12 |cut -c6-7`
set start_day     = `echo $edate1_12 |cut -c9-10`
set start_hour    = `echo $edate1_12 |cut -c12-13`
set start_minute  = `echo $edate1_12 |cut -c15-16`
set start_second  = `echo $edate1_12 |cut -c18-19`

set end_year    = `echo $edate2_12 |cut -c1-4`
set end_month   = `echo $edate2_12 |cut -c6-7`
set end_day     = `echo $edate2_12 |cut -c9-10`
set end_hour    = `echo $edate2_12 |cut -c12-13`
set end_minute  = `echo $edate2_12 |cut -c15-16`
set end_second  = `echo $edate2_12 |cut -c18-19`

### time interval between two analysis
set interval_seconds = 3600
#
cat > script.sed << EOF
/start_year/c \\
 start_year                          = $start_year, $start_year,
/start_month/c \\
 start_month                         = $start_month, $start_month,
/start_day/c \\
 start_day                           = $start_day, $start_day,
/start_hour/c \\
 start_hour                          = $start_hour, $start_hour,
/start_minute/c \\
 start_minute                        = $start_minute, $start_minute,
/start_second/c \\
 start_second                        = $start_second, $start_second,
/end_year/c \\
 end_year                            = $end_year, $end_year,
/end_month/c \\
 end_month                           = $end_month, $end_month,
/end_day/c \\
 end_day                             = $end_day, $end_day,
/end_hour/c \\
 end_hour                            = $end_hour, $end_hour,
/end_minute/c \\
 end_minute                          = $end_minute, $end_minute,
/end_second/c \\
 end_second                          = $end_second, $end_second,
/time_step_fract_num/c \\
 time_step_fract_num                 = 0,
/time_step_fract_den/c \\
 time_step_fract_den                 = 1,
/interval_seconds/c \\
 interval_seconds                    = $interval_seconds,
/max_dom/c \\
 max_dom                             = $domains,
/e_we/c \\
 e_we                                = $grdpts_ew, 1,
/e_sn/c \\
 e_sn                                = $grdpts_ns, 1,
/i_parent_start/c \\
 i_parent_start                      = 1, 1,
/j_parent_start/c \\
 j_parent_start                      = 1, 1,
/numtiles/c \\
 numtiles                            = ${tiles},
/nproc_x/c \\
 nproc_x                             = 4,
/nproc_y/c \\
 nproc_y                             = 12,
/parent_grid_ratio/c \\
 parent_grid_ratio                   = 1, 5,
/parent_time_step_ratio/c \\
 parent_time_step_ratio              = 1, 5,
/time_step/c \\
 time_step                           = $ts,
/p_top_requested/c \\
 p_top_requested                     = 2000,
/num_land_cat/c \\
 num_land_cat                        = 21,

EOF

if ( ! -e namelist.input.template) cp ${TEMPLATE_DIR}/namelists.WOFS.RLT2021/namelist.input.member${emember} namelist.input.template
#if ( ! -e namelist.input.template) cp ${TEMPLATE_DIR}/namelists.WOFS/namelist.input.member6 namelist.input.template
###
sed -f script.sed namelist.input.template > namelist.input

# ------------------------------------------------
# run real.exe, rename wrfinput_d01 and wrfbdy_d01
# ------------------------------------------------

echo "#\!/bin/csh"                                                                >! ${RUNDIR}/mem${emember}/icbc_bc2.csh
echo "#=================================================================="        >> ${RUNDIR}/mem${emember}/icbc_bc2.csh
echo '#SBATCH' "-J mem${emember}/icbc_bc2"                                        >> ${RUNDIR}/mem${emember}/icbc_bc2.csh
echo '#SBATCH' "-o ${RUNDIR}/mem${emember}/icbc_bc2.log"                          >> ${RUNDIR}/mem${emember}/icbc_bc2.csh
echo '#SBATCH' "-e ${RUNDIR}/mem${emember}/icbc_bc2.err"                          >> ${RUNDIR}/mem${emember}/icbc_bc2.csh
echo '#SBATCH' "-A largequeue"                                                    >> ${RUNDIR}/mem${emember}/icbc_bc2.csh
echo '#SBATCH' "-p workq"                                                         >> ${RUNDIR}/mem${emember}/icbc_bc2.csh
echo '#SBATCH' "--ntasks-per-node=24"                                             >> ${RUNDIR}/mem${emember}/icbc_bc2.csh
echo '#SBATCH' "-n 48"                                                            >> ${RUNDIR}/mem${emember}/icbc_bc2.csh
echo '#SBATCH -t 0:30:00'                                                         >> ${RUNDIR}/mem${emember}/icbc_bc2.csh
echo "#=================================================================="        >> ${RUNDIR}/mem${emember}/icbc_bc2.csh

cat >> ${RUNDIR}/mem${emember}/icbc_bc2.csh << EOF

    source ${ENVDIR}/WOFenv_rlt_2021

    set echo

    cd \${SLURM_SUBMIT_DIR}

    setenv MPICH_VERSION_DISPLAY 1
    setenv MPICH_ENV_DISPLAY 1
    setenv MPICH_MPIIO_HINTS_DISPLAY 1
    setenv MPICH_GNI_RDMA_THRESHOLD 2048
    setenv MPICH_GNI_DYNAMIC_CONN disabled

    setenv OMP_NUM_THREADS 1

    cd ${RUNDIR}/mem${emember}/

    ln -sf ${RUNDIR}/WRF_RUN/real.exe real.exe
    ln -sf ${RUNDIR}/WRF_RUN/ETAMPNEW_DATA ETAMPNEW_DATA
    ln -sf ${RUNDIR}/WRF_RUN/GENPARM.TBL GENPARM.TBL
    ln -sf ${RUNDIR}/WRF_RUN/LANDUSE.TBL LANDUSE.TBL
    ln -sf ${RUNDIR}/WRF_RUN/RRTMG_LW_DATA RRTMG_LW_DATA
    ln -sf ${RUNDIR}/WRF_RUN/RRTMG_SW_DATA RRTMG_SW_DATA
    ln -sf ${RUNDIR}/WRF_RUN/RRTM_DATA RRTM_DATA
    ln -sf ${RUNDIR}/WRF_RUN/SOILPARM.TBL SOILPARM.TBL
    ln -sf ${RUNDIR}/WRF_RUN/VEGPARM.TBL VEGPARM.TBL
    ln -sf ${RUNDIR}/WRF_RUN/gribmap.txt gribmap.txt
    ln -sf ${RUNDIR}/WRF_RUN/tr49t67 tr49t67
    ln -sf ${RUNDIR}/WRF_RUN/tr49t85 tr49t85
    ln -sf ${RUNDIR}/WRF_RUN/tr67t85 tr67t85

    srun ${RUNDIR}/WRF_RUN/real.exe

    if ( ! -e wrfinput_d01) then
       echo !!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!
       echo real.exe failed in generating wrfinput_d01
    else if ( ! -e wrfbdy_d01  ) then
       echo !!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!
       echo real.exe failed in generating wrfbdy_d01
    else
       echo Done with Input and Boundary files for BC2

       rm -rf  wrfinput_d01
       sleep 2

    endif

    ${COPY} ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember} ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember}.p1
    sleep 1
    ${MOVE} ${RUNDIR}/mem${emember}/wrfbdy_d01 ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember}.p2
    sleep 1
    /scratch/software/Odin/python/anaconda2/bin/ncrcat ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember}.p1 ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember}.p2 ${RUNDIR}/mem${emember}/wrfbdy_d01.final
    sleep 1

    ${COPY} ${RUNDIR}/mem${emember}/wrfbdy_d01.final ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember2}
    sleep 1
    ${COPY} ${RUNDIR}/mem${emember}/wrfbdy_d01.final ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember3}
    sleep 1
    ${COPY} ${RUNDIR}/mem${emember}/wrfbdy_d01.final ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember4}
    sleep 1
    ${MOVE} ${RUNDIR}/mem${emember}/wrfbdy_d01.final ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember}
    sleep 1
    ${MOVE} ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember2} ${RUNDIR}/mem${emember2}/wrfbdy_d01.${emember2}
    sleep 1
    ${MOVE} ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember3} ${RUNDIR}/mem${emember3}/wrfbdy_d01.${emember3}
    sleep 1
    ${MOVE} ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember4} ${RUNDIR}/mem${emember4}/wrfbdy_d01.${emember4}
    sleep 1

    touch ${SEMA4}/bc2_mem${emember}_done

EOF

 #${COPY} ${RUNDIR}/mem${emember}/wrfbdy_d01.final ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember3}
 #${COPY} ${RUNDIR}/mem${emember}/wrfbdy_d01.final ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember4}
 #${MOVE} ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember3} ${RUNDIR}/mem${emember3}/wrfbdy_d01.${emember3}
 #sleep 1
 #${MOVE} ${RUNDIR}/mem${emember}/wrfbdy_d01.${emember4} ${RUNDIR}/mem${emember4}/wrfbdy_d01.${emember4}


chmod +x ${RUNDIR}/mem${emember}/icbc_bc2.csh
sbatch ${RUNDIR}/mem${emember}/icbc_bc2.csh

sleep 1

exit (0)
#########################################################################################################
