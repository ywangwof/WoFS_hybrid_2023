;   Example script to produce plots for a WRF real-data run,
;   with the ARW coordinate dynamics option.

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
;load "./WRFUserARW.ncl"

begin
;
; Make a list of all files we are interested in

; CHANGE DATE HERE:
  DATADir = "/lfs3/projects/hpc-wof1/afierro/news3dvar_verif/scores/mrms_data/20180607/0000Z/"

 FILES = systemfunc (" ls -1 " + DATADir + "MRMS_HPRCP_2018-06-07_0*[1-9]* " + DATADir + "MRMS_HPRCP_2018-06-07_[1]*[0-2]* " )

  numFILES = dimsizes(FILES)
  print("numFILES = " + numFILES)
  print(FILES)
  print (" ")

; We generate plots, but what kind do we prefer?
;  type = "x11"
; type = "pdf"
 type = "png"
; type = "ps"
; type = "ncgm"
  wks = gsn_open_wks(type,"plt_Precip_multi_total")


; Set some basic resources
  res = True
  res@MainTitle = "MRMS APCP"

  pltres = True
  mpres = True
  mpres@mpGeophysicalLineColor = "Black"
  mpres@mpNationalLineColor    = "Black"
  mpres@mpUSStateLineColor     = "Black"
  mpres@mpGridLineColor        = "Black"
  mpres@mpLimbLineColor        = "Black"
  mpres@mpPerimLineColor       = "Black"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  a = addfiles(FILES+".nc","r")

  ;times = wrf_user_getvar(a,"times",-1)  ; get all times in the file
  ;ntimes = dimsizes(times)         ; number of times in the file

  ;slp = wrf_user_getvar(a,"slp",-1)  ; slp
   ; wrf_smooth_2d( slp, 3 )            ; smooth slp

  ; Get non-convective, convective and total precipitation
  b = wrf_user_getvar(a,"HOURLYPRCP",-1)
  printVarSummary(b)
  ;rain_exp = wrf_user_getvar(a,"HOURLYPRCP",-1)
  ;rain_tot = rain_exp
  ;rain_tot@description = "Total Precipitation"
  ;rain_con = wrf_user_getvar(a,"RAINC",-1)
  ;rain_tot = rain_exp + rain_con

  ; just creating new arrays here
  ;rain_exp_tend = rain_exp 
  ;rain_con_tend = rain_con 
  ;rain_tot_tend = rain_tot 
  ;rain_exp_tend = 0.0 
  ;rain_con_tend = 0.0 
  ;rain_tot_tend = 0.0 
  ;rain_exp_tend@description = "Explicit Precipitation Tendency"
  ;rain_con_tend@description = "Param  Precipitation Tendency"
  ;rain_tot_tend@description = "Precipitation Tendency"

  ; Calculate tendency values 
  ; We know our data is available every 3 hours, so setting tend_int to 1 gives 
  ; tendencies for 3 hours, setting it to 2, gives 6hourly tendencies                               
  ;rain_exp_tend(tend_int:ntimes-1:tend_int,:,:) = rain_exp(tend_int:ntimes-1:tend_int,:,:) - rain_exp(0:ntimes-2:tend_int,:,:)
  ;rain_con_tend(tend_int:ntimes-1:tend_int,:,:) = rain_con(tend_int:ntimes-1:tend_int,:,:) - rain_con(0:ntimes-2:tend_int,:,:)
  ;rain_tot_tend(tend_int:ntimes-1:tend_int,:,:) = rain_tot(tend_int:ntimes-1:tend_int,:,:) - rain_tot(0:ntimes-2:tend_int,:,:)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ;do it = tend_int,ntimes-1,tend_int    ; Let's skip the first time as rain is 0 here
  do it = 0, numFILES-1   ; Let's skip the first time as rain is 0 here

    ;print("Working on time: " + times(it) )
    ;res@TimeLabel = times(it)   ; Set Valid time to use on plots

     ;rain_exp = wrf_user_getvar(a[it],"HOURLYPRCP",-1)

     if (it .eq. 0) then
     rain_exp =  wrf_user_getvar(a[0],"HOURLYPRCP",-1)
     rain_tot = rain_exp
     end if
     if (it .eq. 1) then
     rain_exp =  wrf_user_getvar(a[0],"HOURLYPRCP",-1)
     rain_exp1 =  wrf_user_getvar(a[1],"HOURLYPRCP",-1)
     rain_tot = rain_exp+rain_exp1
     end if
     if (it .eq. 2) then
     rain_exp =  wrf_user_getvar(a[0],"HOURLYPRCP",-1)
     rain_exp1 =  wrf_user_getvar(a[1],"HOURLYPRCP",-1)
     rain_exp2 =  wrf_user_getvar(a[2],"HOURLYPRCP",-1)
     rain_tot = rain_exp+rain_exp1+rain_exp2
     end if
     if (it .eq. 3) then
     rain_exp =  wrf_user_getvar(a[0],"HOURLYPRCP",-1)
     rain_exp1 =  wrf_user_getvar(a[1],"HOURLYPRCP",-1)
     rain_exp2 =  wrf_user_getvar(a[2],"HOURLYPRCP",-1)
     rain_exp3 =  wrf_user_getvar(a[3],"HOURLYPRCP",-1)
     rain_tot = rain_exp+rain_exp1+rain_exp2+rain_exp3
     end if
     if (it .eq. 4) then
     rain_exp =  wrf_user_getvar(a[0],"HOURLYPRCP",-1)
     rain_exp1 =  wrf_user_getvar(a[1],"HOURLYPRCP",-1)
     rain_exp2 =  wrf_user_getvar(a[2],"HOURLYPRCP",-1)
     rain_exp3 =  wrf_user_getvar(a[3],"HOURLYPRCP",-1)
     rain_exp4 =  wrf_user_getvar(a[4],"HOURLYPRCP",-1)
     rain_tot = rain_exp+rain_exp1+rain_exp2+rain_exp3+rain_exp4
     end if
     if (it .eq. 5) then
     rain_exp =  wrf_user_getvar(a[0],"HOURLYPRCP",-1)
     rain_exp1 =  wrf_user_getvar(a[1],"HOURLYPRCP",-1)
     rain_exp2 =  wrf_user_getvar(a[2],"HOURLYPRCP",-1)
     rain_exp3 =  wrf_user_getvar(a[3],"HOURLYPRCP",-1)
     rain_exp4 =  wrf_user_getvar(a[4],"HOURLYPRCP",-1)
     rain_exp5 =  wrf_user_getvar(a[5],"HOURLYPRCP",-1)
     rain_tot = rain_exp+rain_exp1+rain_exp2+rain_exp3+rain_exp4+rain_exp5
     end if
     if (it .eq. 6) then
     rain_exp =  wrf_user_getvar(a[0],"HOURLYPRCP",-1)
     rain_exp1 =  wrf_user_getvar(a[1],"HOURLYPRCP",-1)
     rain_exp2 =  wrf_user_getvar(a[2],"HOURLYPRCP",-1)
     rain_exp3 =  wrf_user_getvar(a[3],"HOURLYPRCP",-1)
     rain_exp4 =  wrf_user_getvar(a[4],"HOURLYPRCP",-1)
     rain_exp5 =  wrf_user_getvar(a[5],"HOURLYPRCP",-1)
     rain_exp6 =  wrf_user_getvar(a[6],"HOURLYPRCP",-1)
     rain_tot = rain_exp+rain_exp1+rain_exp2+rain_exp3+rain_exp4+rain_exp5+rain_exp6
     end if
     if (it .eq. 7) then
     rain_exp =  wrf_user_getvar(a[0],"HOURLYPRCP",-1)
     rain_exp1 =  wrf_user_getvar(a[1],"HOURLYPRCP",-1)
     rain_exp2 =  wrf_user_getvar(a[2],"HOURLYPRCP",-1)
     rain_exp3 =  wrf_user_getvar(a[3],"HOURLYPRCP",-1)
     rain_exp4 =  wrf_user_getvar(a[4],"HOURLYPRCP",-1)
     rain_exp5 =  wrf_user_getvar(a[5],"HOURLYPRCP",-1)
     rain_exp6 =  wrf_user_getvar(a[6],"HOURLYPRCP",-1)
     rain_exp7 =  wrf_user_getvar(a[7],"HOURLYPRCP",-1)
     rain_tot = rain_exp+rain_exp1+rain_exp2+rain_exp3+rain_exp4+rain_exp5+rain_exp6+rain_exp7
     end if
     if (it .eq. 8) then
     rain_exp =  wrf_user_getvar(a[0],"HOURLYPRCP",-1)
     rain_exp1 =  wrf_user_getvar(a[1],"HOURLYPRCP",-1)
     rain_exp2 =  wrf_user_getvar(a[2],"HOURLYPRCP",-1)
     rain_exp3 =  wrf_user_getvar(a[3],"HOURLYPRCP",-1)
     rain_exp4 =  wrf_user_getvar(a[4],"HOURLYPRCP",-1)
     rain_exp5 =  wrf_user_getvar(a[5],"HOURLYPRCP",-1)
     rain_exp6 =  wrf_user_getvar(a[6],"HOURLYPRCP",-1)
     rain_exp7 =  wrf_user_getvar(a[7],"HOURLYPRCP",-1)
     rain_exp8 =  wrf_user_getvar(a[8],"HOURLYPRCP",-1)
     rain_tot = rain_exp+rain_exp1+rain_exp2+rain_exp3+rain_exp4+rain_exp5+rain_exp6+rain_exp7+rain_exp8
     end if
     if (it .eq. 9) then
     rain_exp =  wrf_user_getvar(a[0],"HOURLYPRCP",-1)
     rain_exp1 =  wrf_user_getvar(a[1],"HOURLYPRCP",-1)
     rain_exp2 =  wrf_user_getvar(a[2],"HOURLYPRCP",-1)
     rain_exp3 =  wrf_user_getvar(a[3],"HOURLYPRCP",-1)
     rain_exp4 =  wrf_user_getvar(a[4],"HOURLYPRCP",-1)
     rain_exp5 =  wrf_user_getvar(a[5],"HOURLYPRCP",-1)
     rain_exp6 =  wrf_user_getvar(a[6],"HOURLYPRCP",-1)
     rain_exp7 =  wrf_user_getvar(a[7],"HOURLYPRCP",-1)
     rain_exp8 =  wrf_user_getvar(a[8],"HOURLYPRCP",-1)
     rain_exp9 =  wrf_user_getvar(a[9],"HOURLYPRCP",-1)
     rain_tot = rain_exp+rain_exp1+rain_exp2+rain_exp3+rain_exp4+rain_exp5+rain_exp6+rain_exp7+rain_exp8+rain_exp9
     end if
     if (it .eq. 10) then
     rain_exp =  wrf_user_getvar(a[0],"HOURLYPRCP",-1)
     rain_exp1 =  wrf_user_getvar(a[1],"HOURLYPRCP",-1)
     rain_exp2 =  wrf_user_getvar(a[2],"HOURLYPRCP",-1)
     rain_exp3 =  wrf_user_getvar(a[3],"HOURLYPRCP",-1)
     rain_exp4 =  wrf_user_getvar(a[4],"HOURLYPRCP",-1)
     rain_exp5 =  wrf_user_getvar(a[5],"HOURLYPRCP",-1)
     rain_exp6 =  wrf_user_getvar(a[6],"HOURLYPRCP",-1)
     rain_exp7 =  wrf_user_getvar(a[7],"HOURLYPRCP",-1)
     rain_exp8 =  wrf_user_getvar(a[8],"HOURLYPRCP",-1)
     rain_exp9 =  wrf_user_getvar(a[9],"HOURLYPRCP",-1)
     rain_exp10 =  wrf_user_getvar(a[10],"HOURLYPRCP",-1)
     rain_tot = rain_exp+rain_exp1+rain_exp2+rain_exp3+rain_exp4+rain_exp5+rain_exp6+rain_exp7+rain_exp8+rain_exp9+rain_exp10
     end if
     if (it .eq. 11) then
     rain_exp =  wrf_user_getvar(a[0],"HOURLYPRCP",-1)
     rain_exp1 =  wrf_user_getvar(a[1],"HOURLYPRCP",-1)
     rain_exp2 =  wrf_user_getvar(a[2],"HOURLYPRCP",-1)
     rain_exp3 =  wrf_user_getvar(a[3],"HOURLYPRCP",-1)
     rain_exp4 =  wrf_user_getvar(a[4],"HOURLYPRCP",-1)
     rain_exp5 =  wrf_user_getvar(a[5],"HOURLYPRCP",-1)
     rain_exp6 =  wrf_user_getvar(a[6],"HOURLYPRCP",-1)
     rain_exp7 =  wrf_user_getvar(a[7],"HOURLYPRCP",-1)
     rain_exp8 =  wrf_user_getvar(a[8],"HOURLYPRCP",-1)
     rain_exp9 =  wrf_user_getvar(a[9],"HOURLYPRCP",-1)
     rain_exp10 =  wrf_user_getvar(a[10],"HOURLYPRCP",-1)
     rain_exp11 =  wrf_user_getvar(a[11],"HOURLYPRCP",-1)
     rain_tot = rain_exp+rain_exp1+rain_exp2+rain_exp3+rain_exp4+rain_exp5+rain_exp6+rain_exp7+rain_exp8+rain_exp9+rain_exp10+rain_exp11
     end if
     if (it .eq. 12) then
     rain_exp =  wrf_user_getvar(a[0],"HOURLYPRCP",-1)
     rain_exp1 =  wrf_user_getvar(a[1],"HOURLYPRCP",-1)
     rain_exp2 =  wrf_user_getvar(a[2],"HOURLYPRCP",-1)
     rain_exp3 =  wrf_user_getvar(a[3],"HOURLYPRCP",-1)
     rain_exp4 =  wrf_user_getvar(a[4],"HOURLYPRCP",-1)
     rain_exp5 =  wrf_user_getvar(a[5],"HOURLYPRCP",-1)
     rain_exp6 =  wrf_user_getvar(a[6],"HOURLYPRCP",-1)
     rain_exp7 =  wrf_user_getvar(a[7],"HOURLYPRCP",-1)
     rain_exp8 =  wrf_user_getvar(a[8],"HOURLYPRCP",-1)
     rain_exp9 =  wrf_user_getvar(a[9],"HOURLYPRCP",-1)
     rain_exp10 =  wrf_user_getvar(a[10],"HOURLYPRCP",-1)
     rain_exp11 =  wrf_user_getvar(a[11],"HOURLYPRCP",-1)
     rain_exp12 =  wrf_user_getvar(a[12],"HOURLYPRCP",-1)
     rain_tot = rain_exp+rain_exp1+rain_exp2+rain_exp3+rain_exp4+rain_exp5+rain_exp6+rain_exp7+rain_exp8+rain_exp9+rain_exp10+rain_exp11+rain_exp12
     end if


     ;rain_exp = sum(b(0:it,:,:)) 
     rain_tot@description = "Total Precipitation"

  ; Plotting options for Sea Level Pressure
    ;opts_psl = res          
    ;opts_psl@ContourParameters = (/ 900., 1100., 2. /)
    ;opts_psl@cnLineColor       = "Blue"
    ;opts_psl@cnInfoLabelOn     = False
    ;opts_psl@cnLineLabelFontHeightF = 0.01
    ;opts_psl@cnLineLabelPerimOn = False
    ;opts_psl@gsnContourLineThicknessesScale = 1.5
    ;contour_psl = wrf_contour(a[it],wks,slp(it,:,:),opts_psl)
    ;delete(opts_psl)
    

  ; Plotting options for Precipitation
    opts_r = res                        
    opts_r@UnitLabel            = "mm"
    opts_r@cnFillPalette = "precip2_17lev" 
    opts_r@cnLevelSelectionMode = "ExplicitLevels"
    ;opts_r@cnLevels            = (/10, 20, 30,40,50,60,70,80,100/)
    opts_r@cnLevels             = (/1, 5, 10,15,20,30,40,50,75,100/)
    ;opts_r@cnLevels             = (/ .1, .2, .4, .8, 1.6, 3.2, 6.4, \
    ;                                12.8, 25.6, 51.2, 102.4/)
    ;opts_r@cnFillColors         = (/"White","White","DarkOliveGreen1", \
    ;                            "DarkOliveGreen3","Chartreuse", \
    ;                                "Chartreuse3","Green","ForestGreen", \
    ;                                "Yellow","Orange","Red","Violet"/)
    opts_r@cnFillColors        = (/0,  2 ,5 ,7, 9, 10,11,12,13,14,15/) ; #s refer to indices of colors in palette
    opts_r@cnInfoLabelOn        = False
    opts_r@cnConstFLabelOn      = False
    opts_r@cnFillOn             = True
    opts_r@FieldTitle             = "APCP"
    

    printVarSummary(rain_tot)
  ; Total Precipitation (color fill)
    atot = dim_sum_n(rain_tot,0)
    ;contour_tot = wrf_contour(a[it],wks, rain_tot(it,:,:), opts_r)
    contour_tot = wrf_contour(a[it],wks, atot, opts_r)

  ; MAKE PLOTS                                       

    ; Total Precipitation 
     plot = wrf_map_overlays(a[it],wks,contour_tot,pltres,mpres)

    ; Total Precipitation Tendency + SLP
    ;  plot = wrf_map_overlays(a[it],wks,(/contour_tend,contour_psl/),pltres,mpres)

    ; Non-Convective and Convective Precipiation Tendencies
    ; plot = wrf_map_overlays(a[it],wks,(/contour_res,contour_prm/),pltres,mpres)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  end do        ; END OF TIME LOOP

end
