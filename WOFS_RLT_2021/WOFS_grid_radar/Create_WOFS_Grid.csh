#!/bin/csh

set echo

# <<< conda initialize <<<
source /scratch/software/miniconda3/etc/profile.d/conda.csh
conda activate wofs_post
# <<< conda initialize <<<


setenv SCRIPTDIR /scratch/ywang/NEWSVAR/news3dvar.2023/WOFS_RLT_2021/WOFS_grid_radar
setenv event 20220520
#setenv event 20170825

# $1  Y: plot domain
# $2  station name to center the WoFS grid
# $3  Nudging in km from the station point, DX
# $4  DY
# $5  Y: copy domain image to the web
# $6  Y: copy to realtime directory
# $7  start_hr 15


#scp Kent.Knopfmeier@bigbang3.protect.nssl:/raid/roberts/data/sfe_json/sector_bounds/2021/hwt_primary.${event}.json ${SCRIPTDIR}/sfe_sectors

if ($1 == 'Y') then

   python ${SCRIPTDIR}/WOFS_grid_radars_dd.py -s $2 --nudge $3 $4 -d
   source ${SCRIPTDIR}/radars.${event}.csh

else

   python ${SCRIPTDIR}/WOFS_grid_radars_dd.py -s $2 --nudge $3 $4
   source ${SCRIPTDIR}/radars.${event}.csh

endif

echo "setenv start_hr $7" >> radars.${event}.csh

### Commented code below is for realtime purposes only
#ncl event=\"${event}\" lat_ll=\"${lat_ll}\" lat_ur=\"${lat_ur}\" lon_ll=\"${lon_ll}\" lon_ur=\"${lon_ur}\" ${SCRIPTDIR}/HRRRE_extraction/hrrre_extraction.ncl

if ($5 == 'Y') then

   cp ${SCRIPTDIR}/WOFS_domain_${event}.png /www/wof.nssl.noaa.gov/newse_images/${event}/WOFS_domain_${event}.png

endif

if ($6 == 'Y') then

  cp ${SCRIPTDIR}/radars.${event}.csh /scratch/wof/realtime/radar_files

  #scp ${SCRIPTDIR}/HRRRE_extraction/grid_specs_newse.${event}.txt Kent.Knopfmeier@dtn-jet.rdhpcs.noaa.gov:/mnt/lfs3/projects/hpc-wof1/WOF/HRRRE/${event}

  echo $2 >! gridinfo_${event}.txt
  echo $3 >> gridinfo_${event}.txt
  echo $4 >> gridinfo_${event}.txt

endif

exit (0)
