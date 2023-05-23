
;   Script display location of model domains
;   Only works for ARW domains
;   Only works for NCL versions 6.2 or later
;   Reads namelist file directly

;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;load "/scratch/ywang/NEWSVAR/newe3dvar.git/NSSLVAR/nclscripts/WRFUserARW.ncl"
;
;begin
;

  ;domains = new((/1,6/),float)
  ;domains(0,:) = (/ 37.49, -120.33, 401, 401, 1000.0,1000.0 /)

  ;lats(0,:) = (/  36.1833 /)
  ;lons(0,:) = (/-119.7092 /)

; Check the version of NCL
;  version = systemfunc("ncl -V")
;  if(version.lt.6.2) then
;    print("You need NCL V6.2 or later to run this script. Try running plotgrids.ncl. Stopping now...")
;    return
;  end if

; We generate plots, but what kind do we prefer?
; type = "x11"
; type = "pdf"
;  type = "ps"
; type = "ncgm"
;  wks = gsn_open_wks(type,"domains-ain")

; read the following namelist file
  filename = "namelist.wps"

; Set the colors to be used
  colors = (/"white","black","White","ForestGreen","DeepSkyBlue","Red","Blue"/)
  gsn_define_colormap(wks, colors)

  domainColors = (/ "Blue", "Red" , "Red" , "Black" /)

; Set some map information ; line and text information
  mpres = True
  mpres@mpFillOn = True
  mpres@mpFillColors  = (/"background","Gray95","White","Gray95", "transparent"/)
  mpres@mpDataBaseVersion           = "Ncarg4_1"
  mpres@mpGeophysicalLineColor      = "Black"
  mpres@mpGridLineColor             = "Gray60"  ; "ForestGreen"
  mpres@mpLimbLineColor             = "Black"
  mpres@mpNationalLineColor         = "Purple"
  mpres@mpPerimLineColor            = "Black"
  mpres@mpUSStateLineColor          = "Black"
  ;mpres@mpOutlineBoundarySets       = "AllBoundaries"
  ;mpres@mpGridSpacingF              = 45
  mpres@tiMainString                = " Analysis Domain and Radar Coverage "
  mpres@gsnPaperOrientation         = "portrait"

  lnres = True
  lnres@gsLineThicknessF = 2.5
  lnres@domLineColors    = domainColors

  txres = True
  txres@txFont = "helvetica-bold"
  ;txres@txJust = "BottomLeft"
  txres@txJust = "TopLeft"
  txres@txPerimOn = False
  txres@txFontHeightF = 0.015

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Do not change anything between the ";;;;;" lines

  maxdom = 21
  nvar = 19
  parent_idn = new (maxdom,integer)
  parent_grid_ration = new (maxdom,integer)
  i_parent_startn = new (maxdom,integer)
  j_parent_startn = new (maxdom,integer)
  e_wen = new (maxdom,integer)
  e_snn = new (maxdom,integer)
  plotvar = new((/maxdom,nvar/),float)
  plotvar@_FillValue = -999.0

  plotvar = wrf_wps_read_nml(filename)

  wrfres = True
  mpres@max_dom = floattointeger(plotvar(0,0))
  mpres@dx = plotvar(0,1)
  mpres@dy = plotvar(0,2)
  wrfres@dx = mpres@dx
  wrfres@dy = mpres@dy
  if (.not.ismissing(plotvar(0,3))) then
    mpres@ref_lat = plotvar(0,3)
  else
    mpres@ref_lat = 0.0
  end if
  if (.not.ismissing(plotvar(0,4))) then
    mpres@ref_lon = plotvar(0,4)
  else
    mpres@ref_lon = 0.0
  end if
  if (.not.ismissing(plotvar(0,5))) then
    mpres@ref_x = plotvar(0,5)
  end if
  if (.not.ismissing(plotvar(0,6))) then
    mpres@ref_y = plotvar(0,6)
  end if
  mpres@truelat1 = plotvar(0,7)
  mpres@truelat2 = plotvar(0,8)
  mpres@stand_lon = plotvar(0,9)
  mproj_int = plotvar(0,10)
  mpres@pole_lat = plotvar(0,11)
  mpres@pole_lon = plotvar(0,12)

  wrfres@truelat1 = plotvar(0,7)
  wrfres@truelat2 = plotvar(0,8)
  wrfres@stand_lon = plotvar(0,9)
  wrfres@pole_lat = plotvar(0,11)
  wrfres@pole_lon = plotvar(0,12)
  wrfres@KNOWNI = plotvar(0,17)/2.
  wrfres@KNOWNJ = plotvar(0,18)/2.
  wrfres@ref_lon = mpres@ref_lon
  wrfres@ref_lat = mpres@ref_lat

  if(mproj_int .eq. 1) then
    mpres@map_proj = "lambert"
    mpres@pole_lat = 0.0
    mpres@pole_lon = 0.0
	wrfres@map_proj = 1
  else if(mproj_int .eq. 2) then
    mpres@map_proj = "mercator"
    mpres@pole_lat = 0.0
    mpres@pole_lon = 0.0
	wrfres@map_proj = 3
  else if(mproj_int .eq. 3) then
    mpres@map_proj = "polar"
    mpres@pole_lat = 0.0
    mpres@pole_lon = 0.0
	wrfres@map_proj = 2
  else if(mproj_int .eq. 4) then
    mpres@map_proj = "lat-lon"
	wrfres@map_proj = 6
	wrfres@LATINC = mpres@dy
	wrfres@LONINC = mpres@dx
  end if
  end if
  end if
  end if

; Deal with global wrf domains that don't have dx or dy

  if (mpres@dx.lt.1e-10 .and. mpres@dx.lt.1e-10) then
    mpres@dx = 360./(mpres@e_we(0) - 1)
    mpres@dy = 180./(mpres@e_sn(0) - 1)
    mpres@ref_lat = 0.0
    mpres@ref_lon = 180.0
  end if

  do i = 0,maxdom-1
    parent_idn(i) = floattointeger(plotvar(i,13))
    parent_grid_ration(i) = floattointeger(plotvar(i,14))
    i_parent_startn(i) = floattointeger(plotvar(i,15))
    j_parent_startn(i) = floattointeger(plotvar(i,16))
    e_wen(i) = floattointeger(plotvar(i,17))
    e_snn(i) = floattointeger(plotvar(i,18))
  end do

  domsize = dimsizes(domains)
  do i = 0, domsize(0)-1
    loci = wrf_ll_to_ij(domains(i,1),domains(i,0),wrfres)

    parent_idn(i+1) = 1
    parent_grid_ration(i+1) = floattointeger(mpres@dx/domains(i,4))
    e_wen(i+1) = floattointeger(domains(i,2))
    e_snn(i+1) = floattointeger(domains(i,3))
    i_parent_startn(i+1) = floattointeger(loci(0)-(e_wen(i+1)-1)/(2*parent_grid_ration(i+1)))
    j_parent_startn(i+1) = floattointeger(loci(1)-(e_snn(i+1)-1)/(2*parent_grid_ration(i+1)))
    mpres@max_dom = i+2
  end do

  if(mpres@max_dom .gt. 1) then
    do i = 1,mpres@max_dom-1

      ;Making sure edge is nested grid is at least 5 grid points from mother domain.
      if(i_parent_startn(i) .lt. 5) then
        print("Warning: Western edge of grid must be at least 5 grid points from mother domain!")
      end if
      if(j_parent_startn(i) .lt. 5) then
        print("Warning: Southern edge of grid must be at least 5 grid points from mother domain!")
      end if
      pointwe = (e_wen(i)-1.)/parent_grid_ration(i)
      pointsn = (e_snn(i)-1.)/parent_grid_ration(i)
      gridwe = e_wen(parent_idn(i)-1)-(pointwe+i_parent_startn(i))
      gridsn = e_snn(parent_idn(i)-1)-(pointsn+j_parent_startn(i))
      if(gridwe .lt. 5) then
        print("Warning: Eastern edge of grid must be at least 5 grid points from mother domain!")
      end if
      if(gridsn .lt. 5) then
        print("Warning: Northern edge of grid must be at least 5 grid points from mother domain!")
      end if

      ;Making sure nested grid is fully contained in mother domain.
      gridsizewe = (((e_wen(parent_idn(i)-1)-4)-i_parent_startn(i))*parent_grid_ration(i))-(parent_grid_ration(i)-1)
      gridsizesn = (((e_snn(parent_idn(i)-1)-4)-j_parent_startn(i))*parent_grid_ration(i))-(parent_grid_ration(i)-1)
      if(gridwe .lt. 5) then
        print("Warning: Inner nest (domain = " + (i+1) + ") is not fully contained in mother nest (domain = " + parent_idn(i) + ")!")
        print("For the current setup of mother domain = " + parent_idn(i) + ", you can only have a nest of size " + gridsizewe + "X" + gridsizesn + ". Stopping Program!")
        exit
      end if
      if(gridsn .lt. 5) then
        print("Warning: Inner nest (domain = " + (i+1) + ") is not fully contained in mother nest (domain = " + parent_idn(i) + ")!")
        print("For the current setup of mother domain = " + parent_idn(i) + ", you can only have a nest of size " + gridsizewe + "X" + gridsizesn + ". Stopping Program!")
        exit
      end if

      ;Making sure the nest ends at a mother grid domain point.
      pointwetrunc = decimalPlaces(pointwe,0,False)
      pointsntrunc = decimalPlaces(pointsn,0,False)
      if((pointwe-pointwetrunc) .ne. 0.) then
        nest_we_up = (ceil(pointwe)*parent_grid_ration(i))+1
        nest_we_dn = (floor(pointwe)*parent_grid_ration(i))+1
        print("Nest does not end on mother grid domain point. Try " + nest_we_dn + " or " + nest_we_up + ".")
      end if
      if((pointsn-pointsntrunc) .ne. 0.) then
        nest_sn_up = (ceil(pointsn)*parent_grid_ration(i))+1
        nest_sn_dn = (floor(pointsn)*parent_grid_ration(i))+1
        print("Nest does not end on mother grid domain point. Try " + nest_sn_dn + " or " + nest_sn_up + ".")
      end if

    end do
  end if

  mpres@parent_id = parent_idn(0:mpres@max_dom-1)
  mpres@parent_grid_ratio = parent_grid_ration(0:mpres@max_dom-1)
  mpres@i_parent_start = i_parent_startn(0:mpres@max_dom-1)
  mpres@j_parent_start = j_parent_startn(0:mpres@max_dom-1)
  mpres@e_we = e_wen(0:mpres@max_dom-1)
  mpres@e_sn = e_snn(0:mpres@max_dom-1)

  mp = wrf_wps_dom (wks,mpres,lnres,txres)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Now you can add some information to the plot.
; Below is an example of adding a white dot over the domain center
  if(mpres@max_dom .gt. 1) then
    do i = 0,domsize(0)-1
      pmres = True
      pmres@gsMarkerColor = domainColors(i)
      pmres@gsMarkerIndex = 16
      pmres@gsMarkerSizeF = 0.01
      gsn_polymarker(wks,mp,domains(i,1),domains(i,0),pmres)
    end do
  end if

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  rinm  = 230000

  pmres = True
  pmres@gsMarkerColor = "Darkgreen"
  pmres@gsMarkerIndex = 16
  pmres@gsMarkerSizeF = 0.008

  resc=True
  resc@gsLineColor="red"
  resc@gsLineThicknessF=0.5
  resc@Scale=1
  resc@Rotation=0

  txres = True
  txres@txFontColor = "Gray10"
  txres@txFontHeightF = 0.008
  txres@txJust = "topCenter"

  if (numradars .gt. 0) then
    radsize = dimsizes(latlons)
    do i = 0,radsize(0)-1
      do j = 0,radsize(1)-1

        if ( .not. ismissing(latlons(i,j,0)) ) then
          latr  = latlons(i,j,0)
          lonr  = latlons(i,j,1)
          rangr = wrf_xdist_to_ldist(lonr,latr,rinm,mpres)

          gsn_polymarker(wks,mp,lonr,latr,pmres)
          circle_ll(wks,mp,lonr,latr,rangr,resc)
          gsn_text (wks,mp,radnams(i,j),lonr,latr-0.2,txres)
        end if

      end do
    end do
  end if

;;;;;; Plot radar outside of the domain ;;;;;
    pmres@gsMarkerColor = "Black"
    pmres@gsMarkerIndex = 14

    radsize = dimsizes(latlons_out)
    do i = 0,radsize(0)-1   ;  domain
      do j = 0,radsize(1)-1   ; radar index

        if ( .not. ismissing(latlons_out(i,j,0)) ) then
          latr  = latlons_out(i,j,0)
          lonr  = latlons_out(i,j,1)

          gsn_polymarker(wks,mp,lonr,latr,pmres)
          gsn_text (wks,mp,radnams_out(i,j),lonr,latr-0.2,txres)
        end if

      end do
    end do

;;;;;;; Plot meso range ;;;;;
    resc=True
    resc@gsLineColor="darkgreen"
    resc@gsLineThicknessF=3
    resc@Scale=1
    resc@Rotation=0
    resc@gsLineDashPattern  = 1

    if (nranges .gt. 0) then
        do i = 0, nranges-1
            xs = (/latlons_rge(i,0),latlons_rge(i,1),latlons_rge(i,1),latlons_rge(i,0),latlons_rge(i,0)/)
            ys = (/latlons_rge(i,2),latlons_rge(i,2),latlons_rge(i,3),latlons_rge(i,3),latlons_rge(i,2)/)
            gsn_polyline(wks,mp,xs,ys,resc)
        end do
    end if

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  frame(wks)           ; lets frame the plot - do not delete

end
