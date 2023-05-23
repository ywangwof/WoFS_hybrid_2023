;;;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;;;load "$NSSLVAR/nclscripts/WRFUserARW.ncl"
;;;
;;;begin
;;;  a = addfile("./wrfout_d02_2009-06-11_23:30:00.nc","r")
;;;  wks = gsn_open_wks("x11","vor3km")


;;;;;;;;; TEMPLATE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  gsn_define_colormap(wks,"WhViBlGrYeOrReWh")

  ;Set some basic resources
  res                      = True
  res@Footer               = True
  res@InitTime             = True
  res@MainTitle            = "Surface Temperature/Pressure"

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
     res@TimeLabel = timescst

     p  = wrf_user_getvar(a,"pressure",it)
     tc = wrf_user_getvar(a,"tk",it) - 273.15

     ;---------- Plot surface pressure --------------

     opts = res
     contourp = wrf_contour(a,wks,p(1,:,:),opts)
     delete(opts)

     ;---------- Plot surface temperature --------------

     opts = res
     opts@cnFillOn = True
     opts@UnitLabel = "C"
     opts@FieldTitle = "Temperature"
     contourt = wrf_contour(a,wks,tc(1,:,:),opts)
     delete(opts)

     ;---------- Put all together --------------

     plot = wrf_map_overlays(a,wks,(/contourp,contourt/),pltres,mpres)

     ;;--- Attach the shapefile polylines here ---

     ;--- draw the map and the shapefile outlines ---

;;;     draw(plot)
;;;     frame(wks)
;;;
;;;  end do        ; END OF TIME LOOP
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;end
