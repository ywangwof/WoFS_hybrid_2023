#!/usr/bin/env python
##
##----------------------------------------------------------------------
##
## This file set up analysis domains.
##
## setRadars    find radar within given model domains based on an static
##              radarinfo file.
##
## ---------------------------------------------------------------------
##
## HISTORY:
##   Yunheng Wang (03/23/2016)
##   Initial version based on a Fortran version getRadar.f90.
##
##
########################################################################
##
## Requirements:
##
##   o Python 2.7 or above
##
########################################################################

import re
from NWPMapProjection import NWPMapProjector

##%%%%%%%%%%%%%%%%%%%%%%%  class Radar      %%%%%%%%%%%%%%%%%%%%%%%%%%%

class Radar:
    #classbegin
    ''' This class holds the information for one radar, including

        name:
        lat:        latitude
        lon:        longitude
        distance:   Square of latitude/longitude difference
    '''

    ##----------------------- Constructor  -----------------------------
    def __init__(self,radname,radlat,radlon,rdist=None) :
      self.name  = radname
      self.lat   = radlat
      self.lon   = radlon
      self.distance = rdist    # distance from the central of the domain
    #enddef __init__

    ####################### outputString ###############################
    def __str__(self):
        ''' print or str()'''

        #outstring = '{'
        #outstring += "'name': '%s', " %(self.name)
        #outstring += "'lat': %f, " %(self.lat)
        #outstring += "'lon': %f " %(self.lon)
        #outstring += '}'
        outstring = "('%s', %f, %f)" %(self.name,self.lat,self.lon)

        return outstring

    def __repr__(self):
       return str(self)

#endclass Radar

##%%%%%%%%%%%%%%%%%%%%%%%  class Domain      %%%%%%%%%%%%%%%%%%%%%%%%%%%

class Domain(dict):
    #classbegin
    ''' This class holds the domain information

       'nx' : 501,
       'ny' : 501,
       'dx' : 1500.,
       'dy' : 1500.,
       'ctrlat' : None,
       'ctrlon' : None,

       'map_proj'  : 'lambert', #AOF TO REMVOE THIS POS LAMBERT PROJECTION !!!
       'truelat1'  : 30.0,
       'truelat2'  : 60.0,
       'standlon' : -98.0,

       'radars'    : [],
       'usedradars': [],
       'search_done' : False,
       'cycle_num'   : 0,
       'cycle_base'  : ' ',
    '''

    ##----------------------- Constructor  -----------------------------
    def __init__(self) :

        default = {'id' : 0,
                   'nx' : 601,
                   'ny' : 601,
                   'dx' : 1500.,
                   'dy' : 1500.,
               'ctrlat' : None,
               'ctrlon' : None,

                   'map_proj'  : 'lambert', #AOF TO REMVOE THIS POS LAMBERT PROJECTION !!!
                   'truelat1'  : 30.0,
                   'truelat2'  : 60.0,
                   'standlon'  : -98.0,

                   'radars'    : [],        # radars within this domain, store radar objects
                   'usedradars': [],        # radars will be used for analysis, store radar.name only
                   'outradars' : [],        # radars outside of this domain, for diagnostic purpose
                   'search_done' : False,
                   'cycle_num'   : 0,
                   'cycle_base'  : ' ',
                   'ranges'      : []
                }
        super().__init__(default)

    #enddef __init__

    def __getattr__(self,key):
          return self[key]

    #def __setattr__(self,key,value):
    #    if key in ("numtry",):
    #        self[key] = value
    #    else:
    #        raise KeyError("Only job <numtry> can be set")

    ##%%%%%%%%%%%%%%%%%%%%%%%  setRadars     %%%%%%%%%%%%%%%%%%%%%%%%%%%

    def setRadars(self,radarlist,extendx=140,extendy=140,ordered=True,info=False) :
        '''
          Find radar name within the domain based on a radar list that
          contains Radar object as elements.

          extendx   Extended search range (KM) in each direction
          extendy
        '''

        extrng_x = extendx*1000.0
        extrng_y = extendy*1000.0

        mapwrftoarps = { 'lambert' : 2, 'polar' : 1, 'mercator' : 3 }

        #
        #  Set up map projection.
        #
        iproj = mapwrftoarps[self.map_proj]
        latnot = [ self.truelat1,self.truelat2 ]
        orient = self.standlon

        #NOTE1: Create an instance with the specified map projection
        mapproj = NWPMapProjector(iproj,latnot,orient,scale=1.0,info=False)

        clat = self.ctrlat
        clon = self.ctrlon

        nx = self.nx
        ny = self.ny
        dx = self.dx
        dy = self.dy

        xl = (nx-1)*dx
        yl = (ny-1)*dy

        # NOTE2: The following code working on this instance
        (cx,cy) = mapproj.lltoxy( clat,clon )
        # NOTE3: input/output to lltoxy may be lists or scalars
        # NOTE4: the return status should be checked to ensure error-free.
        if cx is not None and cy is not None:
          swx = cx - 0.5*xl
          swy = cy - 0.5*yl
          mapproj.setorig( 1, swx, swy)
          #NOTE5: Reset the map projection origin to be our model southwest corn
          #       instead of the default north pole. Then we can convert between
          #       the model coordinates x/y and lat/lon by calling xytoll or lltoxy.
        else:
          raise Exception("May projection problem in Domain")
          #continue

        xorig = 0.0
        yorig = 0.0

        (rad_grd_lat1,rad_grd_lon1) = mapproj.xytoll(xorig-extrng_x,yorig-extrng_y)
        if info: print ('Lat/lon at the SW corner of base grid= %f, %f.' %(rad_grd_lat1,rad_grd_lon1))

        (rad_grd_lat2,rad_grd_lon2) = mapproj.xytoll((xorig+xl+extrng_x),(yorig+yl+extrng_y),)
        if info: print ('Lat/lon at the NE corner of base grid= %f, %f.' %(rad_grd_lat2,rad_grd_lon2))

        rlat = 0.5*(rad_grd_lat1+rad_grd_lat2)
        rlon = 0.5*(rad_grd_lon1+rad_grd_lon2)

        #
        # Match radar name and table name
        #
        radars = []
        radars_outside = []
        for radar in radarlist:
            if radar.lat>rad_grd_lat1 and radar.lat<rad_grd_lat2 and    \
               radar.lon>rad_grd_lon1 and radar.lon<rad_grd_lon2 :

                radar.distance = (radar.lat-rlat)**2+(radar.lon-rlon)**2

                radars.append( radar )
            else:
                radars_outside.append( radar )

        #
        # find the distance between center and radars
        #
        if ordered:
            radars = sorted(radars,key=lambda radar: radar.distance)  # sorted by distance

        self['radars'] = radars
        self['outradars'] = radars_outside

    #enddef setRadars

    ##%%%%%%%%%%%%%%%%%%%%%%%  checkRange   %%%%%%%%%%%%%%%%%%%%%%%%%%%

    def checkRange(self,latmin,latmax,lonmin,lonmax,extend=0,info=False) :
        '''
          Check whether this domain is within the given range (latmin - latmax,lonmin - lonmax)
          even the domain will be shrinked an exension in KM.

        NOTE: assume range (OK MESO network) is larger than this domain.
        '''

        extrng_x = extend*1000.0
        extrng_y = extend*1000.0

        mapwrftoarps = { 'lambert' : 2, 'polar' : 1, 'mercator' : 3 }

        #
        #  Set up map projection.
        #
        iproj = mapwrftoarps[self.map_proj]
        latnot = [ self.truelat1,self.truelat2 ]
        orient = self.standlon

        #NOTE1: Create an instance with the specified map projection
        mapproj = NWPMapProjector(iproj,latnot,orient,scale=1.0,info=False)

        clat = self.ctrlat
        clon = self.ctrlon

        nx = self.nx
        ny = self.ny
        dx = self.dx
        dy = self.dy

        xl = (nx-1)*dx
        yl = (ny-1)*dy

        # NOTE2: The following code working on this instance
        (cx,cy) = mapproj.lltoxy( clat,clon )
        # NOTE3: input/output to lltoxy may be lists or scalars
        # NOTE4: the return status should be checked to ensure error-free.
        if cx is not None and cy is not None:
          swx = cx - 0.5*xl
          swy = cy - 0.5*yl
          mapproj.setorig( 1, swx, swy)
          #NOTE5: Reset the map projection origin to be our model southwest corn
          #       instead of the default north pole. Then we can convert between
          #       the model coordinates x/y and lat/lon by calling xytoll or lltoxy.
        else:
          raise Exception("May projection problem in Domain")
          #continue

        xorig = 0.0
        yorig = 0.0

        (rad_grd_lat1,rad_grd_lon1) = mapproj.xytoll(xorig+extrng_x,yorig+extrng_y)
        if info: print (f'Lat/lon at the SW corner of base grid= {rad_grd_lat1}, {rad_grd_lon1}.')

        (rad_grd_lat2,rad_grd_lon2) = mapproj.xytoll((xorig+xl-extrng_x),(yorig+yl-extrng_y),)
        if info: print (f'Lat/lon at the NE corner of base grid= {rad_grd_lat2}, {rad_grd_lon2}.')

        #rlat = 0.5*(rad_grd_lat1+rad_grd_lat2)
        #rlon = 0.5*(rad_grd_lon1+rad_grd_lon2)

        #
        # check if two rectangles overlap
        #

        overlap = True
        # If one rectangle is on left side of other
        if rad_grd_lon1 >= lonmax:
            if info: print(f"This domain (shrinking {extend} KM) is on the east of the range {lonmin,lonmax}.")
            overlap = False

        elif rad_grd_lon2 <= lonmin:
            if info: print(f"This domain (shrinking {extend} KM) is on the west of the range {lonmin,lonmax}.")
            overlap = False

        # If one rectangle is above other
        elif rad_grd_lat1 >= latmax:
            if info: print(f"This domain (shrinking {extend} KM) is on the north of the range {latmin,latmax}.")
            overlap = False

        elif rad_grd_lat2 <= latmin:
            if info: print(f"This domain (shrinking {extend} KM) is on the south of the range {latmin,latmax}.")
            overlap = False

        self.ranges.append( (overlap, lonmin, lonmax, latmin, latmax))
        if info: print(f"This domain (shrinking {extend} KM) overlaps with the range.")
        return overlap

        #
        # Match the range with the domain
        #
        # Check 4 points
        #
        #print(latmin,latmax, latmax-latmin)
        #print(lonmin,lonmax, lonmax-lonmin)
        #print(rad_grd_lat1,rad_grd_lat2,rad_grd_lat2-rad_grd_lat1)
        #print(rad_grd_lon1,rad_grd_lon2,rad_grd_lon2-rad_grd_lon1)
        #ncorners=0
        #if rad_grd_lat1 > latmin  and rad_grd_lat1 < latmax:
        #    if rad_grd_lon1 > lonmin and rad_grd_lon1 < lonmax:
        #        if info: print(f"The domain SW corner (shrinking {extend} KM) is within the range.")
        #        ncorners +=1
        #
        #    if rad_grd_lon2 > lonmin and rad_grd_lon2 < lonmax:
        #        if info: print(f"The domain SE corner (shrinking {extend} KM) is within the range.")
        #        ncorners +=1
        #
        #if rad_grd_lat2 > latmin  and rad_grd_lat2 < latmax:
        #    if rad_grd_lon1 > lonmin and rad_grd_lon1 < lonmax:
        #        if info: print(f"The domain NW corner (shrinking {extend} KM) is within the range.")
        #        ncorners +=1
        #
        #    if rad_grd_lon2 > lonmin and rad_grd_lon2 < lonmax:
        #        if info: print(f"The domain NE corner (shrinking {extend} KM) is within the range.")
        #        ncorners +=1
        #
        #if info and ncorners <= 0: print(f"lat: {latmin} to {latmax}, lon: {lonmin} to {lonmax} no overlap with domain even shrink {extend} KM")
        #
        #return ncorners > 0
    #enddef checkRange

    ####################### outputString ###############################
    def __str__(self):
        ''' print or str()'''
        outstring = '%02d: '%self['id']
        if self['ctrlat'] is None or self['ctrlon'] is None:
          outstring = 'domain is still not initialized because ctrlat/ctrlon is None'
        else:
          for key in ['nx','ny','dx','dy','ctrlat','ctrlon']:
              outstring += f'{key} = {self[key]}, '

        return outstring

#endclass Domain

##%%%%%%%%%%%%%%%%%%%%%%%  class NSSLDomains %%%%%%%%%%%%%%%%%%%%%%%%%%%

class NSSLDomains(list):
    #classbegin

    ##----------------------- Constructor  -----------------------------
    def __init__(self,number=1,cycledir=None,cycleno=0) :
        domain = Domain()
        self.source = None
        self.cyclebase = cycledir
        self.numcycles = cycleno
        list.__init__(self, [domain for i in range(number)])

    ##%%%%%%%%%%%%%%%%%%%%%%%  setIDS     %%%%%%%%%%%%%%%%%%%%%%%%%%%

    def setAttrs(self,caseNo) :
        ''' set default values to all fields for all domains
        '''
        if caseNo == 3:
            rootid = 10                      # The first domain id in this group
        elif caseNo in ( 4,5,6,7 ):          # Only it will do ungrib or other special processes
            rootid = 20                      # that are domain independent
        elif caseNo == 27:
            rootid = 30
        else:
            rootid = 0

        domainid = 0
        for domain in self:
            domain["id"] = rootid + domainid
            if domain.id == rootid:
              domain["isroot"] = True
            else:
              domain["isroot"] = False
            domainid += 1

            # set default cycling attributes to all domains
            domain["cycle_base"] = self.cyclebase
            domain['cycle_num']  = self.numcycles

    #enddef setAttrs

    ##%%%%%%%%%%%%%%%%%%%%%%%  setRadars     %%%%%%%%%%%%%%%%%%%%%%%%%%%

    def setRadars(self,radinfo,extendx=140,extendy=140,ordered=True,info=False) :
        '''
          Extract a radar list from the radar information file "radinfo".

          Set the radar names within each domain based on the extended ranges.

          extendx:   Extended search range (km) in each direction
          extendy:
        '''

        ## ----------------- Read station table data -------------------

        radinfo_line_ex = re.compile(r'^(\w{4}) +[^ ]+ +((?:\d{1,3} +){6})\d+ *')

        radartable = []
        with open(radinfo) as res:
            for line in res:
                linematch = radinfo_line_ex.match(line)
                if linematch:
                    rnam = linematch.group(1)
                    ilat,ilatmin,ilatsec,ilon,ilonmin,ilonsec =  linematch.group(2).split()
                    rlat = float(ilat)+(float(ilatmin)/60.)+(float(ilatsec)/3600.)
                    rlon = -1.*(float(ilon)+(float(ilonmin)/60.)+(float(ilonsec)/3600.))
                    radar = Radar(rnam,rlat,rlon)
                    radartable.append(radar)

        if info: print (' Read in %d NEXRAD radars from table "%s".' % (len(radartable),radinfo))

        ## ------------------ process each domain ----------------------

        for domain in self:
            domain.setRadars(radartable,extendx,extendy,ordered,info)

    #enddef setRadars

    ###################################################################
    ##
    ## Given output in a text file and construct a domains list
    ##
    ###################################################################

    def parseOutput(self,txtfile):
        '''
        decode getmaxref text output for domains
        '''

        domainex = re.compile(r'^ \d{2} = +([0-9.-]{3,12}) +([0-9.-]{3,12})$')

        domcount = 0
        with open(txtfile) as res:
            for line in res:
                dommath = domainex.match(line)
                if dommath:
                    domain = Domain()
                    domain['ctrlon'] = float(dommath.group(1))
                    domain['ctrlat'] = float(dommath.group(2))
                    self.append(domain)
                    domcount += 1

        self.source = txtfile

        return domcount

    #enddef parseOutput

    ###################################################################
    ##
    ## Given command line string to construct a domains list
    ##
    ## Expect the string to be: nx,ny,dx,dy,ctrlat,ctrlon:nx,ny,dx,dy,ctrlat,ctrlon:...
    ##
    ###################################################################

    def parseCMD(self,args):
        dcases = args.split(':')
        for case in dcases:
            parms = case.split(',')
            domain = Domain()
            #domain['nx'    ] = int(parms[0])
            #domain['ny'    ] = int(parms[1])
            #domain['dx'    ] = float(parms[2])
            #domain['dy'    ] = float(parms[3])
            domain['ctrlat']   = float(parms[0])
            domain['ctrlon']   = float(parms[1])
            domain['standlon'] = float(parms[1])
            self.append(domain)

        self.source = args

        #print "=== Get %d domains from input:" % (lendom)
        #dom = 0
        #for domain in domains:
        #    dom += 1
        #    print("    \t %d: {" + ", ".join("{}: {}".format(k, v) for k, v in domain.items()) + "}") % dom

    ###################################################################
    ##
    ## Given a text file name, read it and parse into a domains list
    ##
    ## lines in the file like:
    ##    nx,ny,dx,dy,ctrlat,ctrlon
    ##    nx,ny,dx,dy,ctrlat,ctrlon
    ##    ...
    ##
    ###################################################################

    def parseTXT(self,filename):
        with open(filename) as f:
            for line in f:
                if line[0] == '#': continue
                lines  = line.split('#')
                parms  = lines[0].split(',')

                if len(parms) == 6:
                    domain = Domain()
                    domain['nx'    ] = int(parms[0])
                    domain['ny'    ] = int(parms[1])
                    domain['dx'    ] = float(parms[2])
                    domain['dy'    ] = float(parms[3])
                    domain['ctrlat'] = float(parms[4])
                    domain['ctrlon'] = float(parms[5])
                    domain['standlon'] = float(parms[5])
                    self.append(domain)
                elif len(parms) == 9:
                    domain = Domain()
                    domain['nx'    ] = int(parms[0])
                    domain['ny'    ] = int(parms[1])
                    domain['dx'    ] = float(parms[2])
                    domain['dy'    ] = float(parms[3])
                    domain['ctrlat'] = float(parms[4])
                    domain['ctrlon'] = float(parms[5])
                    domain['truelat1' ] = float(parms[6])
                    domain['truelat2' ] = float(parms[7])
                    domain['standlon'] = float(parms[8])
                    self.append(domain)
                elif len(parms) == 2:
                    domain = Domain()
                    domain['ctrlat'] = float(parms[0])
                    domain['ctrlon'] = float(parms[1])
                    domain['standlon'] = float(parms[1])
                    self.append(domain)
                else:
                    continue
                #print(domain)
        self.source = filename

    ###################################################################
    ##
    ## Given a list of dict variables, parse them into a domains list
    ##
    ###################################################################
    def parseDict(self,domlist):

      for domdict in domlist:
        if len(domdict) > 0:
          domain = Domain()
          for k,v in domdict.items():
            if k in domain.keys():
              domain[k] = v

          self.append(domain)

      self.source = str(domlist)

#endclass NSSLDoamins


#############################  Portral   ###############################

if __name__ == "__main__":
    #
    #
    # Program to do testing
    #
    #
    #radinfo = "/scratch/ywang/real_runs/20160315/1705Z/dom00/getradar/radarinfo.dat"
    #radinfo = "/oldscratch/ywang/NEWSVAR/news3dvar.2019/NSSLVAR/radarinfo.wofldm"
    #domains = NSSLDomains(1)
    #print(domains[0])
    #domains[0]['ctrlat'] = 37.0944
    #domains[0]['ctrlon'] = -95.5987
    #print(domains[0])
    #radars_all = domains.setRadars(radinfo,info=True)
    #
    #print(domains.source)
    #for domain in domains:
    #    radars = domain.radars
    #
    #    print( 'radar names(%d): %s '% (len(radars),', '.join([radar.name for radar in radars]) ))
    #    print( 'lats = (/ %s /)' % (', '.join(['%10.4f'%radar.lat for radar in radars]) )        )
    #    print( 'lons = (/ %s /)' % (', '.join(['%10.4f'%radar.lon for radar in radars]) )        )
    #    print( 'dist = (/ %s /)' % (', '.join(['%10.2f'%radar.distance for radar in radars]) )   )
    #    print( "\n"                                                                              )

    # Check domain and mesonet range
    #
    from prep_okmeso import findRange

    rlonmin, rlatmin, rlonmax, rlatmax = findRange('/oldscratch/ywang/NEWSVAR/news3dvar.2021/NSSLVAR/okmeso_geoinfo.csv')
    print(f"latmin = {rlatmin}, latmax = {rlatmax}")
    print(f"lonmin = {rlonmin}, lonmax = {rlonmax}")

    domains = NSSLDomains(0)
    domains.parseTXT('/scratch/ywang/real_runs/20210506.dom')

    a = domains[0].checkRange(rlatmin,rlatmax,rlonmin,rlonmax,0,True)
    print(a)
