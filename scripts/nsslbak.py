#!/usr/bin/env python3
## ---------------------------------------------------------------------
##
## This is a python program that backup realtime run date with
## external dataset and radar observations.
##
##
## ---------------------------------------------------------------------
##
## HISTORY:
##
##   Yunheng Wang (04/09/2016)
##   Initial version based on nsslvar.py.
##
##
########################################################################
##
## Requirements:
##
##   o Python 3.6 or above
##
########################################################################

import sys, os, re, getopt, subprocess, time
from datetime import datetime, timedelta
import shutil, glob
import logging

from nssldomains import NSSLDomains
from nsslconf import caseConf as APSCase
from configBase import runException, ConfDict

##======================================================================
## Parse command line arguments
##======================================================================

def parseargv():
  import argparse

  version  = '3.0'
  lastdate = '2020.04.15'

  defaultwrkdir = '/work/ywang/saved_data'

  usage='\r{}\nUsage: %(prog)s [options] time_s [time_e] [bakdir]'.format(f'Version {version}, {lastdate} by Y. Wang\n'.ljust(len('usage:')))

  parser = argparse.ArgumentParser(description="Variational/Hybrid/Ensemble Analysis and Forecast System",
                     formatter_class = argparse.RawTextHelpFormatter,
                     usage=usage)
  parser.add_argument("-v", "--verbose", action="store_true", help="More messages while running")
  parser.add_argument("-n", "--dry",     action="store_true", help="Generate namelist files and job scripts only without actually running them")

  parser.add_argument("-c", "--conf",    default='config.yaml', help="File that provides configuration in YAML format")
  parser.add_argument("-f", "--file",                           help="File that provides domain and grid information")
  parser.add_argument("-r", "--run",     type=int, choices=[1,2,3,4,7], default=3,
                      help='''Which dataset to be backup
( 1: background forecasts;       )
( 2: radar and observations;     )
( 3: Both of above               )
( 4: NEWSe Analysis and forecast;)
( 7: both 3 & 4;                 ) ''' )

  parser.add_argument("time_s",             help="Starting time as YYYYmmdd[HH[MM[SS]]]")
  parser.add_argument("time_e",  nargs='?', help="Ending   time as YYYYmmdd[HH[MM[SS]]]")
  parser.add_argument("bakdir",  nargs='?', help=f"Bake directory, default: {defaultwrkdir}" )

  args = parser.parse_args()

  ##
  ## Decode command line arguments
  ##

  _debug = args.verbose
  _show  = args.dry

  if not os.path.lexists(args.conf):
      parser.print_help()
      raise runException(f'configuration file <{args.conf}> not exist')

  domains = NSSLDomains(0)
  if args.file is not None:
      if os.path.lexists(args.file):
          domains.parseTXT(args.file)
      else:
          parser.print_help()
          raise runException(f'domain file <{args.file}> not exist')

  #
  # Positional arguments for wrkdir & wrktime may in any order
  #

  indir  = defaultwrkdir
  if args.bakdir is not None:
      indir = args.bakdir

  runtimes = dict()
  intime = APSCase.matchStartingTime(args.time_s)
  if intime is None:
      parser.print_help()
      raise runException(f'starting time <{args.time_s}> not in the right format')
  else:
      runtimes["start"] = intime

  if args.time_e is None:
      runtimes["end"] = runtimes["start"] + timedelta(hours=27)
  else:
      intime = APSCase.matchStartingTime(args.time_e)
      if intime is not None:
          runtimes["end"]  = intime
      else:
          if args.bakdir is None:
               indir            = args.time_e
               runtimes["end"]  = runtimes["start"] + timedelta(hours=27)
          else:
               parser.print_help()
               raise runException(f'ending time <{args.time_e}> not in the right format')

  if not os.path.lexists(indir):
      parser.print_help()
      raise runException(f'working directory <{indir}> not exist')

  ##
  ## Now, prepare for the return arguments in a dictionary
  ##
  argsdict = dict()
  argsdict['wrkdir']  = indir
  argsdict['times']   = runtimes
  argsdict['runcase'] = args.run
  argsdict['domains'] = domains
  argsdict['confile'] = args.conf

  return argsdict
#enddef parseargv

##%%%%%%%%%%%%%%%%%%%%%%%  main program here  %%%%%%%%%%%%%%%%%%%%%%%%%%

def main(confile,times,wrkdir,runcase,domains) :
  '''
     main program driver layer
     set namelist parameters and runtime environments
     and trigue each workflow separately as a thread
  '''

  global _debug, _show

  ## No user's changes from here
  ##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

  ## ---
  ## Retrieve configuration
  ## ---

  conf = ConfDict.fromfilename(confile)

  #times['start'] = times['start']+timedelta(hours=conf.wofstarthour)

  eventdate=times['start'].strftime('%Y%m%d')

  ## ---
  ## working directory
  ## ---

  if not os.path.lexists(wrkdir) :
    logging.error("Working directoy %s does not exist." %wrkdir)
    raise runException("Saving directory not exist.")

  setuplog(wrkdir,"nsslbak_%s.log"%eventdate,_debug)

  logger=logging.getLogger("MAIN")
  logger.info(f"--- Baking {eventdate} (runcase {runcase}) starting ...")
  logger.info(f"Script      - <{os.path.realpath(__file__)}>")
  logger.info(f"Config file - <{os.path.realpath(confile)}>")

  ## ---
  ## Determine the domains to be run or anlyzed
  ## ---

  if len(domains) < 1:
      defaultfile="/scratch/ywang/real_runs/%s.dom"%(eventdate)

      if len(conf.domains) > 0:
          domains.parseDict(conf.domains)
      elif os.path.lexists(defaultfile):
          logging.warning("Domain is still not set, use %s"%defaultfile)
          domains.parseTXT(defaultfile)
      else:
          logger.error("Domain is still not set.")
          raise runException("Doamin not set.")

  confile(f"Domain file - <{domains.source}>")

  radarinfo = os.path.join(conf.rundirs.inputdir,conf.obsconfs.radar.radarinfo)
  domains.setRadars(radarinfo)

  ## @@@
  ## Start execution
  ## @@@

  logger.info('- %s -' % domains[0])

  epoch   = datetime.utcfromtimestamp(0)

  runtime_s = times['start']
  runtime_e = times['end']

  second_s = int( (runtime_s-epoch).total_seconds() )
  second_e = int( (runtime_e-epoch).total_seconds() )
  intvl = conf.outint[3]     # cycle (run case 4) interval

  if runcase in (4,7):
    logger.info("  Backing up NEWSe runs ...")
    copy_newse(runtime_s,conf.wofstarthour,wrkdir)

    if runcase == 4:
      return
    else:
      runcase = 3

  for dts in range(second_s,second_e+intvl,intvl):

      dt = datetime.utcfromtimestamp(dts)
      logger.info("--------- Working on %s --------" % dt.strftime('%Y-%m-%d %H:%M'))

      #datestr= dt.strftime('%Y%m%d')
      #datedir= os.path.join(wrkdir,datestr)
      if runcase in (1,3):
          logger.info ("  Backing up external dataset ...")
          copy_extm(dt,wrkdir,conf)

      if runcase in (2,3):
          logger.info ("  Backing up observations ...")
          copy_obs(dt,domains,wrkdir,conf)

  logger.info("======== Done at %s ========\n" % (time.strftime('%Y%m%d %H:%M:%S')))

#enddef main

##%%%%%%%%%%%%%%%%%%%%%%  copy_newse  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def copy_newse(indate,starthour,wrkdir) :
  ''' Copy NEWSe run at event date "dt"'''

  newsedir =  '/scratch/wof/realtime'

  dowrk = not _show

  epoch   = datetime.utcfromtimestamp(0)

  eventdt = datetime.strftime(indate,'%Y%m%d')

  desthome = os.path.join(wrkdir,'WOFS2020',eventdt)
  if not os.path.lexists(desthome):
    os.mkdir(desthome)

  logger=logging.getLogger("WOFS")

  runtime_s = datetime.strptime('%s %02d:00:00'%(eventdt,starthour),'%Y%m%d %H:%M:%S')
  runtime_e = datetime.strptime('%s 03:00:00'%eventdt,'%Y%m%d %H:%M:%S') + timedelta(days=1)
  second_s = int( (runtime_s-epoch).total_seconds() )
  second_e = int( (runtime_e-epoch).total_seconds() )
  intvl = 900

  #
  # Save wrfinput_d01_ic
  #
  for nmem in range(1,37):

    eventdir = os.path.join(newsedir,eventdt,'mem%d'%nmem)

    destdir = os.path.join(desthome,'mem%d'%nmem)
    if not os.path.lexists(destdir):
      os.mkdir(destdir)

    filename = 'wrfinput_d01_ic'
    filesrc = os.path.join(eventdir,filename)

    logger.debug ('Looking for file %s  ....' % (filesrc))

    if os.path.lexists(filesrc):
      filedest = os.path.join(destdir,filename)
      if dowrk:
        if not os.path.lexists(filedest):
          logger.debug('Copying to %s  ....' % (filename))
          shutil.copy(filesrc,filedest)
      else:
          logger.info ('  $ %s' % (filesrc))

  #
  # Save WRFFCST files
  #
  eventdir = os.path.join(newsedir,eventdt,'WRFOUT')

  destdir = os.path.join(desthome,'WRFOUT')
  if not os.path.lexists(destdir):
    os.mkdir(destdir)

  for dts in range(second_s,second_e+intvl,intvl):
    dt = datetime.utcfromtimestamp(dts)
    timestr = dt.strftime('%Y-%m-%d_%H:%M:%S')

    for flhead in ('wrffcst',):
      for nmem in range(1,37):
        filename = '%s_d01_%s_%d'%(flhead,timestr,nmem)
        filesrc = os.path.join(eventdir,filename)

        logger.debug('Looking for file %s  ....' % (filesrc))

        if os.path.lexists(filesrc):
          filedest = os.path.join(destdir,filename)
          if dowrk:
            if not os.path.lexists(filedest):
              logger.debug('Copying to %s  ....' % (filename))
              shutil.copy(filesrc,filedest)
          else:
              logger.info ('  $ %s' % (filesrc))

  return
#enddef copy_newse

##%%%%%%%%%%%%%%%%%%%%%%  link extm  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def copy_extm(dt,wrkdir,conf) :
  ''' Link external data set'''

  #extdirs =  { 'NAMTL': '/scratch/ywang/test_runs/data4April_20_2010/nam12_rename',
  #             'NAM40': '/LDM/NAM_40km',
  #             'NAM12': '/LDM/NAM_12km',
  #             'RAP13': '/scratch/ywang/saved_data/20160429/RUC13',
  #             'RAPEL': '/scratch/ldm2/RAP-ESRL/13km_conus',
  #             'RAPNH': '/LDM/RAP-CONUS'
  #           }
  logger=logging.getLogger('EXTM')

  mpiconfig = conf.runConfig[0]["ungrib"]

  dowrk = not _show

  epoch   = datetime.utcfromtimestamp(0)

  ## link external grib files
  hrlength = max(conf.fcstlngth)/3600        # in hours
  datestr  = dt.strftime('%Y%m%d')

  for extdname in conf.extsrcs :

    extconf = ConfDict(conf.extconfs[extdname])

    srcHour, extHour = extconf.extintvals

    initHour = dt.hour//srcHour*srcHour
    exttime  = datetime.strptime("%s_%02d:00:00" % (datestr,initHour),'%Y%m%d_%H:%M:%S')
    startHour = (dt.hour%srcHour)//extHour*extHour
    endHour   = hrlength + startHour+extHour

    caseDate  = exttime.strftime('%Y%m%d')
    yyjuld    = exttime.strftime('%y%j')
    ntotal  = int(endHour-startHour)/extHour+1

    ntotal *= (mpiconfig.numens+1)

    numtry = 0
    while numtry < 5:

        numtry += 1

        #direxts = { 'GFSS'  : '%s%s'%(caseDate, initHour),
        #            'GFSG'  : '',
        #            'RAP13' : '',
        #            'RAPNH' : os.path.join('%04d'%exttime.year,'%02d'%exttime.month,'%02d'%exttime.day),
        #            'RAPEL' : os.path.join('%04d'%exttime.year,'%02d'%exttime.month,'%02d'%exttime.day),
        #            'NAM40' : os.path.join('%04d'%exttime.year,'%02d'%exttime.month,'%02d'%exttime.day,'%02dz'%exttime.hour),
        #            'NAMTL' : '%s' % (caseDate),
        #            'NAM12' : os.path.join('%04d'%exttime.year,'%02d'%exttime.month,'%02d'%exttime.day,'%02dz'%exttime.hour)
        #          }
        #filexts = { 'GFSS'  : 'gfs.%s%02dgrb2f%%03d'   %(caseDate,initHour),
        #            'GFSG'  : '%s%02d_fh.0%%03d_tl.press_gr.1p0deg.grib2' % (caseDate, initHour),
        #            'NAM40' : 'nam.t%02dz.awip3d%%02d.tm00.grib2' % (initHour),
        #            'NAMTL' : 'nam12grb2.t%02dz.awip218%%02d.%%02d' % (initHour),
        #            'NAM12' : 'nam.t%02dz.awphys%%02d.grb2.tm00' % (initHour),
        #            'RAP13' : 'ruc13rrgrb2.%s%02df%%02d' % (caseDate,initHour),
        #            'RAPNH' : 'rap.t%02dz.awp130bgrbf%%02d.grib2'%(initHour),
        #            'RAPEL' : '%s%02d00%%02d00'%(yyjuld,initHour),
        #          }
        extdat = os.path.join(extconf.extdir, extconf.extsubdir.format(exttime))

        itotal = 0
        for nj in range(startHour,endHour+1,extHour) :
            ij = nj = startHour

            mid=0
            for extmdir in extmdirs:
              fl = extconf.filext.format(exttime,no=nj,iens=mid)
              mid += 1

              absfl = os.path.join(extdat,fl)

              logger.debug('Looking for file %s  ....' % (absfl))

              if os.path.lexists(absfl):
                 last = os.path.getmtime(absfl)
                 if last <= (dt-epoch).total_seconds():   # file must not be later than the requested time
                     itotal += 1
                     if dowrk:
                         destdir=os.path.join(wrkdir,caseDate)
                         if not os.path.lexists(destdir): os.mkdir(destdir)

                         destdir=os.path.join(wrkdir,caseDate,extdname)
                         if not os.path.lexists(destdir): os.mkdir(destdir)

                         flname = os.path.join(destdir,fl)
                         if not os.path.lexists(flname):
                            logger.debug('Copying to %s  ....' % (flname))
                            shutil.copy(absfl,flname)
                     else:
                         logger.info('  $%02d %s' % (itotal,absfl))

        if itotal == ntotal :
            logger.debug("= Try: %d - Found all %i files from external data source %s." % (numtry,itotal,extdname))
            break
        else:
            logger.debug("= Found %i/%i files from external data source %s." % (itotal,ntotal,extdname))

            exttime  = exttime - timedelta(hours=srcHour)
            caseDate = exttime.strftime('%Y%m%d')
            yyjuld   = exttime.strftime('%y%j')
            initHour = exttime.hour
            startHour = startHour + srcHour
            endHour   = startHour + (ntotal-1)*extHour
    else:
        continue
    #break

  if itotal < ntotal:
     logger.error("ERROR: = Got %d / %d ..." % (itotal, ntotal))

  return
#enddef copy_extm

##%%%%%%%%%%%%%%%%%  Preprocess Observation data %%%%%%%%%%%%%%%%%%%%

def copy_obs(dt,domains,wrkdir,conf) :
    ''' Preprocess observations '''

    #obsvars = { 'radar' : { 'datdir' : '/LDM/NEXRAD2',
    #                        'typeof' : 'rad'
    #                       },
    #            'satcwp': { 'datdir' : '/scratch/wof/realtime/OBSGEN/Satellite/temp',
    #                        'typeof' : 'cwp'
    #                       },
    #          }
    #
    #obsext = {'surf' : 'lso',  'auto' : 'lso',  'windp' : 'pro',  'satcwp' : 'PX.04K.CDF'}
    #obspre = {'surf' : 'surf', 'auto' : 'auto', 'windp' : 'WND',  'satcwp' : 'G13V04.0.SGP.'}
    #obsrng = {'surf'  : [0],      'auto'  : [0,5,-5],
    #          'windp' : [0,5,-5], 'satcwp': [0,-15,-30] }

    datestr = dt.strftime('%Y%m%d')

    destdir = os.path.join(wrkdir,datestr)
    if not os.path.lexists(destdir):
        os.mkdir(destdir)

    destdir = os.path.join(wrkdir,datestr,'OBS')
    if not os.path.lexists(destdir):
        os.mkdir(destdir)

    ### get time strings
    startime   = dt

    ## --------------- find each observations -----------------------

    retobs = {'ua' : [], 'sng' : [], 'cwp' : [], 'conv': [], 'lightning' : []}

    for obstype in conf.obs4var :
        obsconf = ConfDict(conf.obsconfs[obstype])

        if obstype == 'radar':
          retobs['radar'] = copy_radar(dt,domains,wrkdir,conf)
          continue

        elif obstype == '88vad':
            continue
        elif obstype == 'radial':
          retobs['radial'] = copy_radial(dt,obsconf,domains,wrkdir)
          continue
        elif obstype == 'mrms':
          retobs['mrms'] = copy_mrms(dt,obsconf,wrkdir)
          continue

        logger=logging.getLogger(obstype)

        ##---------- looking for original observation files -----------
        currTime = startime

        obsfound  = False
        obsfileRe = obsconf.filename.format(currTime)
        obsfileAb = os.path.join(destdir,obsfileRe)

        if os.path.lexists(obsfileAb) :
            logger.debug('    Found data file for %s as %s ... ' % (obstype,obsfileAb))
            obsfound = True
        else :
            for minrng in obsconf.timerange :
               currTime  = currTime + timedelta(minutes=minrng)
               obsfileRe = obsconf.filename.format(currTime)
               datfile  = os.path.join(obsconf.datdir,obsconf.subdir.format(currTime),obsfileRe )
               logger.debug('    Looking for data file %s ... ' % (datfile))

               ## -------- Preprocessing each datfile to get obsfile ---
               if os.path.lexists(datfile) :
                  obsfileAb = os.path.join(destdir,obsfileRe)
                  if not os.path.lexists(obsfileAb) and not _show:
                      if _debug: print ('    Copying to %s ...'%obsfileAb)
                      shutil.copy(datfile,obsfileAb)
                  else:
                      logger.info('  %%01 %s' % (datfile))
                  obsfound = True
                  break

        ## Search for dat file 1 hour early
        if obsfound :
            if obsconf.typeof == "sng":
                currTime = currTime - timedelta(hours=1)
                datfile1hrRe = obsconf.filename.format(currTime)
                datfile1hr  = os.path.join(obsconf.datdir,obsconf.subdir.format(currTime),datfile1hrRe )
                logger.info  ('    Looking for data file %s ... ' % (datfile1hr) )
                if os.path.lexists(datfile1hr) :
                  obsfile1hrAb = os.path.join(destdir,datfile1hrRe)
                  if not os.path.lexists(obsfile1hrAb) and not _show:
                        shutil.copy(datfile1hr,obsfile1hrAb)
                        logger.info ('    Saved data file %s ... ' % (obsfile1hrAb))
                  else:
                        logger.info ( '  Found %s' % (datfile1hr))
                else :
                     obsfile1hrAb = 'None'

                retobs[obskey].append([obsfileAb,obsfile1hrAb])
            else:
                retobs[obsconf.typeof].append(obsfileAb)

    ##
    ## Log the observation files
    ##
    logger = logging.getLogger('')

    validobs = {}
    for (obskey,files) in retobs.items() :
      if len(files) > 0 :
         if isinstance(files[0],list) :
           filelst = [fl[0] for fl in files]
         else :
           filelst = files
         logger.debug('    %d "%s" files found and they are:\n    %s' %(
                           len(files),obskey, '\n    '.join(filelst) ))
         validobs[obskey] = files
      else :
         logger.debug('    0 "%s" files found.' %(obskey ))
         validobs[obskey] = []

    return validobs

#enddef copy_obs

##%%%%%%%%%%%%%%%%%%%%  Wait for radar data %%%%%%%%%%%%%%%%%%%%%%%%%%%%

def copy_radar(dt,domains,wrkdir,conf) :
    ''' Wait for radar data'''

    datestr = dt.strftime('%Y%m%d')
    destdir = os.path.join(wrkdir,datestr,'NEXRAD2')
    if not os.path.lexists(destdir):
        os.mkdir(destdir)

    logger=logging.getLogger("RADAR")

    ##---------------- looking for radar within domain --------------

    radarswithindomain = conf.radars
    if len(radarswithindomain) < 1:
      radarswithindomain = [radar.name for radar in domains[0]['radars']]

    radconf = conf.obsconfs.radar

    ##---------------- looking for radar files ----------------------
    radars = []
    radarsToCheck = set(radarswithindomain).difference(set(radars))
    iradar = 0
    for radname in  radarsToCheck :
        currTime = dt

        radfound = False
        radfileRe = radconf.filename.format(radar=radname,time=currtime)
        radfile = os.path.join(destdir,radfileRe)
        if os.path.lexists(radfile) :
            logger.debug('    Found radar data file %s ... ' % radfile)
            radfound = True
        else :
          ##
          ## look for radar data files
          ##
          #for timemin in range(0,timerange) :
          for timemin in radconf.timerange:

             #for sign in (-1,1) :
                currTime = dt+timedelta(seconds=timemin*60)

                radfileRe = radconf.filename.format(radar=radname,time=currtime)
                datfile1  = os.path.join(radconf.datdir,
                               radconf.subdir.format(radar=radname,time=currtime),
                               radfileRe )

                #datcmpr1  = '%s.gz' % datfile1
                logger.debug(f'    Looking for radar data file {datfile1} ... ')

                datafls = glob.glob(datfile1)
                if len(datafls)>=1:
                    logger.debug(f'    Found radar data file {datafls[0]} ... ')
                    radfound = True
                    radfile   = os.path.join(destdir,os.path.basename(datafls[0]))
                    if not os.path.lexists(radfile) and not _show:
                        logger.debug('    Copying to %s ...'%radfile)
                        shutil.copy(datafls[0],radfile)
                    else:
                        logger.info('  #%02d %s' % (iradar+1,datfile1))

                    break

        if radfound :
            radars.append(radname)
            iradar += 1

    logger.debug('    %d radar files found and they are [%s] ' %(len(radars),', '.join(radars) ))

    return radars
#enddef copy_radar

def copy_mrms(dt,obsconf,wrkdir) :
     ''' Wait for MRMS data at one specific time "dt".'''

     datestr = dt.strftime('%Y%m%d')
     destdir = os.path.join(wrkdir,datestr,'MRMS')
     if not os.path.lexists(destdir):
         os.mkdir(destdir)

     logger = logging.getLogger("MRMS")
     obsdir = obsconf.datdir

     mrmslvls = ['00.50', '00.75', '01.00', '01.25', '01.50',
                 '01.75', '02.00', '02.25', '02.50', '02.75', '03.00', '03.50',
                 '04.00', '04.50', '05.00', '05.50', '06.00', '06.50', '07.00',
                 '07.50', '08.00', '08.50', '09.00', '10.00', '11.00', '12.00',
                 '13.00', '14.00', '15.00', '16.00', '17.00', '18.00', '19.00' ]


     currTime   = dt
     ##---------- looking for original observation files -----------
     obsfound  = False
     foundfiles = []

     # search for files around this time

     waittime = 0
     while waittime < obsconf.maxwait  :
         for minrng in obsconf.timerange:
           currTime  = dt + timedelta(minutes=minrng)

           obsfileSr = [obsconf.filename.format(currTime,level=lvl) for lvl in mrmslvls]
           subdirdt = obsconf.subdir.format(currTime)
           datfiles  = [os.path.join(obsconf.datdir,subdirdt,fileSr) for fileSr in obsfileSr]

           logger.info('    Looking for data file %s ... ' % (datfiles[0]))

           ## -------- Preprocessing each datfile to get obsfile ---
           i = 0
           for datfile in datfiles:     # each level
               datafls   = glob.glob(datfile)
               assert(len(datafls) <= 1)
               if len(datafls)==1 :
                  obsfileAb = os.path.join(destdir,os.path.basename(datafls[0]))
                  shutil.copy(datafls[0],obsfileAb)
                  logger.debug('    Found data file %s ... ' %datafls[0])
                  foundfiles.append(obsfileAb)
               else:
                  foundfiles = []
                  break
               i += 1

           if len(foundfiles) == len(mrmslvls):
               obsfound = True
               logger.info('    Saved MRMS data at %s ... ' % (timstr))
               break

         ## Continue waiting or exit
         if obsfound :
           break  # waittime loop
         elif (datetime.utcnow()-startime).total_seconds > 3600  :
           break
         else :
           time.sleep(10)
           waittime += 10

     return foundfiles
#enddef copy_mrms

##%%%%%%%%%%%%%%%%%%%%  Copy radar radial data %%%%%%%%%%%%%%%%%%%%%%%%%

def copy_radial(dt,obsconf,domains,wrkdir) :
    ''' Copy radar raidal data at time "dt"'''

    import getradial

    datestr = dt.strftime('%Y%m%d')
    destdir = os.path.join(wrkdir,datestr,'RADIAL')
    if not os.path.lexists(destdir):
        os.mkdir(destdir)

    logger=logging.getLogger("Radial")

    timstr = dt.strftime('%Y%m%d%H%M%S')  # fixed file name for easy process
    obsdir = obsconf.datdir

    ##---------------- looking for radar within domain --------------

    radarswithindomain = [radar.name for radar in domains[0]['radars']]

    filelist = getradial.get_radial_list(dt,obsdir,radarswithindomain)

    for radar in filelist.keys():
       if len(filelist[radar]) > 0:
           radlistfile = os.path.join(destdir,"RADR_%s%s.list" % (radar,timstr))
           raddir = os.path.join(destdir,radar)
           if not os.path.lexists(raddir): os.makedirs(raddir)
           with open(radlistfile,'w') as lfile:
                for fl in filelist[radar]:
                    (radrelpath,radfname) = os.path.split(fl)
                    flpaths = radrelpath.split(os.sep)
                    (radfhead,radfext) = os.path.splitext(radfname)
                    radfname = "%s_%s%s" %(radfhead,flpaths[2],radfext)
                    absfile = os.path.join(obsdir,fl)
                    wrkfile = os.path.join(raddir,radfname)
                    if not os.path.lexists(wrkfile):
                        shutil.copy(absfile,wrkfile)
                    print(wrkfile, file = lfile)
       else:
           filelist.pop(radar,None)

    radars = filelist.keys()
    logger.info('  Found %d radar files and they are [%s] ' %(
                          len(radars),', '.join(radars) ) )

    return radars
#enddef copy_radial

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Custom formatter
class MyLogFormatter(logging.Formatter):

    #err_fmt  = "%(levelname)-8s %(name)-12s %(lineno)4d:  %(message)s"
    #dbg_fmt  = "%(name)-12s: %(message)s"


    def __init__(self, fmt1="%(name)-12s: %(message)s",
        fmt2="%(levelname)-8s %(name)-12s %(lineno)4d:  %(message)s",
        datefmt='%m-%d %H:%M',tcolor=False):
        self.dbg_fmt = fmt1
        self.err_fmt = fmt2
        self.color   = tcolor
        logging.Formatter.__init__(self, fmt1,datefmt)

    def format(self, record):

        # Save the original format configured by the user
        # when the logger formatter was instantiated
        #orig_format = self._fmt

        # Replace the original format with one customized by logging level
        if record.levelno >= logging.ERROR:
            self._fmt = self.err_fmt
            wcolor = 'red'
        elif record.levelno == logging.WARNING:
            self._fmt = self.err_fmt
            wcolor = 'cyan'
        else:
            self._fmt = self.dbg_fmt
            wcolor = 'white'

        # Call the original formatter class to do the grunt work
        result = logging.Formatter.format(self, record)

        # Restore the original format configured by the user
        #self._fmt = orig_format

        if self.color:
          result = self.cprint(result,wcolor)

        return result

    ##----------------------------------------------------------------------
    ##
    def cprint(self,field, color = 'white'):
      """Return the 'field' in collored terminal form"""

      Term_colors = {
        'black':30,
        'red':31,
        'green':32,
        'yellow':33,
        'blue':34,
        'magenta':35,
        'cyan':36,
        'white':37,
      }
      field = '[01;%dm%s[00m' % ( Term_colors[color], str(field) )
      return field

    #enddef  cprint

def setuplog(logdir,logname,debug):
  '''
  set up logging path
  '''

  logfile = os.path.join(logdir,logname)
  logger=logging.getLogger('')

  #Level	Numeric value
  # WARNING    30
  # INFO       20
  # DEBUG      10
  # NOTSET      0
  #
  if debug:
    loglevel=logging.DEBUG
    conlevel=logging.DEBUG
  else:
    loglevel=logging.INFO
    conlevel=logging.WARNING

  logger.setLevel(loglevel)

  filelog = logging.FileHandler(logfile,'w')
  filelog.setLevel(loglevel)
  filefmt = MyLogFormatter("%(asctime)s : %(message)s",
              "%(asctime)s:%(levelname)s : %(message)s",
              datefmt='%m-%d %H:%M:%S')
  filelog.setFormatter(filefmt)
  logger.addHandler(filelog)

  #logging.basicConfig(level=loglevel,
  #                    format='%(asctime)s %(name)-12s %(threadName)-12s: %(message)s',
  #                    datefmt='%m-%d %H:%M',
  #                    filename=logfile,
  #                    filemode='w')
  # define a Handler which writes INFO messages or higher to the sys.stderr
  console = logging.StreamHandler()   # stderr, logging.StreamHandler(sys.stdout)
  console.setLevel(conlevel)
  # set a format which is simpler for console use
  #formatter = logging.Formatter('%(name)-12s %(lineno)4d: %(levelname)-8s %(message)s')
  formatter = MyLogFormatter("%(name)-12s : %(message)s",
              "%(levelname)s:%(name)s : %(message)s",tcolor=True)
  # tell the handler to use this format
  console.setFormatter(formatter)
  # add the handler to the root logger
  logger.addHandler(console)

  logger.warning("Logging to file <%s> ...." % logfile)

  return
#enddef setuplog

#############################  Portral   ###############################
if __name__ == "__main__":

##----------------------------------------------------------------------
##
## Global variables are:  _debug, _show, cmd
##
## Argument dictionary:
##
##   keys            Values
##   -------------   --------------------------
##   show            do not run
##   starting        dict of starting time
##
##----------------------------------------------------------------------

  ##- start the jobs now
  _debug   = False
  _show    = False

  cmd  = os.path.basename(sys.argv[0])
  #argsdict = parseArgv(sys.argv[1:])

  try:
    argsdict = parseargv()
    main(**argsdict)
  except runException as ex:
    print(f'\nERROR: {ex}.\n', file = sys.stderr)
