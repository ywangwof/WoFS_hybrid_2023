#!/usr/bin/env python3
## ---------------------------------------------------------------------
##
## This is the Configure file for users to make specific configuration.
##
## Users should only change configurations in classmethod (starting with
## clsGetXXXXXX) and staticmethod near the end of this file.
##
## ---------------------------------------------------------------------
##
## HISTORY:
##
##   Yunheng Wang (07/31/2013)
##   Initial version.
##
##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

import os,time
import re

from datetime import datetime, timedelta
from configBase import runException, MPIConf, ConfDict
#import threading

class caseConf :
  #classbegin
  ''' This call holds the case specific configurature'''

  ##----------------------- Constructor  -------------------------------
  def __init__(self,configfile,runnum,rundatetime) :
    self._cfg = ConfDict.fromfilename(configfile)

    self.runname   = self._cfg.runname
    self.caseNo    = runnum
    self.caseIndex = runnum - 1           # starting from 0 for index of CaseNo
    if runnum == 27: self.caseIndex = 7

    self.hybrid       = self._cfg.hybrid
    self.wofstarthour = self._cfg.wofstarthour
    self.nens         = self._cfg.nens

    ##----------------------- Initialization      ----------------------
    '''Initialize this instance'''

    self.fcstSeconds = self._cfg.fcstlngth[self.caseIndex]
    self.fcstOutput  = self._cfg.outint[self.caseIndex]     # in seconds

    self.startTime   = rundatetime
    self.endTime     = self.startTime + timedelta(seconds=self.fcstSeconds)

    self.eventDate = rundatetime.replace(hour=self.wofstarthour,minute=0,second=0,microsecond=0)
    if rundatetime.hour < self.wofstarthour:   # WOF specific, The event date is from 12:00 pm to 11:59 am
        self.eventDate = self.eventDate - timedelta(days=1)

    if self.caseNo in (1,3,6,7):   # do not use time sampling anyway
      self.ntimesample = 1
    else:
      self.ntimesample = self._cfg.ntimesample
    self.timesamin   = self._cfg.timesamin         # 5-minutes of time sample WRF output

    self.cyclelength  = self.fcstSeconds
    if self.ntimesample > 1:
      self.fcstSeconds += (self.ntimesample//2)*self.timesamin*60
      self.endTime      = self.startTime + timedelta(seconds=self.fcstSeconds)

    # original are methods

    self.rundirs  = ConfDict(self._cfg.rundirs)    # ConfDict  for runtime directories
    self.radars   = self._cfg.radars     # list of radars to be used or empty
    self.domains  = self._cfg.domains    # list of domains or empty
    self.fields   = self._cfg.fields     # list of plotting fields
    self.programs = self._cfg.programs[self.caseIndex]    # list of programs to be run in order
    self.skipwrfdaupdate = self._cfg.skipwrfdaupdate
    self.extsrcs  = self._cfg.extsrcs    # list of external data sources to be sought one by one

    self.cmprun   = self._cfg.cmprun

  #enddef __init__

  ##----------------------- Instance Methods    -----------------------

  def getDistinguishTimeStr(self) :
    '''Return a date time string for distinguishing this case'''

    caseDate = self.startTime.strftime('%Y%m%d_%H%M')
    if self.caseNo == 1:
      timestr = "var-%s" % (caseDate)

    elif self.caseNo == 2:
      timestr = "wrf-%s" % ( caseDate )

    elif self.caseNo == 3:
      timestr = "fcst-%s" % ( caseDate )

    elif self.caseNo == 4:
      timestr = "cyla-%s" % ( caseDate )

    elif self.caseNo == 5:
      timestr = "cylf-%s" % ( caseDate )

    elif self.caseNo in (6,7):
      timestr = "fcyl-%s" % ( caseDate )

    elif self.caseNo == 27:
      timestr = "hybr-%s" % ( caseDate )

    return timestr
  #enddef getDistinguishTimeStr

  ##--------------------------------------------------------------------

  def getCaseDir(self,domid,acrossday=True,runtime=None,rootdir=None) :

    if runtime is None:
      runtime = self.startTime

    eventdt = runtime
    if acrossday:    # The event date is from 12:00 pm to 11:59 am
        eventdt = self.eventDate

    caseDate = eventdt.strftime('%Y%m%d')
    caseTime = runtime.strftime('%H%MZ')
    caseDom  = "dom%02d" % domid

    if rootdir is not None:
        casedatedir = os.path.join(rootdir,caseDate)
        casetimedir = os.path.join(casedatedir,caseTime)
        casedomndir = os.path.join(casetimedir,caseDom)
        return (casedatedir,casetimedir,casedomndir)

    return (caseDate,caseTime,caseDom)

  #enddef getCaseDir

  ##--------------------------------------------------------------------

  def getwrkdir(self,dtdDir,program_name,attachnum=True,numens=None) :
    '''
       dtdDir:       Work directory contains Date/Time/Domain
       program_name: Name of the program to be run
       attachnm:     Whether to attached a number that indicates the caseNo
                     for distinguish the same program ran for different caseNo
       numens        3DEnVAR ensemble number
                     None for single control member
                     otherwise, numens + control member (_0) subdirectories will be returned
    '''
    if self.caseNo in (6,7):
      wrknum = 5
    else:
      wrknum = self.caseIndex

    if program_name.startswith('ungrib'):
      wrkroot = os.path.dirname(dtdDir)
    else:
      wrkroot = dtdDir        # Date-Time-Domain dir

    if not attachnum:         # geogrid, tinterp, radremap, news3dvar etc.
      wrkdir = os.path.join(wrkroot,program_name)
    else:
      wrkdir = os.path.join(wrkroot,"%s%d" % (program_name,wrknum))

    wrkbase = wrkdir
    if numens is None:
      wrkdirs = [wrkdir]
    else:
      wrkdirs = ["%s_%d"%(wrkdir,mid) for mid in range(0,numens+1)]

    return wrkbase,wrkdirs

  #enddef getwrkdir

  ##---------- check whether job is in the workflow --------------------

  def enrelax_in_workflow(self):
    ''' Check whether the job enrelax is in the workflow (any of the runnums)'''

    if self.caseNo <= 3:
        workflowp = self.programs
    elif self.caseNo > 3:
        # check for analysis cycle only, i.e. caseNo = 4
        workflowp = self._cfg.programs[3]

    return 'enrelax' in workflowp
  #enddef enrelax_in_workflow

  ##--------------------------------------------------------------------

  def getNamelistTemplate(self,progname,ensno=None) :

    nmltmpls = self._cfg.NMLTemplates[self.caseIndex]    # dict
    if ensno is None:
      nmltmpl = os.path.join(self.rundirs.inputdir,'input',nmltmpls[progname])
    else:
        nmldict = nmltmpls[progname]
        found = 0
        if isinstance(nmldict,dict):
            dlen = 0
            for k,v in nmldict.items():
                if "allMemsExceptCtl" in v:
                    v.remove("allMemsExceptCtl")
                    v.extend(range(1,self.nens+1))
                dlen += len(v)
                if ensno in v:
                    nmlfile = k.format(iens=ensno)
                    found += 1
        else:
            found = 1
            dlen = self.nens+1 if self.nens is not None else 0
            nmlfile = nmldict
            #raise  runException('Unsupported namelist configuration for %s' % progname)

        if found > 0:
            if found == 1:
                if self.nens is not None:
                    if dlen == self.nens+1:
                        nmltmpl = os.path.join(self.rundirs.inputdir,'input',nmlfile)
                    else:
                        raise  runException('Inconsistent list value (%d) for %s, expected %d.' % (dlen,progname,self.nens+1))
                else:
                    nmltmpl = os.path.join(self.rundirs.inputdir,'input',nmlfile)
            else:
                raise  runException('Found multiple entries of %s for ensemble %d.' % (progname,ensno))
        else:
            raise  runException('Unsupported namelist configuration for %s.' % progname)

    return nmltmpl

  #enddef getNamelistTemplate

  ##--------------------------------------------------------------------

  def getRuntimeConfig(self,gridsize=None) :
    '''
      Program run-time configuraiton in runConfig
    '''

    config = ConfDict(self._cfg.runConfig[self.caseIndex])

    retConfig = ConfDict({})
    for k,v in config.items():
        argsa = []
        argsb = {}
        for e in v:
            if isinstance(e,dict):    # extra run-time configurations
                argsb = e
            else:                  # normal mpi options
                argsa.append(e)

        retConfig[k] = MPIConf(*argsa,**argsb)

    #To make sure the MPI configuration is valid with respect to grid sizes
    progtolerance = ("geogrid","metgrid","ungrib","real","wrf")

    if gridsize is not None:
        for prog in self.programs:
            progconf = retConfig[prog]
            if not progconf.check_dims(gridsize):
                print(f'MPI configuration {progconf} for "{prog}" is not divisable by gridsize {gridsize}')
                if prog not in progtolerance:
                    raise  runException(f'MPI configuration for {prog} is not divisable by gridsize')

    return retConfig

  #enddef getRuntimeConfig

  ##--------------------------------------------------------------------

  def getExtConfig(self,extsrc) :

    if extsrc not in self._cfg.extconfs.keys():
        raise runException('Unsupported external source %s' % extsrc)

    return  ConfDict(self._cfg.extconfs[extsrc])

  #enddef getExtConfig

  ##--------------------------------------------------------------------

  def getObsConfig(self,obsvar) :

    if obsvar not in self._cfg.obsconfs.keys():
        raise runException('Unsupported observation source %s' % obsvar)

    return  ConfDict(self._cfg.obsconfs[obsvar])

  #enddef getExtConfig

  ##--------------------------------------------------------------------

  def getCaseObsType(self) :

    if self.caseNo in (1,3,4,27):
      obs4var =  self._cfg.obs4var
    elif self.caseNo in (2,5,6,7):
      obs4var =  ( )

    return obs4var

  #enddef getCaseObsType

######################### Static Methods ############################

  @staticmethod
  def findDefaultStartingTime(runNo) :
    ''' Given a case no and the current time
        Return the model starting time based on the case No.
    '''

    currTime = datetime.utcnow()

    if runNo in (1,4):             ## Analysis
      #currTime = currTime - timedelta(hours=4)
      tyear   = '%04d' % currTime.year
      tmonth  = '%02d' % currTime.month
      tday    = '%02d' % currTime.day
      thour   = '%02d' %(currTime.hour)
      tminute = '%02d' %(currTime.minute//5*5)
      tsecond = '00'
      if currTime.minute%5 == 0: time.sleep(30)    # delay 30 seconds for data
    elif runNo in (2, 3, 5, 6, 7):   ## forecast
      #currTime = currTime - timedelta(minutes=6)
      tyear   = '%04d' % currTime.year
      tmonth  = '%02d' % currTime.month
      tday    = '%02d' % currTime.day
      thour   = '%02d' % currTime.hour
      tminute = '%02d' %(currTime.minute//5 * 5)
      tsecond = '00'
      if currTime.minute%5 == 0: time.sleep(60)    # delay 1 minute for analysis to be done
    else :
      raise runException('Unsupported case No %d' % runNo)

    runstart = datetime (int(tyear),  int(tmonth), int(tday),
                         int(thour),  int(tminute),int(tsecond) )
    return runstart

  #enddef findDefaultStartingTime

######################### Static Methods ############################

  @staticmethod
  def matchStartingTime(timestr):
      ''' Match the pass in string with time expression'''

      dtre = re.compile(r'^(\d{4})(0[1-9]|1[0-2])([0-2]\d|3[0-1])((\d{2}){0,3})$')
      mobj = dtre.match(timestr)

      if mobj:
          syear   = mobj.group(1)
          smonth  = mobj.group(2)
          sday    = mobj.group(3)

          hms = mobj.group(4)
          shour   = hms[0:2] if len(hms) >= 2 else "0"
          sminute = hms[2:4] if len(hms) >= 4 else "0"
          ssecond = hms[4:6] if len(hms) == 6 else "0"

          runstart = datetime (int(syear),  int(smonth), int(sday),
                               int(shour),  int(sminute),int(ssecond) )

      else:
          runstart = None

      return runstart

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#endclass caseConf

if __name__ == "__main__":

    try:
        caseconf = caseConf('config.yaml',1,datetime.utcnow().strftime('%Y-%m-%d_%H:%M:%S'))

        print('''\n test wrkdirs''')
        caseroot,caserel,casedom = caseconf.getCaseDir(1)
        casedir = os.path.join('command.wrkdir',caseroot,caserel,casedom)
        rwrkbas,rwrkdirs = caseconf.getwrkdir(casedir,'tinterp',False,3)

        print("wrkbase = %s"%rwrkbas)
        print("wrkdirs = %s"%rwrkdirs)


        myconfig = caseconf._cfg

        print('''\n test NMLTemplates''')
        i = 0
        for nmlt in myconfig.NMLTemplates:
          print(i+1,' -> ',nmlt)
          i += 1

        print(caseconf.caseIndex)
        print(caseconf.getNamelistTemplate('real',ensno=2))

        print("""\n test runConfig""")

        for runno in range(0,5):

          caseconf = ConfDict(myconfig.runConfig[runno])

          jobconf = ConfDict({})
          for ak,av in caseconf.items():
                args1 = []
                args2 = {}
                for ae in av:
                    if isinstance(ae,dict):
                        args2 = ae
                    else:
                        args1.append(ae)

                jobconf[ak] = MPIConf(*args1,**args2)

          print (runno, '-> ',jobconf.wrf,jobconf.wrf.numens,jobconf.wrf.shell)

        caseconf = myconfig.runConfig[0]['geogrid']

        args1 = []
        args2 = {}
        for ae in caseconf:
            if isinstance(ae,dict):
                args2 = ae
            else:
                args1.append(ae)

        jobconf = MPIConf(*args1,**args2)

        print ('geogrid',jobconf,jobconf.numens,jobconf.shell,jobconf.numtry)

    except Exception as ex:
        print("ERROR: %s" % ex)
