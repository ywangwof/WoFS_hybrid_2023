;;;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;;;load "$NSSLVAR/nclscripts/WRFUserARW.ncl"
;;;
;;;begin
;;;  a = addfile("./wrfout_d02_2009-06-11_23:30:00.nc","r")
;;;  wks = gsn_open_wks("x11","csectew")


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
  pltres@gsnMaximize       = True
  pltres@gsnPaperOrientation = "portrait"

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

  ;--- Which times and how many time steps are in the data set? ---

  times  = wrf_user_getvar(a,"times",-1)  ; get all times in the file
  ntimes = dimsizes(times)                ; number of times in the file

;---------------------------------------------------------------


  do it = 0,ntimes-1               ; TIME LOOP

     print("Working on time: " + times(it) )
     ;res@TimeLabel = times(it)   ; Set Valid time to use on plots
     res@TimeLabel = timescst

  ua  = wrf_user_getvar(a,"ua",it)      ; 3D U at mass points
     va  = wrf_user_getvar(a,"va",it)      ; 3D U at mass points
     wa  = wrf_user_getvar(a,"wa",it)      ; 3D V at mass points
     msft = a->MAPFAC_M(0,:,:)*1.0D

     ds = dimsizes(ua)
     rk = dimsizes(ds)
     nx = ds(rk-1)
     ny = ds(rk-2)
     nz = ds(rk-3)

     ;print(max(wa))
     ;print(min(wa))

     vr  = wrf_user_getvar(a,"rvo",it)      ; 3D relative vorticity
     ;;;vor = new((/nz,ny,nx/),double)
     ;;;VOR::DCOMPUTECURL(vor,flt2dble(ua),flt2dble(va),msft,a@DX,a@DY,nx,ny,nz)
     ;;;vr = doubletofloat(vor)*1.0E5
     ;;;copy_VarAtts(ua,vr)
     ;;;vr@description = "Horizontal relative vorticity"
     ;;;vr@units = "1.0E-5 s-1"

     ; First get the variables we will need
     ; Both dbz and mdbz will be calculated using intercept parameters
     ; for rain, snow, and graupel, which are consistent with
     ; Thompson, Rasmussen, and Manning (2004, Monthly Weather Review,
     ; Vol. 132, No. 2, pp. 519-542.)
     ;	First "1" in wrf_user_getvar
     ; Frozen particles that are at a temperature above freezing will be
     ; assumed to scatter as a liquid particle.
     ;	Second "1" in wrf_user_getvar

     ;mdbz = wrf_user_getvar(a,(/"mdbz","1","1"/),it)
     ;dbz = wrf_user_getvar(a,(/"dbz","1","1"/),it)

     ;amdbz = wrf_user_getvar(a,"mdbz",it)
     adbz = wrf_user_getvar(a,dbzvarn,it)

     z = wrf_user_getvar(a,"z",it)
     zmin = 0.
     zmax = max(z)/1000.
     ;nz   = floattoint(zmax/2 + 1)
     tvalues = ispan(0,floattoint(zmax),2)

;;;
;;; Get vorticity max indices
;;;
     ;; cross section
     dima = dimsizes(vr)
     a1D  = ndtooned(vr)
     indices = ind_resolve(maxind(a1D),dima)
     ;print(indices)

     ii = indices(0,2)
     jj = indices(0,1)
     dbz_plane = wrf_user_intrp3d(adbz,z,"v",(/jj,jj/),90.0,False)
     ua_plane  = wrf_user_intrp3d(ua,z,"v",(/jj,jj/),90.0,False)
     wa_plane  = wrf_user_intrp3d(wa,z,"v",(/jj,jj/),90.0,False)
     vr_plane  = wrf_user_intrp3d(vr,z,"v",(/jj,jj/),90.0,False)

     wspd = sqrt(ua_plane^2+wa_plane^2)

     ;print(max(wa_plane))
     ;print(min(wa_plane))

     dim = dimsizes(vr_plane)                      ; Find the data span - for use in labels
     zspan = dim(0)

     ; --- Plot UW wind ----
     res@MainTitle     = "East-West cross through maximum vorticity"
     res@tiYAxisString           = "Height (km)"
     ;res@cnMissingValPerimOn     = True
     ;res@cnMissingValFillColor   = 0
     ;res@cnMissingValFillPattern = 11
     res@tmYLMode                = "Explicit"
     res@tmYLValues              = tvalues*zspan/zmax        ; Create tick marks
     res@tmYLLabels              = sprintf("%.1f",tvalues)   ; Create labels
     ;;;res@tmXBMode                = "Explicit"
     ;;;res@tmXBValues              = xvalues
     ;;;res@tmXBLabels              = sprintf("%.1f",(xvalues-iloc)*a@DX/1000.)
     res@tiXAxisFontHeightF      = 0.020
     res@tiYAxisFontHeightF      = 0.020
     res@tmXBMajorLengthF        = 0.02
     res@tmYLMajorLengthF        = 0.02
     res@tmYLLabelFontHeightF    = 0.015
     res@PlotOrientation         = vr_plane@Orientation

     ;print("nz="+nz+"; zspan= "+zspan)
     ;print("zmin="+zmin+"; zmax= "+zmax)

     opts = res
     opts@NumVectors = 30           ; density of wind barbs
     opts@vcGlyphStyle = "LineArrow"
     opts@FieldTitle = "UW wind vector"
     opts@vcRefAnnoOn             = True
     opts@vcRefAnnoPerimOn        = False
     opts@vcRefAnnoString2On      = False
     opts@vcRefAnnoString1        = "$VMG$ m/s"
     opts@vcRefAnnoSide           = "Top"
     opts@vcRefAnnoParallelPosF   =  0.92
     opts@vcRefAnnoOrthogonalPosF = -0.22

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

     vectora = wrf_vector_scalar(a,wks,ua_plane,wa_plane,wspd,opts)
     delete(opts)

     ;---------- Plot vorticity --------------

     amax = max(vr_plane)
     amin = min(vr_plane)

     opts = res
     opts@ContourParameters = (/ 100., 1600., 200./)
     opts@cnLineColor = "Black"
     ;;;opts@cnMonoLineColor = False
     ;;;opts@cnMonoLineDashPattern = False
     ;;;opts@cnLineColors = ndtooned( (/lclr1,lclr2/) )
     ;;;opts@cnLevelSelectionMode = "ExplicitLevels"
     ;;;opts@cnLevels = ndtooned( (/half1,half2/) )
     ;;;opts@cnLineDashPatterns = ndtooned( (/ltyp1, ltyp2 /) )

     opts@amax = amax
     opts@amin = amin

     contourvr = wrf_contour(a,wks,vr_plane,opts)      ; plot vorticity
     delete(opts)

     ;---------- Plot W contour --------------
     opts = res
     opts@ContourParameters = (/ -10., 10., 1./)
     opts@cnLineColor = "Blue"
     opts@gsnContourNegLineDashPattern = 2
     contourw = wrf_contour(a,wks,wa_plane,opts)       ; plot W contour
     delete(opts)

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

     contourdbz = wrf_contour(a,wks,dbz_plane,opts)    ; plot reflectivity
     delete(opts)

     ;---------- Put all together --------------

     plot = wrf_overlays(a,wks,(/contourdbz,vectora,contourvr/),pltres)


     ;--- draw the map and the shapefile outlines ---

     lnres = True
     lnres@gsLineColor      = "Blue"
     lnres@gsLineThicknessF = 2
     line1 = gsn_add_polyline(wks,plot,(/ii,ii/),(/0.0,zspan/),lnres)
     delete(lnres)


     ;--- draw the map and the shapefile outlines ---
;;;     draw(plot)
;;;     frame(wks)
;;;
;;;  end do        ; END OF TIME LOOP
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;end

