;;;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;;;load "$NSSLVAR/nclscripts/WRFUserARW.ncl"
;;;
;;;external DIV "$NSSLVAR/nclscripts/wrfdivergence.so"
;;;external VOR "$NSSLVAR/nclscripts/wrfvorticity.so"
;;;
;;;begin
;;;  a = addfile("./wrfout_d02_2009-06-11_23:30:00.nc","r")
;;;  wks = gsn_open_wks("x11","vor3km")

;;;heights = (/ 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5, 10.5, 11.5, 12.5, 13.5 /)

;;;;;;;;; TEMPLATE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; --- Customized Color map

cumRGBcolors = (/                   \
                  (/ 255,255,255 /),  \
                  (/   1,160,246 /),  \
                  (/   1,  0,246 /),  \
                  (/   0,239,  0 /),  \
                  (/   0,144,  0 /),  \
                  (/ 255,255,  0 /),  \
                  (/ 231,192,  0 /),  \
                  (/ 255,144,  2 /),  \
                  (/ 255,0,    0 /),  \
                  (/ 166,0,    0 /),  \
                  (/ 101,0,    0 /),  \
                  (/ 255,0,  255 /),  \
                  (/ 255,255,255 /)   \
                /)
;                  (/   0,200,  0 /),  \
;                  (/ 128,0,  128 /),  \

cumcolors = cumRGBcolors / 255.0


  gsn_define_colormap(wks,"WhViBlGrYeOrReWh")

  ;Set some basic resources
  res                      = True
  res@Footer               = True
  res@InitTime             = True

  pltres                   = True
  pltres@PanelPlot         = True   ; Tells wrf_map_overlays not to remove overlays

  mpres                             = True
  ;mpres@mpDataBaseVersion           = "Ncarg4_1"
  mpres@mpDataBaseVersion           = "HighRes"
  mpres@mpGeophysicalLineColor      = "Black"
  mpres@mpGridLineColor             = "Brown"
  mpres@mpGridLineDashPattern       = 2
  mpres@mpGridLineThicknessF        = 1.5
  mpres@mpLimbLineColor             = "Gray30"
  mpres@mpNationalLineColor         = "Gray30"
  mpres@mpPerimLineColor            = "Gray30"
  mpres@mpUSStateLineColor          = "Gray30"
  mpres@mpOutlineBoundarySets       = "AllBoundaries"
  mpres@mpGridAndLimbOn             = True
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
  msft = a->MAPFAC_M(0,:,:)*1.0D

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
  adbz = wrf_user_getvar(a,"dbz",it)

  ;; Interpolations
  zsea = wrf_user_getvar(a,"z",it)    ; z on mass points
  ter  = wrf_user_getvar(a,"ter",it)  ; terrain heights
  zter = conform(zsea,ter,(/1,2/))
  zagl = zsea-zter

  do ih = 0,nheights-1               ; TIME LOOP

     print("Working on time: " + times(it) + " at " + heights(ih) + " km." )

     res@MainTitle = "Analysis at "+heights(ih)+" km above ground"
     res@TimeLabel = timescst   ; Set Valid time to use on plots

     ;---------- Interpolate to desired height --------------
     height = heights(ih)*1000.0
     dbz2d = wrf_interp_3d_z(adbz,zagl,height)
     ;hl2d  = wrf_interp_3d_z(hl,z3d,height)
     ;vr2d  = wrf_interp_3d_z(vr,zagl,height)
     ua2d  = wrf_interp_3d_z(ua,zagl,height)
     va2d  = wrf_interp_3d_z(va,zagl,height)
;;;     vr2d  = wrf_get_avo2d(ua2d,va2d,a@DX,a@DY)
;;;
;;;     ds = dimsizes(vr2d)
;;;     rk = dimsizes(ds)
;;;     rvo = new(ds,float)     ;;; vorticity gradient
;;;     do j = 1, ds(rk-2)-2
;;;       do i = 1, ds(rk-1) -2
;;;         rvo(j,i) = ((vr2d(j,i+1)-vr2d(j,i-1))/(2*a@DX))+   \
;;;                    ((vr2d(j+1,i)-vr2d(j-1,i))/(2*a@DY))
;;;       end do
;;;     end do
;;;     ;vr2d@_FillValue = 0.0
;;;     vrplt = mask(vr2d,(abs(rvo) .lt. 0.1),True)   ;;; mask out gradient > 0.1

     wspd = sqrt(ua2d^2+va2d^2)                    ;;; Horizontal wind speed

     ;---------- Get DIV and VOR by using fortran subroutines ---------

     ds = dimsizes(msft)
     rk = dimsizes(ds)
     nx = ds(rk-1)
     ny = ds(rk-2)

     ;;;ua3d = reshape(ua2d,(/1,ny,nx/))
     ;;;va3d = reshape(va2d,(/1,ny,nx/))
     ua3d = onedtond(ndtooned(ua2d),(/1,ny,nx/))*1.0D
     va3d = onedtond(ndtooned(va2d),(/1,ny,nx/))*1.0D

     ;div2d = new((/1,ny,nx/),double)
     ;DIV::DCOMPUTEDIV(div2d,ua3d,va3d,msft,a@DX,a@DY,nx,ny,1)
     ;div2d = div2d*1.0E5
     ;copy_VarAtts(ua2d,div2d)
     ;div2d@description = "Horizontal Divergence"
     ;div2d@units = "1.0E-5 s-1"

     vor2d = new((/1,ny,nx/),double)
     VOR::DCOMPUTECURL(vor2d,ua3d,va3d,msft,a@DX,a@DY,nx,ny,1)
     vor2d = vor2d*1.0E5
     copy_VarAtts(ua2d,vor2d)
     vor2d@description = "Relative vorticity"
     vor2d@units = "1.0E-5 s-1"

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

     ;;;opts@vcLevelSelectionMode      = "ExplicitLevels"
     ;;;opts@vcLevels                  = (/10.8,17.2,24.5/)

     ;;;vectora = wrf_vector_scalar(a,wks,ua2d,va2d,wspd,opts)
     vectora = wrf_vector(a,wks,ua2d,va2d,opts)
     delete(opts)

     ;---------- Plot vorticity --------------

     cinc = 10
     amax = max(abs(vor2d))
     imax = doubletoint(ceil(amax))/cinc*cinc+cinc
     nline = (imax-10)/10+1

     half1 = fspan(-1.0*imax,-1.0*cinc,nline)
     half2 = fspan(  cinc,1.0*imax,nline)
     ltyp1 = conform(half1,11,-1)
     ltyp2 = conform(half2,0,-1)
     lclr1 = conform(half1,"Red",-1)
     lclr2 = conform(half2,"Blue",-1)

     amax = max(vor2d)
     amin = min(vor2d)

     opts = res
;;;     ;opts@ContourParameters = (/ 100., 1600., 100./)
;;;     ;opts@gsnContourNegLineDashPattern = 16
     opts@cnLineColor = "Brown"
     opts@FieldTitle = "Horizontal Relative vorticity"
     opts@cnMonoLineColor = False
     opts@cnMonoLineDashPattern = False
     opts@cnLineColors = ndtooned( (/lclr1,lclr2/) )
     opts@cnLevelSelectionMode = "ExplicitLevels"
     opts@cnLevels = ndtooned( (/half1,half2/) )
     opts@cnLineDashPatterns = ndtooned( (/ltyp1, ltyp2 /) )
     opts@cinc = cinc
     opts@amax = amax
     opts@amin = amin
;;;     contourvr = wrf_contour(a,wks,vrplt,opts)    ; plot relative vorticity
     contourvr = wrf_contour(a,wks,vor2d(0,:,:),opts)    ; plot relative vorticity
     delete(opts)

     delete(half1)
     delete(half2)
     delete(ltyp1)
     delete(ltyp2)
     delete(lclr1)
     delete(lclr2)


     ;---------- Plot Dievergence --------------

     ;amax = max(abs(div2d))
     ;imax = doubletoint(ceil(amax))/10*10+10
     ;nline = (imax-10)/10+1
     ;
     ;half1 = fspan(-1.0*imax,-10.0,nline)
     ;half2 = fspan(  10.0,1.0*imax,nline)
     ;ltyp1 = conform(half1,2,-1)
     ;ltyp2 = conform(half2,0,-1)
     ;lclr1 = conform(half1,"Red",-1)
     ;lclr2 = conform(half2,"Blue",-1)
     ;
     ;opts = res
;;;  ;   ;opts@ContourParameters = (/ -800., 1000., 250./)
;;;  ;   ;opts@gsnContourNegLineDashPattern = 16
     ;opts@cnLineColor = "Blue"
     ;opts@FieldTitle = "Horizontal Divergence"
     ;opts@cnMonoLineColor = False
     ;opts@cnMonoLineDashPattern = False
     ;opts@cnLineColors = ndtooned( (/lclr1,lclr2/) )
     ;opts@cnLevelSelectionMode = "ExplicitLevels"
     ;opts@cnLevels = ndtooned( (/half1,half2/) )
     ;opts@cnLineDashPatterns = ndtooned( (/ltyp1, ltyp2 /) )
     ;
     ;contourdv = wrf_contour(a,wks,div2d(0,:,:),opts)    ; plot horizontal divergence
     ;delete(opts)
     ;
     ;delete(half1)
     ;delete(half2)
     ;delete(ltyp1)
     ;delete(ltyp2)
     ;delete(lclr1)
     ;delete(lclr2)

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
     opts@ContourParameters = (/ 15., 70., 5./)
     opts@cnFillColors      = cumcolors
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


     contourdbz = wrf_contour(a,wks,dbz2d,opts)    ; plot Reflectivity
     delete(opts)

     ;---------- Put all together --------------

     plot = wrf_map_overlays(a,wks,(/vectora,contourdbz,contourvr/),pltres,mpres)
     ;;;plot = wrf_map_overlays(a,wks,(/vectora,contourdbz,contourdv/),pltres,mpres)

     ;;;;--- Attach the shapefile polylines ---

     ;;;--- draw the map and the shapefile outlines ---

     ;;;draw(plot)
     ;;;frame(wks)

  ;;;end do        ; END OF HEIGHTS LOOP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;end
