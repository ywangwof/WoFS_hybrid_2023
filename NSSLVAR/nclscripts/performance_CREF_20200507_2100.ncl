; ***********************************************
; These files are loaded by default in NCL V6.2.0 and newer
; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
;************************************************
begin

  nfiles = 2      ; Number of cases/files
  filenames = (/"/scratch/ywang/test_runs/verif_ens/mixing/20200507/2100Z/contingency_CREF_20200507_2100.txt",  \
                "/scratch/ywang/test_runs/verif_ens/norelax/20200507/2100Z/contingency_CREF_20200507_2100.txt" /)
  filecolors= (/"red","chartreuse4"/)
  filelabels= (/"mixing", "norelax"/)

  timecst = "20200507_2100"
  units = "dBZ"
  ;fcstintvl = "minutes"
  nitime = 6

  wks_type = "png"
  wks_type@wkWidth  = 1224
  wks_type@wkHeight = 1584
  filebase = "prf_CREF_"+timecst

; ***********************************************
;
  filename0 = filenames(0)
;
; ***********************************************
; These files are loaded by default in NCL V6.2.0 and newer
; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
;************************************************


  ;legends=(/"20.0","30.0","40.0"/)
  ;
  ; Read data file
  ;
  head = readAsciiHead(filename0, 5)
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

  datain = new((/nfiles, nradis,nthres,ntimes,7/),float)
  do c = 0, nfiles-1
    ;--- Read in file data t
    data = readAsciiTable(filenames(c), 7, "float", 5) ; read 7 columns and ignore first 5 rows
    datain(c,:,:,:,:) = reshape(data,(/nradis,nthres,ntimes,7/))

    ;print(datain(c,:,:,:,:))
  end do

  ; background contours
  npts = tointeger((1.0-0.005)/0.005+1)
  cord = fspan(0.005,1.0,npts)
  grid = new((/npts,npts/),"float")
  sr_grid = conform(grid,cord,1)
  pod_grid = conform(grid,cord,0)

  bias_grid = pod_grid / sr_grid
  bias_grid!0   = "y"     ; Name the dimensions and
  bias_grid!1   = "x"     ; attach coordinate arrays
  bias_grid&x = cord
  bias_grid&y = cord

  csi_grid = 1. / (1. / sr_grid + 1. / pod_grid - 1)
  csi_grid!0   = "y"     ; Name the dimensions and
  csi_grid!1   = "x"     ; attach coordinate arrays
  csi_grid&x = cord
  csi_grid&y = cord

  npts = tointeger((.9-0.1)/0.1+1)
  csi_levels = fspan(0.1,0.9,npts)
  csi_colors = "purple"
  csi_lb_x = (/.92, .92, .92, .92, .92, .92, .92, .95, .95/)
  csi_lb_y = (/0.1,  .2, 0.3,  .4, 0.5,  .6, 0.7, .85, 0.95/)

  bias_levels = (/0.2, 0.5, 1., 1.5, 2., 3., 5./)
  bias_colors = "gray"
  bias_lb_x = (/.2,    .3, .47, .57, .8, .8,  .8/)
  bias_lb_y = (/0.95, .95, .95, .95, .8, .42, .2/)


  do r = 0, nradis-1
    do n = 0, nthres-1

      outfile=filebase+"_"+datain(0,r,n,0,0)+"km_"+datain(0,r,n,0,1)+units+".png"
      wks   = gsn_open_wks (wks_type,outfile)

      ;---Set plotting parameters

      res                   = True                           ; plot mods desired
      res@gsnDraw           = False
      res@gsnFrame          = False
      res@tiMainString      = "Performance for "+timecst+"~C~ ~Z75~Threshold = "+thres(n)+" "+units+", radius = "+radius(r)+" km"

      ; label axis
      res@tiXAxisString = "Success Ratio (1 - FAR)"
      res@tiYAxisString = "Probability of Detection"
      res@trYMinF = 0.0
      res@trYMaxF = 1.0
      res@trXMinF = 0.0
      res@trXMaxF = 1.0
      res@tmYROn = False            ; Turn off right tickmarks.
      res@tmXTOn = False            ; Turn off top tickmarks.

      res@cnInfoLabelOn = False

      ; legend
      ;res@pmLegendDisplayMode    = "Always"            ; turn on legend
      ;res@pmLegendSide           = "Right"             ; Change location of
      ;res@pmLegendParallelPosF   = lgdpositn(0)        ; move units up
      ;res@pmLegendOrthogonalPosF = -0.4                ; move units left
      ;res@pmLegendWidthF         = 0.15                ; Change width and
      ;res@pmLegendHeightF        = 0.18                ; height of legend.
      ;res@lgPerimOn              = False               ; turn off box around
      ;res@lgLabelFontHeightF     = .02                 ; label font height

      ;print(max(bias_grid))
      ;print(min(bias_grid))

      res@cnMonoLineColor = True
      res@cnMonoLineLabelFontColor = True
      res@cnLineColor = csi_colors
      res@cnLineLabelFontColor = csi_colors
      res@cnLineLabelInterval = 1
      res@cnLineLabelDensityF = 0.8
      csi_plot = gsn_csm_contour(wks,csi_grid,res)

      ;lbres = True
      ;lbres@txFontColor = csi_colors
      ;lbres@txFontHeightF = 0.005
      ;gsn_text(wks,csi_plot,tostring(csi_levels),csi_lb_x,csi_lb_y,lbres)

      res@cnLevelSelectionMode = "ExplicitLevels"	; manually set the contour levels with the following 3 resources
      res@cnLevels  = bias_levels
      res@cnLineColor = bias_colors
      res@cnLineLabelFontColor = bias_colors
      ;res@lbLabelStrings = flt2string(bias_levels)

      bis_plot = gsn_csm_contour(wks,bias_grid,res)
      overlay(csi_plot,bis_plot)
      draw(csi_plot)

      do c = 0,nfiles-1
        ;
        ; Plot data file c
        ;
        do t = 0,  ntimes-1, 6
          ; 1. compute POD
          ;datain1(r,n,t,3)    : hits (A)
          ;datain1(r,n,t,4)    : fals (B)
          ;datain1(r,n,t,5)    : miss (C)
          ;datain1(r,n,t,6)    : cneg (D)

          if (datain(c,r,n,t,4) .le. 0) then
            datain(c,r,n,t,4) = 1
          end if

          if (datain(c,r,n,t,3) .le. 0) then
            datain(c,r,n,t,3) = 1
          end if

          pod =  datain(c,r,n,t,3)/(datain(c,r,n,t,3)+datain(c,r,n,t,5))
          far =  datain(c,r,n,t,4)/(datain(c,r,n,t,3)+datain(c,r,n,t,4))
          bis = (datain(c,r,n,t,3)+ datain(c,r,n,t,4))/(datain(c,r,n,t,3)+datain(c,r,n,t,5))
          csi =  datain(c,r,n,t,3)/(datain(c,r,n,t,3)+datain(c,r,n,t,4)+datain(c,r,n,t,5))

          ;print(n+","+t+","+pod+":"+datain1(r,n,t,3)+","+datain1(r,n,t,5))
          sr = 1-far


          pmres = True
          pmres@gsMarkerColor = filecolors(c)
          pmres@gsMarkerIndex = 16
          pmres@gsMarkerSizeF = 0.02
          gsn_polymarker(wks,csi_plot,sr,pod,pmres)

          lbres = True
          lbres@txFontColor = "white"
          lbres@txFontHeightF = 0.006

          fcsttime = tostring_with_format(tointeger(datain(c,r,n,t,2)/60),"%2d")
          gsn_text(wks,csi_plot,fcsttime,sr,pod,lbres)

          delete(pmres)
          delete(lbres)

        end do

        ; label the symbols
        pmres = True
        pmres@gsMarkerColor = filecolors(c)
        pmres@gsMarkerIndex = 16
        pmres@gsMarkerSizeF = 0.02
        gsn_polymarker(wks,csi_plot,0.02,0.3-c*0.04,pmres)

        lbres = True
        lbres@txFontColor = "white"
        lbres@txFontHeightF = 0.006

        fcsttime = "fcst"
        gsn_text(wks,csi_plot,fcsttime,0.02,0.3-c*0.04,lbres)

        lbres@txFontColor = "black"
        lbres@txFontHeightF = 0.008
        lbres@txJust = "CenterLeft"
        gsn_text(wks,csi_plot,filelabels(c),0.05,0.3-c*0.04,lbres)

        delete(pmres)
        delete(lbres)

     end do

     frame(wks)
     delete(res)
     delete(wks)

    end do
  end do

end
