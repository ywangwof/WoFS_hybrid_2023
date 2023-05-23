;--------------------------------------------------------------------------------

undef("circle_ll")
procedure circle_ll(wks:graphic,plt:graphic,x0:numeric,y0:numeric,r:numeric,res:logical)
; Draws a circle (or ellipse) or radius (or x-axis length) r
; centered at (x0,y0). Optionally it can draw an ellipse and axes can be rotated as desired.
;
; Input Parameters:
;
; wks: graphics workstation
; plt: the plot graphics
; (x0,y0): center of the circle in terms of plot coordinate
; r: radius (or x-direction length) of the circle in terms of plot coordinate
; res: resources. If true can take any line graphic parameter valid to gsn_add_polyline.
;      In addition, there are two special resources for this procedure:
;
;      Scale: The scale by which the y-axis length should be modified to
;             the x-axis length. This can be used to plot an ellipse. (default=1).
;      Rotation: The rotation angle (in degrees) by which the axes are
;                rotated (positive anticlockwhise). (default=0).
;
; Example:
;...
; arr=random_uniform(1,10,(/15,20/))
; wks = gsn_open_wks("x11","circle");
; res = True
; res@vpHeightF=0.5
; res@vpWidthF=0.8
; res@gsnDraw = False
; res@gsnFrame = False
; plt=gsn_csm_contour(wks,arr,res)

; resc=True
; resc@gsLineColor="red"
; resc@gsLineThicknessF=2
; resc@Scale=1.5
; resc@Rotation=-45
; circle_ll(wks,plt,10,7,3,resc)
; draw(plt)
; frame(wks)
;...
;
; Author: Arindam Chakraborty <arch at caos.iisc.ernet.in>
;

begin
  rot = 0.0
  scale = 1.0
  th = ispan(0,360,1)
  pi = acos(-1.0)

  res1 = res
  if(res)then
    if(isatt(res,"Scale"))then
      scale = res@Scale
      delete(res1@Scale)
    end if
    if(isatt(res,"Rotation"))then
      rot = res@Rotation
      delete(res1@Rotation)
    end if
  end if

  getvalues plt
   "trXMinF":xmin
   "trXMaxF":xmax
   "trYMinF":ymin
   "trYMaxF":ymax
   "vpXF":vpx0
   "vpYF":vpy1
   "vpWidthF":vpw
   "vpHeightF":vph
  end getvalues

  rx = r/(xmax-xmin)
  ry = rx*vpw/vph

  xpts1 = cos(th*pi/180)
  ypts1 = sin(th*pi/180)*scale

  xpts2 = xpts1*cos(rot*pi/180) - ypts1*sin(rot*pi/180)
  ypts2 = xpts1*sin(rot*pi/180) + ypts1*cos(rot*pi/180)

  xpts = rx*xpts2*(xmax-xmin) + x0
  ypts = ry*ypts2*(ymax-ymin) + y0
  ;str = unique_string("circle_ll")
  ;print (xpts)
  ;print (ypts)
  ;plt@$str$ = gsn_add_polyline(wks,plt,xpts,ypts,res1)
  ;delete(str)

  x_out = new(dimsizes(xpts),typeof(xpts))
  y_out = new(dimsizes(ypts),typeof(ypts))
  datatondc(plt, xpts, ypts, x_out, y_out)
  gsn_polyline_ndc(wks, x_out, y_out, res1)

  delete(xpts1)
  delete(ypts1)
  delete(xpts2)
  delete(ypts2)
  delete(th)
  delete(res1)

end

;--------------------------------------------------------------------------------
undef("wrf_xdist_to_ldist")
function wrf_xdist_to_ldist(lon0:numeric,lat0:numeric,rangeinM:numeric,opt_args[1]:logical)

begin

  mpres = opt_args

  res = True
  res@DX = mpres@dx
  res@DY = mpres@dy
  res@LATINC = 0.0
  res@LONINC = 0.0
  if ( mpres@map_proj .eq. "lambert") then
    mpres@map_proj = 1
    res@MAP_PROJ = 1
  end if
  if ( mpres@map_proj .eq. "polar") then
    mpres@map_proj = 2
    res@MAP_PROJ = 2
  end if
  if ( mpres@map_proj .eq. "mercator") then
    mpres@map_proj = 3
    res@MAP_PROJ = 3
  end if
  if ( mpres@map_proj .eq. "lat-lon") then
    mpres@map_proj = 6
    res@MAP_PROJ = 6
    res@LATINC = mpres@dy
    res@LONINC = mpres@dx
  end if
  res@TRUELAT1 = mpres@truelat1
  res@TRUELAT2 = mpres@truelat2
  res@STAND_LON = mpres@stand_lon

  res@REF_LAT = mpres@ref_lat
  res@REF_LON = mpres@ref_lon
  if ( isatt(mpres,"ref_x") ) then
    res@KNOWNI = mpres@ref_x
  else
    res@KNOWNI = int2flt(mpres@e_we(0))/2.
  end if
  if ( isatt(mpres,"ref_y") ) then
    res@KNOWNJ = mpres@ref_y
  else
    res@KNOWNJ = int2flt(mpres@e_sn(0))/2.
  end if

  if ( isatt(mpres,"pole_lat") ) then
    res@POLE_LAT = mpres@pole_lat
  else
    res@POLE_LAT = 90.0
  end if
  if ( isatt(mpres,"pole_lon") ) then
    res@POLE_LON = mpres@pole_lon
  else
    res@POLE_LON = 0.0
  end if


  loc0 = wrf_ll_to_ij (lon0,lat0,res)
  xx0 = loc0(0)
  yy0 = loc0(1)

  ;print(lat0+", "+lon0)
  ;print(xx0+", "+yy0)

  xx = xx0 + (rangeinM/res@DX)
  yy = yy0

  loc = wrf_ij_to_ll(xx,yy,res)
  lon = loc(0)
  lat = loc(1)
  ;print(xx+", "+yy)
  ;print(lat+", "+lon)

  ranginD = abs(lon-lon0)

  delete(mpres)
  delete(res)
  delete(loc0)
  delete(loc)

  return(ranginD)

end