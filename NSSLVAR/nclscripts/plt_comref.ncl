;;;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;;;load "$NSSLVAR/nclscripts/WRFUserARW.ncl"
;;;
;;;begin
;;;  a = addfile("./wrfout_d02_2009-06-11_23:30:00.nc","r")
;;;  wks = gsn_open_wks("x11","vor3km")


;;;;;;;;; TEMPLATE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; --- Customized Color map

                   ;(/ 0.000, 0.925, 0.925 /), \  ; !28- begin REF
  cumcolors =    (/                   \
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



  gsn_define_colormap(wks,"WhViBlGrYeOrReWh")

  ;Set some basic resources
  res                      = True
  res@Footer               = True
  res@InitTime             = True

  pltres                   = True
  pltres@PanelPlot         = True   ; Tells wrf_map_overlays not to remove overlays
  res@MainTitle            = "Composite Reflectivity"

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
  mpres@mpCountyLineDashPattern     = 2
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


  do it = 0,ntimes-1               ; TIME LOOP

     print("Working on time: " + times(it) )
     ;res@TimeLabel = times(it)   ; Set Valid time to use on plots
     res@TimeLabel = timescst     ; Set Valid time to use on plots

     ua  = wrf_user_getvar(a,"ua",it)      ; 3D U at mass points
     va  = wrf_user_getvar(a,"va",it)      ; 3D V at mass points

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

     amdbz = wrf_user_getvar(a,"m"+dbzvarn,it)
     ;adbz = wrf_user_getvar(a,"dbz",it)

     wspd = sqrt(ua(0,:,:)^2+va(0,:,:)^2)                    ;;; Horizontal wind speed

     ;---------- Plot Wind vectors --------------

     opts = res
     opts@NumVectors = 30           ; density of wind barbs
     opts@vcGlyphStyle = "LineArrow"
     opts@FieldTitle = "Horizontal wind vector at surface"
     opts@vcRefAnnoOn             = True
     opts@vcRefAnnoPerimOn        = False
     opts@vcRefAnnoString2On      = False
     opts@vcRefAnnoString1        = "$VMG$ m/s"
     opts@vcRefAnnoSide           = "Top"
     opts@vcRefAnnoParallelPosF   =  0.92
     opts@vcRefAnnoOrthogonalPosF = -0.23

;;;
;;;  Added wind speed legend bar
;;;
     ;;;opts@pmLabelBarDisplayMode    = "Always"
     ;;;opts@pmLabelBarSide           = "Bottom"
     ;;;opts@pmLabelBarHeightF        = 0.12
     ;;;opts@pmLabelBarWidthF         = 0.8
     ;;;opts@lbOrientation            = "Horizontal"
     ;;;opts@lbPerimOn                = False
     ;;;opts@lbTitleString            = "Wind Speed"
     ;;;opts@lbAutoManage             = False
     ;;;opts@lbTitleOffsetF           = 0.025
     ;;;opts@lbTitleFontHeightF       = 0.02
     ;;;opts@lbLabelFontHeightF       = 0.015
     ;opts@lbLabelAutoStride        = True

     ;;;opts@vcLevelSelectionMode      = "ExplicitLevels"
     ;;;opts@vcLevels                  = (/10.8,17.2,24.5/)

     ;;;vectora = wrf_vector_scalar(a,wks,ua(0,:,:),va(0,:,:),wspd,opts)
     vectora = wrf_vector(a,wks,ua(0,:,:),va(0,:,:),opts)
     delete(opts)

     ;---------- Plot Reflectivity --------------

     opts = res
     opts@cnFillOn = True
     opts@ContourParameters = (/ 10., 75., 5./)
     ;;;opts@cnFillColors      = cumcolors

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

     contourma = wrf_contour(a,wks,amdbz,opts)
     delete(opts)

     ;---------- Put all together --------------

     plot = wrf_map_overlays(a,wks,(/contourma,vectora/),pltres,mpres)

;;;     ;--- draw the map and the shapefile outlines ---
;;;
;;;     draw(plot)
;;;     frame(wks)
;;;
;;;  end do        ; END OF TIME LOOP
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;end
