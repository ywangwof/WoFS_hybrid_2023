#!/usr/bin/env python3
## ---------------------------------------------------------------------
##
## This class allows for transformation between lat-lon coordinates and
## distance in meter with any of the supported map projections in a
## NWP model, e.g.
##
##     o Ploar,
##     o Stereographic,
##     o Lambert Conformal or
##     o Mercator
##
##  It is based on a Fortran program maproj3d.f90 in the ARPS package
##
## ---------------------------------------------------------------------
##
## HISTORY:
##
##   Yunheng Wang (01/28/2015)
##   Initial version based on early works at CAPS.
##
##
########################################################################
##
## Requirements:
##
##   o Python 2.7 or above
##
########################################################################

import math

class NWPMapProjector:

  ##----------------------- Constructor  -------------------------------

  def __init__(self,iproj,latnot,orient,scale=1.0,info=False) :

    self.info = info            ## message output

    self.eradius = 6371000.     ## mean earth radius in m
    self.d2rad   = math.pi/180.
    self.r2deg   = 180./math.pi

    #
    # Field Variables
    # Corresponding to Fortran common block "projcst"
    #
    #self.jproj  = 0
    #self.jpole  = 0
    self.trulat = [None]*2
    #self.rota   = 0.0
    #self.scmap  = 0.0
    #self.xorig  = 0.0
    #self.yorig  = 0.0
    #self.projc1 = 0.0
    #self.projc2 = 0.0
    #self.projc3 = 0.0
    #self.projc4 = 0.0

    ret = self.setmapr(iproj,latnot,orient,scale)
    if ret != 0:
        print ('ERROR: in setmapr, return = %d.'%ret)
    #if self.info:
    #    print """
    #          WARNING: The map projecter is still not initialized.
    #                   Please remember to call setmapr to initialize it.
    #          """
  #enddef __init__

  ##----------------------- setmapr  -------------------------------

  def setmapr(self,iproj, latnot, orient, scale=1.0):
    ##
    ## Set values to map projection variables
    ##
    ## iproj    Map projection flag
    ##            1 = North Polar Stereographic   (-1 South Pole)
    ##            2 = Northern Lambert Conformal  (-2 Southern)
    ##            3 = Mercator
    ##            4 = Lat,Lon
    ## scale    Map scale factor,  at latitude=latnot
    ##          Distance on map = (Distance on earth) * scale
    ##          For model runs, generally this is 1.0
    ##          For plotting this will depend on window size and
    ##          the area to be plotted.
    ## latnot   "True" latitude(s) of map projection (degrees, positive north)
    ##          Except for iproj=1, only latnot[0] is used
    ##
    ## orient   Longitude line that runs vertically on the map.
    ##          (degrees, negative west, positive east)
    ##
    ## return         0 - success; otherwise - fail.
    ##
    ##
    self.xorig = 0.0
    self.yorig = 0.0
    self.jproj = abs(iproj)
    self.jpole = 1 if iproj > 0 else -1

    istatus = 0
    if iproj == 0:
        if self.info: print ("""
                    INFO: No map projection will be used.
                            """)
    elif iproj in (1,-1):
        #
        #---------------------------------------------------------------
        #  Polar Stereographic projection
        #
        #  For this projection:
        #     projc1 is the scaled earth's radius, scale times eradius
        #     projc2 is the numerator of emfact, the map image scale factor.
        #     projc3 is projc2 times the scaled earth's radius.
        #
        #---------------------------------------------------------------
        #

        self.trulat[0] = latnot[0]
        self.rota      = orient
        self.scmap     = scale
        self.projc1    = scale*self.eradius
        self.projc2    = ( 1. + math.sin( self.d2rad * self.jpole * self.trulat[0] ) )
        self.projc3    = self.projc1*self.projc2

        if self.info:
            if self.jpole > 0:
              print ("""
                    INFO: Map projection set to Polar Stereographic
                          X origin, Y origin set to 0.,0. at the North Pole.
                    """)
            else:
              print ("""
                    INFO: Map projection set to Polar Stereographic
                          X origin, Y origin set to 0.,0. at the South Pole.
                    """)

    elif iproj in (2,-2):
        #
        #-----------------------------------------------------------------------
        #
        #  Lambert Conformal Conic Projection.
        #  For this projection:
        #      projc1 is the scaled earth's radius, scale times eradius/n
        #      projc2 is cos of trulat(1)
        #      projc3 is tan (45. - trulat/2) a const for local map scale
        #      projc4 is the cone constant, n
        #
        #-----------------------------------------------------------------------
        #
        self.trulat[0] = latnot[0]
        self.trulat[1] = latnot[1]
        self.rota      = orient
        self.scmap     = scale
        self.projc2    = math.cos( self.d2rad * self.trulat[0] )
        self.projc3    = math.tan( self.d2rad * (45. - 0.5*self.jpole * self.trulat[0]) )
        denom1 = math.cos(self.d2rad * self.trulat[1])
        denom2 = math.tan(self.d2rad * (45.-0.5*self.jpole * self.trulat[1]) )
        if abs(self.trulat[0]-self.trulat[1]) > 0.01 and denom2 != 0.:
          denom3 = math.log( self.projc3 / denom2)
        else:
          denom3 = 0.

        if denom1 != 0. and denom3 != 0.:
          self.projc4 = math.log( self.projc2 / denom1) / denom3
          if self.projc4 < 0.:
              print ("""
                    WARNING: in setmapr for Lambert Projection,
                             true latitudes provided: %f, %f
                             Projection must be from opposite pole
                             changing pole ......
                    """ % (self.trulat[0],self.trulat[1]))
              self.jpole = -1*self.jpole
              self.projc3 = math.tan(self.d2rad * (45.-0.5*self.jpole * self.trulat[0]) )
              denom2      = math.tan(self.d2rad * (45.-0.5*self.jpole * self.trulat[1]) )
              if denom2 != 0.0:
                  denom3 = math.log( self.projc3/denom2 )
              else:
                  denom3 = 0.0

              if denom1 != 0. and denom3 != 0.:
                 self.projc4 = math.log( self.projc2 / denom1 ) / denom3
              else:
                 print ("""
                       ERROR: in SETMAPR for Lambert Projection.
                              Illegal combination of trulats: %f, %f
                       """ % (self.trulat[0], self.trulat[1]))
                 return -2

          self.projc1 = scale*self.eradius/self.projc4
        elif denom3 == 0. and denom2 != 0.:
          self.projc4 = math.sin( self.d2rad * self.jpole * self.trulat[0] )
          if self.projc4 < 0.:
            print ("""
                  WARNING: in setmapr for Lambert Projection
                           For the true latitudes provided: %f, %f
                           Projection must be from opposite pole
                           changing pole ......
                 """ % (self.trulat[0], self.trulat[1]))
            self.jpole = -1*self.jpole
            self.projc4 = math.sin( self.d2rad * self.jpole * self.trulat[0] )
          self.projc1 = (scale*self.eradius)/self.projc4
        else:
          print ("""
                ERROR: in SETMAPR for Lambert Projection.
                       Illegal combination of trulats: %f, %f
                """ % (self.trulat[0],self.trulat[1]))
          return -2


        if self.info:
            if self.jpole > 0:
              print ("""
                    INFO: Map projection set to Lambert Conformal
                          X origin, Y origin set to 0.,0. at the North Pole.
                    """)
            else:
              print ("""
                    INFO: Map projection set to Lambert Conformal
                          X origin, Y origin set to 0.,0. at the South Pole.
                    """)

    elif iproj in (3,-3):
        #
        #---------------------------------------------------------------
        #
        #  Mercator Projection.
        #  For this projection:
        #      projc1 is the scaled earth's radius, scale times eradius
        #      projc2 is cos of trulat(1)
        #      projc3 is projc1 times projc2
        #
        #---------------------------------------------------------------
        #
        self.trulat[0] = latnot[0]
        self.rota = orient
        self.scmap = scale
        self.projc1 = scale*self.eradius
        self.projc2 = math.cos(self.d2rad*self.trulat[0])
        self.projc3 = self.projc1*self.projc2
        if self.projc2 <= 0.:
          print ("""
                ERROR: in SETMAPR for Mercator Projection
                      "       Illegal true latitude provided: %f.
                """ % (self.trulat[0]))
          return -2

        if self.info:
          print ("""
                INFO: Map projection set to Mercator
                      X origin, Y origin set to 0.,0. at the equator, %f
                      Y positive toward the North Pole.
                """ % (self.rota))
    elif iproj in (4,-4):
        #
        #---------------------------------------------------------------
        #
        #  Lat, Lon Projection.
        #  For this projection:
        #      projc1 is the scaled earth's radius, scale times eradius
        #      projc2 is cos of trulat(1)
        #      projc3 is projc1 times projc2 times 180/pi
        #
        #---------------------------------------------------------------
        #
        self.trulat[0] = latnot[0]
        self.rota   = orient
        self.scmap  = scale
        self.projc1 = scale*self.eradius
        self.projc2 = math.cos(self.d2rad*self.trulat[0])
        if self.projc2 <= 0.:
          print ("""
                ERROR: in SETMAPR for Lat,Lon Projection
                       Illegal true latitude provided: %f.
                """ % (self.trulat[0]))
          return -2

        self.projc3 = self.projc1*self.projc2/self.d2rad
        if self.info:
            print ("""
                  INFO: Map projection set to Lat, Lon
                        X origin, Y origin set to 0.,0. at the equator, 0. long
                        Y positive toward the North Pole.
                  """)
    else:
        print ("ERROR: unknown map projection option iproj = %i." % iproj)
        return -1


    return istatus

  ##----------------------- getmapr  -------------------------------

  def getmapr(self,info=False):
    # public int getmapr(int iproj, double scale, double[] latnot,
    #                 double orient, double x0, double y0)

    #
    # Get the settings for the current map projection, where var can be
    #
    # iproj    return map projection flag
    # scale    return map scale factor
    # latnot   return true latitudes in an array
    # orient   return true longitude
    # xorig    return X coordinate of origin
    # yorig    return Y coordinate of origin
    #

    mapdesc = ['No map projection',
               'Polar Stereographic projection',
               'Lambert Conformal Conic Projection',
               'Mercator projection',
               'Latitude/Longitude' ]
    mp = {}
    mp['iproj']  = self.jproj*self.jpole
    mp['scale']  = self.scmap
    mp['latnot'] = self.trulat
    mp['orient'] = self.rota

    if info:
        mp['xorig'] = self.xorig
        mp['yorig'] = self.xorig
        mp['jproj'] = self.jproj
        mp['jpole'] = self.jpole
        mp['projection'] = mapdesc[mp['iproj']]
        mp['constants'] = [self.projc1]
        if hasattr(self,'projc2'):
            mp['constants'].append(self.projc2)
        if hasattr(self,'projc3'):
            mp['constants'].append(self.projc3)
        if hasattr(self,'projc4'):
            mp['constants'].append(self.projc4)

    return mp

  ##----------------------- setorig  -------------------------------

  def setorig(self,iopt,x0,y0):
    # public int setorig(int iopt, double x0, double y0)
    #
    #
    # Set the origin for the map projection.
    # This is call after subroutine setmapr if the origin
    # must be moved from the original position, which is the
    # pole for
    #
    #   o the polar stereographic projection
    #   o the Lambert conformal
    #   o the equator for Mercator
    #
    #  iopt     origin setting option
    #         1: origin given in corrdinate x,y
    #         2: origin given in lat,lon on earth
    #
    #  x0       first coordinate of origin
    #  y0       second coordinate of origin
    #  return          0 - success; otherwise - failed
    #

    istatus = 0

    if iopt == 1:
      self.xorig = x0
      self.yorig = y0

      (rlat,rlon) = self.xytoll(0.0,0.0)
      if rlat is None or rlon is None:
          istatus = -2

      if self.info:
          print ("""
                INFO: Coordinate origin set to absolute x = %f, y = %f
                      latitude = %f, longitude = %f.
                """ % (x0,y0,rlat,rlon))
    elif iopt == 2:
      self.xorig = 0.
      self.yorig = 0.

      (xnew,ynew) = self.lltoxy(x0,y0)
      if xnew is None or ynew is None:
          istatus = -2

      self.xorig = xnew
      self.xorig = ynew

      if self.info:
          print ("""
                INFO: Coordinate origin set to absolute x = %f, y = %f
                      Latitude = %f, longitude = %f
                """ % (xnew,ynew,x0,y0))
    else:
      istatus = -1
      print ("ERROR: unknown option in setorig iopt = %i." % iopt)

    return istatus

  ##----------------------- xytoll  -------------------------------

  def xytoll(self,xin,yin):

    # public int xytoll(int idim, int jdim, double[] x, double[] y,
    #                double[][] rlat, double[][] rlon)
    #
    #
    # Determine latitude and longitude given X,Y coordinates on
    # map projection.  setmapr must be called before this routine
    # to set-up the map projection constants.
    #
    # idim     Number of points in x direction. (INPUT)
    # jdim     Number of points in y direction. (INPUT)
    #
    # x        Vector of x in map coordinates (INPUT)
    # y        Vector of y in map coordinates (INPUT)
    #          Units are meters unless the scale parameter is
    #          not equal to 1.0
    #
    # rlat     Array of latitude  (OUTPUT).
    #          (degrees, negative south, positive north)
    # rlon     Array of longitude (OUTPUT).
    #                  (degrees, negative west, positive east)
    # @return          0 - success; otherwise - failed.
    #
    #

    #-------------------------------------------------------------------
    #
    # Check input and output array sizes
    #
    #-------------------------------------------------------------------

    if xin is list:
        xlen = len(xin)
        ylen = len(yin)

        if ylen != xlen:
            print ("""
                  ERROR: dimension size is not consistent for input lists:
                            xin - %d, yin - %d
                  """%(xlen,ylen))
            return -1

        x = xin
        y = yin
    else:
        x = [xin]
        y = [yin]
        xlen = 1

    rlat = [None]*xlen
    rlon = [None]*xlen
    #-------------------------------------------------------------------
    #
    # Actual code to do the job
    #
    #-------------------------------------------------------------------

    if self.jproj == 0:
       ratio = self.r2deg / self.eradius
       for i in range(0,xlen):
           rlat[i] = ratio*(y[i]+self.yorig)
           rlon[i] = ratio*(x[i]+self.xorig)

    elif self.jproj == 1:
       for i in range(0,xlen):
           yabs = y[i]+self.yorig
           xabs = x[i]+self.xorig
           radius = math.sqrt( xabs*xabs + yabs*yabs ) / self.projc3
           rlat[i] = self.jpole*(90.-2.*self.r2deg*math.atan(radius))
           rlat[i] = min(rlat[i], 90.)
           rlat[i] = max(rlat[i],-90.)

           if self.jpole*yabs > 0.:
             dlon = 180. + self.r2deg*math.atan(-1*xabs / yabs)
           elif self.jpole*yabs < 0.:
             dlon = self.r2deg*math.atan(-1*xabs/yabs)
           elif xabs > 0.:    # y= 0.
             dlon =  90.
           else:
             dlon = -90.

           rlon[i] = self.rota+self.jpole*dlon
           if rlon[i] >  180.: rlon[i] = rlon[i]-360.
           if rlon[i] < -180.: rlon[i] = rlon[i]+360.

           rlon[i] = min(rlon[i], 180.)
           rlon[i] = max(rlon[i],-180.)

    elif self.jproj == 2:
       for i in range(0,xlen):
           yabs=y[i]+self.yorig
           xabs=x[i]+self.xorig
           radius=math.sqrt( xabs*xabs+ yabs*yabs )
           ratio=self.projc3*(pow( (radius/(self.projc1*self.projc2)), (1./self.projc4) ) )
           rlat[i] = self.jpole*(90. -2.*self.r2deg*(math.atan(ratio)))
           rlat[i] = min(rlat[i], 90.)
           rlat[i] = max(rlat[i],-90.)

           yjp=self.jpole*yabs
           if yjp > 0.:
             dlon=180. + self.r2deg*math.atan(-xabs/yabs)/self.projc4
           elif yjp < 0.:
             dlon=self.r2deg*math.atan(-xabs/yabs)/self.projc4
           elif xabs > 0.:     # y=0.
             dlon=90./self.projc4
           else:
             dlon=-90./self.projc4

           rlon[i] = self.rota + self.jpole*dlon
           if rlon[i] >  180.: rlon[i] = rlon[i]-360.
           if rlon[i] < -180.: rlon[i] = rlon[i]+360.

           rlon[i] = min(rlon[i], 180.)
           rlon[i] = max(rlon[i],-180.)

    elif self.jproj == 3:
       for i in range(0,xlen):
           yabs=y[i]+self.yorig
           xabs=x[i]+self.xorig
           rlat[i] = (90. - 2.*self.r2deg*math.atan(math.exp(-yabs/self.projc3)))
           rlat[i] = min(rlat[i], 90.)
           rlat[i] = max(rlat[i],-90.)

           dlon=self.r2deg*(xabs/self.projc3)
           rlon[i] = self.rota + dlon
           if rlon[i] >  180: rlon[i] = rlon[i]-360.
           if rlon[i] < -180: rlon[i] = rlon[i]+360.

    elif self.jproj == 4:
       for i in range(0,xlen):
           rlon[i]=x[i]+self.xorig
           rlat[i]=y[i]+self.yorig
    else:
       print ("ERROR: unknown map projection option jproj = %d."%(self.jproj))

    if xlen > 1:
        return (rlat,rlon)
    else:
        return (rlat[0],rlon[0])

  ##----------------------- lltoxy  -------------------------------

  def lltoxy(self,rlatin,rlonin):
    # public int lltoxy(int idim, int jdim, double[][] rlat, double[][] rlon,
    #                double[][] xloc, double[][] yloc)
    #
    #
    # Determine x, y coordinates on map projection from the given latitude
    # and longitude. setmapr must be called before this routine to set-up
    # the map projection constants.
    #
    # idim     Array dimension in x direction (INPUT)
    # jdim     Array dimension in y direction (INPUT)
    #
    # rlat     Array of latitude. (INPUT)
    #          (degrees, negative south, positive north)
    #
    # rlon     Array of longitude. (INPUT)
    #          (degrees, negative west, positive east)
    #
    #
    # xloc     Array of x in map coordinates (OUTPUT)
    # yloc     Array of y in map coordinates (OUTPUT)
    # return          0 - success; otherwise - failed.
    #

    #-------------------------------------------------------------------
    #
    # Check input and output array sizes
    #
    #-------------------------------------------------------------------

    if type(rlatin) is list:

        xlen = len(rlatin)
        ylen = len(rlonin)
        if xlen != ylen:
          print ("""
                ERROR: dimension size is not consistent for array rlat & rlon
                             rlatin - %d
                             rlonin - %d
                """%( xlen, ylen))
          return (None,None)
    else:
        rlon = [rlonin]
        rlat = [rlatin]
        xlen = 1

    xloc = [None]*xlen
    yloc = [None]*xlen

    #-------------------------------------------------------------------
    #
    # Executable code to do the convertion
    #
    #-------------------------------------------------------------------

    if self.jproj == 0:
       ratio = self.d2rad*self.eradius
       for i in range(0,xlen):
           xloc[i] = ratio*rlon[i] - self.xorig
           yloc[i] = ratio*rlat[i] - self.yorig
    elif self.jproj == 1:

       for i in range(0,xlen):
           denom=(1. + math.sin(self.d2rad*self.jpole*rlat[i]))
           if denom == 0.: denom=1.0e-10
           radius=self.jpole*self.projc3*math.cos(self.d2rad*rlat[i])/denom
           dlon=self.jpole*self.d2rad*(rlon[i]-self.rota)
           xloc[i]= radius*math.sin(dlon) - self.xorig
           yloc[i]=-radius*math.cos(dlon) - self.yorig

    elif self.jproj == 2:
       for i in range(0,xlen):
           # Handle opposite pole
           if self.jpole*rlat[i] < -89.9:
             lat = -89.9 * self.jpole
           else:
             lat = rlat[i]

           radius=self.projc1*self.projc2*pow(
                 ( math.tan(self.d2rad*(45.-0.5*self.jpole*lat))/self.projc3),
                   self.projc4 )
           tem = rlon[i]-self.rota
           if tem < -180.0: tem = 360.0+tem
           if tem >  180.0: tem = tem-360.0
           dlon=self.projc4*self.d2rad*tem
           xloc[i] =       radius*math.sin(dlon) - self.xorig
           yloc[i] =-self.jpole*radius*math.cos(dlon) - self.yorig
    elif self.jproj == 3:
       for i in range(0,xlen):
           dlon=rlon[i]-self.rota
           if dlon < -180.: dlon=dlon+360.
           if dlon >  180.: dlon=dlon-360.
           xloc[i]=self.projc3*self.d2rad*dlon - self.xorig
           denom=math.tan(self.d2rad*(45. - 0.5*rlat[i]))
           if denom <= 0. : denom=1.0e-10
           yloc[i]=-self.projc3*math.log(denom) - self.yorig
    elif self.jproj == 4:
       for i in range(0,xlen):
           xloc[i]=rlon[i]-self.xorig
           if xloc[i] < -180.: xloc[i]=xloc[i]+360.
           if xloc[i] >  180.: xloc[i]=xloc[i]-360.
           yloc[i]=rlat[i]-self.yorig
    else:
       print ("ERROR: unknown map projection option jproj = %d." % jproj)

    if xlen > 1:
        return xloc,yloc
    else:
        return xloc[0],yloc[0]


#############################  Portral   ###############################

if __name__ == "__main__":
    #
    #
    # Program to do testing
    #
    #
    latnot = [ 30.0, 60.0 ]

    print ("\n=== Test of a complete setup")
    #NOTE1: Create an instance with the specified map projection
    mapproj_test0 = NWPMapProjector(2,latnot,-100.0,info=False)

    clat = 38.
    clon = -98.

    nx_wrf = 65
    ny_wrf = 65
    dx_wrf = 30000.0
    dy_wrf = 30000.

    # NOTE2: The following code working on this instance
    (cx,cy) = mapproj_test0.lltoxy( clat,clon )
    #(swx,swy) = mapproj_test0.lltoxy( clat,clon )
    # NOTE3: input/output to lltoxy may be lists or scalars
    # NOTE4: the return status should be checked to ensure error-free.
    if cx is not None and cy is not None:
    #if swx is not None and swy is not None:
      swx = cx - 0.5*(nx_wrf-1) * dx_wrf
      swy = cy - 0.5*(ny_wrf-1) * dy_wrf
      rstatus = mapproj_test0.setorig( 1, swx, swy)
      #NOTE5: Reset the map projection origin to be our model southwest corn
      #       instead of the default north pole. Then we can convert between
      #       the model coordinates x/y and lat/lon by calling xytoll or lltoxy.

    clat =  35.97202
    clon = -97.94890
    cx,cy = mapproj_test0.lltoxy(clat,clon)
    # This call find x/y coordiates of an arbitrary lat/lon point. Note again
    # that the inputs/outputs must be arrays. You should also check the retrun
    # status.
    print ("ctrx = %f, ctry = %f" % (cx,cy))
    print ("ctrx = %f, ctry = %f" % mapproj_test0.xytoll(960000,960000))

    if cx is  None or cy is  None:
      print ("*** Failed ***")
    else:
      print ("--- success ---")

    print ("\n=== Test with no map projection:")
    mapproj_test0 = NWPMapProjector(0,latnot, -100.0,info=False)
    mapproj_test0.setorig(1,2000000,4000000)

    print ("\n=== Test with 1:")
    mapproj_test1 = NWPMapProjector(1, latnot, -100.0,False)

    print ("\n=== Test with -2:")
    latnot = [ -30, -60. ]
    mapproj_test2 = NWPMapProjector(-2, latnot, -100.0,False)

    print ("\n=== Test with no parameter:")
    mapproj_test0 = NWPMapProjector(4, latnot, -100.0,False)
    if rstatus == 0:
      rstatus = mapproj_test0.setorig(2,38.0,-89.9)

    if rstatus != 0:
      print ("*** Failed ***")
    else:
      print ("--- success ---")
