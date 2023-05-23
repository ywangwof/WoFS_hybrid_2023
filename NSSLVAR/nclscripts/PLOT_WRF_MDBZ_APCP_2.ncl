;   Example script to produce plots for a WRF real-data run,
;   with the ARW coordinate dynamics option.
;   Interpolating to specified height levels
;   In this example we obtain all the fields at once and interpolate to all height levels at once


; https://www.ncl.ucar.edu/Document/Functions/WRF_arw/wrf_user_getvar.shtml

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"

begin
;
; The WRF ARW input file.
; This needs to have a ".nc" appended, so just do it.
; a = addfile("./wrfout_d01_2018-04-06_01:00:00.nc","r")

; list of files:
; files = systemfunc("ls -1 wrfout_d01_2018*") + ".nc"
; a = addfiles(files,"r")
; slp = wrf_user_getvar(a,"slp",-1)

 ; target date
 ; year="2012"
 ; month="07"
 ;day="11" 

 ;wrfDir="/lfs3/projects/hpc-wof1/afierro/r009/news3dvar/tmp/"+year+"/run_"+month+"/"
 ;wrfName="wrfout_d0"+domain+"_"+year+"-"+month+"-"+day+"_12-00-00.nc"
 ;wrfout=wrfDir+wrfName
 ;print("Opening file: "+wrfout+" ...") 

 ;wrfDir="/lfs3/projects/hpc-wof1/afierro/news3dvar/tmp/"
 ;files = systemfunc("ls -1 wrfDir/wrfout_d01_2018*") + ".nc"
 ;files = systemfunc("ls -1 /lfs3/projects/hpc-wof1/afierro/news3dvar/tmp/wrfout_d01_2018*") + ".nc"

; SPECIFIC LIST OF FILES

 files = systemfunc("ls -1 /lfs3/projects/hpc-wof1/afierro/news3dvar/tmp/wrfout_d01_2018*0[1-5]:00:00 /lfs3/projects/hpc-wof1/afierro/news3dvar/tmp/wrfout_d01_2018*06:00:00 /lfs3/projects/hpc-wof1/afierro/news3dvar/tmp/wrfout_d01_2018*12:00:00") 
 print(files)

 ;a = addfiles(files,"r") 
 nfiles  = dimsizes(files)
 print(nfiles)
 print(files(0))

; We generate plots, but what kind do we prefer?
;  type = "x11"
 type = "pdf"
; type = "ps"
; type = "ncgm"

;  NAME OF THE FILE

  wks = gsn_open_wks(type,"plt_APCP_MDBZ")


; Set some basic resources
  res = True
  res@MainTitle = "REAL-TIME WRF"
  res@Footer = False

  pltres = True
  mpres = True
  mpres@mpGeophysicalLineColor = "Black"
  mpres@mpNationalLineColor    = "Black"
  mpres@mpUSStateLineColor     = "Black"
  mpres@mpGridLineColor        = "Black"
  mpres@mpLimbLineColor        = "Black"
  mpres@mpPerimLineColor       = "Black"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; What times and how many time steps are in the data set?
;  times = wrf_user_getvar(a,"times",-1)  ; get all times in the file
;  ntimes = dimsizes(times)         ; number of times in the file


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

                   ;(/ 0.000, 0.925, 0.925 /), \  ; !28- begin REF
  refcolors =    (/                   \
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



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; First get the variables we will need


; WITH $$#@# NCL ALWAYS HAVE -1 because array starts at 0 !! 
  do ifile = 0,nfiles-1            ; 

;  ADDFILES AND ADDFILE ARE DIFFERENT !!!!! BE CAREFUL OTHERWISE GET @@#$ COERCE ERROR !!!
 
  
   a = addfile(files(ifile),"r") 
   print(files(ifile))
   print("Ifile INDEX: " +ifile)

   
   ;a = addfile("./wrfout_d01_2018-05-31_01:00:00.nc","r") 


   times = wrf_user_getvar(a,"times",-1)  

   it=0


;  THESE VARNAMES DONT COME FROM NCDUMP BUT FROM WRFUserARW.ncl !!!

;   DIAGNOSTIC
    ;tc = wrf_user_getvar(a,"tc",-1)        ; T in C
    ;u  = wrf_user_getvar(a,"ua",-1)        ; u averaged to mass points
    ;v  = wrf_user_getvar(a,"va",-1)        ; v averaged to mass points
    ;p  = wrf_user_getvar(a, "pressure",-1) ; pressure is our vertical coordinate
    ;z  = wrf_user_getvar(a, "z",-1)        ; grid point height
    ;rh = wrf_user_getvar(a,"rh",-1)        ; relative humidity

;   RAW VARS, as in NCDUMP -h. THIS POS IS CASE SENSITIVE !!!!!!
; SEE AVAIL RAW FIELDS ncl_filedump wrfout_d01_2000-01-24_12:00:00.nc

;    maxdbz = wrf_user_getvar(a,"mdbz",-1)        ; max DBZ: defined in WRFUserARW.ncl
;    REFD_MAX IS CORRUPT !!! TAKES CVALUES OF PREVIOSU TIME IN I/O ...
;    maxdbz = wrf_user_getvar(a,"REFD_MAX",-1)        ; NCDUMP 

     dbz = wrf_user_getvar(a,"REFL_10CM",-1)        ; 

    apcp = wrf_user_getvar(a,"RAINNC",-1)        ; RAINNC = APCP defined in NCDUMP -H
    apcp@units = "mm"
    dbz@units = "dBZ"

; The specific height levels that we want the data interpolated to.
; And interpolate to these levels
; height_levels = (/ 250., 1000., 2000., 4000./)            ; height levels to plot - in meter
;  height_levels = (/ 1000., 4000./)            ; height levels to plot - in meter
;  nlevels       = dimsizes(height_levels)     ; number of height levels

;  print("Nlevs: " + nlevels )

 ; p_plane  = wrf_user_intrp3d( p,z,"h",height_levels,0.,False)
  ;tc_plane = wrf_user_intrp3d(tc,z,"h",height_levels,0.,False)
  ;rh_plane = wrf_user_intrp3d(rh,z,"h",height_levels,0.,False)
  ;u_plane  = wrf_user_intrp3d( u,z,"h",height_levels,0.,False)
  ;v_plane  = wrf_user_intrp3d( v,z,"h",height_levels,0.,False)

  ;refl_plane = wrf_user_intrp3d(refl,z,"h",height_levels,0.,False)

  ;u_plane = u_plane*1.94386     ; kts
  ;v_plane = v_plane*1.94386     ; kts
   ; u_plane@units = "kts"
   ; v_plane@units = "kts"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;  do it = 0,ntimes-1,2             ; TIME LOOP

    print("Working on time: " + times(it) )
    res@TimeLabel = times(it)   ; Set Valid time to use on plots

     print("current time: " + times(it) )

   ; do level = 0,nlevels-1                 ; LOOP OVER LEVELS

    ;  print("current level (m): " + height_levels(level) )

     ; height = height_levels(level)

    ; Add some level into to the plot
     ; res@PlotLevelID = .001*height + " km"

    ; Plotting options for APCP
      opts = res
      opts@cnFillOn = True
     ; opts@cnFillColors      =  nexrad ;  refcolors
;     IF A PALETTE IS USED SPECIFY CONTOURS OTHERWISE GET ALL SORTS OF WEIRD #$%#%# ERRORS !!
      opts@cnFillPalette = "precip2_17lev"
      opts@cnLevelSelectionMode = "ExplicitLevels"   ; set explicit contour levels
     ; opts@ContourParameters = (/ 10., 200., 20./)
;    DO NOT START CONTOURS AT 0  - AUTOMATICALLY THERE !!!
     ;opts@cnLevels            = (/10, 20, 30,40,50,60,70,80,100/)
     opts@cnLevels            = (/1, 5, 10,15,20,30,40,50,75,100/)
;    # FillColors +1 = # cnLevels
     opts@cnFillColors        = (/0, 2, 5, 7, 9, 10,11,12,13,14,15/) ; #s refer to indices of colors in palette
      opts@FieldTitle        = "APCP"
     ;;;
     ;;; legend on the right
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
     ; opts@cnFillColors = (/"White","White","White", \
     ;                       "White","Chartreuse","Green",\
     ;                       "Green3","Green4", \
     ;                       "ForestGreen","PaleGreen4"/)
      printVarSummary(apcp)
      contour_apcp = wrf_contour(a,wks,apcp(0,:,:),opts)
      plot = wrf_map_overlays(a,wks,(/contour_apcp/),pltres,mpres)

;     overwrite these opts for dbz

      delete(opts@cnLevelSelectionMode)
      delete(opts@cnLevels)
      delete(opts@cnFillColors)
      delete(opts@cnFillPalette)

      opts@cnFillColors      = nexrad ;  refcolors
      opts@ContourParameters = (/ 10., 70., 5./)
      ;opts@FieldTitle        = "Composite reflectivity"
      
      printVarSummary(dbz)
      maxdbz=dim_max_n(dbz, 0)

      printVarSummary(maxdbz)
      contour_mdbz = wrf_contour(a,wks,maxdbz(1,:,:),opts)
      plot = wrf_map_overlays(a,wks,(/contour_mdbz/),pltres,mpres)

      delete(opts)

    ; end do      ; END OF LEVEL LOOP


  end do        ; END OF TIME LOOP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

end

