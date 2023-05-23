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
rm -f geogrid.log.00*
rm -f geogrid.log
rm -f ${SEMA4}/geogrid_done
rm -f ${SEMA4}/ungrib_mem*_done
rm -f ${SEMA4}/metgrid_mem*_done
###

############################
# UNGRIB HRRRE ICs DATA
############################

set n = 1
@ count = 1
while ( $n <= $ENS_SIZE )

      mkdir ic$n

      cd ic$n

      if ( -e namelist.wps ) rm -f namelist.wps

      set startdate = " start_date = '${sdate3}', '${sdate3}',"
      set enddate = " end_date = '${edate3}', '${edate3}',"

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
      echo " geog_data_path = '/scratch/wof/MODEL_DATA/geog'" >> namelist.wps
      echo " opt_geogrid_tbl_path = '${TEMPLATE_DIR}'" >> namelist.wps
      echo "/" >> namelist.wps

      cat namelist.wps.template.HRRRE >> namelist.wps

      ln -sf ${TEMPLATE_DIR}/Vtable.HRRRE.2018 ./Vtable

      @ anlys_hr = ${start_hr} - 1

      if ( $n <= $HRRRE_BCS ) then
         #${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/20200204/2300/postprd_mem000$n/wrfnat_hrrre_newse_mem000${n}_01.grib2 .
         ${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/${anlys_hr}00/postprd_mem000$n/wrfnat_hrrre_newse_mem000${n}_01.grib2 .
      else
        if ( $n <= 36 ) then
            #${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/20200204/2300/postprd_mem00$n/wrfnat_hrrre_newse_mem00${n}_01.grib2 .
            ${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/${anlys_hr}00/postprd_mem00$n/wrfnat_hrrre_newse_mem00${n}_01.grib2 .
        else
           @ n2 = ${n} - ${count}
           if ( $n2 > $HRRRE_BCS ) then
               ${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/${anlys_hr}00/postprd_mem00$n2/wrfnat_hrrre_newse_mem00${n2}_01.grib2 .
           else
               ${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/${anlys_hr}00/postprd_mem000$n2/wrfnat_hrrre_newse_mem000${n2}_01.grib2 .
           endif
           @ count = ${count} + 2
           #${RUNDIR}/WRF_RUN/link_grib.csh ${HRRRE_DIR}/${event}/1700/postprd_mem00$n/wrfnat_mem00${n}_00.grib2 .
        endif
      endif

      echo "Linked HRRRE grib files for member " $n

      @ n++

      cd ..

     end

     echo "#\!/bin/csh"                                                           >! ${RUNDIR}/ungrib_mem.csh
     echo "#=================================================================="   >> ${RUNDIR}/ungrib_mem.csh
     echo '#SBATCH' "-J ungrib_mem"                                               >> ${RUNDIR}/ungrib_mem.csh
     echo '#SBATCH' "-o ${RUNDIR}/ic\%a/ungrib_mem\%a.log"                        >> ${RUNDIR}/ungrib_mem.csh
     echo '#SBATCH' "-e ${RUNDIR}/ic\%a/ungrib_mem\%a.err"                        >> ${RUNDIR}/ungrib_mem.csh
     echo '#SBATCH' "-A largequeue"                                               >> ${RUNDIR}/ungrib_mem.csh
     echo '#SBATCH' "-p workq"                                                    >> ${RUNDIR}/ungrib_mem.csh
     echo '#SBATCH' "--ntasks-per-node=1"                                         >> ${RUNDIR}/ungrib_mem.csh
     echo '#SBATCH' "-n 1"                                                        >> ${RUNDIR}/ungrib_mem.csh
     echo '#SBATCH -t 1:00:00'                                                    >> ${RUNDIR}/ungrib_mem.csh
     echo "#=================================================================="   >> ${RUNDIR}/ungrib_mem.csh

     cat >> ${RUNDIR}/ungrib_mem.csh << EOF

     set echo

     source ${ENVDIR}/WOFenv_rlt_2021

     setenv MPICH_VERSION_DISPLAY 1
     setenv MPICH_ENV_DISPLAY 1
     setenv MPICH_MPIIO_HINTS_DISPLAY 1

     setenv MPICH_GNI_RDMA_THRESHOLD 2048
     setenv MPICH_GNI_DYNAMIC_CONN disabled

     setenv MPICH_CPUMASK_DISPLAY 1
     setenv OMP_NUM_THREADS 1

     cd ${RUNDIR}/ic\${SLURM_ARRAY_TASK_ID}

     sleep 2

     srun ${RUNDIR}/WRF_RUN/ungrib.exe

     sleep 1

     touch ${SEMA4}/ungrib_mem\${SLURM_ARRAY_TASK_ID}_done

EOF

     sbatch --array=1-${ENS_SIZE} ${RUNDIR}/ungrib_mem.csh

     while ( `ls -f ${SEMA4}/ungrib_mem*_done | wc -l` != $ENS_SIZE )

           echo "Waiting for ungribbing of GSD HRRRE Files"
           sleep 1

     end


###########################################################################
# METGRID FOR ALL HRRRE MEMBERS
###########################################################################

set n = 1
while ( $n <= $ENS_SIZE )

      cd ic${n}

      ln -sf ${RUNDIR}/geo_em.d01.nc ./geo_em.d01.nc

      @ n++

      cd ..

end

echo "#\!/bin/csh"                                                           >! ${RUNDIR}/metgrid_mem.csh
echo "#=================================================================="   >> ${RUNDIR}/metgrid_mem.csh
echo '#SBATCH' "-J metgrid_mem"                                              >> ${RUNDIR}/metgrid_mem.csh
echo '#SBATCH' "-o ${RUNDIR}/ic\%a/metgrid_mem\%a.log"                       >> ${RUNDIR}/metgrid_mem.csh
echo '#SBATCH' "-e ${RUNDIR}/ic\%a/metgrid_mem\%a.err"                       >> ${RUNDIR}/metgrid_mem.csh
echo '#SBATCH' "-A largequeue"                                               >> ${RUNDIR}/metgrid_mem.csh
echo '#SBATCH' "-p workq"                                                    >> ${RUNDIR}/metgrid_mem.csh
echo '#SBATCH' "--ntasks-per-node=24"                                        >> ${RUNDIR}/metgrid_mem.csh
echo '#SBATCH' "-n 24"                                                       >> ${RUNDIR}/metgrid_mem.csh
echo '#SBATCH -t 0:45:00'                                                    >> ${RUNDIR}/metgrid_mem.csh
echo "#=================================================================="   >> ${RUNDIR}/metgrid_mem.csh

      cat >> ${RUNDIR}/metgrid_mem.csh << EOF

      set echo

      source ${ENVDIR}/WOFenv_rlt_2021

      setenv MPICH_VERSION_DISPLAY 1
      setenv MPICH_ENV_DISPLAY 1
      setenv MPICH_MPIIO_HINTS_DISPLAY 1
      setenv MPICH_GNI_RDMA_THRESHOLD 2048
      setenv MPICH_GNI_DYNAMIC_CONN disabled

      setenv OMP_NUM_THREADS 1

      cd ${RUNDIR}/ic\${SLURM_ARRAY_TASK_ID}

      sleep 2

      srun ${RUNDIR}/WRF_RUN/metgrid.exe

      sleep 1

      rm HRRRE* GRIBFILE* metgrid.log.*

      touch ${SEMA4}/metgrid_mem\${SLURM_ARRAY_TASK_ID}_done

EOF

sbatch --array=1-${ENS_SIZE} ${RUNDIR}/metgrid_mem.csh


while ( `ls -f  ${SEMA4}/metgrid_mem*_done | wc -l` != $ENS_SIZE )

       echo "Waiting for metgrid to finish for $ENS_SIZE members"
       sleep 1

end

echo "WPS is complete"

rm ungrib_mem.csh metgrid_mem.csh

###########################################################################
exit (0)
###########################################################################
