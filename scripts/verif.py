#!/usr/bin/env python3
##
##----------------------------------------------------------------------
##
## This file defines a forecast/analysis workflow and running steps for
## each program in the workflow.
##
## ---------------------------------------------------------------------
##
## HISTORY:
##   Yunheng Wang (05/25/2018)
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

import sys, os, re
from datetime import datetime, timedelta
import time
import logging, argparse

import namelist

##========================== run_interp ==============================

def run_interp(cmd,opts,start_time,workfiles,mrmsfiles,worktimes):

    executable = os.path.join(opts.srcdir,'bin','minterp')
    tmplinput  = os.path.join(opts.srcdir,'NSSLVAR','input','mrmsinterp.input')

    #                  ##    MPI   nx ny Queue    Min NCPN Exclusive
    jconf = Command.MPIConf(True,  2,  2,None, 30,4, False, shell=True)
    if jconf.mpi : executable += '_mpi'

    ##---------------- make working directory -------------------------

    mydir = create_wrkdir(start_time,opts.wrkdir,1)

    if opts.field == 'ref':
        refsrc = 1
    else:
        if start_time.year < 2021:
            refsrc = 2            # 7001 x 3501
        else:
            refsrc = 3            # 7000 x 3500

    calpath = os.path.join(mydir,'calib')
    if not os.path.lexists(calpath) :
      calbas = os.path.join(opts.srcdir,'NSSLVAR','calib')
      #calbas = '/scratch/ywang/NEWSVAR/news3dvar.git/data/adas'
      cmd.copyfile(calbas,calpath,True)

    time_str   = start_time.strftime('%Y%m%d%H%M' )

    obss_files = []
    for fcstfile,mrmsfile,wrktime in zip(workfiles,mrmsfiles,worktimes):

      ##---------------- make namelist file ------------------------------

      hhmmstr = wrktime.strftime('%d%H%M')

      nmlfile  = os.path.join(mydir,'mintrp_%s_%s.input'%(opts.outname,hhmmstr))
      nmlgrp = namelist.decode_namelist_file(tmplinput)

      nmlin  = {'initime'     : wrktime.strftime('%Y-%m-%d.%H:%M:00')
               ,'modelopt'    : 2
               ,'inifile'     : fcstfile
               ,'inigbf'      : 'xxxxxx'
               ,'runname'     : 'mrmsinterp_%s' % (time_str)
               ,'refsrc'      : refsrc
               ,'reffmt'      : 202
               ,'refile'      : mrmsfile
               ,'nradfil'     : 0,  'radfname' : ['xxx']
               ,'nsngfil'     : 0,  'sngfname' : ['xxx'],  'sngtmchk' : ['xxx']
               ,'nuafil'      : 0,  'uafname'  : ['xxx']
               ,'ncwpfil'     : 0,  'cwpfname' : ['xxx']
               ,'nlgtfil'     : 0,  'lightning_files': ['xxx']
               ,'dirname'     : './'
               ,'refout'      : 207
               ,'nproc_x'     : jconf.nproc_x
               ,'nproc_y'     : jconf.nproc_y
               ,'max_fopen'   : jconf.nproc_x*jconf.nproc_y
               ,'cov_factor'  : 0.0
               }

      nmlgrp.merge(nmlin)
      nmlgrp.writeToFile(nmlfile)

      ##-------------- run the program from command line ----------------
      outfile = 'mintrp_%s_%s.output'%(opts.outname,hhmmstr)
      jobid = cmd.run_a_program(executable,nmlfile,outfile,mydir,jconf)

      ##-------------- wait for it to be done -------------------
      if not cmd.wait_job('mintrp_%s'%hhmmstr,jobid,False) :
          raise SystemExit()

      anafile = os.path.join(mydir,'%s_%s'%(opts.intrpname[opts.field],
                                    wrktime.strftime('%Y-%m-%d_%H:%M:%S.nc')))
      obss_files.append(anafile)

    return obss_files
#enddef run_interp

##========================== FSS ==============================

def run_fss(cmd,opts,timestr,workfiles,obss_files) :

  executable = os.path.join(opts.srcdir,'bin','fss')
  tmplinput  = os.path.join(opts.srcdir,'NSSLVAR','input','neighbor_fss.input')

  #                  ##    MPI   nx ny Queue    Min NCPN Exclusive
  jconf = Command.MPIConf(True,  4,  6,None,    30,12,   False)
  if jconf.mpi : executable += '_mpi'

  ##---------------- make working directory -------------------------

  mydir = cmd.wrkdir

  txtfile = os.path.join(mydir,'vscore_%s_%s.fss'%(opts.outname,timestr))

  ##--------------- make namelist file ------------------------------

  nmlfile  = os.path.join(mydir,'neighbor_%s_fss.input'%opts.outname)

  nmlgrp = namelist.decode_namelist_file(tmplinput)

  ncopy = opts.naggregation
  ntime = len(workfiles)
  ncopyopt  = 0
  wrkfiles  = [fn for sublist in workfiles for fn in sublist]
  obsfiles  = [fn for sublist in obss_files for fn in sublist]

  if opts.nens is not None and opts.nens > 0:
      ncopy     = opts.nens
      ncopyopt  = 1

  nmlin  = { 'fcst_files' : wrkfiles,
             'fcst_file_header' : f'{opts.wrfheader}_d',
             'obsfmt'     : opts.obsfmt,
             'obs_files'  : obsfiles,
             'ntime'      : ntime,
             'ncopy'      : ncopy,

             'vfield'     : opts.vfield,
             'rainaccum'  : opts.rainaccum,
             'ncopyopt'   : ncopyopt,
             'radius'     : opts.hradius[opts.field],
             'nradius'    : len(opts.hradius[opts.field]),
             'thres'      : opts.thres[opts.field],
             'nthres'     : len(opts.thres[opts.field]),

             'outfile'    : txtfile,
             'nproc_x'    : jconf.nproc_x,
             'nproc_y'    : jconf.nproc_y
           }

  nmlgrp.merge(nmlin)
  nmlgrp.writeToFile(nmlfile)

  ##-------------- run the program from command line ----------------

  outfile = 'fss_%s_%s.output'%(opts.outname,timestr)
  jobid = cmd.run_a_program(executable,nmlfile,outfile,mydir,jconf)

  ##-------------- wait for it to be done -------------------
  if not cmd.wait_job('run_fss',jobid,False) :
      raise SystemExit()

  return txtfile
#enddef run_fss

##========================== ETS ==============================

def run_ets(cmd,opts,timestr,workfiles,obss_files) :

  executable = os.path.join(opts.srcdir,'bin','ets')
  tmplinput  = os.path.join(opts.srcdir,'NSSLVAR','input','neighbor_ets.input')

  #                  ##    MPI   nx ny Queue    Min NCPN Exclusive
  jconf = Command.MPIConf(True,  4,  6,None,    30,12,   False)
  if jconf.mpi : executable += '_mpi'

  ##---------------- make working directory -------------------------

  mydir = cmd.wrkdir

  txtfile1 = os.path.join(mydir,'vscore_%s_%s.ets'%(opts.outname,timestr))
  txtfile2 = os.path.join(mydir,'vscore_%s_%s.bias'%(opts.outname,timestr))
  txtfile3 = os.path.join(mydir,'contingency_%s_%s.txt'%(opts.outname,timestr))

  ##--------------- make namelist file ------------------------------

  nmlfile  = os.path.join(mydir,'neighbor_%s_ets.input'%opts.outname)

  nmlgrp = namelist.decode_namelist_file(tmplinput)

  ncopy = opts.naggregation
  ntime     = len(workfiles)
  ncopyopt  = 0
  wrkfiles  = [fn for sublist in workfiles for fn in sublist]
  obsfiles  = [fn for sublist in obss_files for fn in sublist]

  if opts.nens is not None and opts.nens > 0:
      ncopy     = opts.nens
      ncopyopt  = 1

  nmlin  = { 'fcst_files' : wrkfiles,
             'fcst_file_header' : f'{opts.wrfheader}_d',
             'obsfmt'     : opts.obsfmt,
             'obs_files'  : obsfiles,
             'ntime'      : ntime,
             'ncopy'      : ncopy,

             'vfield'     : opts.vfield,
             'rainaccum'  : opts.rainaccum,
             'ncopyopt'   : ncopyopt,
             'radius'     : opts.hradius[opts.field],
             'vradius'    : opts.vradius[opts.field],
             'nradius'    : len(opts.hradius[opts.field]),
             'thres'      : opts.thres[opts.field],
             'nthres'     : len(opts.thres[opts.field]),

             'outfile'    : [txtfile1,txtfile2],
             'outcontg'   : 1,
             'contgfile'  : txtfile3,
             'nproc_x'    : jconf.nproc_x,
             'nproc_y'    : jconf.nproc_y
           }

  nmlgrp.merge(nmlin)
  nmlgrp.writeToFile(nmlfile)

  ##-------------- run the program from command line ----------------

  outfile = 'ets_%s_%s.output'%(opts.outname,timestr)
  jobid = cmd.run_a_program(executable,nmlfile,outfile,mydir,jconf)


  ##-------------- wait for it to be done -------------------
  if not cmd.wait_job('run_ets',jobid,False) :
      raise SystemExit()

  return txtfile1,txtfile2
#enddef run_ets

##========================== Reliability ==============================

def run_reliability(cmd,opts,timestr,workfiles,obss_files) :

  executable = os.path.join(opts.srcdir,'bin','reliability')
  tmplinput  = os.path.join(opts.srcdir,'NSSLVAR','input','reliability.input')

  #                  ##    MPI   nx ny Queue    Min NCPN Exclusive
  jconf = Command.MPIConf(False,  1, 1,None,    30, 24,   False,   shell=True)

  ##---------------- make working directory -------------------------

  mydir = cmd.wrkdir

  txtfile = os.path.join(mydir,'vscore_%s_%s.rel'%(opts.outname,timestr))

  ##--------------- make namelist file ------------------------------

  nmlfile  = os.path.join(mydir,'reliability_%s.input'%opts.outname)

  nmlgrp = namelist.decode_namelist_file(tmplinput)

  nmlin  = { 'fcst_files' : workfiles,
             'obsfmt'     : opts.obsfmt,
             'obs_files'  : obss_files,
             'ntime'      : len(workfiles),

             'vfield'     : opts.vfield,
             'rainaccum'  : opts.rainaccum,
             'bins'       : opts.bins[opts.field],
             'nbins'      : len(opts.bins[opts.field]),

             'outfile'    : txtfile,
           }

  nmlgrp.merge(nmlin)
  nmlgrp.writeToFile(nmlfile)

  ##-------------- run the program from command line ----------------

  outfile = 'reliability_%s_%s.output'%(opts.outname,timestr)
  jobid = cmd.run_a_program(executable,nmlfile,outfile,mydir,jconf)

  ##-------------- wait for it to be done -------------------
  if not cmd.wait_job('run_reliability',jobid,False) :
      raise SystemExit()

  return txtfile
#enddef run_reliability

##========================== PLT_FSS =================================

def plt_fss(cmd,opts,timestr,txtfile) :

  inputdir   = os.path.join(opts.srcdir,'NSSLVAR')
  executable = os.path.join(opts.ncldir,'ncl')

  ncltmpl = os.path.join(inputdir,'nclscripts','fss.ncl' )

  #                  ##    MPI   nx ny Queue    Min NCPN Exclusive
  jconf = Command.MPIConf(False,  1,  1,None, 30,1, False,   shell=True)

  ##---------------- make working directory -------------------------

  mydir = cmd.wrkdir

  if not cmd.wait_for_a_file('plt_fss',txtfile,3600,300,10):
    raise RuntimeError("FSS file not found.")

  ##---------------- Plot each field --------------------------------

  timeline = 'timecst = "%sZ"'%timestr
  unitsline = 'units = "%s"'%opts.units[opts.field]
  fcsttime  = 'fcstintvl = "%s"'%opts.timeunits[opts.field]

  nclscpt = os.path.join(mydir,'plt_fss_%s_%s.ncl'%(opts.outname,timestr))

  nclfile = open(nclscpt,'w')
  nclstr  = '''
       ; ***********************************************
       ; These files are loaded by default in NCL V6.2.0 and newer
       ; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
       ; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
       ; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
       ;************************************************
       begin

         filename = "%(filename)s"

         wks_type = "png"
         wks_type@wkWidth  = 1224
         wks_type@wkHeight = 1584
         wks   = gsn_open_wks (wks_type,"fss_%(varname)s_%(timestr)s.png")

         %(timeline)s
         %(unitsline)s
         %(fcsttime)s
       ''' % { 'filename' : txtfile, 'timestr' : timestr,
               'timeline' : timeline,'varname' : opts.outname,
               'unitsline': unitsline, 'fcsttime' : fcsttime
              }

  nclfile.write(cmd.trim(nclstr))
  with open(ncltmpl) as fp:
      for line in fp :
          if line.startswith(';;;'): continue
          nclfile.write(line)

  nclfile.close()

  ## Now execute the ncl script
  jobid = cmd.run_ncl_plt(executable,nclscpt,mydir,jconf )

  #retcode = subprocess.call('ncl %s'% nclscpt,cwd=mydir,shell=True)

  if not cmd.wait_job('plt_fss',jobid,True) :
       raise RuntimeError("Job plt_fss failed")

#enddef plt_fss

##========================== PLT_ETS =================================

def plt_ets(cmd,opts,timestr,txtfiles) :

  inputdir   = os.path.join(opts.srcdir,'NSSLVAR')
  executable = os.path.join(opts.ncldir,'ncl')

  #                  ##    MPI   nx ny Queue    Min NCPN Exclusive
  jconf = Command.MPIConf(False,  1,  1,None, 30,1, False,   shell=True)

  ##---------------- make working directory -------------------------

  mydir = cmd.wrkdir
  #if not os.path.lexists(mydir) :
  #  os.mkdir(mydir)

  if not cmd.wait_for_a_file('plt_ets',txtfiles[0],3600,300,10):
    raise RuntimeError("ETS file not found.")

  ##---------------- Plot each field --------------------------------

  timeline  = 'timecst = "%sZ"'%timestr
  unitsline = 'units = "%s"'%opts.units[opts.field]
  fcsttime  = 'fcstintvl = "%s"'%opts.timeunits[opts.field]

  i = 0
  for field in ("ets","bias"):
    ncltmpl = os.path.join(inputdir,'nclscripts','%s.ncl'%field )
    nclscpt = os.path.join(mydir,'plt_%s_%s_%s.ncl'%(field,opts.outname,timestr))

    nclfile = open(nclscpt,'w')
    nclstr  = '''
         ; ***********************************************
         ; These files are loaded by default in NCL V6.2.0 and newer
         ; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
         ; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
         ; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
         ;************************************************
         begin

           filename = "%(filename)s"

           wks_type = "png"
           wks_type@wkWidth  = 1224
           wks_type@wkHeight = 1584
           wks   = gsn_open_wks (wks_type,"%(field)s_%(varname)s_%(timestr)s.png")

           %(timeline)s
           %(unitsline)s
           %(fcsttime)s
      ''' % { 'filename' : txtfiles[i], 'timestr' : timestr,
              'timeline' : timeline, 'field' : field, 'varname':opts.outname,
              'unitsline': unitsline, 'fcsttime' : fcsttime
            }

    nclfile.write(cmd.trim(nclstr))
    with open(ncltmpl) as fp:
        for line in fp :
            if line.startswith(';;;'): continue
            nclfile.write(line)

    nclfile.close()
    i += 1

    ## Now execute the ncl script
    jobid = cmd.run_ncl_plt(executable,nclscpt,mydir,jconf )

    if not cmd.wait_job('plt_ets',jobid,True) :
         raise RuntimeError("Job plt_ets failed")

#enddef plt_ets

##======================= PLT_RELIABILITY ==============================

def plt_reliability(cmd,opts,timestr,txtfile) :

    inputdir   = os.path.join(opts.srcdir,'NSSLVAR')
    executable = os.path.join(opts.ncldir,'ncl')

    #                  ##    MPI   nx ny Queue    Min NCPN Exclusive
    jconf = Command.MPIConf(False,  1,  1,None, 30,1, False,   shell=True)

    ##---------------- make working directory -------------------------

    mydir = cmd.wrkdir

    if not cmd.wait_for_a_file('plt_reliability',txtfile,3600,300,10):
        raise RuntimeError("REL file not found.")

    ##---------------- Plot each field --------------------------------

    timeline  = 'timecst = "%sZ"'%timestr
    unitsline = 'units = "%s"'%opts.units[opts.field]
    fcsttime  = 'fcstintvl = "%s"'%opts.timeunits[opts.field]

    ncltmpl = os.path.join(inputdir,'nclscripts','reliability.ncl' )
    nclscpt = os.path.join(mydir,'plt_rel_%s_%s.ncl'%(opts.outname,timestr))

    nclfile = open(nclscpt,'w')
    nclstr  = '''
         ; ***********************************************
         ; These files are loaded by default in NCL V6.2.0 and newer
         ; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
         ; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
         ; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
         ;************************************************
         begin

           nfiles    = 1
           filenames = "%(filename)s"

           wks_type = "png"
           wks_type@wkWidth  = 1224
           wks_type@wkHeight = 1584
           wks   = gsn_open_wks (wks_type,"%(field)s_%(varname)s_%(timestr)s.png")

           %(timeline)s
           %(unitsline)s
           %(fcsttime)s
      ''' % { 'filename' : txtfile,  'timestr' : timestr,
              'timeline' : timeline, 'field' : opts.field, 'varname':opts.outname,
              'unitsline': unitsline, 'fcsttime' : fcsttime
            }

    nclfile.write(cmd.trim(nclstr))
    with open(ncltmpl) as fp:
        for line in fp :
            if line.startswith(';;;'): continue
            nclfile.write(line)

    nclfile.close()

    ## Now execute the ncl script
    jobid = cmd.run_ncl_plt(executable,nclscpt,mydir,jconf )

    if not cmd.wait_job('plt_ets',jobid,True) :
         raise RuntimeError("Job plt_ets failed")

#enddef plt_reliability

##========================== PLT_COMREF =================================

def plt_comref(cmd,opts,field,obssfiles,worktimes,dirmod=2) :

  inputdir   = os.path.join(opts.srcdir,'NSSLVAR')
  executable = os.path.join(opts.ncldir,'ncl')

  #                  ##    MPI   nx ny Queue    Min NCPN Exclusive
  jconf = Command.MPIConf(False,  1,  1,'radarq', 30,1, False,   shell=True)

  ##---------------- make working directory -------------------------

  mydir = create_wrkdir(worktimes[0],opts.wrkdir,mode=dirmod)

  do_sub = False
  if field == 'obsref':
     refname = 'REFMOSAIC3D'
     tmplfile = 'comref.ncl'
     title = 'MRMS observation'
  elif field == 'fcstref':
     refname = 'REFL_10CM'
     tmplfile = 'comref.ncl'
     title = 'WRF forecast'
  elif field == 'obspcp':
     refname = 'HOURLYPRCP'
     tmplfile = 'hrlypcp.ncl'
     title = 'Stage IV observation'
  elif field == 'fcstpcp':
     refname = 'RAINNC'
     tmplfile = 'hrlypcp.ncl'
     title = 'WRF forecast'
     do_sub  = True

  prevfile = obssfiles[0]
  for obsfile,wrktime in zip(obssfiles,worktimes):

    if not cmd.wait_for_a_file('plt_%s'%field,obsfile,3600,300,10):
      raise RuntimeError("COMREF file not found.")

  ##---------------- Plot each field --------------------------------

    timestr = wrktime.strftime('%Y%m%d_%H%M')

    logging.info(f"Ploting {timestr}" )

    timeline = 'timescst = "%sZ"'%timestr
    titleline = 'title = "%s"' % title

    ncltmpl = os.path.join(inputdir,'nclscripts',tmplfile)
    nclscpt = os.path.join(mydir,'plt_%s_%s.ncl'%(field,timestr))

    nclfile = open(nclscpt,'w')
    nclstr  = '''
         ; ***********************************************
         ; These files are loaded by default in NCL V6.2.0 and newer
         load "%(ncargroot)s/lib/ncarg/nclscripts/csm/gsn_code.ncl"
         ;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
         ;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
         ;************************************************
         load "%(ncargroot)s/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
         begin

           filename = "%(filename)s"
           field    = "%(refname)s"

           wks_type = "png"
           wks_type@wkWidth  = 1224
           wks_type@wkHeight = 1584
           wks   = gsn_open_wks (wks_type,"%(field)s_%(timestr)s.png")

           %(timeline)s
           %(titleline)s
      ''' % { 'filename' : obsfile, 'timestr' : timestr,
              'timeline' : timeline, 'field' : field,
              'refname'  : refname,  'titleline': titleline,
              'ncargroot': os.path.dirname(opts.ncldir)
            }

    nclfile.write(cmd.trim(nclstr))

    if do_sub:
      nclfile.write('''  do_sub = True \n''')
      nclfile.write('''  filename0 = "%s"\n'''%prevfile)

      prevfile = obsfile
    else:
      nclfile.write('''  do_sub = False \n''')

    with open(ncltmpl) as fp:
        for line in fp:
            if line.startswith(';;;'): continue
            nclfile.write(line)

    nclfile.close()

    ## Now execute the ncl script
    jobid = cmd.run_ncl_plt(executable,nclscpt,mydir,jconf )

    #retcode = subprocess.call('ncl %s'% nclscpt,cwd=mydir,shell=True)
                        #stdin=None,stdout=subprocess.STDOUT,stderr=stdout)

    if not cmd.wait_job('plt_comref',jobid,True) :
         raise RuntimeError("Job plt_comref failed")

#enddef plt_comref

################# Waiting for file ready #############################

def wait_for_a_file(filepath,maxwaitexist=10800,waittick=10):
  """
     Checks if a file is ready for reading/copying.

     For a file to be ready it must exist and is not writing by
     any other processe.
  """

  ##
  ## First, make sure file exists
  ##
  #  If the file doesn't exist, wait waittick seconds and try again
  #  until it's found.
  #

  wait_time = 0
  while wait_time < maxwaitexist :
    if not os.path.exists(filepath):
      logging.info(f"<{filepath}> hasn't arrived after {wait_time} seconds.")
      time.sleep(waittick)
      wait_time += waittick
    else :
      done=True
      break
  else:   ## We have waitted too long
      logging.error(f'Waiting for file <{filepath}> excceeded {maxwaitexist} seconds.\n')
      done=False

  return done

################# Retrieve forecast files #############################

def get_files(fstart_times,fcst_interval,fcst_len,diropts):
  '''Retrive forecast files and observation files
     Return are two-dimensional lists
     row:    is the forecast length
     column: is the forecast starting time for the same forecast length
  '''
  wrk_files = []
  ver_files = []
  ver_times = []

  for dtime in range(0,fcst_len+fcst_interval,fcst_interval):  # forecast length
      fcst_file_at_t = []
      obs_file_at_t  = []
      wrk_time_at_t  = []

      for ftime in fstart_times:        # forecast starting time
          print(f"ftime = {ftime}")
          wrkTime = ftime + timedelta(minutes=dtime)
          wrk_time_at_t.append(wrkTime)

          wrffile,varfile = get_files_at_t(ftime,wrkTime,diropts)

          if isinstance(wrffile,list):
            fcst_file_at_t.extend(wrffile)
          else:
            fcst_file_at_t.append(wrffile)

          obs_file_at_t.append(varfile)

      wrk_files.append(fcst_file_at_t)
      ver_files.append(obs_file_at_t)
      ver_times.append(wrk_time_at_t)


  return wrk_files, ver_files, ver_times

def get_files_at_t(fstart_time,curr_time,opts):
    '''Find working files at one specific time '''

    #print(fstart_time, curr_time)
    basedir = fstart_time.strftime('%Y%m%d')
    if fstart_time.hour < 16:
      basedir = (fstart_time-timedelta(hours=24)).strftime('%Y%m%d')

    wrfdir  = fstart_time.strftime('%H%MZ')
    if opts.minterp:

        #
        # find WRF forecast file at this time or a time specified at command line
        # just to provide model grid for the interpolation
        #
        wrf_time = curr_time
        if opts.wrftime is not None:
            wrf_time = fstart_time + timedelta(minutes=opts.wrftime)

        filename  = f'{opts.wrfheader}_d01_{wrf_time:%Y-%m-%d_%H_%M_%S}'
        readyname = f'{opts.wrfheader}Ready_d01_{wrf_time:%Y-%m-%d_%H:%M:%S}'

        if opts.nens is None:
            wrffile = os.path.join(opts.fcstdir,basedir,wrfdir,'dom20/wrf5',filename)
            wrfready = os.path.join(opts.fcstdir,basedir,wrfdir,'dom20/wrf5',readyname)
            if not wait_for_a_file(wrfready,3600,waittick=10):
                raise RuntimeError(f"Forecast file not found: {readyname}.")
            if not os.path.lexists(wrffile):
                filename  = f'{opts.wrfheader}_d01_{wrf_time:%Y-%m-%d_%H:%M:%S}'
                wrffile = os.path.join(opts.fcstdir,basedir,wrfdir,'dom20/wrf5',filename)
            if not os.path.lexists(wrffile):
                raise RuntimeError(f"WRF FCST file not found: {wrffile}.")
        elif opts.nens == 0:
            wrffile = os.path.join(opts.fcstdir,basedir,wrfdir,'dom20/wrf5_0',filename)
        #else:
        #    logging.error(f'For MINTERP, it is not necessary to run multiple ensemble member. args.ensno = {opts.nens}\n')
        #    raise RuntimeError("MINTERP does not work with multiple ensemble members.")

        #
        # Find MRMS file in binary or netCDF format
        #
        mrmsfile = f"{opts.mrmsname[opts.field]}.{curr_time:%Y%m%d.%H%M%S}"
        #print(f"Looking for {mrmsfile} ...")
        varfile  = os.path.join(opts.mrmsdir,basedir,mrmsfile)
        #mrmsfilegz = os.path.join(opts.mrmsdir,'%s.gz'%mrmstime)
        if not wait_for_a_file(varfile,3600,waittick=10):
            raise RuntimeError(f"MRMS file not found: {varfile}.")

    else:

        #
        # find WRF forecast file at this time
        #
        filename  = f'{opts.wrfheader}_d01_{curr_time:%Y-%m-%d_%H_%M_%S}'
        readyname = f'{opts.wrfheader}Ready_d01_{curr_time:%Y-%m-%d_%H:%M:%S}'
        if opts.nens is None:
            wrffile = os.path.join(opts.fcstdir,basedir,wrfdir,'dom20/wrf5',filename)
            #wrfready = os.path.join(opts.fcstdir,basedir,wrfdir,'dom20/wrf5',readyname)
            #if not wait_for_a_file(wrfready,3600,waittick=10):
            #    raise RuntimeError(f"Forecast file not found: {readyname}.")
        elif opts.nens == 0:
            wrffile = os.path.join(opts.fcstdir,basedir,wrfdir,'dom20/wrf5_0',filename)
        else:
            wrffile = []
            for mem in range(1,opts.nens+1):
                wrffile.append(os.path.join(opts.fcstdir,basedir,wrfdir,f'dom20/wrf5_{mem}',filename))

        #
        # Find verification file, either 3DVAR output file or MRMS interpolated to the model grid
        #
        if opts.obsfmt == 1:     #'ANALYSIS':    # find 3D var analysis files
          vardir  = curr_time.strftime('%H%MZ')
          filename  = f'wrfout_d01_{curr_time:%Y-%m-%d_%H:%M:%S}'
          readyname = f'wrfoutReady_d01_{curr_time:%Y-%m-%d_%H:%M:%S}'
          varfile = os.path.join(opts.fcstdir,basedir,vardir,'dom20/news3dvar',filename)
          varready = os.path.join(opts.fcstdir,basedir,vardir,'dom20/news3dvar',readyname)
          if not wait_for_a_file(varready,3600,waittick=10):
              raise RuntimeError(f"Analysis file not found: {readyname}.")

        elif opts.obsfmt == 202:  #'MRMSBIN', Interpolated netCDF files
          creffile = f"{opts.intrpname[opts.field]}_{curr_time:%Y-%m-%d_%H:%M:%S}.nc"
          #creffile = os.path.join(opts.obsdir,basedir,wrfdir,'%s.nc'%creftime)
          varfile = os.path.join(opts.obsdir,basedir,creffile)
          if not wait_for_a_file(varfile,3600,waittick=10):
              raise RuntimeError(f"MRMS {opts.intrpname[opts.field]} file not found: {varfile}.")
        else:
          #raise RuntimeError("Unsupported obs. source: %s."%opts.obsfmt)
          varfile=None

    return wrffile, varfile

########################################################################

class CustomFormatter(argparse.RawTextHelpFormatter, argparse.ArgumentDefaultsHelpFormatter):
    '''for output a nice help messge '''
    #pass

def parse_command_line():
  '''Parse command line and return command arguments as argout '''

  parser = argparse.ArgumentParser(description='Run verificaiton scores for NEWSVAR forecast',
                                   epilog='''        \t\t---- Yunheng Wang (2020-11-21).
                                          ''',
                                   formatter_class=CustomFormatter)

  defaultwrkdir = '/scratch/ywang/test_runs'

  parser.add_argument('fcst_date',
                      help='Forcast starting time in "yyyymmddHHMM" or "," separated datetime string \nfor computing aggragation of the contingency table')

  parser.add_argument('field',
                      help='field (one [ref,pcp,pcp3,pcp6])')

  parser.add_argument('-s','--src_dir',
                      help='Program source directory (find "bin","scripts","NSSLVAR/input" etc.)\n',
                      default=os.path.dirname(os.path.dirname(os.path.realpath(__file__))))

  parser.add_argument('-f','--fcst_dir',
                      help='WRF forecast directory\n',default=f"{defaultwrkdir}")

  parser.add_argument('-o','--obs_dir',
                      help='Observation directory (MRMS or other oberservation interpolated to the model grid)\n',
                      default=f"{defaultwrkdir}/verify/mrms")

  parser.add_argument('-w','--wrk_dir',
                      help='Working directory\n',default=f"{defaultwrkdir}/verify")

  parser.add_argument('-p','--program',
                      help='''Program to run, one of [minterp,plt_fcst,plt_obs,run_fss,run_ets,plt_fss,plt_ets]
                      verify = [run_fss,run_ets,plt_fss,plt_ets]\n''',
                      default="verif")

  parser.add_argument('-v','--vdata',action='store_true',
                      help='Use MRMS interpolated to model grid, otherwise, use 3DVAR analysis',default=True)

  parser.add_argument('-r','--wrf_header',
                      help='WRF forecast output file header',default="wrfout")
  parser.add_argument('-e','--ensno',type=int,default=None,
                      help='ensemble number. None: normal run (looking for "wrf5"); 0: control member only (looking for "wrf5_0");\n > 1: number of ensemble (looking for "wrf5_[1-x]"), verify the mean of field\n')

  parser.add_argument('-l', '--fcst_len', default=720, type=int,
                      help='Forecast length in minutes')
  parser.add_argument('-i', '--interval', default=60, type=int,
                      help='Verification interval in minutes')

  parser.add_argument('-m', '--mrms_dir',
                      help='for running "MINTERP" only, MRMS obs. directory (original MRMS in binary or netCDF format)\n',
                      default=f"{defaultwrkdir}/MRMS")

  parser.add_argument('-t','--wrf_time',default=None,type=int,
                    help='for running "MINTERP" only, WRF output file time in minutes (to provide model grid)\n')

  argout = parser.parse_args()

  if argout.program == 'minterp':
      if argout.ensno is not None and argout.ensno > 0:
          logging.error(f'For MINTERP, it is not necessary to run multiple ensemble member. argout.ensno = {argout.ensno}, use 0 or None instead.')
          sys.exit(-1)
      if argout.mrms_dir is None:
          logging.error('For MINTERP, option "-m" is required.')
          sys.exit(-2)

  return argout

########################################################################

class Dirs:
  ''' Initilize working option based on command line arguments
      for easily passing around within subprocedures
  '''

  def __init__(self,argin):
    self.srcdir  = argin.src_dir
    self.fcstdir = argin.fcst_dir
    self.wrkdir  = argin.wrk_dir
    self.mrmsdir = argin.mrms_dir       # original MRMS files
    self.obsdir  = argin.obs_dir        # Interpolated MRMS files on the model grid
    self.ncldir  = '/scratch/software/NCL/default/bin'

    self.field   = argin.field
    self.wrfheader = argin.wrf_header
    self.nens      = argin.ensno

    self.naggregation = 1
    self.minterp      = False
    self.wrftime      = argin.wrf_time

    self.obsfmt = 1                                  # 'ANALYSIS'
    if argin.vdata: self.obsfmt = 202                # 'MRMSBIN', Interpolated netCDF files

    self.rainaccum = 0
    if argin.field == 'ref':
      self.vfield = 1
    elif argin.field == 'pcp':
      self.vfield = 2
      self.rainaccum = 0
    elif argin.field.startswith('pcp'):
      self.vfield = 2
      self.rainaccum = int(argin.field[3:4])
    else:
      self.vfield = 3              # 2-5 km UH, need analysis file to compute UH and no MPI support

    if argin.field == 'ref':
      self.outname = 'CREF'
    elif argin.field == 'pcp6':
      self.outname = 'PCP6'
    elif argin.field == 'pcp3':
      self.outname = 'PCP3'
    else:
      self.outname = 'HPCP'

    self.mrmsname  = {'ref' : 'CREF',
                      'pcp' : '1HR_STAGE4',
                      'pcp6': '1HR_STAGE4',
                      'pcp3': '1HR_STAGE4'
                     }

    self.intrpname = {'ref' : 'MRMS_CREF',
                      'pcp' : 'MRMS_HPRCP',
                      'pcp6': 'MRMS_HPRCP',
                      'pcp3': 'MRMS_HPRCP'
                      }

    self.units     = {'ref' : 'dBZ',
                      'pcp' : 'mm',
                      'pcp6': 'mm',
                      'pcp3': 'mm'
                     }

    self.timeunits = {'ref' : 'minutes',
                      'pcp' : 'hours',
                      'pcp6': 'hours',
                      'pcp3': 'hours'
                     }

#    self.thres   = {'ref': [20.0,30.0,40.0,50.0],
#                    'pcp': [1.0,5.0,10.0,15.0] }
#   For ROC use more to fill the curve - max of 10 values are allowed

    self.thres   = {'ref' : [10.0,20.0,30.0,40.0],
                    'pcp' : [0.0, 0.01,0.1,1.0,5.0,10.0,15.0,25.0,50.0,250.0],
                    'pcp6': [0.0, 0.01,0.1,1.0,5.0,10.0,15.0,25.0,50.0,250.0],
                    'pcp3': [0.0, 0.01,0.1,1.0,5.0,10.0,15.0,25.0,50.0,250.0]
                   }
    self.hradius = {'ref' : [12.0,18.0,24.0,30.0],
                    'pcp' : [12.0,18.0,24.0,30.0],
                    'pcp6': [12.0,18.0,24.0,30.0],
                    'pcp3': [12.0,18.0,24.0,30.0]
                   }

    self.vradius = {'ref' : [  1,  1,  1,   1,   1,   1],
                    'pcp' : [  1,  1,  1,   1,   1,   1],
                    'pcp6': [  1,  1,  1,   1,   1,   1],
                    'pcp3': [  1,  1,  1,   1,   1,   1]
                   }
    #
    # for reflectivity only
    #
    self.bins   = {'ref' : [0.0, 0.01,0.1,1.0,10.0,20.0,30.0,40.0,50.0,80.0],
                    'pcp' : [0.0, 0.01,0.1,1.0,5.0,10.0,15.0,25.0,50.0,250.0],
                    'pcp6': [0.0, 0.01,0.1,1.0,5.0,10.0,15.0,25.0,50.0,250.0],
                    'pcp3': [0.0, 0.01,0.1,1.0,5.0,10.0,15.0,25.0,50.0,250.0]
                   }

  ######################################
  def process_datetime(self,fcst_date):
    '''Processing datetime string from command line
       return a list of datetime  and a distinguish string for working directory
    '''
    process_times = []
    if re.match(r'^(\d{12}[,:;]?)+$',fcst_date) is not None:
        entries = re.findall(r'\d{12}',fcst_date)
        #print(entries)
        self.naggregation = len(entries)
        for entry in entries:
            process_times.append(datetime.strptime(entry,'%Y%m%d%H%M'))

        if self.naggregation == 1:
            time_str  = process_times[0].strftime('%Y%m%d_%H%M')   # just a string to distinguish this run
        else:     # multiple times
            if self.nens is not None and self.nens > 0:
                logging.error('Multiple Datetime canot be used with args.ensno > 0.')
                raise RuntimeError("Multiple datatime conflicts with multiple ensemble members.")

            time_str = process_times[0].strftime('%Y%m%d_%H%M')+"-"+process_times[-1].strftime('%H%M')
    else:
        logging.error(f'Date time string is not right: got "{fcst_date}"')
        raise RuntimeError(f"Wrong datetime string {fcst_date}")

    return process_times,time_str

  ######################################
  def check_program(self,program):
    ''' Check program and option from command line for consistency'''

    if self.nens is not None and self.nens > 0:
      if program in ['minterp','plt_obs','plt_fcst']:
          logging.error(f'Multiple ensembles canot be used with {program}.')
          raise RuntimeError(f"Multiple ensembles conflicts with program {program}.")

    if program == 'minterp':
        self.minterp = True
        self.wrftime = args.wrf_time

#end class Dirs

######################################
def create_wrkdir(wrk_time,bas_dir,mode=2):
    '''mode == 1: Create working directory structure based on event date only
       mode == 2: Create working directory structure based on fcst_time (date and time)
       mode == 0: Check whether the wrk_dir exists'''

    if mode <= 0:        # aggregation of several forecast, put the work in bas_dir
        out_wrk_dir = bas_dir
        if not os.path.lexists(out_wrk_dir):
          os.mkdir(out_wrk_dir)
    else:                            # Otherwise, attach date/timeZ directory structure except for minterp

        if wrk_time.hour < 16:             # for WoF
          eventdate = (wrk_time-timedelta(days=1)).strftime('%Y%m%d')
        else:
          eventdate = wrk_time.strftime('%Y%m%d')

        out_wrk_dir = os.path.join(bas_dir,eventdate)
        if not os.path.lexists(out_wrk_dir):
          os.mkdir(out_wrk_dir)

        if mode == 2:               # minterp does not need time subdirectory
          case_dir = wrk_time.strftime('%H%MZ')
          out_wrk_dir = os.path.join(out_wrk_dir,case_dir)
          if not os.path.lexists(out_wrk_dir):
            os.mkdir(out_wrk_dir)

    return out_wrk_dir
#enddef create_wrkdir

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if __name__ == "__main__":

  _DEBUG = True

  import Command_Odin as Command
  #import Command_Jet as Command

  stime = time.time()

  args = parse_command_line()

  rootdir = Dirs(args)

  rootdir.check_program(args.program)
  fcst_times,timstr = rootdir.process_datetime(args.fcst_date)

  if rootdir.minterp or rootdir.naggregation > 1 or args.program == "plt_obs":
      mode = 1
  else:
      mode = 2
  wrkdir = create_wrkdir(fcst_times[0],args.wrk_dir,mode)

  cmdconfig = Command.configurator(wrkdir,False,_DEBUG)
  cmdconfig.setuplog(wrkdir,'verif',timstr,_DEBUG)

  #thres=[40.0]
  #hradius=[4.0]
  #vradius=[1]

  #flens = { '19' : 360, '20' : 300, '21' : 240 }
  #hour = fcst_time.strftime('%H')
  #fcstlen = flen[hour]

  #---------------------------------------------------------------------
  #
  # Prepare forecast file and observation files
  #
  #---------------------------------------------------------------------

  logging.info(f"Program to be run: {args.program}")
  logging.info(f"Source  directory: {rootdir.srcdir}")
  logging.info(f"Working directory: {rootdir.wrkdir}")
  logging.info(f"FCST    directory: {rootdir.fcstdir}")

  if args.program != "verif" and args.program not in ["run_ets", "run_fss", "minterp", "run_reliability", "plt_obs"]:
      rootdir.obsfmt = 0    # do not check observation directory
  else:
      logging.info(f"Obs     directory: {rootdir.obsdir}")

  fcst_files,obs_files,wrk_times = get_files(fcst_times,args.interval,args.fcst_len,rootdir)


  #---------------------------------------------------------------------
  #
  # Run the programs for score and plot
  #
  #---------------------------------------------------------------------
  if args.program == "verif":
      fssfile = run_fss(cmdconfig,rootdir,timstr,fcst_files,obs_files)
      etsfiles = run_ets(cmdconfig,rootdir,timstr,fcst_files,obs_files)
      #relfile = run_reliability(cmdconfig,rootdir,timstr,fcst_files,obs_files)

      plt_fss(cmdconfig,rootdir,timstr,fssfile)
      plt_ets(cmdconfig,rootdir,timstr,etsfiles)
      #plt_reliability(cmdconfig,rootdir,timstr,relfile)
  else:

      fcstfiles = list(zip(*fcst_files))
      obsifiles = list(zip(*obs_files))
      wrktimes  = list(zip(*wrk_times))

      for t,fcst_time in enumerate(fcst_times):  # Forecast starting time in string
                                                 # wrktimes is forecasting times in Datetime with forecast intervals
          if args.program == "minterp":
            obs_files = run_interp(cmdconfig,rootdir,fcst_time,fcstfiles[t],obsifiles[t],wrktimes[t])

          if args.program == "plt_obs":
            plt_comref(cmdconfig,rootdir,f'obs{args.field}',obsifiles[t],wrktimes[t],dirmod=1)

          if args.program == "plt_fcst":
            #logging.info(f"{t}-{fcst_time},{wrktimes[t]}")
            plt_comref(cmdconfig,rootdir,f'fcst{args.field}',fcstfiles[t],wrktimes[t])

      if args.program == "run_fss":
        fssfile = run_fss(cmdconfig,rootdir,timstr,fcst_files,obs_files)

      if args.program == "run_ets":
        etsfiles = run_ets(cmdconfig,rootdir,timstr,fcst_files,obs_files)

      if args.program == "run_reliability":
        relfile = run_reliability(cmdconfig,rootdir,timstr,fcst_files,obs_files)

      if args.program == "plt_fss":
        fssfile = os.path.join(wrkdir,'vscore_%s_%s.fss'%(rootdir.outname,timstr))
        plt_fss(cmdconfig,rootdir,timstr,fssfile)

      if args.program == "plt_ets":
        etsfiles = [os.path.join(wrkdir,'vscore_%s_%s.ets' %(rootdir.outname,timstr)),
                    os.path.join(wrkdir,'vscore_%s_%s.bias'%(rootdir.outname,timstr)) ]
        plt_ets(cmdconfig,rootdir,timstr,etsfiles)

      if args.program == "plt_reliability":
        relfile = os.path.join(wrkdir,'vscore_%s_%s.rel'%(rootdir.outname,timstr))
        plt_reliability(cmdconfig,rootdir,timstr,relfile)

  etime = time.time()-stime
  fm = (etime % 3600 )//60
  fs =  etime % 3600 - fm*60
  print ("Job finished and used %02dm %02ds." % (fm, fs))
