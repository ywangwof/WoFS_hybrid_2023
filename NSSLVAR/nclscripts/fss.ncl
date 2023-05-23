; ***********************************************
;
;
; ***********************************************
; These files are loaded by default in NCL V6.2.0 and newer
; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
;************************************************
;;;begin
;;;
;;;  filename = "/scratch/ywang/NEWSVAR/news3dvar.git/20180523_0200.txt"
;;;  wks   = gsn_open_wks ("png","fss_20180523_0200.png")  ; send graphics to PNG file


  ;
  ; Read data file
  ;
  head = readAsciiHead(filename, 3)
  field1 = str_get_field(head(0), 1, ",")
  field2 = str_get_field(head(0), 2, ",")
  field3 = str_get_field(head(0), 3, ",")
  nthres = stringtointeger(str_get_field(field1,2," "))
  ntimes = stringtointeger(str_get_field(field2,2," "))
  nradis = stringtointeger(str_get_field(field3,2," "))

  ;print(nthres)
  ;print(ntimes)
  ;print(nradis)

  thres = new((/nthres/),float)
  do n = 0, nthres-1
    thres(n) = stringtofloat(str_get_field(head(1), n+2, " "))
  end do

  radius = new((/nradis/),float)
  do r = 0, nradis-1
    radius(r) = stringtofloat(str_get_field(head(2), r+2, " "))
  end do

  ;--- Read in data
  datain = new((/nthres,ntimes,nradis+1/),float)
  data = readAsciiTable(filename, nradis+1, "float", 3)
  datain = reshape(data,(/nthres,ntimes,nradis+1/))

  ;print(datain)


  ;linethck = (/1.0, 1.0, 1.0, 1.0, 1.0/)
  ;lineclrs = (/"blue","red","purple","orange","green"/)

  linethck = (/4.0, 4.0, 4.0, 4.0, 4.0/)
  lineclrs = (/"grey85","grey65","grey50","grey35","grey20","grey2"/)
  ;linethck = (/2.0, 2.0, 2.0, 2.0, 2.0/)
  ;lineclrs = (/"grey2","grey18","grey37","grey50","grey85"/)

  lgdpositn = (/0.8,0.3,0.8,0.8/)

  plot = new(nthres,graphic)
  do n = 0, nthres-1

    datatim = new((/ntimes/),float)
    dataplt = new((/nradis,ntimes/),float)

    do r = 0, nradis-1
      do nt = 1, ntimes-1
        datatim(nt) = datain(n,nt,0)
        dataplt(r,nt) = datain(n,nt,r+1)
      end do
    end do

    ;---Set plotting parameters

    res                   = True                           ; plot mods desired
    res@gsnDraw           = False
    res@gsnFrame          = False
    res@tiMainString      = timecst+" FSS Threshold = "+thres(n)+" "+units            ; add title
    ;
    ; Similiar resources are xyLineThicknessF and xyLineColor,
    ; which will affect all lines in the array.
    ;
    res@xyLineThicknesses = linethck          ; make second line thicker
    res@xyLineColors      = lineclrs          ; change line color

    ; label axis
    res@tiXAxisString = "Forecast ("+fcstintvl+")"
    res@tiYAxisString = "FSS"  ;"Threshold = "+thres(n)+" "+units
    res@trYMinF = 0.0
    res@trYMaxF = 1.0

    ; legend
    res@pmLegendDisplayMode    = "Always"            ; turn on legend
    res@pmLegendSide           = "Right"             ; Change location of
    res@pmLegendParallelPosF   = lgdpositn(0)        ; move units up
    res@pmLegendOrthogonalPosF = -0.4                ; move units left
    res@pmLegendWidthF         = 0.15                ; Change width and
    res@pmLegendHeightF        = 0.18                ; height of legend.
    res@lgPerimOn              = False               ; turn off box around
    res@lgLabelFontHeightF     = .02                 ; label font height
    res@xyExplicitLegendLabels = radius+" km"           ; create explicit labels
    res@xyDashPattern  = 0                           ; make curve all solid  

    plot(n)  = gsn_csm_xy (wks,datatim,dataplt,res) ; create plot


    delete(datatim)
    delete(dataplt)

  end do

  gsn_panel(wks,plot,(/2,2/),False)             ; now draw as one plot
end
