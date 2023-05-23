#!/bin/csh
#

source ${ENVDIR}/WOFenv_rlt_2021
source ${TOP_DIR}/realtime.cfg.${event}

if ( -e ${SCRIPTDIR}/WOFS_grid_radar/radars.${event}.csh ) then
   source ${SCRIPTDIR}/WOFS_grid_radar/radars.${event}.csh
else
   echo "Cannot find ${SCRIPTDIR}/WOFS_grid_radar/radars.${event}.csh"
   exit 0
endif

###
set echo on
###

cd ${RUNDIR}
### First. remove residual files from last run:
rm -fr mem*
rm -f ungrib_bc1_mem.csh metgrid_bc1_mem.csh
rm -f ${SEMA4}/geogrid_done
rm -f ${SEMA4}/ungrib_bc1_mem*_done
rm -f ${SEMA4}/metgrid_bc1_mem*_done
###

if ( ! -e ${RUNDIR}/geo_em.d01.nc ) then

   cp ${TEMPLATE_DIR}/namelist.wps.template.HRRRE .

   if ( -e namelist.wps ) rm -f namelist.wps

   ############################################
   ### Set up WPS namelist for geogrid
   ############################################

   set startdate = " start_date = '${sdate1_12}', '${sdate1_12}',"
   set enddate = " end_date = '${edate1_12}', '${edate1_12}',"

   echo "&share" > namelist.wps
   echo " wrf_core = 'ARW'," >> namelist.wps
   echo " max_dom = ${domains}," >> namelist.wps
   echo ${startdate} >> namelist.wps
   echo ${enddate} >> namelist.wps
   echo " interval_seconds = 3600" >> namelist.wps
   echo " io_form_geogrid = 2," >> namelist.wps
   echo "/" >> namelist.wps

   echo "&geogrid" >> namelist.wps
   echo " parent_id         = 1,  1," >> namelist.wps
   echo " parent_grid_ratio = 1,  3," >> namelist.wps
   echo " i_parent_start    = 1,  80," >> namelist.wps
   echo " j_parent_start    = 1,  77," >> namelist.wps
   echo " e_we              = ${grdpts_ew},  226," >> namelist.wps
   echo " e_sn              = ${grdpts_ns},  226," >> namelist.wps

   echo " geog_data_res     = 'modis_lakes+15s+modis_fpar+modis_lai+30s', 'modis_15s_lakes+modis_fpar+modis_lai+30s'," >> namelist.wps

   echo " dx = 3000," >> namelist.wps
   echo " dy = 3000," >> namelist.wps
   echo " map_proj = 'lambert'," >> namelist.wps
   echo " ref_lat   =  ${cen_lat}," >> namelist.wps
   echo " ref_lon   =  ${cen_lon}," >> namelist.wps
   echo " truelat1  =  30.00," >> namelist.wps
   echo " truelat2  =  60.00," >> namelist.wps
   echo " stand_lon =  ${cen_lon}," >> namelist.wps
   echo " geog_data_path = '/scratch/wof/realtime/geog'" >> namelist.wps
   echo " opt_geogrid_tbl_path = '${TEMPLATE_DIR}'" >> namelist.wps
   echo "/" >> namelist.wps

   cat namelist.wps.template.HRRRE >> namelist.wps

   ###########################################################################
   # GEOGRID
   ###########################################################################
   echo "Created namelist.wps, running geogrid.exe"

   echo "#\!/bin/csh"                                                            >! ${RUNDIR}/geogrid.csh
   echo "#=================================================================="    >> ${RUNDIR}/geogrid.csh
   echo '#SBATCH' "-J geogrid"                                                   >> ${RUNDIR}/geogrid.csh
   echo '#SBATCH' "-o ${RUNDIR}/geogrid.log"                                     >> ${RUNDIR}/geogrid.csh
   echo '#SBATCH' "-e ${RUNDIR}/geogrid.err"                                     >> ${RUNDIR}/geogrid.csh
   echo '#SBATCH' "-A largequeue"                                                >> ${RUNDIR}/geogrid.csh
   echo '#SBATCH' "-p workq"                                                     >> ${RUNDIR}/geogrid.csh
   echo '#SBATCH' "--ntasks-per-node=24"                                         >> ${RUNDIR}/geogrid.csh
   echo '#SBATCH' "-n 24"                                                        >> ${RUNDIR}/geogrid.csh
   echo '#SBATCH' '-t 0:10:00'                                                   >> ${RUNDIR}/geogrid.csh
   echo "#=================================================================="    >> ${RUNDIR}/geogrid.csh

   cat >> ${RUNDIR}/geogrid.csh << EOF

   set echo

   source ${ENVDIR}/WOFenv_rlt_2021

   cd \${SLURM_SUBMIT_DIR}

   setenv MPICH_VERSION_DISPLAY 1
   setenv MPICH_ENV_DISPLAY 1
   setenv MPICH_MPIIO_HINTS_DISPLAY 1
   setenv MPICH_GNI_RDMA_THRESHOLD 2048
   setenv MPICH_GNI_DYNAMIC_CONN disabled

   setenv OMP_NUM_THREADS 1

   srun ${RUNDIR}/WRF_RUN/geogrid.exe

   touch ${SEMA4}/geogrid_done

EOF

  chmod +x geogrid.csh
  sbatch ${RUNDIR}/geogrid.csh

  while (! -e ${SEMA4}/geogrid_done)
        sleep 5
  end

endif

############################
# UNGRIB HRRRE ENSEMBLE DATA
############################

set n = 1
while ( $n <= $ENS_SIZE )

      rm -rf mem$n

      mkdir mem$n

      if ( $n <= $HRRRE_BCS ) then

         cd mem$n

         if ( -e namelist.wps ) rm -f namelist.wps

         set startdate = " start_date = '${sdate1_12}', '${sdate1_12}',"
         set enddate = " end_date = '${edate1_12}', '${edate1_12}',"

         echo $startdate
         echo $enddate

         cp ${TEMPLATE_DIR}/namelist.wps.template.HRRRE .

        echo "&share" > namelist.wps
        echo " wrf_core = 'ARW'," >> namelist.wps
        echo " max_dom = ${domains}," >> namelist.wps
        echo ${startdate} >> namelist.wps
        echo ${enddate} >> namelist.wps
        echo " interval_seconds = 3600" >> namelist.wps
        echo " io_form_geogrid = 2," >> namelist.wps
        echo "/" >> namelist.wps

        echo "&geogrid" >> namelist.wps
        echo " parent_id         = 1,  1," >> namelist.wps
        echo " parent_grid_ratio = 1,  3," >> namelist.wps
        echo " i_parent_start    = 1,  80," >> namelist.wps
        echo " j_parent_start    = 1,  77," >> namelist.wps
        echo " e_we              = ${grdpts_ew},  226," >> namelist.wps
        echo " e_sn              = ${grdpts_ns},  226," >> namelist.wps

        echo " geog_data_res     = 'modis_lakes+15s+modis_fpar+modis_lai+30s', 'modis_15s_lakes+modis_fpar+modis_lai+30s'," >> namelist.wps

        echo " dx = 3000," >> namelist.wps
        echo " dy = 3000," >> namelist.wps
        echo " map_proj = 'lambert'," >> namelist.wps
        echo " ref_lat   =  ${cen_lat}," >> namelist.wps
        echo " ref_lon   =  ${cen_lon}," >> namelist.wps
        echo " truelat1  =  30.00," >> namelist.wps
        echo " truelat2  =  60.00," >> namelist.wps
        echo " stand_lon =  ${cen_lon}," >> namelist.wps
        echo " geog_data_path = '/oldscratch/wof/MODEL_DATA/geog'" >> namelist.wps
        echo " opt_geogrid_tbl_path = '${TEMPLATE_DIR}'" >> namelist.wps
        echo "/" >> namelist.wps

        cat namelist.wps.template.HRRRE >> namelist.wps

        ln -sf ${TEMPLATE_DIR}/Vtable.HRRRE.2018 ./Vtable

        if ( $cycle_start == 00 ) then
           # 0000 UTC START
           # 0000 UTC HRRRE FORECAST
           ${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/0000/postprd_mem000$n/wrfnat_mem000${n}_0[0-9].grib2 ${HRRRE_DIR}/${event}/0000/postprd_mem000$n/wrfnat_mem000${n}_1[0-1].grib2  .
        endif

        if ( $cycle_start == 12 ) then
            # 1200 UTC START
            # 1200 UTC HRRRE FORECAST
            ${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_mem000${n}_0[0-9].grib2 ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_mem000${n}_1[0-2].grib2 .
        endif

        if ( ( $cycle_start == 15 ) || ( $cycle_start == 18 ) ) then
           # 1500 OR 1700 UTC START
           # 1200 UTC HRRRE FORECAST
           #${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_mem000${n}_0[3-9].grib2 ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_mem000${n}_1[0-1].grib2 ${HRRRE_DIR}/${nxtDay}/0000/postprd_mem000$n/wrfnat_mem000${n}_0[0-6].grib2 .

           #echo "${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_pert_hrrr_mem000${n}_0[3-9].grib2"
           #echo "${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_pert_hrrr_mem000${n}_1[0-4].grib2"
           ${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_pert_hrrr_mem000${n}_0[3-9].grib2 ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_pert_hrrr_mem000${n}_1[0-4].grib2 .

           ### NEW LBCs
           #if ( ${n} <= 9 ) then
           #   ${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_pert_hrrr_mem000${n}_0[3-9].grib2 ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_pert_hrrr_mem000${n}_1[0-4].grib2 .
           #else
           #   ${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/1200/postprd_mem00$n/wrfnat_pert_hrrr_mem00${n}_0[3-9].grib2 ${HRRRE_DIR}/${event}/1200/postprd_mem00$n/wrfnat_pert_hrrr_mem00${n}_1[0-4].grib2 .
           #endif
           ### END NEW LBCs

           #${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_mem000${n}_0[3-9].grib2 ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_mem000${n}_1[0-1].grib2 .

           #${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/0600/postprd_mem000$n/wrfnat_mem000${n}_0[6-9].grib2 ${HRRRE_DIR}/${event}/0600/postprd_mem000$n/wrfnat_mem000${n}_1[0-9].grib2 ${HRRRE_DIR}/${event}/0600/postprd_mem000$n/wrfnat_mem000${n}_20.grib2 .
        endif

        #if ( $cycle_start == 18 ) then
           # 1800 UTC START
           # 1200 UTC HRRRE FORECAST
        #   ${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_mem000${n}_0[6-9].grib2 ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_mem000${n}_1[0-1].grib2 .
        #endif

        if ( $cycle_start == 21 ) then
           # 2100 UTC START
           # 1200 UTC HRRRE FORECAST
           ${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_mem000${n}_09.grib2 ${HRRRE_DIR}/${event}/1200/postprd_mem000$n/wrfnat_mem000${n}_1[0-4].grib2 .
        endif

        echo "Linked HRRRE grib files for member " $n

        @ n++

        cd ..

      else

        @ n++

      endif
     end

     echo "#\!/bin/csh"                                                           >! ${RUNDIR}/ungrib_bc1_mem.csh
     echo "#=================================================================="   >> ${RUNDIR}/ungrib_bc1_mem.csh
     echo '#SBATCH' "-J ungrib_bc1_mem"                                           >> ${RUNDIR}/ungrib_bc1_mem.csh
     echo '#SBATCH' "-o ${RUNDIR}/mem\%a/ungrib_bc1_mem\%a.log"                   >> ${RUNDIR}/ungrib_bc1_mem.csh
     echo '#SBATCH' "-e ${RUNDIR}/mem\%a/ungrib_bc1_mem\%a.err"                   >> ${RUNDIR}/ungrib_bc1_mem.csh
     echo '#SBATCH' "-A largequeue"                                               >> ${RUNDIR}/ungrib_bc1_mem.csh
     echo '#SBATCH' "-p workq"                                                    >> ${RUNDIR}/ungrib_bc1_mem.csh
     echo '#SBATCH' "--ntasks-per-node=1"                                         >> ${RUNDIR}/ungrib_bc1_mem.csh
     echo '#SBATCH' "-n 1"                                                        >> ${RUNDIR}/ungrib_bc1_mem.csh
     echo '#SBATCH -t 0:45:00'                                                    >> ${RUNDIR}/ungrib_bc1_mem.csh
     echo "#=================================================================="   >> ${RUNDIR}/ungrib_bc1_mem.csh

     cat >> ${RUNDIR}/ungrib_bc1_mem.csh << EOF

     set echo

     source ${ENVDIR}/WOFenv_rlt_2021

     setenv MPICH_VERSION_DISPLAY 1
     setenv MPICH_ENV_DISPLAY 1
     setenv MPICH_MPIIO_HINTS_DISPLAY 1

     setenv MPICH_GNI_RDMA_THRESHOLD 2048
     setenv MPICH_GNI_DYNAMIC_CONN disabled

     setenv MPICH_CPUMASK_DISPLAY 1
     setenv OMP_NUM_THREADS 1

     cd ${RUNDIR}/mem\${SLURM_ARRAY_TASK_ID}

     srun ${RUNDIR}/WRF_RUN/ungrib.exe

     sleep 1

     touch ${SEMA4}/ungrib_bc1_mem\${SLURM_ARRAY_TASK_ID}_done

EOF

     sbatch --array=1-${HRRRE_BCS} ${RUNDIR}/ungrib_bc1_mem.csh

     while ( `ls -f ${SEMA4}/ungrib_bc1_mem*_done | wc -l` != $HRRRE_BCS )

           echo "Waiting for ungribbing of GSD HRRRE Part 1 Files"
           sleep 5

     end


###########################################################################
# METGRID FOR ALL HRRRE MEMBERS
###########################################################################

set n = 1
while ( $n <= $HRRRE_BCS )

      cd mem${n}

      ln -sf ${RUNDIR}/geo_em.d01.nc ./geo_em.d01.nc

      @ n++

      cd ..

end

echo "#\!/bin/csh"                                                           >! ${RUNDIR}/metgrid_bc1_mem.csh
echo "#=================================================================="   >> ${RUNDIR}/metgrid_bc1_mem.csh
echo '#SBATCH' "-J metgrid_bc1_mem"                                          >> ${RUNDIR}/metgrid_bc1_mem.csh
echo '#SBATCH' "-o ${RUNDIR}/mem\%a/metgrid_bc1_mem\%a.log"                  >> ${RUNDIR}/metgrid_bc1_mem.csh
echo '#SBATCH' "-e ${RUNDIR}/mem\%a/metgrid_bc1_mem\%a.err"                  >> ${RUNDIR}/metgrid_bc1_mem.csh
echo '#SBATCH' "-A largequeue"                                               >> ${RUNDIR}/metgrid_bc1_mem.csh
echo '#SBATCH' "-p workq"                                                    >> ${RUNDIR}/metgrid_bc1_mem.csh
echo '#SBATCH' "--ntasks-per-node=24"                                        >> ${RUNDIR}/metgrid_bc1_mem.csh
echo '#SBATCH' "-n 48"                                                       >> ${RUNDIR}/metgrid_bc1_mem.csh
echo '#SBATCH -t 0:45:00'                                                    >> ${RUNDIR}/metgrid_bc1_mem.csh
echo "#=================================================================="   >> ${RUNDIR}/metgrid_bc1_mem.csh

      cat >> ${RUNDIR}/metgrid_bc1_mem.csh << EOF

      set echo

      source ${ENVDIR}/WOFenv_rlt_2021

      setenv MPICH_VERSION_DISPLAY 1
      setenv MPICH_ENV_DISPLAY 1
      setenv MPICH_MPIIO_HINTS_DISPLAY 1
      setenv MPICH_GNI_RDMA_THRESHOLD 2048
      setenv MPICH_GNI_DYNAMIC_CONN disabled

      setenv OMP_NUM_THREADS 1

      cd ${RUNDIR}/mem\${SLURM_ARRAY_TASK_ID}

      srun ${RUNDIR}/WRF_RUN/metgrid.exe

      sleep 1

      touch ${SEMA4}/metgrid_bc1_mem\${SLURM_ARRAY_TASK_ID}_done

EOF

sbatch --array=1-${HRRRE_BCS} ${RUNDIR}/metgrid_bc1_mem.csh


while ( `ls -f  ${SEMA4}/metgrid_bc1_mem*_done | wc -l` != $HRRRE_BCS )

       echo "Waiting for metgrid to finish for $HRRRE_BCS members"
       sleep 5

end

echo "WPS is complete"

rm geogrid.log geogrid.err geogrid.csh ungrib_bc1_mem.csh metgrid_bc1_mem.csh

rm -fr mem*/GRIBFILE* mem*/HRRRE* mem*/metgrid.log*

###########################################################################
exit (0)
###########################################################################
