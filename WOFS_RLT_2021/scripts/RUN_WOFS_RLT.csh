#!/bin/csh
#
########################################################################
#
#   RUN WoFS SYSTEM
#   Assimilates: MRMS reflectivity and radial velocity,
#                GOES CWP, OK Mesonset data, prebufr conventional observations
#
########################################################################
set scrptdir=$0:h
set scrptdir=`realpath ${scrptdir}`
set parentdir=${scrptdir:h}

if ($#argv >= 1 ) then
    set realconfig = $argv[1]
else
    set realconfig = ${parentdir}/WOFenv_rlt_2021
endif

echo "Realtime configuration file: $realconfig"
source ${realconfig}

#set GSIRLT = ${PWD}/WOFenv_rlt_2021
#source ${GSIRLT}

set ENVFILE = ${TOP_DIR}/realtime.cfg.${event}
source ${ENVFILE}

setenv ENVDIR ${PWD}
set execdir=${parentdir}/exec

#set echo
set nonomatch

set startdate = ${event}${cycle_start}00
#set datea = ${event}${cycle_start}00
if ($#argv >= 2 ) then
    if ($argv[2] =~ [0-9][0-9][0-9][0-9]) then
        set starttime = "${argv[2]}"
    else
        echo "ERROR: unsupported argument: $argv[2]"
        exit 0
    endif
else
    set starttime = "1500"
endif
if ($#argv == 3 ) then
    if ($argv[3] =~ [0-9][0-9][0-9][0-9]) then
        set endtime = "${argv[3]}"
    else
        echo "ERROR: unsupported argument: $argv[3]"
        exit 0
    endif
else
    set endtime = "0300"
endif

#
# modules
#
module load compiler/latest
module load mkl/latest
module load hmpt/2.27

setenv  PATH ./:/bin:/scratch/software/intel/netcdf/bin:/scratch/software/miniconda3/bin:$PATH
setenv LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:/scratch/software/intel/netcdf/lib:/scratch/software/intel/hdf5/lib:/scratch/software/intel/grib2/libpng/lib:/scratch/software/intel/grib2/zlib/lib:/scratch/software/miniconda3/lib:/usr/lib64

## HOLD SCRIPT UNTIL BCs and ICs are ready
#while ( ! -e ${SEMA4}/BCs_ready )
#      echo "Waiting for BCs file generation"
#      sleep 10
#end

#while ( ! -e ${SEMA4}/ICs_ready )
#      echo "Waiting for ICs to be generated"
#      sleep 10
#end

set startdate=${event}${cycle_start}00
set datea = ${event}${starttime}
set datef = ${nxtDay}${endtime}

cd ${RUNDIR}

## MAKE WORK DIRECTORIES
if ( ! -d "${RESULTSDIR}" ) then
    mkdir ${RESULTSDIR}
endif
if ( ! -d "${RESULTSDIR}/stdout" ) then
    mkdir ${RESULTSDIR}/stdout
endif
if ( ! -d "${ENKFDIR}" ) then
    mkdir ${ENKFDIR}
endif

## main loop over data assimilation cycles

while (1 == 1)

  set reflyes = 0
  set vryes = 0
  set cwpyes = 0
  set okmesoyes = 0
  set goesyes = 0
  set bufryes = 0
  set aeriyes = 0
  set dlyes = 0
  set amvyes = 0
  set fedyes = 0
  set uasyes = 0

  #set up some time strings
  set daten  =  `echo  ${datea} ${cycleinterval}m | ${RUNDIR}/advance_time`

  set thisstart = ${datea}
  set thisend = ${daten}

  set startyear  = `echo ${thisstart} | cut -c1-4`
  set startmonth = `echo ${thisstart} | cut -c5-6`
  set startday   = `echo ${thisstart} | cut -c7-8`
  set starthour  = `echo ${thisstart} | cut -c9-10`
  set startmin   = `echo ${thisstart} | cut -c11-12`

  set endyear  = `echo ${thisend} | cut -c1-4`
  set endmonth = `echo ${thisend} | cut -c5-6`
  set endday   = `echo ${thisend} | cut -c7-8`
  set endhour  = `echo ${thisend} | cut -c9-10`
  set endmin   = `echo ${thisend} | cut -c11-12`

  echo " "
  echo "Current DA cycle: ${datea}"

  ${REMOVE} -rf ${ENKFDIR}/enkfrun*
  ${REMOVE} -rf ${ENKFDIR}/*_done

  #### COPY OVER STATIC AND ICBC FILES AT FIRST ASSMILATION CYCLE
  if ( ${startdate} == ${datea} ) then
    ${COPY} ${SATANGL} ${ENKFDIR}/satbias_angle
    ${COPY} ${SATINFO} ${ENKFDIR}/satinfo
    ${COPY} ${CONVINFO} ${ENKFDIR}/convinfo
    ${COPY} ${OZINFO} ${ENKFDIR}/ozinfo
    ${COPY} ${SATBIASING} ${ENKFDIR}/satbias_in
    ${COPY} ${SATBIASPC} ${ENKFDIR}/satbias_pc
    ${COPY} ${TEMPLATE_DIR}/obs_locinfo_multi ${ENKFDIR}/obs_locinfo
    ${COPY} ${RUNDIR}/input.nml ${ENKFDIR}/input.nml
    #${COPY} ${SCRIPTDIR}/vr_masking.job ${ENKFDIR}
    #${COPY} ${SCRIPTDIR}/vr_mask_realtime.py ${ENKFDIR}

    set imem = 1
    while ( ${imem} <= ${ENS_SIZE} )
        ${COPY} ${RUNDIR}/ic${imem}/wrfinput_d01_ic ${ENKFDIR}/wrfinput_d01.${imem}
        @ imem++
    end

    cd ${ENKFDIR} ###FIRST CD INTO THERE

    # CALCULATE ENSEMBLE MEAN REFLECTIVITY FOR ADD NOISE (and for EnKF use)
    ${COPY} ${SCRIPTDIR}/run_nceamean_conv_d01.job .
    sbatch run_nceamean_conv_d01.job

    echo "WAITING FOR ENSEMBLE MEAN TO FINISH"
    while ( ! -e ${ENKFDIR}/ensmean_done01 )
        sleep 3
    end
    ${REMOVE} ${ENKFDIR}/ensmean_done01
    ${REMOVE} ${ENKFDIR}/nceamean01*

  endif   #END FIRST CYCLE WORK

  # Link correct boundary conditions into EnKF directory
  set imem = 1
  while ( ${imem} <= ${ENS_SIZE} )
       ln -sf ${RUNDIR}/mem${imem}/wrfbdy_d01.${imem} ${ENKFDIR}/wrfbdy_d01.${imem}
       @ imem++
  end

###################### APPLY PRIOR INFLATION (later)
  set DOMAIN = 01
  mkdir ${RUNDIR}/${thisstart}/diag_${DOMAIN}

  #### write enkf namelist file, include prior inflation information
  ${REMOVE} ${ENKFDIR}/enkf.sed ${ENKFDIR}/enkf.nml
  cat >! ${ENKFDIR}/enkf.sed << EOF
  /datestring=/c\
  datestring="${datea}",
  /datapath=/c\
  datapath="${ENKFDIR}/",
  /analpertwtnh=/c\
  analpertwtnh=${ANALPERTWTNH3KM},
  /analpertwtsh=/c\
  analpertwtsh=${ANALPERTWTSH},
  /analpertwttr=/c\
   analpertwttr=${ANALPERTWTTR},
  /corrlengthnh=/c\
   corrlengthnh=${CORRLENGTHNH},
  /corrlengthsh=/c\
   corrlengthsh=${CORRLENGTHSH},
  /corrlengthtr=/c\
   corrlengthtr=${CORRLENGTHTR},
  /lnsigcutoffnh=/c\
   lnsigcutoffnh=${LNSIGCUTOFFNH},
  /lnsigcutoffsh=/c\
   lnsigcutoffsh=${LNSIGCUTOFFSH},
  /lnsigcutofftr=/c\
   lnsigcutofftr=${LNSIGCUTOFFTR},
  /lnsigcutoffpsnh=/c\
   lnsigcutoffpsnh=${LNSIGCUTOFFPSNH},
  /lnsigcutoffpssh=/c\
   lnsigcutoffpssh=${LNSIGCUTOFFPSSH},
  /lnsigcutoffpstr=/c\
   lnsigcutoffpstr=${LNSIGCUTOFFPSTR},
  /nlons=/c\
  nlons=${NLONS},
  /nlats=/c\
  nlats=${NLATS},
  /nlevs=/c\
  nlevs=${NLEVS},
  /nanals=/c\
  nanals=${NANALS},
  /nvars=/c\
  nvars=${NVARS},
  /prior_inf=/c\
  prior_inf=${PRIOR_INF},
  /fgfileprefixes =/c\
   fgfileprefixes = 'wrfinput_d${DOMAIN}.','','','','','','',
  /anlfileprefixes =/c\
   anlfileprefixes = 'wrfinput_d${DOMAIN}.','','','','','','',
  /prior_inf_file = /c\
   prior_inf_file = 'prior_inf_d${DOMAIN}',
  /prior_inf_sd_file = /c\
   prior_inf_sd_file = 'prior_inf_sd_d${DOMAIN}',
EOF
# The EOF on the line above MUST REMAIN in column 1.
  /bin/cp -p ${TEMPLATE_DIR}/enkf.nml.template ${ENKFDIR}/enkf.nml.temp
  sed -f ${ENKFDIR}/enkf.sed ${ENKFDIR}/enkf.nml.temp >! ${ENKFDIR}/enkf.nml

# RUN PRIOR Inflation ##################

  if( ${PRIOR_INF} == 1) then
    # check whether the prior_inf.nc and prior_in_sd.nc exist, if one of them does not exist, create new copies for both
    if ((! -e ${ENKFDIR}/prior_inf_d${DOMAIN}.1) || (! -e ${ENKFDIR}/prior_inf_sd_d${DOMAIN}.1)) then # one background
     echo "prior_inf_d${DOMAIN}.1 OR prior_inf_sd_d${DOMAIN}.1 does not exist at time: "${datea}
     echo "create prior_inf_d${DOMAIN}.1 and prior_inf_sd_d${DOMAIN}.1 files"
     echo "#\!/bin/csh"                                                          >! ${ENKFDIR}/runinitinf.job
     echo "#=================================================================="  >> ${ENKFDIR}/runinitinf.job
     echo '#SBATCH' "-J runinitinf"                                              >> ${ENKFDIR}/runinitinf.job
     echo '#SBATCH' "-o ${ENKFDIR}/runinitinf.log.${thisstart}"                  >> ${ENKFDIR}/runinitinf.job
     echo '#SBATCH' "-e ${ENKFDIR}/runinitinf.err.${thisstart}"                  >> ${ENKFDIR}/runinitinf.job
     echo '#SBATCH' "-p batch"                                                   >> ${ENKFDIR}/runinitinf.job
     echo '#SBATCH' "--mem-per-cpu=6G"                                           >> ${ENKFDIR}/runinitinf.job
     echo '#SBATCH' "-n ${INF_CORES}"                                            >> ${ENKFDIR}/runinitinf.job
     echo '#SBATCH' "-t 00:10:00"                                                >> ${ENKFDIR}/runinitinf.job
     echo "#=================================================================="  >> ${ENKFDIR}/runinitinf.job

     cat >> ${ENKFDIR}/runinitinf.job << EOF

     module load compiler
     module load mkl/latest
     module load hmpt/2.27

     source ${ENVFILE}

     set echo

     setenv OMP_NUM_THREADS 1

     srun --mpi=pmi2 ${RUNDIR}/GSI_RUN/init_inf

     touch init_inf_done
     exit 0
EOF

    # SUBMIT INIT INFLATION
    sbatch runinitinf.job
    echo "WAITING FOR INITIALIZING INFLATION TO FINISH"
    while ( ! -e ${ENKFDIR}/init_inf_done )
        sleep 3
    end

    # CLEAN UP THINGS
    #${REMOVE} runinitinf.err
    ${REMOVE} init_inf_done
    ${REMOVE} runinitinf.job
    ${MOVE} *log* ${RESULTSDIR}/stdout
    ${MOVE} *err* ${RESULTSDIR}/stdout

   endif # END CREATE PRIOR_INF_d${DOMAIN}.1 and PRIOR_INF_SD_d${DOMAIN}_1 FILES

   # copy the original inflation files to every time cycle directory
   ${COPY} ${ENKFDIR}/prior_inf_d${DOMAIN}.1 ${RUNDIR}/${thisstart}/initial_prior_inf_d${DOMAIN}.1
   ${COPY} ${ENKFDIR}/prior_inf_sd_d${DOMAIN}.1 ${RUNDIR}/${thisstart}/initial_prior_inf_sd_d${DOMAIN}.1

    ### START PRIOR INFLATION
    cd ${ENKFDIR}
    echo "running prior inflation"
    echo "#\!/bin/csh"                                                          >! ${ENKFDIR}/runpriorinf.job
    echo "#=================================================================="  >> ${ENKFDIR}/runpriorinf.job
    echo '#SBATCH' "-J runpriorinf"                                             >> ${ENKFDIR}/runpriorinf.job
    echo '#SBATCH' "-o ${ENKFDIR}/runpriorinf.log.${thisstart}"                 >> ${ENKFDIR}/runpriorinf.job
    echo '#SBATCH' "-e ${ENKFDIR}/runpriorinf.err.${thisstart}"                 >> ${ENKFDIR}/runpriorinf.job
     echo '#SBATCH' "-p batch"                                                   >> ${ENKFDIR}/runpriorinf.job
     echo '#SBATCH' "--mem-per-cpu=6G"                                           >> ${ENKFDIR}/runpriorinf.job
    echo '#SBATCH' "-n ${INF_CORES}"                                            >> ${ENKFDIR}/runpriorinf.job
    echo '#SBATCH' "-t 00:30:00"                                                >> ${ENKFDIR}/runpriorinf.job
    echo "#=================================================================="  >> ${ENKFDIR}/runpriorinf.job

    cat >> ${ENKFDIR}/runpriorinf.job << EOF

     module load compiler
     module load mkl/latest
     module load hmpt/2.27

     source ${ENVFILE}

     set echo

     setenv OMP_NUM_THREADS 1

     srun --mpi=pmi2 ${RUNDIR}/GSI_RUN/prior_inf

   touch prior_inf_done
   exit 0
EOF

   # SUBMIT PRIOR INFLATION
   sbatch runpriorinf.job

   echo "WAITING FOR PRIOR INFLATION TO FINISH"
   while ( ! -e ${ENKFDIR}/prior_inf_done )
       sleep 3
       if ( -e ${ENKFDIR}/core ) then
          ${MOVE} core ${RESULTSDIR}/stdout/core.priorinf.${thisstart}
       endif
   end

   # CLEAN UP THINGS
   #${REMOVE} runpriorinf.err
   ${REMOVE} prior_inf_done
   ${REMOVE} runpriorinf.job
   ${MOVE} *log* ${RESULTSDIR}/stdout
   ${MOVE} *err* ${RESULTSDIR}/stdout
   ### END PRIOR INFLATION

   # copy the inflation values (may be different from the initial values because of damping)
   ${COPY} ${ENKFDIR}/prior_inf_d${DOMAIN}.1 ${RUNDIR}/${thisstart}/damped_prior_inf_d${DOMAIN}.1
   ${COPY} ${ENKFDIR}/prior_inf_sd_d${DOMAIN}.1 ${RUNDIR}/${thisstart}/damped_prior_inf_sd_d${DOMAIN}.1

  endif ###### END PRIOR INFLATION CONDITION

######################### END PRIOR Inflation ##################

######################### RUN GSI.exe ###########################

    # WAIT UNTIL 8 MINUTES AFTER ANALYSIS TIME FOR OBSERVATION FILES
    set datew  =  `echo  ${datea} ${waitinterval}m | ${RUNDIR}/advance_time`
    set today  =  `date -u +%Y%m%d%H%M`
    while ( ${today} < ${datew} )
        echo "WAITING FOR OBSERVATIONS " ${datea} ${datew} ${today}
        sleep 10
        set today  =  `date -u +%Y%m%d%H%M`
    end

    # CREATE ENV VARIABLES FOR OBSERVATION TIMES
    set yyyymmdd = `echo $thisstart | cut -c1-8`
    set hhmm = `echo $thisstart | cut -c9-12`

    # SEARCH FOR REFLECTIVITY OBSERVATIONS and RUN GRID REFL OBS
    ### RLT CODE
    echo "Looking for ${REF_DIR}/${yyyymmdd}/obs_seq_RF_${yyyymmdd}_${hhmm}.nc"
    if ( -e ${REF_DIR}/${yyyymmdd}/obs_seq_RF_${yyyymmdd}_${hhmm}.nc ) then
        /bin/cp -pv ${REF_DIR}/${yyyymmdd}/obs_seq_RF_${yyyymmdd}_${hhmm}.nc ${ENKFDIR}/dbzobs.nc
        ### RLT CODE
        #if ( -e ${LRAD_DIR}/REF/${event}/VER2/min_dbz_analysis_zeros_0/obs_seq_RF_${yyyymmdd}_${hhmm}.nc ) then
        #   /bin/cp -pv ${LRAD_DIR}/REF/${event}/VER2/min_dbz_analysis_zeros_0/obs_seq_RF_${yyyymmdd}_${hhmm}.nc ${ENKFDIR}/dbzobs.nc
       set reflyes = 1
       ${COPY} ${ADDNOISEDIR}/grid_refl_obs_gsi.exe ./
       ${COPY} ${SCRIPTDIR}/run_grid_refl.job ./
       if ( -e ${ENKFDIR}/grid_refl_obs_gsi.exe ) then
            echo "ADDITIVE NOISE APPLIED"
            # RUN NCL SCRIPT TO EXTRACT WHERE ADD-NOISE IS TO BE APPLIED
            sbatch run_grid_refl.job
            echo "WAITING FOR NCL REFL TO FINISH"
            while ( ! -e "refl_done" )
                sleep 2
            end
       else
            echo "NO GRID REFL FOUND: ADDITIVE NOISE NOT APPLIED"
       endif
   endif

   # SEARCH FOR RADIAL VELOCITY OBSERVATIONS
   ### RLT CODE
   if ( -e ${VEL_DIR}/${yyyymmdd}/obs_seq_VR_${yyyymmdd}_${hhmm}.nc ) then
        echo "Looking for ${VEL_DIR}/${yyyymmdd}/obs_seq_VR_${yyyymmdd}_${hhmm}.nc"
        /bin/cp -pv ${VEL_DIR}/${yyyymmdd}/obs_seq_VR_${yyyymmdd}_${hhmm}.nc ${ENKFDIR}/vrobs.nc
        ### RLT CODE
        #if ( -e ${LRAD_DIR}/VEL/${event}/obs_seq_VR_${yyyymmdd}_${hhmm}.nc ) then
        #   /bin/cp -pv ${LRAD_DIR}/VEL/${event}/obs_seq_VR_${yyyymmdd}_${hhmm}.nc ${ENKFDIR}/vrobs.nc
        set vryes = 1
   endif

   # SEARCH FOR NEW CWP OBSERVATION FILES
   #if ( -e ${SAT_DIR}/CWP/${startyear}/${thisstart}_GOES${GOESV}_CWP_OBS.nc ) then
   #   /bin/cp -pv  ${SAT_DIR}/CWP/${startyear}/${thisstart}_GOES${GOESV}_CWP_OBS.nc ${ENKFDIR}/cwpobs.nc
   #   set cwpyes = 1
   #endif

   # AMVs DATA from GOES-16   ----  Swapan Mallick
   # SEARCH FOR AMVs FILES
   #if ( -e ${SAT_DIR}/AMV/${startyear}/${thisstart}_GOES${GOESV}AMV.nc ) then
       #/bin/cp -pv ${SAT_DIR}/AMV/${startyear}/${thisstart}_GOES${GOESV}AMV.nc ${ENKFDIR}/goes_amv.nc
       #set amvyes = 1
   #endif

   # SEARCH FOR GOES-16 RADIANCE FILES
   #if ( -e ${SAT_DIR}/RADIANCE/${startyear}/D2/${thisstart}_GOES${GOESV}_TB_ALLSKY.nc ) then
   #   /bin/cp -pv ${SAT_DIR}/RADIANCE/${startyear}/D2/${thisstart}_GOES${GOESV}_TB_ALLSKY.nc ${ENKFDIR}/goes.nc
   #   set goesyes = 1
   #endif

    # COPY AVAILBLE MESONET AND PREBUFR OBS TO WORKING DIR
    if ( -e ${OBSDIR}/Mesonet/${startyear}/${startmonth}/${startday}/mesonet.realtime.${thisstart}.mdf ) then
        echo "Looking for ${OBSDIR}/Mesonet/${startyear}/${startmonth}/${startday}/mesonet.realtime.${thisstart}.mdf"
        /bin/cp -pv ${OBSDIR}/Mesonet/${startyear}/${startmonth}/${startday}/mesonet.realtime.${thisstart}.mdf ${ENKFDIR}/okmeso.mdf
        set okmesoyes = 1
    endif

    # BUFR DATA
    if ( ${startmin} == 15 ) then
       if ( -e ${OBSDIR}/EBUFR/${startyear}/${startmonth}/${startday}/rap.${startyear}${startmonth}${startday}${starthour}.prepbufr.tm00 ) then
          set pbufrfile = ${OBSDIR}/EBUFR/${startyear}/${startmonth}/${startday}/rap.${startyear}${startmonth}${startday}${starthour}.prepbufr.tm00
          echo "Looking for $pbufrfile"
          /bin/cp -pv ${pbufrfile} ${ENKFDIR}/prepbufr
          set  bufryes = 1
          echo "BUFR DATA ASSIMILATED"
       else if ( -e ${OBSDIR}/RBUFR/${startyear}/${startmonth}/${startday}/rtma.${startyear}${startmonth}${startday}${starthour}00.prepbufr.tm00 ) then
          set pbufrfile = ${OBSDIR}/RBUFR/${startyear}/${startmonth}/${startday}/rtma.${startyear}${startmonth}${startday}${starthour}00.prepbufr.tm00
          echo "Looking for $pbufrfile"
          /bin/cp -pv ${pbufrfile} ${ENKFDIR}/prepbufr
          set  bufryes = 1
          echo "BUFR DATA ASSIMILATED"
       endif
    endif

    # AERI And DWL from SGP ARM site
    #set dlbufrfile = ${SGP_DIR}/DLBUFR/dl_${thisstart}.dlbufr
    #if ( -e ${dlbufrfile} ) then
        #     /bin/cp -pv ${dlbufrfile} ${ENKFDIR}/dlbufr
        #set  dlyes = 1
        #echo "DWL BUFR DATA ASSIMILATED"
    #endif

    #set aeribufrfile = ${SGP_DIR}/AERIBUFR/aeri_${thisstart}.aeribufr
    #if ( -e ${aeribufrfile} ) then
        #     /bin/cp -pv ${aeribufrfile} ${ENKFDIR}/aeribufr
        #set  aeriyes = 1
        #echo "AERI BUFR DATA ASSIMILATED"
    #endif

    echo ${reflyes} ${vryes} ${cwpyes} ${bufryes} ${okmesoyes} ${goesyes} ${dlyes} ${aeriyes}

    # SETUP GSI NAMELIST
    ${REMOVE} -f ${ENKFDIR}/gsiparm.anl*
    if ( ${bufryes} == 1) then
        echo "   prepbufr         ps          null        ps        1.0      0       0           0.35" >> ${ENKFDIR}/gsiparm.anl.obs
        echo "   prepbufr         t           null        t         1.0      0       0           0.35" >> ${ENKFDIR}/gsiparm.anl.obs
        echo "   prepbufr         td          null        td        1.0      0       0           0.35" >> ${ENKFDIR}/gsiparm.anl.obs
        echo "   prepbufr         uv          null        uv        1.0      0       0           0.35" >> ${ENKFDIR}/gsiparm.anl.obs
    endif

    if ( ${okmesoyes} == 1) then
        echo "    okmeso.mdf      okt          null        okt       1.0      0       0         0.125" >> ${ENKFDIR}/gsiparm.anl.obs
        echo "    okmeso.mdf      oktd         null        oktd      1.0      0       0         0.125" >> ${ENKFDIR}/gsiparm.anl.obs
        echo "    okmeso.mdf      okuv         null        okuv      1.0      0       0         0.125" >> ${ENKFDIR}/gsiparm.anl.obs
        echo "    okmeso.mdf      okps         null        okps      1.0      0       0         0.125" >> ${ENKFDIR}/gsiparm.anl.obs
    endif

    if ( ${aeriyes} == 1) then
        echo "    aeribufr        aerit        null        aerit     1.0      0       0         0.25" >> ${ENKFDIR}/gsiparm.anl.obs
        echo "    aeribufr        aeritd       null        aeritd    1.0      0       0         0.25" >> ${ENKFDIR}/gsiparm.anl.obs
    endif

    if ( ${dlyes} == 1) then
        echo "    dlbufr          dlw          null        dlw       1.0      0       0         0.25" >> ${ENKFDIR}/gsiparm.anl.obs
    endif

    if ( ${reflyes} == 1) echo "    dbzobs.nc       dbz          null        dbz       1.0      0       0         0.04166666667" >> ${ENKFDIR}/gsiparm.anl.obs
    if ( ${vryes} == 1)   echo "    vrobs.nc        rw           null        rw        1.0      0       0         0.11666666667" >> ${ENKFDIR}/gsiparm.anl.obs
    if ( ${cwpyes} == 1)  echo "    cwpobs.nc       cwp          null        cwp       1.0      0       0         0.175" >> ${ENKFDIR}/gsiparm.anl.obs
    if ( ${goesyes} == 1) echo "    goes.nc         abi          g16         abi_g16   0.0      0       0         0.125" >> ${ENKFDIR}/gsiparm.anl.obs
    if ( ${amvyes} == 1) echo  "    goes_amv.nc     uv           null        uv        1.0      0       0         0.35" >> ${ENKFDIR}/gsiparm.anl.obs
  if ( ${fedyes} == 1) echo  "    fedobs.nc       fed          null        fed       1.0      0       0         0.08333333334">> ${ENKFDIR}/gsiparm.anl.obs
  if ( ${uasyes} == 1) then
    echo  "    uasobs.nc       uast         null        uast      1.0      0       0         0.25" >> ${ENKFDIR}/gsiparm.anl.obs
    echo  "    uasobs.nc       uastd        null        uastd     1.0      0       0         0.25" >> ${ENKFDIR}/gsiparm.anl.obs
    echo  "    uasobs.nc       uasuv        null        uasuv     1.0      0       0         0.25" >> ${ENKFDIR}/gsiparm.anl.obs
  endif

    ${REMOVE} advModel.sed
    cat >! advModel.sed << EOF
  /NLAT=xxx,NLON=yyy,nsig=zzz,/c\
  JCAP=62,JCAP_B=62,NLAT=${NLATS},NLON=${NLONS},nsig=${NLEVS},
EOF
# The EOF on the line above MUST REMAIN in column 1.
    sed -f advModel.sed ${TEMPLATE_DIR}/gsiparm.anl.template.head >! ${ENKFDIR}/gsiparm.anl.head

  # ADD obs portion to rest of template gsi parm file
    cat ${ENKFDIR}/gsiparm.anl.head ${ENKFDIR}/gsiparm.anl.obs ${TEMPLATE_DIR}/gsiparm.anl.template.tail > ${ENKFDIR}/gsiparm.anl
    ${REMOVE} advModel.sed gsiparm.anl.head

    rm -f ${ENKFDIR}/gsi*/gsi_done*

   ################### SET UP GSI-BATCH JOB   #########################
   echo "#\!/bin/csh"                                                          >! ${ENKFDIR}/run_gsi_mem.job
   echo "#=================================================================="  >> ${ENKFDIR}/run_gsi_mem.job
   echo '#SBATCH' "-J run_gsi_mem"                                             >> ${ENKFDIR}/run_gsi_mem.job
   echo '#SBATCH' "-o ${ENKFDIR}/run_gsi\%a.log"                               >> ${ENKFDIR}/run_gsi_mem.job
   echo '#SBATCH' "-e ${ENKFDIR}/run_gsi\%a.err"                               >> ${ENKFDIR}/run_gsi_mem.job
   echo '#SBATCH' "-p batch"                                                   >> ${ENKFDIR}/run_gsi_mem.job
   echo '#SBATCH' "--mem-per-cpu=24G"                                           >> ${ENKFDIR}/run_gsi_mem.job
   echo '#SBATCH' "-n ${GSI_CORES}"                                            >> ${ENKFDIR}/run_gsi_mem.job
   echo '#SBATCH -t 0:30:00'                                                   >> ${ENKFDIR}/run_gsi_mem.job
   echo "#=================================================================="  >> ${ENKFDIR}/run_gsi_mem.job

   cat >> ${ENKFDIR}/run_gsi_mem.job << EOF

   module load compiler
   module load mkl/latest
   module load hmpt/2.27

   source ${ENVFILE}

   #CREATE DIRECTORIES AND COPY IN REQUIRED FILES
   echo " Create working directory:" ${ENKFDIR}/gsi\${SLURM_ARRAY_TASK_ID}
   if ( -d "${ENKFDIR}/gsi\${SLURM_ARRAY_TASK_ID}" ) then
      rm -rf ${ENKFDIR}/gsi\${SLURM_ARRAY_TASK_ID}
   endif
   mkdir -p ${ENKFDIR}/gsi\${SLURM_ARRAY_TASK_ID}
   cd ${ENKFDIR}/gsi\${SLURM_ARRAY_TASK_ID}

   #ln -sf ${RUNDIR}/GSI_RUN/gsi.exe .
   ln -sf ${ENKFDIR}/wrfinput_d01.\${SLURM_ARRAY_TASK_ID} ./wrf_inout
   /bin/cp -pv ${ENKFDIR}/gsiparm.anl ./gsiparm.anl

   #observation files
   /bin/cp -pv ${ENKFDIR}/goes.nc ./goes.nc
   /bin/cp -pv ${ENKFDIR}/dbzobs.nc  ./dbzobs.nc
   /bin/cp -pv ${ENKFDIR}/vrobs.nc  ./vrobs.nc
   /bin/cp -pv ${ENKFDIR}/cwpobs.nc  ./cwpobs.nc
   /bin/cp -pv ${ENKFDIR}/goes_amv.nc ./goes_amv.nc
   /bin/cp -pv ${ENKFDIR}/okmeso.mdf    ./okmeso.mdf
   /bin/cp -pv ${ENKFDIR}/prepbufr ./prepbufr
   /bin/cp -pv ${ENKFDIR}/dlbufr ./dlbufr
   /bin/cp -pv ${ENKFDIR}/aeribufr ./aeribufr
   /bin/cp -pv ${ENKFDIR}/fedobs.nc  ./fedobs.nc
   /bin/cp -pv ${ENKFDIR}/uasobs.nc ./uasobs.nc
   /bin/cp -pv ${OBSDIR}/geoinfo.csv ./

   #fixed files
   echo " Copy fixed files and link CRTM coefficient files to working directory"
   /bin/cp -pv $ANAVINFO ./anavinfo
   /bin/cp -pv $BERROR   ./berror_stats
   /bin/cp -pv $SATANGL  ./satbias_angle
   /bin/cp -pv $SATINFO  ./satinfo
   /bin/cp -pv $CONVINFO ./convinfo
   /bin/cp -pv $OZINFO   ./ozinfo
   /bin/cp -pv $PCPINFO  ./pcpinfo
   /bin/cp -pv $OBERROR  ./errtable
   /bin/cp -pv ${SATBIASING} ./satbias_in
   #ln -sf ${CRTM_DIR}/EmisCoeff.bin .
   ln -sf ${CRTM_DIR}/AerosolCoeff.bin .
   ln -sf ${CRTM_DIR}/CloudCoeff.bin .
   ln -sf ${CRTM_DIR}/NPOESS.* .
   ln -sf ${CRTM_DIR}/USGS.* .
   ln -sf ${CRTM_DIR}/FAST* .
   ln -sf ${CRTM_DIR}/MWwaterLUT.bin .
   ln -sf ${CRTM_DIR}/Nalli.IRwater.EmisCoeff.bin .
   ln -sf ${CRTM_DIR}/WuSmith.IRwater.EmisCoeff.bin .
   ln -sf ${CRTM_DIR}/abi* .

   #/bin/cp -p ${GSIDIR}/util/Analysis_Utilities/read_diag/histo_adj_radiance.exe ./
   #/bin/cp -p ${GSIDIR}/util/Analysis_Utilities/read_diag/namelist.adj ./

   sleep 1
   srun --mpi=pmi2 ${RUNDIR}/GSI_RUN/gsi.exe > ${ENKFDIR}/run_gsi.mem\${SLURM_ARRAY_TASK_ID}_${datea}.log
   sleep 1

   if ( ${goesyes} == 1) then
     cp ./bias_info ${RESULTSDIR}/stdout/bias_info.${datea}.\${SLURM_ARRAY_TASK_ID}
     cat pe*abi_g16_01* > ./diag_abi_g16_ges.temp
     #sleep 1
     #srun -n 1 ./histo_adj_radiance.exe > ${ENKFDIR}/run_histomatch.mem\${SLURM_ARRAY_TASK_ID}_${datea}.log
   endif

   sleep 1

   touch gsi_done\${SLURM_ARRAY_TASK_ID}

   exit 0

EOF

    #SUBMIT ALL MEMBERS AT ONCE
    sbatch --array=1-${ENS_SIZE} run_gsi_mem.job

    ## CHECK TO SEE IF ALL MEMBERS HAVE FINISHED
    set imem = 1
    while ( ${imem} <= ${ENS_SIZE} )
    set mem=${imem}
    if ( ${imem} < 100 ) then
      set mem=0${imem}
    endif
    if ( ${imem} < 10 ) then
      set mem=00${imem}
    endif

    echo "WAITING FOR GSI MEMBER "${imem}" TO FINISH"
    while ( ! -e  ${ENKFDIR}/gsi${imem}/gsi_done${imem} )
        if ( -e ${ENKFDIR}/gsi${imem}/core ) then
            echo "GSI FOR MEMBER "${imem}" FAILED...STOPPING"
            exit(0)
        endif
        sleep 3
    end

    # MOVE Files
    cat ${ENKFDIR}/gsi${imem}/pe*conv_01* > ${ENKFDIR}/diag_conv_ges.mem${mem}
    if ( ${goesyes} == 1) then
        mv ${ENKFDIR}/gsi${imem}/diag_abi_g16_ges.temp ${ENKFDIR}/diag_abi_g16_ges.mem${mem}
    #mv ${ENKFDIR}/gsi${imem}/ADJ_CDF_WV.txt ${RESULTSDIR}/stdout/ADJ_CDF_WV.${datea}_${mem}.txt
    endif
    @ imem++
   end

   ${REMOVE} ${ENKFDIR}/gsi*/pe*

   # CALCULATE MEAN PRIOR INNOVATION FILE
   cd ${ENKFDIR}
   ${COPY} ${execdir}/innov_mean_conv.exe ${ENKFDIR}/innov_mean_conv.exe
   ${COPY} ${execdir}/innov_mean_radiance.exe ${ENKFDIR}/innov_mean_radiance.exe
   ${COPY} ${SCRIPTDIR}/run_diagmean.job ${ENKFDIR}/run_diagmean.job
   ${COPY} ${SCRIPTDIR}/run_diagmean_rad.job ${ENKFDIR}/run_diagmean_rad.job

    ${REMOVE} advModel.sed namelist.innov
    cat >! advModel.sed << EOF
 /nmem/c\
 nmem  = ${ENS_SIZE},
EOF

# The EOF on the line above MUST REMAIN in column 1.
   sed -f advModel.sed ${TEMPLATE_DIR}/namelist.innov.template >! ${ENKFDIR}/namelist.innov
   sed -f advModel.sed ${TEMPLATE_DIR}/namelist.innov.rad.template.g16 >! ${ENKFDIR}/namelist.innov.rad

   #CONVENTIONAL
   sbatch run_diagmean.job
   echo "WAITING FOR DIAG MEAN CONV TO FINISH"
   while ( ! -e ${ENKFDIR}/diagmean_done )
       sleep 2
   end

    #RADIANCES
    if ( -e  ${ENKFDIR}/diag_abi_g16_ges.mem001 ) then
        sbatch run_diagmean_rad.job
        echo "WAITING FOR DIAG MEAN-RAD CONV TO FINISH"
        while ( ! -e ${ENKFDIR}/diagmeanrad_done )
            sleep 2
        end
    endif

    # CLEAN UP THINGS
    #${REMOVE} ${ENKFDIR}/gsi*/*err
    ${REMOVE} ${ENKFDIR}/gsi*/*done*
    ${MOVE} ${ENKFDIR}/run_gsi.mem*log* ${RESULTSDIR}/stdout
    ${MOVE} ${ENKFDIR}/run_gsi.mem*err* ${RESULTSDIR}/stdout
    #${MOVE} ${ENKFDIR}/run_histomatch.mem*log* ${RESULTSDIR}/stdout
    #${REMOVE} ${ENKFDIR}/*log
    ${REMOVE} ${ENKFDIR}/advModel.sed

    sleep 1

########################### PERFORM ENKF DA ##############################

    # COPY OVER FIRST GUESS BIAS ADJUSTMENT FILE FOR ENKF...first cycle only
    if ( ${datea} == ${runDay}${cycle_start}00 ) then
      ${COPY} ${SATBIASINE} ${ENKFDIR}/satbias_in
    endif

    set lastpath=`pwd`
    cd ${ENKFDIR}
    echo "running EnKF"
    echo "#\!/bin/csh"                                                          >! ${ENKFDIR}/runenkf.job
    echo "#=================================================================="  >> ${ENKFDIR}/runenkf.job
    echo '#SBATCH' "-J runenkf"                                                 >> ${ENKFDIR}/runenkf.job
    echo '#SBATCH' "-o ${ENKFDIR}/runenkf.log.${thisstart}"                     >> ${ENKFDIR}/runenkf.job
    echo '#SBATCH' "-e ${ENKFDIR}/runenkf.err.${thisstart}"                     >> ${ENKFDIR}/runenkf.job
     echo '#SBATCH' "-p batch"                                                   >> ${ENKFDIR}/runenkf.job
     echo '#SBATCH' "--exclusive"                                                >> ${ENKFDIR}/runenkf.job
    echo '#SBATCH' "-n ${EKF_CORES}"                                            >> ${ENKFDIR}/runenkf.job
    echo '#SBATCH' "-t 0:30:00"                                                 >> ${ENKFDIR}/runenkf.job
    echo "#=================================================================="  >> ${ENKFDIR}/runenkf.job

    cat >> ${ENKFDIR}/runenkf.job << EOF

     module load compiler
     module load mkl/latest
     module load hmpt/2.27

     source ${ENVFILE}
     set echo

     setenv OMP_NUM_THREADS 1

     srun --mpi=pmi2 ${RUNDIR}/GSI_RUN/wrf_enkf

     sleep 1

     if ( -e ${ENKFDIR}/allobs_enkf) then
        touch ${ENKFDIR}/enkf_done
     endif

     exit 0
EOF

   # SUBMIT ENKF
   sbatch ${ENKFDIR}/runenkf.job
   sleep 1

    echo "WAITING FOR ENKF TO FINISH, ${ENKFDIR}/enkf_done"
    while ( ! -e ${ENKFDIR}/enkf_done )
        sleep 5
        if ( -e ${ENKFDIR}/core ) then
           echo "ENKF FAILED....RETRYING "${datea}
           rm -f ${ENKFDIR}/core
           #rm -f ${ENKFDIR}/enkf_done
           sbatch ${ENKFDIR}/runenkf.job
        endif
    end

    #if ( ! -e ${ENKFDIR}/allobs_enkf ) then
       #rm -f ${ENKFDIR}/enkf_done
       #sbatch ${ENKFDIR}/runenkf.job
       #while ( ! -e ${ENKFDIR}/enkf_done )
             #echo "WAITING FOR ENKF TO FINISH"
          #sleep 5
          #if ( -e ${ENKFDIR}/core ) then
           #echo "ENKF FAILED....RETRYING "${datea}
           #rm -f ${ENKFDIR}/core
           #rm -f ${ENKFDIR}/enkf_done
           #sbatch ${ENKFDIR}/runenkf.job
          #endif
       #end
    #endif

    # CLEAN UP THINGS
    #${REMOVE} *err
    ${REMOVE} *done
    ${REMOVE} *job
    ${REMOVE} enkf.nml.temp enkf.sed
    ${MOVE} *log* ${RESULTSDIR}/stdout
    ${MOVE} *err* ${RESULTSDIR}/stdout

    # SAVE ENKF OBS OUTPUT FILE
    ${MOVE} ${ENKFDIR}/allobs_enkf ${RESULTSDIR}/allobs_enkf_d${DOMAIN}.${thisstart}

    # SAVE DIAG FILES FOR THIS DOMAIN
    ${MOVE} ${ENKFDIR}/diag* ${RUNDIR}/${thisstart}/diag_${DOMAIN}

    # SAVE wrfinputs for forecast start
    ${MOVE} ${ENKFDIR}/wrfinput_d01.? ${RUNDIR}/${thisstart}
    ${MOVE} ${ENKFDIR}/wrfinput_d01.?? ${RUNDIR}/${thisstart}

    sleep 1

##### GENERATE FLAG TO TELL FORECASTS ITS OK TO START
    touch ${FCST_DIR}/analysis_${datea}_done

    touch ${SEMA4}/done.filter_${datea}
    echo "Waiting for WRFHYBRID"
    while ( ! -e ${SEMA4}/done.hybrid_${datea} )
        sleep 10
    end

###### APPLY ADDITIVE NOISE AND ADVANCE ENSEMBLE MEMBERS
# SET ADDITIVE NOISE FLAG TO FALSE FOR FIRST CYELE
     set noise_flag = 1
     if ( ${starthour}${startmin} == ${cycle_start}00 ) then
        set noise_flag = 0
     endif

     echo "#\!/bin/csh"                                                       >! ${RUNDIR}/adv_wrf_mem.job
     echo "#=================================================================="  >> ${RUNDIR}/adv_wrf_mem.job
     echo '#SBATCH' "-J adv_wrf_mem"                                             >> ${RUNDIR}/adv_wrf_mem.job
     echo '#SBATCH' "-o ${RUNDIR}/adv_wrf_mem\%a.log"                            >> ${RUNDIR}/adv_wrf_mem.job
     echo '#SBATCH' "-e ${RUNDIR}/adv_wrf_mem\%a.err"                            >> ${RUNDIR}/adv_wrf_mem.job
     echo '#SBATCH' "-p batch"                                                   >> ${RUNDIR}/adv_wrf_mem.job
     echo '#SBATCH' "--mem-per-cpu=5G"                                           >> ${RUNDIR}/adv_wrf_mem.job
     echo '#SBATCH' "-n ${WRF_CORES}"                                            >> ${RUNDIR}/adv_wrf_mem.job
     echo '#SBATCH' "-t 1:00:00"                                                 >> ${RUNDIR}/adv_wrf_mem.job
     echo "#=================================================================="  >> ${RUNDIR}/adv_wrf_mem.job

     cat >> ${RUNDIR}/adv_wrf_mem.job << EOF

     module load compiler
     module load mkl/latest
     module load hmpt/2.27

     #setenv  PATH ./:/bin:/scratch/software/intel/netcdf/bin:/scratch/software/miniconda3/bin:$PATH
     setenv LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:/scratch/software/intel/netcdf/lib:/scratch/software/intel/hdf5/lib:/scratch/software/intel/grib2/libpng/lib:/scratch/software/intel/grib2/zlib/lib:/scratch/software/miniconda3/lib:/usr/lib64

     source ${ENVFILE}
     set echo

     setenv OMP_NUM_THREADS 1

     if ( -d "${RUNDIR}/enkfrun\${SLURM_ARRAY_TASK_ID}" ) then
        ${REMOVEDIR} ${RUNDIR}/enkfrun\${SLURM_ARRAY_TASK_ID}
     endif

     mkdir ${RUNDIR}/enkfrun\${SLURM_ARRAY_TASK_ID}
     cd ${RUNDIR}/enkfrun\${SLURM_ARRAY_TASK_ID}

     ${SCRIPTDIR}/runwrf_conv.csh \${SLURM_ARRAY_TASK_ID} ${thisstart} ${thisend} ${ENVFILE}
     cp -f ${TEMPLATE_DIR}/input.nml.conv1 ./input.nml
     cp -f ${ADDNOISEDIR}/add_pert_where_high_refl.exe ./add_pert_where_high_refl.exe
     cp -f ${ENKFDIR}/refl_obs.txt ./refl_obs.txt

     if ( ${noise_flag} == 1 ) then
        srun -n 1 ./add_pert_where_high_refl.exe refl_obs.txt wrfinput_d01 $lh $lv $u_sd $v_sd $w_sd $t_sd $td_sd $qv_sd ${iseed} ${iseed2} \${SLURM_ARRAY_TASK_ID}  > ./addnoise.output.\${SLURM_ARRAY_TASK_ID}
     endif

     sleep 5
     srun -n 1 ./update_wrf_bc > ./update_wrf_bc.output.\${SLURM_ARRAY_TASK_ID}
     sleep 2

     srun --mpi=pmi2 ${RUNDIR}/WRF_RUN/wrf.exe
     sleep 2

     if ( -e ${RUNDIR}/enkfrun\${SLURM_ARRAY_TASK_ID}/wrfout_d01_${endyear}-${endmonth}-${endday}_${endhour}:${endmin}:00 ) then
      ${MOVE} ${RUNDIR}/enkfrun\${SLURM_ARRAY_TASK_ID}/wrfout_d01_${startyear}-${startmonth}-${startday}_${starthour}:${startmin}:00 ${RUNDIR}/${thisstart}/wrfout_d01_${startyear}-${startmonth}-${startday}_${starthour}:${startmin}:00_\${SLURM_ARRAY_TASK_ID}
      ${COPY} ${RUNDIR}/enkfrun\${SLURM_ARRAY_TASK_ID}/wrfout_d01_${endyear}-${endmonth}-${endday}_${endhour}:${endmin}:00 ${RUNDIR}/${thisstart}/wrffcst_d01_${endyear}-${endmonth}-${endday}_${endhour}:${endmin}:00_\${SLURM_ARRAY_TASK_ID}
      ${MOVE} ${RUNDIR}/enkfrun\${SLURM_ARRAY_TASK_ID}/wrfout_d01_${endyear}-${endmonth}-${endday}_${endhour}:${endmin}:00 ${ENKFDIR}/wrfinput_d01.\${SLURM_ARRAY_TASK_ID}

      ${COPY} ${RUNDIR}/enkfrun\${SLURM_ARRAY_TASK_ID}/rsl.error.0000  ${RUNDIR}/${thisstart}/rsl.error.0000_\${SLURM_ARRAY_TASK_ID}

      sleep 1
      touch ${RUNDIR}/adv_wrf_done\${SLURM_ARRAY_TASK_ID}
     endif

     exit 0

EOF

     #SUBMIT ALL MEMBERS AT ONCE
     sbatch --array=1-${ENS_SIZE} ${RUNDIR}/adv_wrf_mem.job

## CHECK TO SEE IF ALL MEMBERS HAVE FINISHED AND MOVE FILES AROUND
     set imem = 1
     while ( ${imem} <= ${ENS_SIZE} )
        echo "WAITING FOR MEMBER "${imem}" TO FINISH, ${RUNDIR}/adv_wrf_done${imem} "
        while ( ! -e ${RUNDIR}/adv_wrf_done${imem} )
            sleep 3
        end

       ${REMOVE} enkfrun${imem}/rsl*

       @ imem++
     end

    # CLEAN UP THINGS
    ${MOVE} ${ENKFDIR}/refl_obs.txt ${RESULTSDIR}/stdout/refl_obs_${thisstart}.txt
    ${REMOVE} ${RUNDIR}/*done*
    ${REMOVE} ${RUNDIR}/*job
    ${REMOVE} ${RUNDIR}/*err
    ${REMOVE} ${ENKFDIR}/gridrefl*
    ${REMOVE} ${ENKFDIR}/nceamean01_sm.*

   echo "*** DONE ADVANCE MEMBERS"

   ### CALCULATE ENSEMBLE MEAN REFL FORECAST (use as prior mean for next cycle)
   cd ${ENKFDIR}
   ${REMOVE} -f ${ENKFDIR}/wrfinput_d01*ensmean
   ${COPY} ${SCRIPTDIR}/run_nceamean_conv_d01.job .
   sbatch run_nceamean_conv_d01.job

   while ( ! -e ${ENKFDIR}/ensmean_done01 )
     echo "WAITING FOR ENSEMBLE MEAN TO FINISH"
     sleep 3
   end
   ${REMOVE} ${ENKFDIR}/ensmean_done01
   ${REMOVE} ${ENKFDIR}/nceamean01.*

   ### MOVE FILES TO RESULTS DIRECTORY
   ${MOVE} ${ENKFDIR}/diag* ${RUNDIR}/${thisstart}
   #${REMOVE} ${ENKFDIR}/copy*output*
   ### KEEP VROBS FOR COMPARISON
   #${MOVE} ${ENKFDIR}/vrobs.nc ${ENKFDIR}/vrobs_mask_${thisstart}.nc
   ${REMOVE} ${ENKFDIR}/*nc
   ${REMOVE} ${ENKFDIR}/*mdf
   ${REMOVE} ${ENKFDIR}/*bufr

   grep cfl ${RUNDIR}/enkfrun*/rsl* > ${RUNDIR}/cfl.log.${thisstart}

   # Advance to the next time if this is not the final time
    if ( $datea == $datef ) then
        echo "Script exiting normally"
        break
     else
        set datea  =  `echo  ${datea} ${cycleinterval}m | ${RUNDIR}/advance_time`
        echo "Starting next time ${datea} => "
        echo " "
     endif

     #if ( $datea > 202004191700 ) then
         #sleep 300
     #endif

end    # END CYCLE WHILE LOOP

# CLEAN UP AND MOVE FINAL THINGS
exit 0
