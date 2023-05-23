#!/bin/csh
#

#set echo

source ${ENVDIR}/WOFenv_rlt_2021
source ${TOP_DIR}/realtime.cfg.${event}

echo "Starting Script ICBC.csh"

set emember = ${1}

cd ${RUNDIR}/ic${emember}
rm -f namelist.input.template
${LINK} ${RUNDIR}/input.nml ${RUNDIR}/ic${emember}/input.nml
#
echo ${PWD}

### 1st analysis time
set start_year   = ${runyr}
set start_month  = ${runmon}
set start_day    = ${runday}
set start_hour   = ${cycle_start}
set start_minute = 00
set start_second = 00

### time interval between two analysis
set interval_seconds = 3600

# --------------------------------------------------
# convert to Gregorian date using
# --------------------------------------------------
set start_g_date = `${RUNDIR}/convertdate | tail -1 | cut -d: -f2` << EOF
1
$start_year $start_month $start_day $start_hour $start_minute $start_second
EOF

echo $start_g_date
###
set g_days = `echo ${start_g_date[1]} | cut -b1-6`
set g_seconds = $start_g_date[2]
set c_date = `echo {$start_year}-{$start_month}-{$start_day}_{$start_hour}:{$start_minute}:{$start_second}.0000`
set g_days_all = `echo $g_days`
set g_seconds_all = `echo $g_seconds`
set c_date_all = `echo $c_date`

# --------------------------------------------------
# construct required wrfinput and wrfbdy file names
#  and get all corresponding date/time
# --------------------------------------------------
set wrfinfn = ""
set wrfbdyfn = ""
set wrfinfn = `echo ${wrfinfn} wrfinput_d01_${g_days}_${g_seconds}_${emember}`
@ g_seconds += $interval_seconds
if ($g_seconds >= 86400) then
   @ g_seconds -= 86400
   @ g_days += 1
endif
set wrfbdyfn = `echo ${wrfbdyfn} wrfbdy_d01_${g_days}_${g_seconds}_${emember}`
set g_days_all = `echo $g_days_all $g_days`
set g_seconds_all = `echo $g_seconds_all $g_seconds`

set c_date = `echo {$cdtmp[1]}-{$cdtmp[2]}-{$cdtmp[3]}_{$cdtmp[4]}:{$cdtmp[5]}:{$cdtmp[6]}.0000`
set c_date_all = `echo $c_date_all $c_date`

# --------------------------------------------------
# check if required WPS output files exist
# --------------------------------------------------
set errorflag = 0
foreach c_date ( $c_date_all )
  set fn = met_em.d01.`echo $c_date |cut -c1-19`.nc
  if (! -e $fn ) then
    echo $fn does not exist!
    set errorflag = 1
  else
    echo $fn
  endif
end
###
if ( $errorflag > 0 ) exit
###

# ------------------------------
# Get cycle time
# ------------------------------
set ICYC = 1
cd ${RUNDIR}/ic${emember}
set start_year    = `echo $c_date_all[$ICYC] |cut -c1-4`
set start_month   = `echo $c_date_all[$ICYC] |cut -c6-7`
set start_day     = `echo $c_date_all[$ICYC] |cut -c9-10`
set start_hour    = `echo $c_date_all[$ICYC] |cut -c12-13`
set start_minute  = `echo $c_date_all[$ICYC] |cut -c15-16`
set start_second  = `echo $c_date_all[$ICYC] |cut -c18-19`
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
 end_year                            = $start_year, $start_year,
/end_month/c \\
 end_month                           = $start_month, $start_month,
/end_day/c \\
 end_day                             = $start_day, $start_day,
/end_hour/c \\
 end_hour                            = $start_hour, $start_hour,
/end_minute/c \\
 end_minute                          = $start_minute, $start_minute,
/end_second/c \\
 end_second                          = $start_second, $start_second,
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
 nproc_x                             = 2,
/nproc_y/c \\
 nproc_y                             = 12,
/parent_grid_ratio/c \\
 parent_grid_ratio                   = 1, 5,
/parent_time_step_ratio/c\
 parent_time_step_ratio              = 1, 5,
/time_step/c \\
 time_step                           = $ts,
/num_land_cat/c \\
 num_land_cat                        = 21,

EOF

if ( ! -e namelist.input.template) cp ${TEMPLATE_DIR}/namelists.WOFS.RLT2021/namelist.input.member${emember} namelist.input.template
#if ( ! -e namelist.input.template) cp ${TEMPLATE_DIR}/namelists.WOFS/namelist.input.member6 namelist.input.template

sed -f script.sed namelist.input.template > namelist.input

# ------------------------------------------------
# run real.exe, rename wrfinput_d01 and wrfbdy_d01
# ------------------------------------------------

if ( -e cycle_1h_$ICYC ) rm -rf cycle_1h_$ICYC

mkdir cycle_1h_$ICYC
cd cycle_1h_$ICYC
cp ${RUNDIR}/ic${emember}/namelist.input .

echo "#\!/bin/csh"                                                                >! ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh
echo "#=================================================================="        >> ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh
echo '#SBATCH' "-J mem${emember}/cycle_${ICYC}/icbc_1h_${ICYC}"                   >> ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh
echo '#SBATCH' "-o ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.log"   >> ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh
echo '#SBATCH' "-e ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.err"   >> ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh
echo '#SBATCH' "-A largequeue"                                                    >> ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh
echo '#SBATCH' "-p workq"                                                         >> ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh
echo '#SBATCH' "--ntasks-per-node=24"                                             >> ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh
echo '#SBATCH' "-n 24"                                                            >> ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh
echo '#SBATCH -t 0:30:00'                                                         >> ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh
echo "#=================================================================="        >> ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh

    cat >> ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh << EOF

    source ${ENVDIR}/WOFenv_rlt_2021

    set echo

    cd \${SLURM_SUBMIT_DIR}

    setenv MPICH_VERSION_DISPLAY 1
    setenv MPICH_ENV_DISPLAY 1
    setenv MPICH_MPIIO_HINTS_DISPLAY 1
    setenv MPICH_GNI_RDMA_THRESHOLD 2048
    setenv MPICH_GNI_DYNAMIC_CONN disabled

    setenv OMP_NUM_THREADS 1

    cd ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}

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

    ln -sf ${RUNDIR}/ic${emember}/met_em* .

    srun ${RUNDIR}/WRF_RUN/real.exe

    if ( ! -e wrfinput_d01) then
       echo !!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!
       echo real.exe failed in generating wrfinput_d01
    else
       echo Done with Input and Boundary files for  Cycle $ICYC
       if ( $ICYC == 1 ) then
          cp wrfinput_d01 ${RUNDIR}/ic${emember}/wrfinput_d01_ic
       endif
       sleep 1
       rm wrfinput_d01
       echo "struct check:  " $wrfinfn[$ICYC]
       sleep 1
       rm wrfbdy_d01
       sleep 1
    endif

    cp namelist.input namelist.input$ICYC

    touch ${SEMA4}/ic_mem${emember}_cycle${ICYC}_done

EOF

chmod +x ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh
sbatch ${RUNDIR}/ic${emember}/cycle_1h_${ICYC}/icbc_1h_${ICYC}.csh

sleep 1

exit (0)
###################################################################################################################
