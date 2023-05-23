;;;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;;;load "$NSSLVAR/nclscripts/WRFUserARW.ncl"
;;;
;;;begin
;;;  a = addfile("./wrfout_d02_2009-06-11_23:30:00.nc","r")
;;;  b = addfile("./wrf2d_d02_2009-06-11_23:30:00.nc","r")
;;;  wks = gsn_open_wks("x11","vor3km")


;;;;;;;;; TEMPLATE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; --- Customized Color map

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

                   ;(/ 0.000, 0.925, 0.925 /), \  ; !28- begin REF
  refcolors =    (/                   \
                   (/ 1.000, 1.000, 1.000 /), \
                   (/ 0.004, 0.627, 0.961 /), \  ; !29
                   (/ 0.000, 0.000, 0.965 /), \  ; !30
                   (/ 0.000, 1.000, 0.000 /), \  ; !31 green
                   (/ 0.000, 0.784, 0.000 /), \  ; !32
                   (/ 0.000, 0.565, 0.000 /), \  ; !33
                   (/ 1.000, 1.000, 0.000 /), \  ; !34 yellow
                   (/ 0.906, 0.753, 0.000 /), \  ; !35
                   (/ 1.000, 0.565, 0.000 /), \  ; !36
                   (/ 1.000, 0.000, 0.000 /), \  ; !37 red
                   (/ 0.839, 0.000, 0.000 /), \  ; !38
                   (/ 0.753, 0.000, 0.000 /), \  ; !39
                   (/ 1.000, 0.000, 1.000 /), \  ; !40 magenta
                   (/ 0.600, 0.333, 0.788 /), \  ; !41
                   (/ 0.900, 0.900, 0.900 /)  \  ; !42 white - end of REF col map
                /)

  ;Set some basic resources
  res                      = True
  res@Footer               = True
  res@InitTime             = True

  pltres                   = True
  pltres@PanelPlot         = True   ; Tells wrf_map_overlays not to remove overlays

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

  ;--- Which times and how many time steps are in the data set? ---

  times  = wrf_user_getvar(a,"times",-1)  ; get all times in the file
  ntimes = dimsizes(times)                ; number of times in the file

;---------------------------------------------------------------

  it = 0

  do it = 0,ntimes-1               ; TIME LOOP

     ua  = b->usfc__
     va  = b->vsfc__

     ;adbz = b->comref(0,:,:)
     adbz = b->ref3km(0,:,:)
     avor = b->comvor(0,:,:)*1.0E5

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

     print("Working on time: " + times(it) + "." )

     res@MainTitle = "Composite Vorticity & Reflectivity at 3 km"
     res@TimeLabel = timescst   ; Set Valid time to use on plots


     ;---------- Plot wind vectors --------------

     opts = res
     opts@NumVectors = 30           ; density of wind barbs
     opts@vcGlyphStyle = "LineArrow"
     opts@FieldTitle = "Horizontal wind vector at 3km AGL"
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

     ;---------- Plot vorticity --------------

     opts = res
     opts@ContourParameters = (/ 200., 1600., 200./)
     opts@cnLineColor = "Black"
     opts@FieldTitle = "Composite Vorticity (1.0E5 s-1)"

     amin = min(avor)
     amax = max(avor)
     avor@units= "1.0E-5 s-1, min="+amin+", max="+amax

     if (smooth_opt .gt. 0) then
       wrf_smooth_2d(avor,smooth_opt)
     end if

     contourvr = wrf_contour(a,wks,avor,opts)    ; plot relative vorticity
     delete(opts)


     ;---------- Plot reflectivity --------------

     opts = res
     opts@cnFillOn = True
     opts@ContourParameters = (/ 10., 75., 5./)
     opts@cnFillColors      = refcolors
     opts@FieldTitle        = "Reflectivity at 3km AGL"
     ;;;
     ;;; Reflectivity legend on the right
     ;;;
     opts@pmLabelBarSide       = "right"
     opts@pmLabelBarHeightF    = 0.65
     ;opts@pmLabelBarWidthF     = 0.12
     opts@lbOrientation        = "Vertical"
     opts@lbTitlePosition      = "top"
     opts@lbTitleJust          = "topright"
     opts@lbTitleOffsetF       = 0.0
     opts@lbTitleExtentF       = 0.08
     ;opts@lbTopMarginF         = 0.02
     opts@lbTitleFontHeightF   = 0.015
     opts@lbLabelFontHeightF   = 0.015


     if (smooth_opt .gt. 0) then
       wrf_smooth_2d(adbz,smooth_opt)
     end if

     contourdbz = wrf_contour(a,wks,adbz,opts)    ; plot Reflectivity
     delete(opts)

     ;---------- Put all together --------------

     plot = wrf_map_overlays(a,wks,(/vectora,contourdbz,contourvr/),pltres,mpres)

     ;;;;--- Attach the shapefile polylines ---

     ;;;--- draw the map and the shapefile outlines ---

     ;;;draw(plot)
     ;;;frame(wks)

  ;;;end do        ; END OF HEIGHTS LOOP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;end
