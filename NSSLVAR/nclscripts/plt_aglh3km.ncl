;;;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;;;load "$NSSLVAR/nclscripts/WRFUserARW.ncl"
;;;
;;;begin
;;;  a = addfile("./wrfout_d02_2009-06-11_23:30:00.nc","r")
;;;  wks = gsn_open_wks("x11","vor3km")

;;;heights = (/ 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5, 10.5, 11.5, 12.5, 13.5 /)

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

  refcolors =   (/ (/ 1.000, 1.000, 1.000 /), \
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
                   ;(/ 0.000, 0.925, 0.925 /), \  ; !28- begin REF


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

  nheights = dimsizes(heights)


;---------------------------------------------------------------

  it = 0

  ua  = wrf_user_getvar(a,"ua",it)      ; 3D U at mass points
  va  = wrf_user_getvar(a,"va",it)      ; 3D V at mass points

;;;  ;vr  = wrf_user_getvar(a,"rvo",it)      ; 3D relative vorticity
;;;  ;hl2d  = wrf_user_getvar(a,"helicity",it)      ; 3D Helicity
;;;
;;;  ; First get the variables we will need
;;;  ; Both dbz and mdbz will be calculated using intercept parameters
;;;  ; for rain, snow, and graupel, which are consistent with
;;;  ; Thompson, Rasmussen, and Manning (2004, Monthly Weather Review,
;;;  ; Vol. 132, No. 2, pp. 519-542.)
;;;  ;	First "1" in wrf_user_getvar
;;;  ; Frozen particles that are at a temperature above freezing will be
;;;  ; assumed to scatter as a liquid particle.
;;;  ;	Second "1" in wrf_user_getvar
;;;
;;;  ;mdbz = wrf_user_getvar(a,(/"mdbz","1","1"/),it)
;;;  ;dbz = wrf_user_getvar(a,(/"dbz","1","1"/),it)
;;;
;;;  ;amdbz = wrf_user_getvar(a,"mdbz",it)
;;;
;;; CSM3DVAR version of DBZ
;;;
  adbz = wrf_user_getvar(a,dbzvarn,it)

  ;; Interpolations
  zsea = wrf_user_getvar(a,"z",it)    ; z on mass points
  ter  = wrf_user_getvar(a,"ter",it)  ; terrain heights
  ;rvo3d  = wrf_user_getvar(a,"avo",it)  ; terrain heights
  zter = conform(zsea,ter,(/1,2/))
  zagl = zsea-zter

  do ih = 0,nheights-1               ; TIME LOOP

     print("Working on time: " + times(it) + " at " + heights(ih) + " km." )

     res@MainTitle = jobtype + " at "+heights(ih)+" km above ground"
     res@TimeLabel = timescst   ; Set Valid time to use on plots

     ;---------- Interpolate to desired height --------------
     height = heights(ih)*1000.0
     dbz2d = wrf_interp_3d_z(adbz,zagl,height)
     ;hl2d  = wrf_interp_3d_z(hl,z3d,height)
     ;vr2d  = wrf_interp_3d_z(vr,zagl,height)
     ua2d  = wrf_interp_3d_z(ua,zagl,height)
     va2d  = wrf_interp_3d_z(va,zagl,height)
     vrplt = wrf_get_avo2d(ua2d,va2d,a@DX,a@DY)
     ;vrplt = wrf_interp_3d_z(rvo3d,zagl,height)
     ;;;vr2d  = wrf_get_avo2d(ua2d,va2d,a@DX,a@DY)

     ;;;ds = dimsizes(vr2d)
     ;;;rk = dimsizes(ds)
     ;;;rvo = new(ds,float)     ;;; vorticity gradient
     ;;;do j = 1, ds(rk-2)-2
     ;;;  do i = 1, ds(rk-1) -2
     ;;;    rvo(j,i) = ((vr2d(j,i+1)-vr2d(j,i-1))/(2*a@DX))+   \
     ;;;               ((vr2d(j+1,i)-vr2d(j-1,i))/(2*a@DY))
     ;;;  end do
     ;;;end do
     ;;;;vr2d@_FillValue = 0.0
     ;;;vrplt = mask(vr2d,(abs(rvo) .lt. 0.1),True)   ;;; mask out gradient > 0.1

     wspd = sqrt(ua2d^2+va2d^2)                    ;;; Horizontal wind speed

     amin = min(vrplt)
     amax = max(vrplt)
     vrplt@units= "1.0E-5 s-1, min="+amin+", max="+amax

     wspd = sqrt(ua2d^2+va2d^2)                    ;;; Horizontal wind speed


     ;---------- Plot wind vectors --------------

     opts = res
     opts@NumVectors = 30           ; density of wind barbs
     opts@vcGlyphStyle = "LineArrow"
     opts@FieldTitle = "Horizontal wind vector at "+heights(ih)+" km above ground"
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
     opts@ContourParameters = (/ 100., 1200., 80./)
     opts@cnLineColor = "Black"
     opts@FieldTitle = "Relative vorticity"

     if (smooth_opt .gt. 0) then
       wrf_smooth_2d(vrplt,smooth_opt)
     end if

     contourvr = wrf_contour(a,wks,vrplt,opts)    ; plot relative vorticity
     delete(opts)

;;;     ;---------- Plot helicity --------------
;;;
;;;     ;opts = res
;;;     ;;opts@ContourParameters = (/ 0., 900., 300./)
;;;     ;contourhl = wrf_contour(a,wks,hl2d,opts)    ; plot only lowest level
;;;     ;delete(opts)
;;;
;;;     ;opts = res
;;;     ;line2d = conform(hl2d,-1.,-1)
;;;     ;line2d(142,:) = 1.0
;;;     ;opts@ContourParameters = (/ 0., 1., 1./)
;;;     ;opts@cnConstFLabelOn   = False
;;;     ;contourline = wrf_contour(a,wks,line2d,opts)    ; plot only lowest level
;;;     ;delete(opts)

     ;---------- Plot reflectivity --------------

     opts = res
     opts@cnFillOn = True
     opts@ContourParameters = (/ 10., 75., 5./)
     opts@cnFillColors      = refcolors
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
       wrf_smooth_2d(dbz2d,smooth_opt)
     end if

     contourdbz = wrf_contour(a,wks,dbz2d,opts)    ; plot Reflectivity
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
