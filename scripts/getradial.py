#!/usr/bin/env python

import os, glob
#from datetime import datetime, timedelta
from datetime import datetime, timedelta
import time, sys

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
# class to default values for time related options
#
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class TimeOpt(dict):

    def __init__(self) :
        '''
           Radar radial file time related options
           default values
        '''
        dict.__init__(self)

        self['range']    = range(0,-9,-1)+range(1,2)    # time range to search in minutes
                                                        # relative to "timedt"
        self['grace']    = 2*60                         # grace period in seconds for file ready
        self['maxwait']  = 120                          # max waiting time in seconds for file ready
        self['waittick'] = 5                            # in seconds
        self['expectsize'] = 0                          # in Kilobytes

    def __getattr__(self,key):
        return self[key]

    def __setattr__(self,key,value):
        self[key] = value

#endclass TimeOpt

################# get_radial_list ######################################

def get_radial_list(timedt,rootdir,radars=[],timeopts=TimeOpt()):
  '''
  timedt  : Time to search in datetime formate
  rootdir : Radar data root directory
  '''

  timerange = timeopts.range
  filegrace = timeopts.grace

  rootlen = len(rootdir)

  if len(radars) > 0:
    radarlist = radars
  else:
    radarlist = os.listdir(rootdir)

  file_list  = {}
  for radar in radarlist:   # all radars in the rootdir
    radardir = os.path.join(rootdir,radar,'AliasedVelocityDPQC')
    radarflcnt = 0
    for elvang in sorted(os.listdir(radardir)):
      # all available elevatin angles
      for minute in timerange:
        datatime = timedt + timedelta(minutes=minute)
        datetstr = datatime.strftime('%Y%m%d-%H%M')
        datafls   = glob.glob(os.path.join(radardir,elvang,'%s*.netcdf'%datetstr))
        #print radar, datetstr, elvang, datafls
        filecnt = len(datafls)
        #assert(filecnt <= 1)
        if filecnt == 1:
          candifil = datafls[0]      # Candidate file to be added
          #print radar, datetstr, elvang, 'Adding ', datafls[0]
          timediff = datetime.now() - datatime
          if timediff.total_seconds() <= filegrace:
            #
            # File may be actively writting
            #
            if not wait_file_for_ready(candifil,maxwaitready=timeopts.maxwait,
                              waittick=timeopts.waittick,expectSize=timeopts.expectsize): continue

          if radarflcnt == 0:
            file_list[radar] = [candifil[rootlen+1:]]
            #print radar, file_list[radar]
          else:
            file_list[radar].append(candifil[rootlen+1:])
            #print radar, file_list[radar]
          radarflcnt += 1
          break
        else:
          continue
      #print len(file_list[radar])

  return file_list
#enddef get_radial_list

################# floorTime ###########################################

def floorTime(dt=None, dateDelta=timedelta(minutes=1)):
    """Round a datetime object to a multiple of a timedelta
    dt : datetime.datetime object, default now.
    dateDelta : timedelta object, we round to a multiple of this, default 1 minute.
    """
    roundTo = dateDelta.total_seconds()

    if dt == None : dt = datetime.now()
    seconds = (dt - dt.min).seconds
    # // is a floor division, not a comment on following line:
    rounding = seconds // roundTo * roundTo
    return dt + timedelta(0,rounding-seconds,-dt.microsecond)

################# Waiting for file ready #############################

def wait_file_for_ready(filepath,maxwaitready=300,waittick=5,expectSize=0):
    """
       Checks if a file is ready for reading/copying.

       For a file to be ready it must already exist and is not writing by
       any other processe.

       expectSize      in Kilobytes
    """

    ##
    ## First, make sure file exists
    ##
    #  we assumue file is already exists before calling this function

    ##
    ## Secondly, file should be stable
    ##
    #  Check whether other process is writing this file
    #  If the file exists but is changing continuously, wait "waittick" seconds
    #  and check again until it's stable within "waittick" seconds.
    #
    multiple = 100     # multipulor of wait tick for which file is condisdered old
                       # so not further stability checking
    epoch   = datetime.utcfromtimestamp(0)
    currUTC = datetime.utcnow()
    last    = os.path.getmtime(filepath)
    fileage = (currUTC-epoch).total_seconds()-last
    if fileage < multiple*waittick:  # only wait for newer file
        wait_time = 0
        while wait_time < maxwaitready:
            time.sleep(waittick)
            wait_time += waittick
            current=os.path.getmtime(filepath)
            if last == current:
                if expectSize > 0:
                  fsize = os.path.getsize(filepath)
                  if fsize < expectSize*1024:
                    #self.addlog(999,'CMD',"<%s> is still too small (%d bytes) after %d seconds. Keep Waiting ..."%(filepath,fsize,wait_time) )
                    continue
                  #else:
                    #self.addlog(999,'CMD',"<%s> now has size (%d bytes) after %d seconds."%(filepath,fsize,wait_time) )
                #self.addlog(0,'CMD',"<%s> is now stable after %d seconds."%(filepath,wait_time) )
                break

            else:
                #self.addlog(999,'CMD',"<%s> is actively changing after %s seconds." % (filepath, wait_time) )
                last = current

        else :   ## We have waitted too long
              #self.addlog(1,'CMD', 'Waiting for file <%s> stable excceeded %d seconds.\n' % \
              #             (filepath,maxwaitready) )
              return False
    else:
        pass
        #self.addlog(999,'CMD',"<%s> is (%d seconds) old > %d * tick (%d seconds). No further checking."%(filepath,fileage,multiple,waittick) )

    return True

  #enddef wait_for_a_file

#############################  Portral   ###############################

if __name__ == "__main__":

  stime = time.time()

  dataroot = "/raid/gao-landru/reflectivityQCComposite/MergedReflectivityQCComposite/AliasedVelocityDPQC"

  #currTime = datetime.utcnow() - timedelta(minutes=5)
  #print sys.argv[1]

  if len(sys.argv) >= 2:
    wrkTime = datetime.strptime(sys.argv[1],'%Y%m%d%H%M%S')
  else:
    wrkTime = None

  if len(sys.argv) == 3:
    radars = (sys.argv[2]).split(',')
  else:
    radars = []

  currTime = floorTime(wrkTime,dateDelta=timedelta(minutes=5))
  #currTime = datetime.strptime('2018-03-13_10:01:00Z','%Y-%m-%d_%H:%M:%SZ')

  opts = TimeOpt()
  filelist = get_radial_list(currTime,dataroot,radars,opts)

  #print opts.range
  currdtstr = currTime.strftime('%Y-%m-%d %H:%MZ')
  print ("Root directory: %s; time: %s" % (dataroot,currdtstr))
  maxTime = currTime + timedelta(minutes=max(opts.range)+1)
  minTime = currTime + timedelta(minutes=min(opts.range))
  maxdtstr = maxTime.strftime('%H:%M:00')
  mindtstr = minTime.strftime('%H:%M:00')
  for radar in sorted(filelist.keys()):
    print ("%s: %d files for <%s> [%s -- %s)." % (radar,len(filelist[radar]),currdtstr,mindtstr,maxdtstr))
    for fl in filelist[radar]:
        print ("    %s " % (fl))

  etime = time.time()-stime
  fm = (etime % 3600 )//60
  fs =  etime % 3600 - fm*60
  print ("Job finished and used %02dm %02ds." % ( fm,fs))
