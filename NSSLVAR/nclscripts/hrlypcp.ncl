;load "/scratch/software/NCL/default/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;load "/scratch/software/NCL/default/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"

;begin
;  a = addfile("./MRMS_CREF_2018-05-29_00:00:00.nc","r")
;  wks = gsn_open_wks("png","vor3km")


;;;;;;;;; TEMPLATE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  a = addfile(filename,"r")
;;; --- Customized Color map

   nexrad  = (/                 \
             (/1.0, 1.0, 1.0/), \
;             (/0.8, 0.8, 0.8/), \
;             (/0.6, 0.4, 0.6/), \
;             (/0.388, 0.4, 0.6/), \
;             (/0.188, 0.2, 0.561/), \
;             (/0.188, 0.4, 0.6/), \
             (/0.388, 0.6, 0.761/), \
             (/0.388, 0.761, 0.859/), \
             (/0.2,   0.4,  0.2/), \
             (/0.188, 0.6,0.4/), \
             (/0.6, 0.788, 0.6/), \
             (/0.960, 0.968, 0.788/), \
             (/0.968, 0.961, 0.2/), \
             (/0.980, 0.8, 0.188/), \
             (/0.870, 0.568, 0.180/), \
             (/0.980, 0.388, 0.0706/), \
             (/0.980, 0.059, 0.0509/), \
             (/0.8, 0.188,0.2/), \
             (/0.690, 0.039, 0.2/), \
             (/0.8, 0.4, 0.6/) \
             /)

  ;timescst = "2018-05-29"
  gsn_define_colormap(wks,"WhViBlGrYeOrReWh")

  ;Set some basic resources
  res                      = True
  res@Footer               = True
  res@InitTime             = True

  pltres                   = True
  pltres@PanelPlot         = True   ; Tells wrf_map_overlays not to remove overlays
  res@MainTitle            = "Hourly Precipitation ("+title+")"

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
  ;mpres@mpOutlineBoundarySets       = "USStates"
  mpres@mpGridAndLimbOn             = False
  mpres@mpGridSpacingF              = 1

  mpres@gsnMaximize         = True
  mpres@gsnPaperOrientation = "portrait"

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

  ;--- Which times and how many time steps are in the data set? ---

;---------------------------------------------------------------



     print("Working on time: " + timescst )
     ;res@TimeLabel = times(it)   ; Set Valid time to use on plots
     res@TimeLabel = timescst     ; Set Valid time to use on plots


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

     ;dbz3d = a->REFMOSAIC3D
     dbz3d = a->$field$

     if (do_sub) then
       b = addfile(filename0,"r")
       dbz3d_prev = b->$field$
       dbz3d = dbz3d-dbz3d_prev
     end if

     dims = dimsizes(dbz3d)
     ndim = dimsizes(dims)

     if (ndim .eq. 4) then
       amdbz = dim_max_n(dbz3d(0,:,:,:),0)
     else
       amdbz = dbz3d(0,:,:)
     end if

     amdbz@description="Precipitation"

     levels = (/0.01,0.10,0.50,1.00,1.50,2.00,2.50,3.00,4.00,5.00,7.00,10.00,15.00,20.00/)
     ;---------- Plot Precipitation --------------

     opts = res
     opts@cnFillOn = True
     opts@cnLevelSelectionMode = "ExplicitLevels"
     opts@cnLevels = levels

     ;;opts@ContourParameters = (/ 10., 75., 5./)
     opts@cnFillColors      = nexrad

;;;
;;; Reflectivity legend on the right
;;;
     opts@pmLabelBarSide       = "right"
     opts@pmLabelBarHeightF    = 0.65
     ;opts@pmLabelBarWidthF     = 0.12
     opts@pmLabelBarOrthogonalPosF = .0000000015
     opts@lbOrientation        = "Vertical"
     opts@lbTitlePosition      = "top"
     opts@lbTitleJust          = "topcenter"
     opts@lbTitleString        = "mm"
     opts@lbTitleOffsetF       = 0.0
     opts@lbTitleExtentF       = 0.08
     ;opts@lbTopMarginF         = 0.02
     opts@lbTitleFontHeightF   = 0.015
     opts@lbLabelFontHeightF   = 0.015
     opts@cnExplicitLabelBarLabelsOn = True
     opts@lbLabelStrings       = sprintf("%5.2f",levels)   ; Format the labels

     contourma = wrf_contour(a,wks,amdbz,opts)
     delete(opts)

     ;---------- Put all together --------------

     plot = wrf_map_overlays(a,wks,(/contourma/),pltres,mpres)

     ;--- draw the map and the shapefile outlines ---

     draw(plot)
     frame(wks)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
end
