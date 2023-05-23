load "/scratch/software/NCL/default/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;load "/scratch/software/NCL/default/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "/scratch/ywang/NEWSVAR/newe3dvar.rerun/NSSLVAR/nclscripts/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

begin

  datadir = "/scratch/ywang/test_runs/rerun/20160509/2200Z/dom00/wrf1"
  srptdir = "/lus/scratch/ywang/test_runs/rerun.new/160509_rpts.csv"
  vormin  = 400

  a = addfile(datadir+"/wrfout_d01_2016-05-09_22:00:00.nc","r")

  wks_type = "png"
  wks_type@wkWidth  = 1224
  wks_type@wkHeight = 1584
  wks = gsn_open_wks(wks_type,"fcst-0509_2200")

  inittimestr = "2016-05-09_22:00:00"
  timescst    = "2016-05-10_01:00:00"


  jobtype    = "Forecast"
  dbzvarn    = "dbzp"
  smooth_opt = 3





  cumcolors = (/   "white","black","brown","Gray10", \
                   "cadetblue","darkgreen","blue4","purple4", \
                   "(/ 1.000, 1.000, 1.000 /)", \
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

  vorcolors =    (/(/ 1.000, 1.000, 1.000 /), \
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

  time_minutes = cd_inv_calendar( currints(0), currints(1), currints(2), \
                                  currints(3), currints(4), currints(5),  \
                                  "minutes since "+initstrs(0)+" "+initstrs(1), 0 )
  ;print(time_minutes)
  nt = round(time_minutes,3)
  ;print(nt)

  ;---------- vorticity resources --------------

  opts = res

  opts@ContourParameters = (/ vormin, 1600., 200./)
  opts@cnFillOn = True
  opts@cnMissingValFillColor = -1     ; use "transparent"
  opts@cnFillColors = vorcolors
  opts@cnLineColor  = "Brown"

  opts@pmLabelBarSide       = "right"
  opts@pmLabelBarHeightF    = 0.65
  opts@pmLabelBarOrthogonalPosF = 0.0
  ;opts@pmLabelBarWidthF     = 0.12
  opts@lbOrientation        = "Vertical"
  opts@lbTitleString        = "Vorticity"
  opts@lbTitlePosition      = "top"
  opts@lbTitleJust          = "topright"
  opts@lbTitleOffsetF       = 0.0
  opts@lbTitleExtentF       = 0.08
  ;opts@lbTopMarginF         = 0.02
  opts@lbTitleFontHeightF   = 0.015
  opts@lbLabelFontHeightF   = 0.015

  nsize = nt/5+1
  contourvr = new(nsize,graphic)

  ig = 0
  do it = 0,nt,5

     time_min = it+0.01
     time_min@units = "minutes since "+initstrs(0)+" "+initstrs(1)
     ;print(time_min)

     utc_datei = cd_calendar(time_min, -5)
     ;print(utc_datei)
     currtime = sprinti("%4.4d",utc_datei(0,0))+"-"+  \
                sprinti("%2.2d",utc_datei(0,1))+"-"+  \
                sprinti("%2.2d",utc_datei(0,2))+"_"+  \
                sprinti("%2.2d",utc_datei(0,3))+":"+  \
                sprinti("%2.2d",utc_datei(0,4))+":"+  \
                sprinti("%2.2d",utc_datei(0,5))
     print("Working on time: " + currtime + "." )

     b = addfile(datadir+"/wrfo2d_d01_"+currtime+".nc","r")

     ;adbz = b->comref(0,:,:)
     avor = b->comvor(0,:,:)*1.0E5
     avor@_FillValue = -9999

     ;---------- Plot vorticity --------------

     if (it .eq. nt) then
       opts@FieldTitle   = "Composite Vorticity"
       amin = min(avor)
       amax = max(avor)
       avor@units        = "1.0E-5 s-1, min="+amin+", max="+amax
       ;opts@NoTitles     = False
       opts@lbLabelBarOn = False
       tend=utc_datei(0,3)*100+utc_datei(0,4)
       if (tend .lt. 1000) then
         tend = tend + 10000
       end if
     else
       opts@FieldTitle   = ""
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
       wrf_smooth_2d(avor,smooth_opt)
     end if

     avor = where(avor.lt.vormin,avor@_FillValue,avor)

     contourvr(ig) = wrf_contour(a,wks,avor,opts)    ; plot relative vorticity

     ig = ig+1
  end do

  delete(opts)

  ua  = b->usfc__
  va  = b->vsfc__

  ds = dimsizes(avor)
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

  res@MainTitle = "Composite Vorticity Swath"
  res@TimeLabel = timescst   ; Set Valid time to use on plots


  ;---------- Plot wind vectors --------------

  opts = res
  opts@NumVectors = 30           ; density of wind barbs
  opts@vcGlyphStyle = "LineArrow"
  opts@FieldTitle = "Horizontal wind vector at 3 km AGL"
  opts@vcRefAnnoOn             = True
  opts@vcRefAnnoPerimOn        = False
  opts@vcRefAnnoString2On      = False
  opts@vcRefAnnoString1        = "$VMG$ m/s"
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


     ;---------- Plot reflectivity --------------

     ;;;opts = res
     ;;;opts@cnFillOn = True
     ;;;opts@ContourParameters = (/ 10., 75., 5./)
     ;;;opts@cnFillColors      = cumcolors
     ;;;opts@FieldTitle        = "Composite Reflectivity"
     ;;;opts@pmLabelBarSide       = "right"
     ;;;opts@pmLabelBarHeightF    = 0.65
     ;;;;opts@pmLabelBarWidthF     = 0.12
     ;;;opts@lbOrientation        = "Vertical"
     ;;;opts@lbTitlePosition      = "top"
     ;;;opts@lbTitleJust          = "topright"
     ;;;opts@lbTitleOffsetF       = 0.0
     ;;;opts@lbTitleExtentF       = 0.08
     ;;;opts@lbTopMarginF         = 0.02
     ;;;opts@lbTitleFontHeightF   = 0.015
     ;;;opts@lbLabelFontHeightF   = 0.015


     ;;;contourdbz = wrf_contour(a,wks,adbz,opts)    ; plot Reflectivity
     ;;;delete(opts)


     ;---------- Put all together --------------

     plot = wrf_map_overlays(a,wks,array_append_record(contourvr,vectora,0),pltres,mpres)

     ;;;;--- Attach the shapefile polylines ---

     ;;;;--- Attach storm reports ---
     ;wget http://www.spc.noaa.gov/climo/reports/160509_rpts.csv
     datain = asciiread(srptdir,-1,"string")

     t=str_match_ind(datain,"Time,F_Scale,Location,County,State,Lat,Lon,Comments")
     h=str_match_ind(datain,"Time,Size,Location,County,State,Lat,Lon,Comments")
     w=str_match_ind(datain,"Time,Speed,Location,County,State,Lat,Lon,Comments")
     l=dimsizes(datain)

     delim = ","

     dator=(/t,h,w,l/)
     datcl=(/"red","green","blue","black"/)
     datmk=(/7,9,11/)
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

     ;;;--- draw the map and the shapefile outlines ---

     ;;;draw(plot)
     ;;;frame(wks)

  ;;;end do        ; END OF HEIGHTS LOOP

;--- draw the map and the shapefile outlines ---
     draw(plot)
     frame(wks)
end
