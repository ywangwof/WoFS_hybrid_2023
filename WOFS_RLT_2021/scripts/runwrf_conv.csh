#!/bin/csh

set mem=${1}
set starttime=${2}
set endtime=${3}
set retrofile=${4}
source ${retrofile}

set START_YEAR  = `echo ${starttime} | cut -c1-4`
set START_MONTH = `echo ${starttime} | cut -c5-6`
set START_DAY   = `echo ${starttime} | cut -c7-8`
set START_HOUR  = `echo ${starttime} | cut -c9-10`
set START_MIN   = `echo ${starttime} | cut -c11-12`

set END_YEAR  = `echo ${endtime} | cut -c1-4`
set END_MONTH = `echo ${endtime} | cut -c5-6`
set END_DAY   = `echo ${endtime} | cut -c7-8`
set END_HOUR  = `echo ${endtime} | cut -c9-10`
set END_MIN   = `echo ${endtime} | cut -c11-12`

#echo ${END_HOUR}

set WRFRUNDIR=${RUNDIR}/enkfrun${mem}

${REMOVE} advModel.sed namelist.input
cat >! advModel.sed << EOF
         /run_hours/c\
         run_hours                  = 0,
         /run_minutes/c\
         run_minutes                = ${cycleinterval},
         /run_seconds/c\
         run_seconds                = 0,
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
         history_interval           = 2*${cycleinterval},
         /frames_per_outfile/c\
         frames_per_outfile         = 2*1,
         /auxhist2_interval/c\
         auxhist2_interval          = 2*${cycleinterval},
         /diag_print/c\
         diag_print                 = 0,
         /time_step_fract_num/c\
         time_step_fract_num        = 0,
         /time_step_fract_den/c\
         time_step_fract_den        = 1,
         /max_dom/c\
         max_dom                    = 1,
         /debug_level/c\
         debug_level                = 0,
         /e_we/c\
         e_we                       = ${grdpts_ew},
         /e_sn/c\
         e_sn                       = ${grdpts_ns},
         /parent_time_step_ratio/c\
         parent_time_step_ratio     = 1, 5,
         /parent_grid_ratio/c\
         parent_grid_ratio          = 1, 5,
         /time_step/c\
         time_step                  = ${ts},
         /numtiles/c\
         numtiles                   = 1,
         /nproc_x/c\
         nproc_x                    = 2,
         /nproc_y/c\
         nproc_y                    = 12,
         /radt/c\
         radt                       = ${radt1},
EOF
# The EOF on the line above MUST REMAIN in column 1.

${COPY} -f ${TEMPLATE_DIR}/namelists.WOFS.RLT2021/namelist.input.member${mem} ${WRFRUNDIR}/
#${COPY} -f ${TEMPLATE_DIR}/namelists.WOFS/namelist.input.member6 ${WRFRUNDIR}/namelist.input.member${mem}
sed -f advModel.sed ${WRFRUNDIR}/namelist.input.member${mem} >! ${WRFRUNDIR}/namelist.input

${COPY}    ${ENKFDIR}/wrfbdy_d01.${mem} ${WRFRUNDIR}/wrfbdy_d01
echo "Copy ${RUNDIR}/${starttime}/wrfinput_d01_${mem} -> ${WRFRUNDIR}/wrfinput_d01"
${COPY} -f ${RUNDIR}/${starttime}/wrfinput_d01_${mem} ${WRFRUNDIR}/wrfinput_d01
${LINK}    ${RUNDIR}/WRF_RUN/* ${WRFRUNDIR}

exit 0

########################################################################
