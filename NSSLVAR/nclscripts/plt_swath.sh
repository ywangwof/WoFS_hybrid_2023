#!/usr/bin/env bash

WRK_DIR=$PWD

function usage {
    echo " "
    echo "    USAGE: $0 [options] [DATETIME1] [DATETIME2]"
    echo " "
    echo "    PURPOSE: Plot reflectivity/vorticity track for analysis or forecast."
    echo " "
    echo "    OPTIONS:"
    echo "              -h              Display this message"
    echo "              -n              Show command to be run only"
    echo "              -fcst           Forecast ploting"
    echo "              -anal           Analysis ploting"
    echo "              -cycle          It is cycled runs"
    echo "              -nostrm         Turn off storm report"
    echo "              -f    ref/vor   Field to plot, reflectivity or vorticity or both"
    echo "              -w    wrkdir    Root directory for all datesets"
    echo "                              for analysis: "
    echo "                                   \${wrkdir}/DATE1/TIME1Z/dom00/newe3dvar/wrfinput_d01"
    echo "                                   to"
    echo "                                   \${wrkdir}/DATE2/TIME2Z/dom00/newe3dvar/wrfinput_d01"
    echo "                              for forecast: "
    echo "                                   \${wrkdir}/DATE1/TIME1Z/dom00/wrf1/wrfout_d01_DATETIME1"
    echo "                                   to"
    echo "                                   \${wrkdir}/DATE1/TIME1Z/dom00/wrf1/wrfout_d01_DATETIME2"
    echo "              -keep          Keep working files"
    echo " "
    echo "    DEFAULTS:"
    echo "              WRK_DIR = $WRK_DIR"
    echo " "
    echo "                                     -- By Y. Wang (2016.09.13)"
    echo " "
    exit $1
}

#-----------------------------------------------------------------------
#
# Handle command line arguments
#
#-----------------------------------------------------------------------

dateformat="GNU"

show=""
keep=0

fldset=()
datset=()
cycled=0
pltanal=0
pltfcst=0
pltstrm=1

while [[ $# > 0 ]]
    do
    key="$1"

    case $key in
        -n)
            show="echo"
            ;;
        -h)
            usage 0
            ;;
        -w)
            WRK_DIR="$2"
            shift      # past argument
            ;;
        -anal)
            pltanal=1
            ;;
        -fcst)
            pltfcst=1
            ;;
        -cycle)
            cycled=1
            ;;
        -nostrm)
            pltstrm=0
            ;;
        -keep)
            keep=1
            ;;
        -f)
            fldset=(${2//,/ })
            shift      # past argument
            ;;
        -*)
            echo "Unknown option: $key"
            exit
            ;;
        *)
            datset+=("$1")
            ;;
    esac
    shift # past argument or value
done

#
# Process command line arguments for DATETIME1 & DATETIME2
#
if [[ ${#datset[@]} -ne 2 ]]; then
  echo "ERROR: Wrong number of command line arguments"
  usage 1
else

  for dt in ${datset[@]}
  do

    if ! [[ ${dt} =~ ^[0-9]{12}$ ]]; then
      echo $dt
      echo "ERROR: Wrong command line arguments - ${datset[*]}."
      usage 2
    fi
  done

  if [[ ${datset[1]} -lt ${datset[0]} ]]; then
    echo ""
    echo "    ERROR: DATETIME1 < DATETIME2 is required, got \$DATETIME1=${datset[0]}, \$DATETIME2=${datset[1]}."
    usage 3
  else
    if [[ $dateformat == "GNU" ]]; then
        startd=${datset[0]:0:8}    #${name:start:length}
        startt=${datset[0]:8:4}
        startstr=$(date -d "$startd $startt" +%Y-%m-%d_%H:%M:%S)
        endd=${datset[1]:0:8}    #${name:start:length}
        endt=${datset[1]:8:4}
        endstr=$(date -d "$endd $endt" +%Y-%m-%d_%H:%M:%S)
    else
        startd=${datset[0]:0:8}    #${name:start:length}
        startt=${datset[0]:8:4}
        startstr=$(date -j -f "%Y%m%d%H%M" "${datset[0]}" +%Y-%m-%d_%H:%M:%S)
        endstr=$(date -j -f "%Y%m%d%H%M" "${datset[1]}" +%Y-%m-%d_%H:%M:%S)
    fi
  fi
fi

#
# Process fields to be ploted
#
if [[ ${#fldset[@]} -le 0 ]]; then
  #plot both fields if no one is selected explicitly
  fldset+=("ref")
  fldset+=("vor")
fi

#
# Determine analysis or forecast
#
if [[ $pltanal -eq 0 && $pltfcst -eq 0 ]]; then
  #plot both analysis and forecast if no one is selected explicitly
  pltanal=1
  pltfcst=1
fi

#
# Cycling special
#
if [[ $cycled -eq 1 ]]; then
  cyclestr="True"
  domstr="dom20/wrf5"
else
  cyclestr="False"
  domstr="dom00/wrf1"
fi

#-----------------------------------------------------------------------
#
# Make sure working directorie exists (no change below)
#
#-----------------------------------------------------------------------

NCARG_ROOT="/scratch/software/NCL/default"
MYNCARGDIR="/scratch/ywang/NEWSVAR/newe3dvar.git/NSSLVAR/nclscripts"

         #ref vor
analstep=(30 5)  # minutes
fcststep=(30 5)  # minutes

fldmin=(40 400)
title=("Reflectivity" "Vorticity")

$show cd ${WRK_DIR}

#-----------------------------------------------------------------------
#
# storm report
#
#-----------------------------------------------------------------------

if [[ $pltstrm -eq 1 ]]; then
  srptstr="True"

  if [[ "${startt}" -lt "1000" ]]; then
    rptdt=$(date -d "$startd -1 days" +%y%m%d)
  else
    rptdt=$(date -d "$startd" +%y%m%d)
  fi
  srptfile="$WRK_DIR/${rptdt}_rpts.csv"

  if [[ ! -e $srptfile ]]; then
    wget http://www.spc.noaa.gov/climo/reports/${rptdt}_rpts.csv
  fi

else
  srptstr="False"
  srptfile="xxxxx"
fi

#-----------------------------------------------------------------------
#
# Plot analysis
#
#-----------------------------------------------------------------------

if [[ pltanal -eq 1 ]]; then

  for field in ${fldset[@]}
  do

    if [[ "$field" =~ "ref" ]]; then
      imn=0
    else
      imn=1
    fi

    echo "Ploting \"$field\" -> ${title[$imn]} for analysis"

    nclhead="plt_anal-${field}_${startd}${startt}"
    pnghead="anl-${field}_${startd}_${startt}Z-${endt}Z"
    jobhead="run_anal-${field}"

    cat > ${nclhead}.ncl <<EOFOFNCLA1
load "${NCARG_ROOT}/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;load "${NCARG_ROOT}/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "${MYNCARGDIR}/WRFUserARW.ncl"
load "${NCARG_ROOT}/lib/ncarg/nclscripts/csm/contributed.ncl"

begin

  dataroot = "${WRK_DIR}/"
  stormrpt = ${srptstr}
  srptdir  = "${srptfile}"

  a = addfile(dataroot+"${startd}/${startt}Z/dom00/newe3dvar/wrfinput_d01.nc","r")

  wks_type = "png"
  wks_type@wkWidth  = 1224
  wks_type@wkHeight = 1584
  filename          = "${pnghead}"
  wks = gsn_open_wks(wks_type,filename)

  inittimestr = "${startstr}"
  timescst    = "${endstr}"
  timestep    = ${analstep[$imn]}    ; minutes
  cycled      = ${cyclestr}


  fldmin  = ${fldmin[$imn]}

  heights = (/ 3.000000 /)

  jobtype    = "Analysis"
  smooth_opt = 0

  cumcolors = (/   "white","black","brown","Gray10",          \\
                   "Gray40", "Gray60","Gray80","Gray90",      \\
                   "cadetblue","darkgreen","blue4","purple4", \\
                   "(/ 1.000, 1.000, 1.000 /)", \\
                   "(/ 0.004, 0.627, 0.961 /)", \  ; !29
                   "(/ 0.000, 0.000, 0.965 /)", \  ; !30
                   "(/ 0.000, 1.000, 0.000 /)", \  ; !31 green
                   "(/ 0.000, 0.784, 0.000 /)", \  ; !32
                   "(/ 0.000, 0.565, 0.000 /)", \  ; !33
                   "(/ 1.000, 1.000, 0.000 /)", \  ; !34 yellow
                   "(/ 0.906, 0.753, 0.000 /)", \  ; !35
                   "(/ 1.000, 0.565, 0.000 /)", \  ; !36
                   "(/ 1.000, 0.000, 0.000 /)", \  ; !37 red
                   "(/ 0.839, 0.000, 0.000 /)", \  ; !38
                   "(/ 0.753, 0.000, 0.000 /)", \  ; !39
                   "(/ 1.000, 0.000, 1.000 /)", \  ; !40 magenta
                   "(/ 0.600, 0.333, 0.788 /)", \  ; !41
                   "(/ 0.455, 0.004, 0.875 /)", \  ;
                   "(/ 0.900, 0.900, 0.900 /)"  \  ; !42 white - end of REF col map
                /)

  gsn_define_colormap(wks,cumcolors)

EOFOFNCLA1

    if [[ "$field" == "ref" ]]; then
      cat >> ${nclhead}.ncl <<EOFOFNCLA_COLORREF
  refcolors = (/  "White","Gray80","Gray40","Gray10" /)

  fldvarn    = "mdbz"

EOFOFNCLA_COLORREF

    else
      cat >> ${nclhead}.ncl <<EOFOFNCLA_COLORVOR
  vorcolors =    (/(/ 1.000, 1.000, 1.000 /), \\
                   (/ 0.004, 0.627, 0.961 /), \  ; !29
                   (/ 0.000, 0.565, 0.000 /), \  ; !33
                   (/ 1.000, 0.565, 0.000 /), \  ; !36
                   (/ 0.753, 0.000, 0.000 /), \  ; !39
                   (/ 1.000, 0.000, 1.000 /), \  ; !40 magenta
                   (/ 0.600, 0.333, 0.788 /), \  ; !41
                   (/ 0.900, 0.900, 0.900 /)  \  ; !42 white - end of REF col map
                /)
                   ;(/ 0.000, 0.925, 0.925 /), \  ; !28- begin REF
                   ;(/ 0.000, 0.000, 0.965 /), \  ; !30

  fldvarn    = "mavo"

EOFOFNCLA_COLORVOR
    fi

    cat >> ${nclhead}.ncl <<EOFOFNCLA2
  ;Set some basic resources
  res                      = True
  res@Footer               = False
  res@InitTime             = True
  res@START_DATE           = inittimestr

  pltres                   = True
  pltres@PanelPlot         = True   ; Tells wrf_map_overlays not to remove overlays
  ;pltres@FramePlot         = False

  mpres                             = True
  mpres@mpDataBaseVersion           = "Ncarg4_1"
  mpres@mpGeophysicalLineColor      = "Black"
  ;mpres@mpGridLineColor             = "Brown"
  ;mpres@mpGridLineDashPattern       = 2
  ;mpres@mpGridLineThicknessF        = 1.5
  mpres@mpLimbLineColor             = "Black"
  mpres@mpNationalLineColor         = "Black"
  mpres@mpPerimLineColor            = "Black"
  mpres@mpUSStateLineColor          = "Brown"
  mpres@mpUSStateLineThicknessF     = 1.5
  ;mpres@mpCountyLineDashPattern     = 2
  mpres@mpCountyLineColor           = "Gray10"
  mpres@mpCountyLineThicknessF      = 0.5
  mpres@mpOutlineBoundarySets       = "AllBoundaries"
  mpres@mpGridAndLimbOn             = False
  mpres@mpGridSpacingF              = 1

  mpres@gsnMaximize         = True
  mpres@gsnPaperOrientation = "portrait"

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

  initstrs = str_split(inittimestr,"_")
  currstrs = str_split(timescst, "-_:")
  currints = tointeger(currstrs)
  ;print(currstrs)

  time_minutes = cd_inv_calendar( currints(0), currints(1), currints(2),  \\
                                  currints(3), currints(4), currints(5),  \\
                                  "minutes since "+initstrs(0)+" "+initstrs(1), 0 )
  ;print(time_minutes)
  nt = round(time_minutes,3)
  ;print(nt)
  nsize = nt/timestep
EOFOFNCLA2

    if [[ "$field" == "ref" ]]; then
      cat >> ${nclhead}.ncl <<EOFOFNCLA_RESREF

   ;---------- ${title[$imn]} resources --------------

  opts = res
  ;opts@ContourParameters     = (/ fldmin, 75., 10./)
  opts@cnFillOn = True
  opts@cnFillColors          = refcolors
  opts@cnLevelSelectionMode  = "ExplicitLevels"
  opts@cnLevels              = (/ fldmin, 50, 60 /)
  ;;;; overlay lines
  ;opts@cnLinesOn               = True
  ;opts@cnMonoLineColor         = True
  ;opts@cnLineColor             = "black"
  ;opts@cnLineDrawOrder         = "PostDraw"
  ;opts@cnMonoLineThickness     = True
  ;opts@cnLineThicknessF        = 2.0
  ;opts@cnLevelFlags            = (/"NoLine","LineOnly","LineOnly","LineOnly"/)

  opts@cnMissingValFillColor = -1     ; use "transparent"
  opts@cnFillOpacityF        = 0.6
  ;;;
  ;;; ${title[$imn]} legend on the right
  ;;;
  opts@pmLabelBarSide       = "right"
  opts@pmLabelBarHeightF    = 0.65
  ;opts@pmLabelBarWidthF     = 0.12
  opts@lbOrientation        = "Vertical"
  opts@lbTitleString        = "${title[$imn]}"
  opts@lbTitlePosition      = "top"
  opts@lbTitleJust          = "topright"
  opts@lbTitleOffsetF       = 0.0
  opts@lbTitleExtentF       = 0.08
  ;opts@lbTopMarginF         = 0.02
  opts@lbTitleFontHeightF   = 0.015
  opts@lbLabelFontHeightF   = 0.015

  opainit = 0.1
  opastep = (0.6-opainit)/nsize

EOFOFNCLA_RESREF

    else

      cat >> ${nclhead}.ncl <<EOFOFNCLA_RESVOR

  ;---------- ${title[$imn]} resources --------------

  opts = res

  opts@ContourParameters = (/ fldmin, 1600., 200./)
  opts@cnFillOn = True
  opts@cnMissingValFillColor = -1     ; use "transparent"
  opts@cnFillColors = vorcolors
  opts@cnLineColor  = "Brown"

  opts@pmLabelBarSide       = "right"
  opts@pmLabelBarHeightF    = 0.65
  opts@pmLabelBarOrthogonalPosF = 0.0
  ;opts@pmLabelBarWidthF     = 0.12
  opts@lbOrientation        = "Vertical"
  opts@lbTitleString        = "${title[$imn]}"
  opts@lbTitlePosition      = "top"
  opts@lbTitleJust          = "topright"
  opts@lbTitleOffsetF       = 0.0
  opts@lbTitleExtentF       = 0.08
  ;opts@lbTopMarginF         = 0.02
  opts@lbTitleFontHeightF   = 0.015
  opts@lbLabelFontHeightF   = 0.015

EOFOFNCLA_RESVOR

    fi

    cat >> ${nclhead}.ncl <<EOFOFNCLA3

  ig = 0
  do it = 0,nt,timestep

     time_min = it+0.01
     time_min@units = "minutes since "+initstrs(0)+" "+initstrs(1)
     ;print(time_min)

     utc_datei = cd_calendar(time_min, -5)
     ;print(utc_datei)

     timestr  = sprinti("%4.4d",utc_datei(0,0))+"-"+  \\
                sprinti("%2.2d",utc_datei(0,1))+"-"+  \\
                sprinti("%2.2d",utc_datei(0,2))+"_"+  \\
                sprinti("%2.2d",utc_datei(0,3))+":"+  \\
                sprinti("%2.2d",utc_datei(0,4))+":"+  \\
                sprinti("%2.2d",utc_datei(0,5))

     print("Working on time: " + timestr +"." )

     currdate = sprinti("%4.4d",utc_datei(0,0))+  \\
                sprinti("%2.2d",utc_datei(0,1))+  \\
                sprinti("%2.2d",utc_datei(0,2))

     currtime = sprinti("%2.2d",utc_datei(0,3))+  \\
                sprinti("%2.2d",utc_datei(0,4))

     if (cycled) then
       if (it .eq. 0) then
         b = addfile(dataroot+currdate+"/"+currtime+"Z/dom00/newe3dvar/wrfinput_d01.nc","r")
       else
         b = addfile(dataroot+currdate+"/"+currtime+"Z/dom20/newe3dvar/wrfout_d01_"+timestr+".nc","r")
       end if
     else
       b = addfile(dataroot+currdate+"/"+currtime+"Z/dom00/newe3dvar/wrfinput_d01.nc","r")
     end if

     ;; Interpolations
     zsea = wrf_user_getvar(b,"z",0)    ; z on mass points
     ter  = wrf_user_getvar(b,"ter",0)  ; terrain heights
     zter = conform(zsea,ter,(/1,2/))
     zagl = zsea-zter

     height = heights(0)*1000.0

EOFOFNCLA3

    if [[ "$field" =~ "ref" ]]; then
      cat >> ${nclhead}.ncl <<EOFOFNCLA_REF
     afld = wrf_user_getvar(b,fldvarn,0)
     afld@_FillValue = -9999
EOFOFNCLA_REF

    else

      cat >> ${nclhead}.ncl <<EOFOFNCLA_VOR
     afld = wrf_user_getvar(b,fldvarn,0)
     afld@_FillValue = -9999

     amin = min(afld)
     amax = max(afld)
     afld@units        = "1.0E-5 s-1, min="+amin+", max="+amax
EOFOFNCLA_VOR

    fi

    cat >> ${nclhead}.ncl <<EOFOFNCLA4

     ;---------- Plot ${title[$imn]} --------------

     ;opts@cnFillOpacityF = opainit + ig*opastep

     if (it .eq. nt) then
       opts@FieldTitle   = "Composite ${title[$imn]}"
       opts@lbLabelBarOn = False

       tend=tointeger(currtime)
       if (tend .lt. 1000) then
         tend = tend + 10000
       end if
     else
       opts@FieldTitle   = ""
       delete(afld@units)
     end if

     if (it .eq. 0) then
       opts@lbLabelBarOn = True
       opts@lbTitleOn    = True
       tbgn=tointeger(currtime)
       if (tbgn .lt. 1000) then
         tbgn = tbgn + 10000
       end if
     else
       opts@lbLabelBarOn = False
     end if

     if (smooth_opt .gt. 0) then
       wrf_smooth_2d(afld,smooth_opt)
     end if

     afld = where(afld.lt.fldmin,afld@_FillValue,afld)

     contourplt = wrf_contour(b,wks,afld,opts)    ; plot field

     if (it.eq.0) then
       contourfld = (/contourplt/)
     else
       tmpgra = contourfld
       delete(contourfld)
       contourfld = array_append_record(tmpgra,contourplt,0)
       delete(tmpgra)
     end if
     delete(contourplt)

     ig = ig+1
  end do

  delete(opts)


  res@MainTitle = jobtype + " at "+heights(0)+" km above ground"
  res@TimeLabel = timescst   ; Set Valid time to use on plots


  ;---------- Plot wind vectors --------------

  ua  = wrf_user_getvar(b,"ua",0)      ; 3D U at mass points
  va  = wrf_user_getvar(b,"va",0)      ; 3D V at mass points

  ua2d  = wrf_interp_3d_z(ua,zagl,height)
  va2d  = wrf_interp_3d_z(va,zagl,height)
  wspd = sqrt(ua2d^2+va2d^2)                    ;;; Horizontal wind speed

  opts = res
  opts@NumVectors = 30           ; density of wind barbs
  opts@vcGlyphStyle = "LineArrow"
  opts@FieldTitle = "Horizontal wind vector at "+heights(0)+" km AGL"
  opts@vcRefAnnoOn             = True
  opts@vcRefAnnoPerimOn        = False
  opts@vcRefAnnoString2On      = False
  opts@vcRefAnnoString1        = "\$VMG\$ m/s"
  opts@vcRefAnnoSide           = "Top"
  opts@vcRefAnnoParallelPosF   =  0.92
  opts@vcRefAnnoOrthogonalPosF = -0.23
  ;opts@vcRefMagnitudeF         = 30.0
  ;opts@vcRefLengthF            = 0.015

  ;;;
  ;;;  Added wind speed legend bar
  ;;;
  opts@pmLabelBarDisplayMode    = "Always"
  opts@pmLabelBarSide           = "Bottom"
  opts@pmLabelBarHeightF        = 0.12
  opts@pmLabelBarWidthF         = 0.8
  opts@lbOrientation            = "Horizontal"
  opts@lbPerimOn                = False
  opts@lbTitleString            = "Wind Speed"
  opts@lbAutoManage             = False
  opts@lbTitleOffsetF           = 0.025
  opts@lbTitleFontHeightF       = 0.02
  opts@lbLabelFontHeightF       = 0.015
  ;opts@lbLabelAutoStride        = True

  opts@vcLevelSelectionMode      = "ExplicitLevels"
  opts@vcLevels                  = (/10.8,17.2,24.5,28.5/)
  opts@vcLevelColors             = (/"cadetblue","darkgreen","blue4","purple4","(/ 0.753, 0.000, 0.000 /)"/)

  vectora = wrf_vector_scalar(b,wks,ua2d,va2d,wspd,opts)
  ;vectora = wrf_vector(a,wks,ua2d,va2d,opts)
  delete(opts)


  ;---------- Put all together --------------

  plot = wrf_map_overlays(b,wks,array_append_record(contourfld,vectora,0),pltres,mpres)

  ;;;;--- Attach the shapefile polylines ---

  ;;;;--- Attach storm reports ---
  if ( stormrpt ) then
     ;wget http://www.spc.noaa.gov/climo/reports/160509_rpts.csv
     datain = asciiread(srptdir,-1,"string")

     t=str_match_ind(datain,"Time,F_Scale,Location,County,State,Lat,Lon,Comments")
     h=str_match_ind(datain,"Time,Size,Location,County,State,Lat,Lon,Comments")
     w=str_match_ind(datain,"Time,Speed,Location,County,State,Lat,Lon,Comments")
     l=dimsizes(datain)

     delim = ","

     ;
     ; Create a new marker, keeping all its default settings.
     ; This particular marker is a filled triangle.
     ;
     mstring = "u"
     fontnum = 34
     xoffset = 0.0
     yoffset = 0.0
     ratio   = 1.5
     size    = 1.2
     angle   = 0.0
     filledtriangle = NhlNewMarker(wks,mstring,fontnum,xoffset,yoffset,ratio,size,angle)

     dator=(/t,h,w,l/)
     datcl=(/"red","green","blue","black"/)
     datmk=(/filledtriangle,9,11/)
     cat = dim_pqsort(dator,1)
     ;print(tbgn+", "+tend)
     do i = 0, dimsizes(cat)-2
       if (dator(cat(i)) .ge. 0) then   ; valid data

         lines = datain(dator(cat(i))+1:dator(cat(i+1))-1)
         ;---Read fields lat/lon
         TIME  = tointeger(str_get_field(lines,1,delim))
         ;FSCL  = tointeger(str_get_field(lines,2,delim))
         lats  = tofloat(str_get_field(lines,6,delim))
         lons  = tofloat(str_get_field(lines,7,delim))

         TIME = where(TIME.lt.1000,TIME+10000,TIME)

         ;print(TIME)
         ;print(lats)
         ;print(lons)

         pmres = True
         pmres@gsMarkerColor = datcl(cat(i))
         pmres@gsMarkerIndex = datmk(cat(i))
         pmres@gsMarkerSizeF = 0.008
         pmres@gsMarkerThicknessF  = 2.0

         mlons = mask(lons,TIME .ge. tbgn .and. TIME .le. tend,True)
         mlats = mask(lats,TIME .ge. tbgn .and. TIME .le. tend,True)
         trpt = gsn_add_polymarker (wks,plot,mlons,mlats,pmres)
         if (i.eq.0) then
           strpts = (/trpt/)
         else
           tmpgra = strpts
           delete(strpts)
           strpts = array_append_record(tmpgra,trpt,0)
           delete(tmpgra)
         end if
         delete(trpt)

         delete(lines)
         delete(TIME)
         ;delete(FSCL)
         delete(lats)
         delete(lons)
         delete(mlats)
         delete(mlons)
         delete(pmres)

       end if
     end do

  end if

  ;;;--- draw the map and the shapefile outlines ---

  draw(plot)
  frame(wks)

  print("=== Done file: " + filename + "." + wks_type +" ===" )
end
EOFOFNCLA4

    cat > ${jobhead}.job <<ENDOFJOBPLT
#!/bin/csh
#==================================================================
#SBATCH -J plt_anal-${field}_${startd}${startt}-$field-anal
#SBATCH -o ${jobhead}_%j.out
#SBATCH -e ${jobhead}_%j.err
#SBATCH -A smallqueue
#SBATCH -p workq
#SBATCH -n 1
#SBATCH --ntasks-per-node=1
#SBATCH -t 1:30:00
#==================================================================


aprun -n 1 ncl ${nclhead}.ncl

touch ${nclhead}.done

ENDOFJOBPLT

    $show sbatch ${jobhead}.job

    if [[ -z $show ]]; then

      while [[ ! -e ${nclhead}.done ]]
      do
        echo "Waiting for ${nclhead}.done ..."
        sleep 20
      done

    fi

  done
fi

#-----------------------------------------------------------------------
#
# Plot forecast
#
#-----------------------------------------------------------------------

if [[ pltfcst -eq 1 ]]; then

  for field in ${fldset[@]}
  do

    if [[ "$field" =~ "ref" ]]; then
      imn=0
    else
      imn=1
    fi

    echo "Ploting \"$field\" -> ${title[$imn]} for forecast"

    nclhead="plt_fcst-${field}_${startd}${startt}"
    pnghead="fcst-${field}_${startd}_${startt}Z"
    jobhead="run_fcst-${field}"

    cat > ${nclhead}.ncl <<EOFOFNCLF1
load "${NCARG_ROOT}/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;load "${NCARG_ROOT}/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "${MYNCARGDIR}/WRFUserARW.ncl"
load "${NCARG_ROOT}/lib/ncarg/nclscripts/csm/contributed.ncl"

begin

  datadir = "${WRK_DIR}/${startd}/${startt}Z/${domstr}"
  stormrpt = ${srptstr}
  srptdir  = "${srptfile}"

  a = addfile(datadir+"/wrfout_d01_${startstr}.nc","r")

  wks_type = "png"
  wks_type@wkWidth  = 1224
  wks_type@wkHeight = 1584
  filename          = "$pnghead"
  wks = gsn_open_wks(wks_type,filename)

  inittimestr = "${startstr}"
  timescst    = "${endstr}"
  timestep    = ${fcststep[$imn]}    ; minutes

  fldmin  = ${fldmin[$imn]}

  jobtype    = "Forecast"
  smooth_opt = 3

  cumcolors = (/   "white","black","brown","Gray10",          \\
                   "Gray40", "Gray60","Gray80","Gray90",      \\
                   "cadetblue","darkgreen","blue4","purple4", \\
                   "(/ 1.000, 1.000, 1.000 /)", \\
                   "(/ 0.004, 0.627, 0.961 /)", \  ; !29
                   "(/ 0.000, 0.000, 0.965 /)", \  ; !30
                   "(/ 0.000, 1.000, 0.000 /)", \  ; !31 green
                   "(/ 0.000, 0.784, 0.000 /)", \  ; !32
                   "(/ 0.000, 0.565, 0.000 /)", \  ; !33
                   "(/ 1.000, 1.000, 0.000 /)", \  ; !34 yellow
                   "(/ 0.906, 0.753, 0.000 /)", \  ; !35
                   "(/ 1.000, 0.565, 0.000 /)", \  ; !36
                   "(/ 1.000, 0.000, 0.000 /)", \  ; !37 red
                   "(/ 0.839, 0.000, 0.000 /)", \  ; !38
                   "(/ 0.753, 0.000, 0.000 /)", \  ; !39
                   "(/ 1.000, 0.000, 1.000 /)", \  ; !40 magenta
                   "(/ 0.600, 0.333, 0.788 /)", \  ; !41
                   "(/ 0.900, 0.900, 0.900 /)"  \  ; !42 white - end of REF col map
                /)

  gsn_define_colormap(wks,cumcolors)

EOFOFNCLF1

    if [[ "$field" == "ref" ]]; then
      cat >> ${nclhead}.ncl <<EOFOFNCLF_COLORREF
  refcolors = (/  "White","Gray80","Gray40","Gray10" /)

EOFOFNCLF_COLORREF

    else
      cat >> ${nclhead}.ncl <<EOFOFNCLF_COLORVOR
  vorcolors =    (/(/ 1.000, 1.000, 1.000 /), \\
                   (/ 0.004, 0.627, 0.961 /), \  ; !29
                   (/ 0.000, 0.565, 0.000 /), \  ; !33
                   (/ 1.000, 0.565, 0.000 /), \  ; !36
                   (/ 0.753, 0.000, 0.000 /), \  ; !39
                   (/ 1.000, 0.000, 1.000 /), \  ; !40 magenta
                   (/ 0.600, 0.333, 0.788 /), \  ; !41
                   (/ 0.900, 0.900, 0.900 /)  \  ; !42 white - end of REF col map
                /)
                   ;(/ 0.000, 0.925, 0.925 /), \  ; !28- begin REF
                   ;(/ 0.000, 0.000, 0.965 /), \  ; !30

EOFOFNCLF_COLORVOR
    fi

    cat >> ${nclhead}.ncl  <<EOFOFNCLF2

  ;Set some basic resources
  res                      = True
  res@Footer               = False
  res@InitTime             = True

  pltres                   = True
  pltres@PanelPlot         = True   ; Tells wrf_map_overlays not to remove overlays
  ;pltres@FramePlot         = False

  mpres                             = True
  mpres@mpDataBaseVersion           = "Ncarg4_1"
  mpres@mpGeophysicalLineColor      = "Black"
  ;mpres@mpGridLineColor             = "Brown"
  ;mpres@mpGridLineDashPattern       = 2
  ;mpres@mpGridLineThicknessF        = 1.5
  mpres@mpLimbLineColor             = "Black"
  mpres@mpNationalLineColor         = "Black"
  mpres@mpPerimLineColor            = "Black"
  mpres@mpUSStateLineColor          = "Brown"
  mpres@mpUSStateLineThicknessF     = 1.5
  ;mpres@mpCountyLineDashPattern     = 2
  mpres@mpCountyLineColor           = "Gray10"
  mpres@mpCountyLineThicknessF      = 0.5
  mpres@mpOutlineBoundarySets       = "AllBoundaries"
  mpres@mpGridAndLimbOn             = False
  mpres@mpGridSpacingF              = 1

  mpres@gsnMaximize         = True
  mpres@gsnPaperOrientation = "portrait"

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

  initstrs = str_split(inittimestr,"_")
  currstrs = str_split(timescst, "-_:")
  currints = tointeger(currstrs)
  ;print(currstrs)

  time_minutes = cd_inv_calendar( currints(0), currints(1), currints(2),  \\
                                  currints(3), currints(4), currints(5),  \\
                                  "minutes since "+initstrs(0)+" "+initstrs(1), 0 )
  ;print(time_minutes)
  nt = round(time_minutes,3)
  ;print(nt)
  nsize = nt/timestep

EOFOFNCLF2

    if [[ "$field" == "ref" ]]; then
      cat >> ${nclhead}.ncl  <<EOFOFNCLF_RESREF

   ;---------- ${title[$imn]} resources --------------

  opts = res
  ;opts@ContourParameters     = (/ fldmin, 75., 10./)
  opts@cnFillOn = True
  opts@cnFillColors          = refcolors
  opts@cnLevelSelectionMode  = "ExplicitLevels"
  opts@cnLevels              = (/ fldmin, 50, 60 /)
  ;;;; overlay lines
  ;opts@cnLinesOn               = True
  ;opts@cnMonoLineColor         = True
  ;opts@cnLineColor             = "black"
  ;opts@cnLineDrawOrder         = "PostDraw"
  ;opts@cnMonoLineThickness     = True
  ;opts@cnLineThicknessF        = 2.0
  ;opts@cnLevelFlags            = (/"NoLine","LineOnly","LineOnly","LineOnly"/)

  opts@cnMissingValFillColor = -1     ; use "transparent"
  opts@cnFillOpacityF        = 0.6
  ;;;
  ;;; ${title[$imn]} legend on the right
  ;;;
  opts@pmLabelBarSide       = "right"
  opts@pmLabelBarHeightF    = 0.65
  ;opts@pmLabelBarWidthF     = 0.12
  opts@lbOrientation        = "Vertical"
  opts@lbTitleString        = "${title[$imn]}"
  opts@lbTitlePosition      = "top"
  opts@lbTitleJust          = "topright"
  opts@lbTitleOffsetF       = 0.0
  opts@lbTitleExtentF       = 0.08
  ;opts@lbTopMarginF         = 0.02
  opts@lbTitleFontHeightF   = 0.015
  opts@lbLabelFontHeightF   = 0.015

  opainit = 0.1
  opastep = (0.6-opainit)/nsize

EOFOFNCLF_RESREF

    else

      cat >> ${nclhead}.ncl  <<EOFOFNCLF_RESVOR

  ;---------- ${title[$imn]} resources --------------

  opts = res

  opts@ContourParameters = (/ fldmin, 1600., 200./)
  opts@cnFillOn = True
  opts@cnMissingValFillColor = -1     ; use "transparent"
  opts@cnFillColors = vorcolors
  opts@cnLineColor  = "Brown"

  opts@pmLabelBarSide       = "right"
  opts@pmLabelBarHeightF    = 0.65
  opts@pmLabelBarOrthogonalPosF = 0.0
  ;opts@pmLabelBarWidthF     = 0.12
  opts@lbOrientation        = "Vertical"
  opts@lbTitleString        = "${title[$imn]}"
  opts@lbTitlePosition      = "top"
  opts@lbTitleJust          = "topright"
  opts@lbTitleOffsetF       = 0.0
  opts@lbTitleExtentF       = 0.08
  ;opts@lbTopMarginF         = 0.02
  opts@lbTitleFontHeightF   = 0.015
  opts@lbLabelFontHeightF   = 0.015

EOFOFNCLF_RESVOR

    fi

    cat >> ${nclhead}.ncl  <<EOFOFNCLF3

  ig = 0
  do it = 0,nt,timestep

     time_min = it+0.01
     time_min@units = "minutes since "+initstrs(0)+" "+initstrs(1)
     ;print(time_min)

     utc_datei = cd_calendar(time_min, -5)
     ;print(utc_datei)
     currtime = sprinti("%4.4d",utc_datei(0,0))+"-"+  \\
                sprinti("%2.2d",utc_datei(0,1))+"-"+  \\
                sprinti("%2.2d",utc_datei(0,2))+"_"+  \\
                sprinti("%2.2d",utc_datei(0,3))+":"+  \\
                sprinti("%2.2d",utc_datei(0,4))+":"+  \\
                sprinti("%2.2d",utc_datei(0,5))
     print("Working on time: " + currtime + "." )

     b = addfile(datadir+"/wrfo2d_d01_"+currtime+".nc","r")

EOFOFNCLF3

    if [[ "$field" =~ "ref" ]]; then
      cat >> ${nclhead}.ncl <<EOFOFNCLF_REF
     afld = b->comref(0,:,:)
     afld@_FillValue = -9999
EOFOFNCLF_REF

    else

      cat >> ${nclhead}.ncl <<EOFOFNCLF_VOR
     afld = b->comvor(0,:,:)*1.0E5
     afld@_FillValue = -9999

     amin = min(afld)
     amax = max(afld)
     afld@units        = "1.0E-5 s-1, min="+amin+", max="+amax
EOFOFNCLF_VOR

    fi

    cat >> ${nclhead}.ncl <<EOFOFNCLF4

     ;---------- Plot ${title[$imn]} --------------

     ;opts@cnFillOpacityF = opainit + ig*opastep

     if (it .eq. nt) then
       opts@FieldTitle   = "Composite ${title[$imn]}"
       opts@lbLabelBarOn = False
       tend=utc_datei(0,3)*100+utc_datei(0,4)
       if (tend .lt. 1000) then
         tend = tend + 10000
       end if
     else
       opts@FieldTitle   = ""
       delete(afld@units)
     end if

     if (it .eq. 0) then
       opts@lbLabelBarOn = True
       opts@lbTitleOn    = True
       tbgn=utc_datei(0,3)*100+utc_datei(0,4)
       if (tbgn .lt. 1000) then
         tbgn = tbgn + 10000
       end if
     else
       opts@lbLabelBarOn = False
       ;opts@NoTitles     = True
     end if

     if (smooth_opt .gt. 0) then
       wrf_smooth_2d(afld,smooth_opt)
     end if

     afld = where(afld.lt.fldmin,afld@_FillValue,afld)

     contourplt = wrf_contour(b,wks,afld,opts)    ; plot field

     if (it.eq.0) then
       contourfld = (/contourplt/)
     else
       tmpgra = contourfld
       delete(contourfld)
       contourfld = array_append_record(tmpgra,contourplt,0)
       delete(tmpgra)
     end if
     delete(contourplt)

     ig = ig+1
  end do

  delete(opts)

  ua  = b->usfc__
  va  = b->vsfc__

  ds = dimsizes(afld)
  rk = dimsizes(ds)
  ua2d = new((/ds(rk-2),ds(rk-1)/),float)
  va2d = new((/ds(rk-2),ds(rk-1)/),float)
  do j = 0, ds(rk-2)-1
    do i = 0, ds(rk-1)-1
      ua2d(j,i) = 0.5*(ua(0,j,i)+ua(0,j,i+1))
      va2d(j,i) = 0.5*(va(0,j,i)+va(0,j+1,i))
    end do
  end do

  wspd = sqrt(ua2d^2+va2d^2)

  res@MainTitle = "Composite ${title[$imn]} Track"
  res@TimeLabel = timescst   ; Set Valid time to use on plots


  ;---------- Plot wind vectors --------------

  opts = res
  opts@NumVectors = 30           ; density of wind barbs
  opts@vcGlyphStyle = "LineArrow"
  opts@FieldTitle = "Horizontal wind vector at 3 km AGL"
  opts@vcRefAnnoOn             = True
  opts@vcRefAnnoPerimOn        = False
  opts@vcRefAnnoString2On      = False
  opts@vcRefAnnoString1        = "\$VMG\$ m/s"
  opts@vcRefAnnoSide           = "Top"
  opts@vcRefAnnoParallelPosF   =  0.92
  opts@vcRefAnnoOrthogonalPosF = -0.23
  ;opts@vcRefMagnitudeF         = 30.0
  ;opts@vcRefLengthF            = 0.015

  ;;;
  ;;;  Added wind speed legend bar
  ;;;
  opts@pmLabelBarDisplayMode    = "Always"
  opts@pmLabelBarSide           = "Bottom"
  opts@pmLabelBarHeightF        = 0.12
  opts@pmLabelBarWidthF         = 0.8
  opts@lbOrientation            = "Horizontal"
  opts@lbPerimOn                = False
  opts@lbTitleString            = "Wind Speed"
  opts@lbAutoManage             = False
  opts@lbTitleOffsetF           = 0.025
  opts@lbTitleFontHeightF       = 0.02
  opts@lbLabelFontHeightF       = 0.015
  ;opts@lbLabelAutoStride        = True

  opts@vcLevelSelectionMode      = "ExplicitLevels"
  opts@vcLevels                  = (/10.8,17.2,24.5,28.5/)
  opts@vcLevelColors             = (/"cadetblue","darkgreen","blue4","purple4","(/ 0.753, 0.000, 0.000 /)"/)

  vectora = wrf_vector_scalar(a,wks,ua2d,va2d,wspd,opts)
  ;vectora = wrf_vector(a,wks,ua2d,va2d,opts)
  delete(opts)

  ;---------- Put all together --------------

  plot = wrf_map_overlays(a,wks,array_append_record(contourfld,vectora,0),pltres,mpres)

  ;;;;--- Attach the shapefile polylines ---

  ;;;;--- Attach storm reports ---
  if (stormrpt) then
     ;wget http://www.spc.noaa.gov/climo/reports/160509_rpts.csv
     datain = asciiread(srptdir,-1,"string")

     t=str_match_ind(datain,"Time,F_Scale,Location,County,State,Lat,Lon,Comments")
     h=str_match_ind(datain,"Time,Size,Location,County,State,Lat,Lon,Comments")
     w=str_match_ind(datain,"Time,Speed,Location,County,State,Lat,Lon,Comments")
     l=dimsizes(datain)

     delim = ","

     ;
     ; Create a new marker, keeping all its default settings.
     ; This particular marker is a filled triangle.
     ;
     mstring = "u"
     fontnum = 34
     xoffset = 0.0
     yoffset = 0.0
     ratio   = 1.5
     size    = 1.2
     angle   = 0.0
     filledtriangle = NhlNewMarker(wks,mstring,fontnum,xoffset,yoffset,ratio,size,angle)

     dator=(/t,h,w,l/)
     datcl=(/"red","green","blue","black"/)
     datmk=(/filledtriangle,9,11/)
     cat = dim_pqsort(dator,1)
     do i = 0, dimsizes(cat)-2
       if (dator(cat(i)) .ge. 0) then   ; valid data

         lines = datain(dator(cat(i))+1:dator(cat(i+1))-1)
         ;---Read fields lat/lon
         TIME  = tointeger(str_get_field(lines,1,delim))
         ;FSCL  = tointeger(str_get_field(lines,2,delim))
         lats  = tofloat(str_get_field(lines,6,delim))
         lons  = tofloat(str_get_field(lines,7,delim))

         TIME = where(TIME.lt.1000,TIME+10000,TIME)

         ;print(TIME)
         ;print(lats)
         ;print(lons)

         pmres = True
         pmres@gsMarkerColor = datcl(cat(i))
         pmres@gsMarkerIndex = datmk(cat(i))
         pmres@gsMarkerSizeF = 0.008
         pmres@gsMarkerThicknessF  = 2.0

         mlons = mask(lons,TIME .ge. tbgn .and. TIME .le. tend,True)
         mlats = mask(lats,TIME .ge. tbgn .and. TIME .le. tend,True)
         trpt = gsn_add_polymarker (wks,plot,mlons,mlats,pmres)
         if (i.eq.0) then
           strpts = (/trpt/)
         else
           tmpgra = strpts
           delete(strpts)
           strpts = array_append_record(tmpgra,trpt,0)
           delete(tmpgra)
         end if
         delete(trpt)

         delete(lines)
         delete(TIME)
         ;delete(FSCL)
         delete(lats)
         delete(lons)
         delete(mlats)
         delete(mlons)
         delete(pmres)

       end if
     end do

  end if
  ;;;--- draw the map and the shapefile outlines ---

  draw(plot)
  frame(wks)

  print("=== Done file: " + filename + "." + wks_type +" ===" )
end
EOFOFNCLF4

    cat > ${jobhead}.job  <<ENDOFJOBPLT
#!/bin/csh
#==================================================================
#SBATCH -J plt_fcst-${field}_${startd}${startt}
#SBATCH -o ${jobhead}_%j.out
#SBATCH -e ${jobhead}_%j.err
#SBATCH -A smallqueue
#SBATCH -p workq
#SBATCH -n 1
#SBATCH --ntasks-per-node=1
#SBATCH -t 1:30:00
#==================================================================


aprun -n 1 ncl ${nclhead}.ncl

touch ${nclhead}.done

ENDOFJOBPLT

    $show sbatch ${jobhead}.job

    if [[ -z $show ]]; then

      while [[ ! -e ${nclhead}.done ]]
      do
        echo "Waiting for ${nclhead}.done ..."
        sleep 20
      done
    fi

  done

fi

########################################################################
#
# Clean working flags
#
########################################################################

echo "Done ploting for <${fldset[*]}> from $startstr to $endstr."

rm -f plt_anal*.done plt_fcst*.done
if [[ ${keep} -ne 1 ]]; then
  rm -f plt_anal*.ncl plt_fcst*.ncl
  rm -f run_anal*.job run_anal*.out run_anal*.err
  rm -f run_fcst*.job run_fcst*.out run_fcst*.err
fi
