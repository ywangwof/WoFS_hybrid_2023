#!/bin/csh
#
#-----------------------------------------------------------------------
# Script to create template wrfinput file for obs processing
#-----------------------------------------------------------------------
#
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

set nonomatch

source ${TOP_DIR}/realtime.cfg.${event}

#setenv event 20221104
#
#setenv SCRIPTDIR /scratch/ywang/NEWSVAR/news3dvar.2023/WOFS_RLT_2021
#setenv TEMPLATE_DIR /scratch/ywang/NEWSVAR/news3dvar.2023/WOFS_RLT_2021/Templates
#setenv INPUTDIR /scratch/ywang/test_runs/hyb23/wofs_run/WRFINPUTS
#setenv RUNDIR /scratch/ywang/test_runs/hyb23/wofs_run/20220217

if ( -e ${parentdir}/WOFS_grid_radar/radars.${event}.csh ) then
    source ${parentdir}/WOFS_grid_radar/radars.${event}.csh
else
    echo "file not exist: ${parentdir}/WOFS_grid_radar/radars.${event}.csh"
    exit 0
endif

#set echo

cd ${INPUTDIR}

if (! -d ${INPUTDIR}/flags) thermal
    mkdir -p ${INPUTDIR}/flags
endif

################# run geogrid.exe #########################

rm -rf ${INPUTDIR}/flags/*done

set startdate = " start_date = '"`date -d $event +%Y-%m-%d_12:00:00`"',"
set enddate = " end_date = '"`date -d $event +%Y-%m-%d_12:00:00`"',"

cp ${TEMPLATE_DIR}/namelist.wps.template.WRFINPUTS .

rm -rf namelist.wps

echo "&share" > namelist.wps
echo " wrf_core = 'ARW'," >> namelist.wps
echo " max_dom = 1," >> namelist.wps
echo ${startdate} >> namelist.wps
echo ${enddate} >> namelist.wps
echo " interval_seconds = 3600" >> namelist.wps
echo " io_form_geogrid = 2," >> namelist.wps
echo "/" >> namelist.wps

echo "&geogrid" >> namelist.wps
echo " parent_id         = 1,  1," >> namelist.wps
echo " parent_grid_ratio = 1,  5," >> namelist.wps
echo " i_parent_start    = 1,  1," >> namelist.wps
echo " j_parent_start    = 1,  1," >> namelist.wps
echo " e_we              = ${grdpts_ew},  226," >> namelist.wps
echo " e_sn              = ${grdpts_ns},  226," >> namelist.wps
echo " geog_data_res     = 'modis_lakes+15s+modis_fpar+modis_lai+30s', 'modis_lakes+15s+modis_fpar+modis_lai+30s'," >> namelist.wps
echo " dx = 3000," >> namelist.wps
echo " dy = 3000," >> namelist.wps
echo " map_proj = 'lambert'," >> namelist.wps
echo " ref_lat   =  ${cen_lat}," >> namelist.wps
echo " ref_lon   =  ${cen_lon}," >> namelist.wps
echo " truelat1  =  30.00," >> namelist.wps
echo " truelat2  =  60.00," >> namelist.wps
echo " stand_lon =  ${cen_lon}," >> namelist.wps
echo " geog_data_path = '/scratch/wofuser/realtime/geog'" >> namelist.wps
echo " opt_geogrid_tbl_path = '${TEMPLATE_DIR}'" >> namelist.wps
echo "/" >> namelist.wps


cat namelist.wps.template.WRFINPUTS >> namelist.wps

###########################################################################

echo "#\!/bin/csh"                                                          >! ${INPUTDIR}/geogrid.csh
echo "#=================================================================="  >> ${INPUTDIR}/geogrid.csh
echo '#SBATCH' "-J geogrid"                                                 >> ${INPUTDIR}/geogrid.csh
echo '#SBATCH' "-o ${INPUTDIR}/geogrid.log"                                 >> ${INPUTDIR}/geogrid.csh
echo '#SBATCH' "-e ${INPUTDIR}/geogrid.err"                                 >> ${INPUTDIR}/geogrid.csh
echo '#SBATCH' "-p batch"                                                   >> ${INPUTDIR}/geogrid.csh
echo '#SBATCH' "--ntasks-per-node=24"                                       >> ${INPUTDIR}/geogrid.csh
echo '#SBATCH' "-n 24"                                                      >> ${INPUTDIR}/geogrid.csh
echo '#SBATCH' '-t 0:10:00'                                                 >> ${INPUTDIR}/geogrid.csh
echo "#=================================================================="  >> ${INPUTDIR}/geogrid.csh

cat >> ${INPUTDIR}/geogrid.csh << EOF

set echo

cd \${SLURM_SUBMIT_DIR}

setenv MPICH_VERSION_DISPLAY 1
setenv MPICH_ENV_DISPLAY 1
setenv MPICH_MPIIO_HINTS_DISPLAY 1
setenv MPICH_GNI_RDMA_THRESHOLD 2048
setenv MPICH_GNI_DYNAMIC_CONN disabled

setenv OMP_NUM_THREADS 1

srun --mpi=pmi2 ${RUNDIR}/WRF_RUN/geogrid.exe

touch ${INPUTDIR}/flags/geogrid_done

EOF

chmod +x ${INPUTDIR}/geogrid.csh
sbatch ${INPUTDIR}/geogrid.csh

while (! -e ${INPUTDIR}/flags/geogrid_done)
    sleep 5
end

rm -f rsl.* geogrid.log*

################# run ungrib.exe #########################

${RUNDIR}/WRF_RUN/link_grib.csh /scratch/wofuser/MODEL_DATA/HRRRE/$event/1200/postprd_mem0001/wrfnat_pert_hrrr_mem0001_00.grib2

#ln -fs ${TEMPLATE_DIR}/Vtables/Vtable.RAP.full ./Vtable
ln -fs ${TEMPLATE_DIR}/Vtable.HRRRE.2018 ./Vtable
#
#
echo "#\!/bin/csh"                                                         >! ${INPUTDIR}/ungrib.csh
echo "#==================================================================" >> ${INPUTDIR}/ungrib.csh
echo '#SBATCH' "-J ungrib"                                                 >> ${INPUTDIR}/ungrib.csh
echo '#SBATCH' "-o ${INPUTDIR}/ungrib.log"                                 >> ${INPUTDIR}/ungrib.csh
echo '#SBATCH' "-e ${INPUTDIR}/ungrib.err"                                 >> ${INPUTDIR}/ungrib.csh
echo '#SBATCH' "-p batch"                                                  >> ${INPUTDIR}/ungrib.csh
echo '#SBATCH' "--exclusive"                                               >> ${INPUTDIR}/ungrib.csh
echo '#SBATCH' "-n 1"                                                      >> ${INPUTDIR}/ungrib.csh
echo '#SBATCH' '-t 0:20:00'                                                >> ${INPUTDIR}/ungrib.csh
echo "#==================================================================" >> ${INPUTDIR}/ungrib.csh

cat >> ${INPUTDIR}/ungrib.csh << EOF

set echo

cd \${SLURM_SUBMIT_DIR}

srun -n 1 ${RUNDIR}/WRF_RUN/ungrib.exe

touch ${INPUTDIR}/flags/ungrib_done

EOF

sbatch ${INPUTDIR}/ungrib.csh

echo "Waiting for ${INPUTDIR}/flags/ungrib_done"
while (! -e ${INPUTDIR}/flags/ungrib_done)
    sleep 5
end

################# run metgrid.exe #########################

echo "#\!/bin/csh"                                                         >! ${INPUTDIR}/metgrid.csh
echo "#==================================================================" >> ${INPUTDIR}/metgrid.csh
echo '#SBATCH' "-J metgrid"                                                >> ${INPUTDIR}/metgrid.csh
echo '#SBATCH' "-o ${INPUTDIR}/metgrid.log"                                >> ${INPUTDIR}/metgrid.csh
echo '#SBATCH' "-e ${INPUTDIR}/metgrid.err"                                >> ${INPUTDIR}/metgrid.csh
echo '#SBATCH' "-p batch"                                                  >> ${INPUTDIR}/metgrid.csh
echo '#SBATCH' "--ntasks-per-node=48"                                      >> ${INPUTDIR}/metgrid.csh
echo '#SBATCH' "-n 48"                                                     >> ${INPUTDIR}/metgrid.csh
echo '#SBATCH' '-t 0:10:00'                                                >> ${INPUTDIR}/metgrid.csh
echo "#==================================================================" >> ${INPUTDIR}/metgrid.csh

cat >> ${INPUTDIR}/metgrid.csh << EOF

set echo

cd \${SLURM_SUBMIT_DIR}

setenv MPICH_VERSION_DISPLAY 1
setenv MPICH_ENV_DISPLAY 1
setenv MPICH_MPIIO_HINTS_DISPLAY 1
setenv MPICH_GNI_RDMA_THRESHOLD 2048
setenv MPICH_GNI_DYNAMIC_CONN disabled

setenv OMP_NUM_THREADS 1

srun --mpi=pmi2 ${RUNDIR}/WRF_RUN/metgrid.exe

touch ${INPUTDIR}/flags/metgrid_done

EOF

sbatch ${INPUTDIR}/metgrid.csh

while (! -e ${INPUTDIR}/flags/metgrid_done)
    sleep 5
end

#
rm -rf geo_em.d0*.nc geogrid.log.00* GRIBFILE.* FILE:* ungrib.log
rm -rf geogrid.log metgrid.log* metgrid.log
rm -rf  ${INPUTDIR}/flags/geogrid_done ${INPUTDIR}/flags/metgrid_done

################# run real.exe #########################

rm -rf *.sed ${INPUTDIR}/flags/*done rsl*

cat >! runreal.sed << EOF

/start_year/c \\
 start_year                          = $runyr,
/start_month/c \\
 start_month                         = $runmon,
/start_day/c \\
 start_day                           = $runday,
/start_hour/c \\
 start_hour                          = 12,
/start_minute/c \\
 start_minute                        = 00,
/start_second/c \\
 start_second                        = 00,
/end_year/c \\
 end_year                            = $runyr,
/end_month/c \\
 end_month                           = $runmon,
/end_day/c \\
 end_day                             = $runday,
/end_hour/c \\
 end_hour                            = 12,
/end_minute/c \\
 end_minute                          = 00,
/end_second/c \\
 end_second                          = 00,
/interval_seconds/c \\
 interval_seconds                    = 3600,
/max_dom/c \\
 max_dom                             = 1,
/e_we/c \\
 e_we                                = ${grdpts_ew}, 226,
/e_sn/c \\
 e_sn                                = ${grdpts_ns}, 226,
/p_top_requested/c \\
 p_top_requested                     = 5000,
/num_metgrid_levels/c \\
 num_metgrid_levels                  = 51,
/num_metgrid_soil_levels/c \\
 num_metgrid_soil_levels             = 9,
/num_soil_layers/c \
 num_soil_layers                     = 9,
/i_parent_start/c \\
 i_parent_start                      = 0, 1,
/j_parent_start/c \\
 j_parent_start                      = 0, 1,
/numtiles/c \\
 numtiles                            = 10,
/nproc_x/c \\
 nproc_x                             = 2,
/nproc_y/c \\
 nproc_y                             = 12,
/num_land_cat/c \\
 num_land_cat                        = 21,
/smooth_cg_topo/c \
 smooth_cg_topo                      = .false.,
EOF

sed -f runreal.sed ${TEMPLATE_DIR}/namelists.WOFS.RLT2021/namelist.input.member1 >! namelist.input

echo "#\!/bin/csh"                                                          >! ${INPUTDIR}/real.csh
echo "#=================================================================="  >> ${INPUTDIR}/real.csh
echo '#SBATCH' "-J real"                                                    >> ${INPUTDIR}/real.csh
echo '#SBATCH' "-o ${INPUTDIR}/real.log"                                    >> ${INPUTDIR}/real.csh
echo '#SBATCH' "-e ${INPUTDIR}/real.err"                                    >> ${INPUTDIR}/real.csh
echo '#SBATCH' "-p batch"                                                   >> ${INPUTDIR}/real.csh
echo '#SBATCH' "--ntasks-per-node=24"                                       >> ${INPUTDIR}/real.csh
echo '#SBATCH' "-n 24"                                                      >> ${INPUTDIR}/real.csh
echo '#SBATCH' '-t 0:20:00'                                                 >> ${INPUTDIR}/real.csh
echo "#=================================================================="  >> ${INPUTDIR}/real.csh

cat >> ${INPUTDIR}/real.csh << EOF

set echo

cd \${SLURM_SUBMIT_DIR}

setenv MPICH_VERSION_DISPLAY 1
setenv MPICH_ENV_DISPLAY 1
setenv MPICH_MPIIO_HINTS_DISPLAY 1
setenv MPICH_GNI_RDMA_THRESHOLD 2048
setenv MPICH_GNI_DYNAMIC_CONN disabled

setenv OMP_NUM_THREADS 1

srun --mpi=pmi2 ${RUNDIR}/WRF_RUN/real.exe

touch ${INPUTDIR}/flags/real_done

EOF

chmod +x ${INPUTDIR}/real.csh
sbatch ${INPUTDIR}/real.csh

while (! -e ${INPUTDIR}/flags/real_done)
    sleep 5
end

mv wrfinput_d01 wrfinput_d01.${event}
#cp wrfinput_d01.${event} /work/rt_obs/WRFINPUTS

rm -rf rsl* real.csh namelist* *.sed real.log Vtable met_em* *.err metgrid.csh

exit (0)
