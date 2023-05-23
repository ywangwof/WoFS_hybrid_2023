#!/usr/bin/env python
##
##----------------------------------------------------------------------
##
## This file contains program to convert OK MESONET mdf file to lso
## file format
##
## ---------------------------------------------------------------------
##
## HISTORY:
##   Yunheng Wang (04/27/2018)
##   Initial version based on early works.
##
##
########################################################################
##
## Requirements:
##
##   o Python 2.7 or above
##
########################################################################

import csv
import time, math
from datetime import datetime, timedelta

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
# class to hold station values
#
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#class Station:
#
#    def __init__(self,stnm=0,name=None,nlat=0.0,elon=0.0,elev=0.0):
#        '''
#           station info
#        '''
#        self.stnm  = stnm
#        self.name  = name
#        self.nlat  = nlat
#        self.elon  = elon
#        self.elev  = elev
#
##endclass Station

class Dict2Obj(dict):

    def __init__(self,dictin=None):
        dict.__init__(self)
        if dictin is None: return

        for key in dictin.keys():
          self[key] = dictin[key]

    def __getattr__(self,key):
        return self[key]

    #def __setattr__(self,key,value):
    #    self[key] = value

#endclass Dict2Obj

########################################################################

def decode_geoinfo(filename):
  '''
     Decode MESONET geoinfo file for station information
  '''

  stations = {}
  with open(filename, 'r') as csvfile:
      reader = csv.reader(csvfile)
      row = next(reader)
      headers = row[2:]
      headers.insert(0,row[0])
      for row in reader:
            #        stid              stnm        name         nlat          nlon          elev
            #stations[row[1]] = Station(int(row[0]),row[2],float(row[8]),float(row[9]),float(row[10]))
            vals=row[2:]
            vals.insert(0,row[0])
            stations[row[1]] = Dict2Obj({key: value for key, value in zip(headers, vals)})
      #print stations['ACME'].keys()
      #print stations['ACME'].nlat
      #print stations['ACME'].elon
      #print stations['ACME'].elev
  return stations

########################################################################

def decode_mesomdf(filename):
  '''
     Decode MESONET mdf file
  '''

  mesonet = Dict2Obj()
  with open(filename, "r") as mdffile:
      reader = csv.reader(mdffile,delimiter=' ',skipinitialspace=True)
      copyright = next(reader)          # skip copyright
      times = next(reader)              # get times
      mesonet.basetime = datetime(*map(int, times[1:]))
      #print mesonet['basetime']
      headers = next(reader)[1:]        # get headers
      #print headers
      for row in reader:
          mesonet[row[0]] = Dict2Obj({key: float(value) for key, value in zip(headers, row[1:])})
      mesonet.time_in_minutes = int(row[2])
      #print mesonet['time_in_minutes']
  return mesonet

########################################################################

def rh2td(Te,rh):
  '''

   Convert RH to Td - Arden Buck equation

  '''
  a = 6.1121   # mb,
  b = 18.678
  c = 257.14   # C,
  d = 234.5    # C

  Psm = math.exp((b-Te/d)*(Te/(c+Te)))
  if rh < 0: return -99.9
  Rd = math.log((rh/100.)*Psm)
  Td = (c*Rd)/(b-Rd)

  return Td    # in C

########################################################################

def meso2lso(infilename,stnfilename,outfilename):
  '''
     Convert mesonet observation to LSO observations
  '''
  stations = decode_geoinfo(stnfilename)
  mesonet  = decode_mesomdf(infilename)

  lsotime  = mesonet.basetime+timedelta(minutes=mesonet.time_in_minutes)
  nlso    = len(mesonet)
  lsotimestr1 = lsotime.strftime('%H%M')
  lsotimestr2 = lsotime.strftime('%d-%b-%Y %H:%M:%S.00').upper()

  rmiss = -99.9
  with open(outfilename,'w',encoding="utf-8") as lsofile:
    print(" %s %d   0   0   0   0   0 %d   0 %d 9999" % (lsotimestr2,nlso,nlso,nlso),file=lsofile)
    for key in mesonet.keys():

      if key not in stations.keys():
          print(f"{key} is not in the station file. skipped")
          continue

      td = rh2td(mesonet[key].TAIR, mesonet[key].RELH)

      if td > rmiss:
        tdF = 9.0/5.0 * td + 32.
      else:
        tdF = rmiss

      if mesonet[key].TAIR > rmiss:
        teF = 9.0/5.0 * mesonet[key].TAIR + 32.
      else:
        teF = rmiss

      if mesonet[key].WSPD > rmiss:
        wkts = 1.94384*mesonet[key].WSPD    # knots
      else:
        wkts = rmiss

      if mesonet[key].WMAX > rmiss:
        mkts = 1.94384*mesonet[key].WMAX    # knots
      else:
        mkts = rmiss

      print(" %s %6.2f %7.2f%5.0f. MESO     %s         " % (key,
               float(stations[key].nlat), float(stations[key].elon),
               float(stations[key].elev),lsotimestr1),file=lsofile)
      print("    %6.1f %6.1f %6.1f %6.1f %6.1f %6.1f %6.1f %6.1f %6.1f" %(
               teF,tdF,mesonet[key].WDIR,wkts,mesonet[key].WDIR,mkts,
               mesonet[key].PRES,rmiss,rmiss),file=lsofile)
      print("     0 %6.1f %6.1f %6.1f %6.1f %7.1f  -99" %(
               rmiss,rmiss,rmiss,rmiss,mesonet[key].SRAD),file=lsofile)

########################################################################

def findRange(stnfilename):
    ''' Find the mesonet coverage range '''

    stations = decode_geoinfo(stnfilename)

    latmin=90.0
    latmax=0.0
    lonmin=180
    lonmax=-180
    for k,v in stations.items():
        nlat = float(v["nlat"])
        elon = float(v["elon"])
        if nlat > latmax:
            latmax = nlat
        if nlat < latmin:
            latmin = nlat

        if elon > lonmax:
            lonmax = elon
        if elon < lonmin:
            lonmin = elon

    #print(f"latmin = {latmin}, latmax = {latmax}")
    #print(f"lonmin = {lonmin}, lonmax = {lonmax}")

    return (lonmin, latmin, lonmax, latmax)

#############################  Portral   ###############################

if __name__ == "__main__":

  stime = time.time()

  #meso2lso("/scratch/ywang/real_runs/mesonet.realtime.201804271500.mdf",
  #         "/scratch/ywang/NEWSVAR/news3dvar.2018/NSSLVAR/okmeso_geoinfo.csv",
  #         "201804271500.lso")
  #
  #
  #etime = time.time()-stime
  #fm = (etime % 3600 )//60
  #fs =  etime % 3600 - fm*60
  #print ("Job finished and used %02dm %02ds." % ( fm,fs))

  lonmin, latmin, lonmax, latmax = findRange('/oldscratch/ywang/NEWSVAR/news3dvar.2020/NSSLVAR/okmeso_geoinfo.csv')

  print(f"latmin = {latmin}, latmax = {latmax}")
  print(f"lonmin = {lonmin}, lonmax = {lonmax}")

