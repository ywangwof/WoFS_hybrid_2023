#!/usr/bin/env python
## ---------------------------------------------------------------------
##
## This is a python library to submit program to SLURM (Simple Linux
## Utility for Resource Management).
##
## ---------------------------------------------------------------------
##
## HISTORY:
##   Yunheng Wang (11/20/2017)
##   Initial version based on previous work for LSF, PBS and SGE.
##
##   Yunheng Wang (01/29/2021)
##   Merged all three Command_Odin.py, Command_Jet.py & Command_Schooner.py
##
########################################################################
##
## Requirements:
##
########################################################################

import os, sys, time, re
import subprocess

from configBase import baseConfigurator, JobID, MPIConf

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class configurator (baseConfigurator) :
  #classbegin
  '''
  this is a specific computer-dependent configurations for a cray machine
  Using SLURM.
  '''

  ##----------------------- Initialization      -----------------------
  def __init__(self,wrkdir,norun,debug) :
    baseConfigurator.__init__(self,wrkdir,norun,debug)
    self.hardncpn  = 24    ## constant hardward number cores per node
    self.defaultQueue = 'batch'
    #self.jobstatuscmd = self.get_job_status
    self.hostname  = "VECNA"
    self.schjobext = 'slurm'
    self.needcopy = False
  #enddef

  ##----------------------- Ending of the module -----------------------
  def finalize(self) :
    baseConfigurator.finalize(self)
  #enddef

  ######################################################################

  def run_a_program(self,executable,nmlfile,outfile,wrkdir,jobconf,inarg=None):
    '''
      Generate job script for a task and submit it

      nmlfile : namelist file can be None
      outfile : must provide a output file name
      wrkdir  : the program can be run in a directory different from the
                instance attribute of wrkdir
      NOTE: For array jobs, it is a general directory without ensemble number appended
    '''

    if self.cmdmutex.acquire():
      self.serieno += 1
      myserieno = self.serieno
      self.cmdmutex.release()

    #cwdsaved = os.getcwd()
    #os.chdir(wrkdir)

    cmdstr = executable
    if nmlfile :
      if inarg is None:
        cmdstr += " %s" % nmlfile
      elif inarg == 'STDIN':
        cmdstr += " < %s" % nmlfile
      else:
        cmdstr += " %s %s" % (inarg,nmlfile)

    if outfile :
      (jobname,ext) = os.path.splitext(outfile)
      jobname = os.path.basename(jobname)
      cmdstr += " > %s" % outfile
    else :
      jobname = os.path.basename(executable)

    if jobconf.mpi :

      claimncpn = jobconf.claimncpn
      nprocs = jobconf.nproc_x*jobconf.nproc_y

      (nodes,extra) = divmod(nprocs,claimncpn)
      if extra > 0 :
        nodes += 1

      runcmdstr = f"srun --label -n {nprocs} --mpi=pmi2 {cmdstr}"

    else :
      nprocs = 1
      claimncpn = 1
      nodes  = 1
      runcmdstr = f"srun -n 1 {cmdstr}"


    if jobconf.shell:

      if jobconf.numens is None:
        self.addlog(0,self.hostname, 'In <%s>, executing:\n    $> %s\n' % (wrkdir,cmdstr))
        jobid = JobID(jobname,wrkdir,self,jobconf,myserieno)
        jobid['status'] = subprocess.call(cmdstr,shell=True,cwd=wrkdir)

        if jobid['status'] == 0: subprocess.call('touch done.%s.%d' %(jobname,myserieno),shell=True,cwd=wrkdir)
        else:                    subprocess.call('touch error.%s.%d'%(jobname,myserieno),shell=True,cwd=wrkdir)
      else:
        for noens in range(0,jobconf.numens+1):
          jobdir = "%s_%d" % (wrkdir, noens)
          self.addlog(0,self.hostname, 'In <%s>, executing:\n    $> %s\n' % (jobdir,cmdstr))
          jobid = JobID(jobname,jobdir,self,jobconf,myserieno)
          jobid['status'] = subprocess.call(cmdstr,shell=True,cwd=jobdir)

          if jobid['status'] == 0: subprocess.call('touch done.%s.%d_%d' %(jobname,myserieno,noens),shell=True,cwd=jobdir)
          else:                    subprocess.call('touch error.%s.%d_%d'%(jobname,myserieno,noens),shell=True,cwd=jobdir)

    else:

      if jobconf.numens is None:  # single job
        scptdir   = wrkdir
        jobwrkdir = wrkdir
        append    = "${SLURM_JOBID}"
        logpre    = "%s/%s_%%j"%(wrkdir,jobname)
      else: # job array
        scptdir   = "%s_0" % wrkdir
        append    = "${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
        jobwrkdir = "%s_${SLURM_ARRAY_TASK_ID}"%wrkdir
        logpre    = "%s_%%a/%s_%%a_%%j"%(wrkdir,jobname)

      slurmoptions = ' '
      if jobconf.exclusive:
          #slurmoptions = '--exclusive'
          slurmoptions = '--mem-per-cpu=16G'
      #else:
      #    #slurmoptions = '--share'

      runpart  = jobconf.jobqueue or self.defaultQueue
      if runpart == "radarq":
          runqueue = 'radar'
      else:
          runqueue = 'largequeue' if jobconf.ntotal > 288 else 'smallqueue'

      (hour,minute) = divmod(jobconf.claimmin,60)
      timestr = '%02d:%02d:00' % (hour,minute)

      #SBATCH --exclude=nid00010,nid00604,nid00605,nid00606,nid00445,nid00446,nid00447
      scriptstr = '''#!/bin/bash
          #SBATCH -p %(partition)s
          #SBATCH -J %(jobname)s
          #SBATCH -N %(nodes)d -n %(nprocs)d
          #SBATCH --ntasks-per-node=%(claimncpn)d
          #SBATCH %(slurmoptions)s
          #SBATCH -t %(claimtime)s
          #SBATCH -o %(logpre)s.out
          #SBATCH -e %(logpre)s.err

          #
          # modules
          #
          module load compiler/latest
          module load mkl/latest
          module load hmpt/2.27

          export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/scratch/software/intel/netcdf/lib:/scratch/software/intel/hdf5/lib:/scratch/software/intel/grib2/libpng/lib:/scratch/software/intel/grib2/zlib/lib:/scratch/software/miniconda3/lib:/usr/lib64

          time1=$(date '+%%s')
          echo "Job Started: $(date). Job Id:  $SLURM_JOBID. "
          echo "NODES: $SLURM_JOB_NODELIST"

          # Change to the directory that you want to run in.
          #
          cd %(wrkdir)s

          rm -rf %(outfile)s

          # Set the stack limit as high as we can.
          ulimit -s unlimited
          #ulimit -a

          set echo on

          touch start.%(jobname)s.%(append)s

          %(cmdstr)s

          if [[ $? -eq 0 ]]; then
            touch done.%(jobname)s.%(append)s
          else
            touch error.%(jobname)s.%(append)s
          fi

          set echo off

          time2=$(date '+%%s')

          let diff=time2-time1
          let hour=diff/3600
          let diff=diff%%3600
          let min=diff/60
          let sec=diff%%60

          echo -n "Job   Ended: $(date). "
          printf 'Job run time:  %%02d:%%02d:%%02d' $hour $min $sec
          echo " "

          ''' %{ 'wrkdir' : jobwrkdir, 'logpre'  : logpre, 'jobname' : jobname,
                 'cmdstr' : runcmdstr,    'outfile' : outfile,
                 'queue'  : runqueue,  'partition': runpart,
                 'claimtime' : timestr,'append' : append,
                 'nprocs' : nprocs,    'nodes' : nodes,    'claimncpn' : claimncpn,
                 'slurmoptions' : slurmoptions
                }

      scriptfile = '%s.%s' % (jobname,self.schjobext)
      fullscript = os.path.join(scptdir,scriptfile)

      batchFile = open(fullscript,'w')
      batchFile.write(self.trim(scriptstr))
      batchFile.close()

      self.addlog(0,self.hostname,'''- %02d - Jobscript "%s" generated.''' %(
                        myserieno,scriptfile )  )

      if self.showonly :
        self.addlog(0,self.hostname, 'Preparing job script "%s" in %s.' % (scriptfile,wrkdir))
        jobid = JobID(jobname,wrkdir,self,jobconf)
        jobid['status'] = 0
      else :
        jobid = self.submit_a_job(jobname,scptdir,jobconf)
        jobid.update_status()

    #os.chdir(cwdsaved)

    return jobid
  #enddef run_a_program

  ######################################################################

  def run_ncl_plt(self,executable,nmlfile,wrkdir,jobconf):
    '''
      Plot using NCL and convert to PNG file

      nmlfile : namelist file can be None
      outfile : must provide a output file name
      wrkdir  : the program can be run in a directory different from the
                instance attribute of wrkdir
    '''

    if self.cmdmutex.acquire():
      self.serieno += 1
      myserieno = self.serieno
      self.cmdmutex.release()

    #cwdsaved = os.getcwd()
    #os.chdir(wrkdir)

    cmdstr = executable
    if nmlfile :
      cmdstr += " %s" % nmlfile

    (jobname,ext) = os.path.splitext(nmlfile)
    jobname = os.path.basename(jobname)

    if jobconf.mpi :

      claimncpn = min(jobconf.claimncpn,self.hardncpn)
      nprocs = jobconf.nproc_x*jobconf.nproc_y

      (nodes,extra) = divmod(nprocs,claimncpn)
      if extra > 0 :
        nodes += 1

      #nprocs = nodes*self.hardncpn

    else :
      nprocs = 1
      claimncpn = 1
      nodes  = 1

    cmdstr = 'srun -n %d %s' % (nprocs, cmdstr)

    if jobconf.shell:

      if jobconf.numens is None:  # single job
            self.addlog(0,self.hostname, 'In <%s>, executing:\n    $> %s\n' % (wrkdir,cmdstr))
            job = JobID(jobname,wrkdir,self,jobconf,myserieno)
            cmdlist=cmdstr.split()
            job['status'] = subprocess.call(cmdlist[3:],shell=False,cwd=wrkdir)

            if job['status'] == 0: subprocess.call('touch done.%s.%d' %(jobname,myserieno),shell=True,cwd=wrkdir)
            else:                  subprocess.call('touch error.%s.%d'%(jobname,myserieno),shell=True,cwd=wrkdir)
      else:
        for noens in range(0,jobconf.numens+1):
            jobdir = "%s_%d" % (wrkdir, noens)
            self.addlog(0,self.hostname, 'In <%s>, executing:\n    $> %s\n' % (jobdir,cmdstr))
            job = JobID(jobname,jobdir,self,jobconf,myserieno)
            cmdlist=cmdstr.split()
            job['status'] = subprocess.call(cmdlist[3:],shell=False,cwd=jobdir)

            if job['status'] == 0: subprocess.call('touch done.%s.%d_%d' %(jobname,myserieno,noens),shell=True,cwd=jobdir)
            else:                  subprocess.call('touch error.%s.%d_%d'%(jobname,myserieno,noens),shell=True,cwd=jobdir)

    else:

      if jobconf.numens is None:  # single job
        scptdir   = wrkdir
        jobwrkdir = wrkdir
        append    = "${SLURM_JOBID}"
        logpre    = "%s/%s_%%j"%(wrkdir,jobname)
      else: # job array
        scptdir   = "%s_1" % wrkdir
        append    = "${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
        jobwrkdir = "%s_${SLURM_ARRAY_TASK_ID}"%wrkdir
        logpre    = "%s_%%a/%s_%%a_%%j"%(wrkdir,jobname)

      #if jobconf.exclusive:
      #    slurmoptions = '--exclusive'
      #else:
      #    #slurmoptions = '--share'
      #    slurmoptions = ' '

      runpart  = jobconf.jobqueue or self.defaultQueue
      #if runpart == "radarq":
      #    runqueue = 'radar'
      #else:
      #    runqueue = 'largequeue' if jobconf.ntotal > 288 else 'smallqueue'

      (hour,minute) = divmod(jobconf.claimmin,60)
      timestr = '%02d:%02d:00' % (hour,minute)

      scriptstr = '''#!/bin/bash
          #SBATCH -p %(partition)s
          #SBATCH -J %(jobname)s
          #SBATCH -N %(nodes)d -n %(claimncpn)d -c 1
          #SBATCH --ntasks-per-node=%(claimncpn)d
          #SBATCH -t %(claimtime)s
          #SBATCH -o %(logpre)s.out
          #SBATCH -e %(logpre)s.err

          time1=$(date '+%%s')
          echo "Job Started: $(date). Job Id:  $SLURM_JOBID"
          echo " "

          cd %(wrkdir)s

          set echo on

          %(cmdstr)s

          if [[ $? -eq 0 ]]; then
            touch done.%(jobname)s.%(append)s
          else
            touch error.%(jobname)s.%(append)s
          fi

          set echo off

          time2=$(date '+%%s')

          let diff=time2-time1
          let hour=diff/3600
          let diff=diff%%3600
          let min=diff/60
          let sec=diff%%60

          echo -n "Job   Ended: $(date). "
          printf 'Job run time:  %%02d:%%02d:%%02d' $hour $min $sec
          echo " "

          ''' %{ 'wrkdir'   : jobwrkdir,    'jobname'     : jobname,
                 'cmdstr'   : cmdstr,    'claimtime'   : timestr,
                 'partition'   : runpart,
                 'nodes'    : nodes,     'claimncpn'   : claimncpn,
                 'logpre'      : logpre, 'append' : append
                }

      scriptfile = '%s.%s' % (jobname,self.schjobext)
      scriptfull = os.path.join(scptdir,scriptfile)

      batchFile = open(scriptfull,'w')
      batchFile.write(self.trim(scriptstr))
      batchFile.close()

      self.addlog(0,self.hostname,'''- %02d -  Jobscript "%s" generated.''' %(
                        myserieno,scriptfile )  )

      if self.showonly :
        self.addlog(0,"jet",'Preparing job script "%s" in %s.' % (scriptfile,wrkdir))
        job = JobID(jobname,wrkdir,self,jobconf)

      else :
        job = self.submit_a_job(jobname,scptdir,jobconf)
        job.update_status()

    #os.chdir(cwdsaved)

    return job
  #enddef run_ncl_plt

  ######################################################################

  def run_joinwrf(self,executable,nmlfile,outfile,wrkdir,jobconf,inarg=None):
    '''
      Join WRF output files in split format.
      It is mostly the same as run_a_program execpt for it is a NON-MPI
      task and special CLEAN after the program successfully run.

      nmlfile : namelist file can be None
      outfile : must provide a output file name
      wrkdir  : the program can be run in a directory different from the
                instance attribute of wrkdir
      NOTE: For array jobs, it is a general directory without ensemble number appended
    '''
    import namelist

    if self.cmdmutex.acquire():
      self.serieno += 1
      myserieno = self.serieno
      self.cmdmutex.release()

    #cwdsaved = os.getcwd()
    #os.chdir(wrkdir)

    cmdstr = executable
    if nmlfile :
      if inarg is None:
        cmdstr += " %s" % nmlfile
      elif inarg == 'STDIN':
        cmdstr += " < %s" % nmlfile
      else:
        cmdstr += " %s %s" % (inarg,nmlfile)

    if outfile :
      (jobname,ext) = os.path.splitext(outfile)
      jobname = os.path.basename(jobname)
      cmdstr += " > %s" % outfile
    else :
      jobname = os.path.basename(executable)

    # joinwrf is a non-mpi job
    nprocs = 1
    claimncpn = 1
    nodes  = 1

    cmdstr = 'srun -n %d %s' % (nprocs, cmdstr)

    if jobconf.numens is None:
        nmldir = wrkdir
    else:
        nmldir= f"{wrkdir}_0"

    nmlgrp = namelist.decode_namelist_file(os.path.join(nmldir,nmlfile))
    fileheader = nmlgrp['wrfdfile'].filename_header
    filetime   = nmlgrp['wrfdfile'].end_time_str
    fileready  = f"{fileheader}_d01_{filetime}_ready"
    filewrf    = f"{fileheader}_d01_{filetime}_????"

    if jobconf.shell:

      if jobconf.numens is None:  # single job
            self.addlog(0,self.hostname, 'In <%s>, executing:\n    $> %s\n' % (wrkdir,cmdstr))
            jobid = JobID(jobname,wrkdir,self,jobconf,myserieno)
            jobid['status'] = subprocess.call(cmdstr,shell=False,cwd=wrkdir)

            if jobid['status'] == 0: subprocess.call('touch done.%s.%d' %(jobname,myserieno),shell=True,cwd=wrkdir)
            else:                    subprocess.call('touch error.%s.%d'%(jobname,myserieno),shell=True,cwd=wrkdir)
      else:
        for noens in range(0,jobconf.numens+1):
            jobdir = "%s_%d" % (wrkdir, noens)
            self.addlog(0,self.hostname, 'In <%s>, executing:\n    $> %s\n' % (jobdir,cmdstr))
            jobid = JobID(jobname,jobdir,self,jobconf,myserieno)
            jobid['status'] = subprocess.call(cmdstr,shell=False,cwd=jobdir)

            if jobid['status'] == 0: subprocess.call('touch done.%s.%d_%d' %(jobname,myserieno,noens),shell=True,cwd=jobdir)
            else:                    subprocess.call('touch error.%s.%d_%d'%(jobname,myserieno,noens),shell=True,cwd=jobdir)

    else:

      if jobconf.numens is None:  # single job
        scptdir   = wrkdir
        jobwrkdir = wrkdir
        append    = "${SLURM_JOBID}"
        logpre    = f"{wrkdir}/{jobname}_%j"
      else: # job array
        scptdir   = f"{wrkdir}_0"
        append    = "${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
        jobwrkdir = f"{wrkdir}_${{SLURM_ARRAY_TASK_ID}}"
        logpre    = f"{wrkdir}_%a/{jobname}_%a_%j"

      if jobconf.exclusive:
          slurmoptions = '--exclusive'
      else:
          #slurmoptions = '--share'
          slurmoptions = ' '

      runpart  = jobconf.jobqueue or self.defaultQueue
      if runpart == "radarq":
          runqueue = 'radar'
      else:
          runqueue = 'largequeue' if jobconf.ntotal > 288 else 'smallqueue'

      (hour,minute) = divmod(jobconf.claimmin,60)
      timestr = '%02d:%02d:00' % (hour,minute)

      scriptfile = f"{jobname}.{self.schjobext}"

      scriptstr = '''#!/bin/bash
          #SBATCH -A %(queue)s
          #SBATCH -p %(partition)s
          #SBATCH -J %(jobname)s
          #SBATCH -N %(nodes)d
          #SBATCH %(slurmoptions)s
          #SBATCH -t %(claimtime)s
          #SBATCH -o %(logpre)s.out
          #SBATCH -e %(logpre)s.err

          time1=$(date '+%%s')
          echo "Job Started: $(date). Job Id:  $SLURM_JOBID"
          echo " "

          cd %(wrkdir)s

          set echo on

          touch start.%(jobname)s.%(append)s

          %(cmdstr)s

          if [[ $? -eq 0 ]]; then
            #touch done.%(jobname)s.%(append)s
            #
            # Specail clean after join run successfully
            #
            if [[ -e %(fileready)s ]]; then
                rm -rf %(filewrf)s
                rm %(nmlfile)s %(outfile)s %(scriptfile)s
            fi
            rm start.%(jobname)s.%(append)s
          else
            touch error.%(jobname)s.%(append)s
          fi

          set echo off

          time2=$(date '+%%s')

          let diff=time2-time1
          let hour=diff/3600
          let diff=diff%%3600
          let min=diff/60
          let sec=diff%%60

          echo -n "Job   Ended: $(date). "
          printf 'Job run time:  %%02d:%%02d:%%02d' $hour $min $sec
          echo " "

          ''' %{ 'wrkdir'   : jobwrkdir, 'jobname'     : jobname,
                 'cmdstr'   : cmdstr,    'claimtime'   : timestr,
                 'queue'    : runqueue,  'partition'   : runpart,
                 'nodes'    : nodes,     'slurmoptions': slurmoptions,
                 'logpre'      : logpre, 'append' : append,
                 'fileready'   : fileready, 'filewrf' : filewrf,
                 'nmlfile'     : nmlfile, 'outfile'     : outfile,
                 'scriptfile'  : scriptfile
                }

      scriptfull = os.path.join(scptdir,scriptfile)
      batchFile = open(scriptfull,'w')
      batchFile.write(self.trim(scriptstr))
      batchFile.close()

      self.addlog(0,self.hostname,'''- %02d -  Jobscript "%s" generated.''' %(
                        myserieno,scriptfile )  )

      if self.showonly :
        self.addlog(0,self.hostname,'Preparing job script "%s" in %s.' % (scriptfile,wrkdir))
        jobid = JobID(jobname,wrkdir,self,jobconf)
        jobid['status'] = 0
      else :
        jobid = self.submit_a_job(jobname,scptdir,jobconf)
        jobid.update_status()

    #os.chdir(cwdsaved)

    return jobid
  #enddef run_joinwrf

  ######################################################################

  def run_unipost(self,executable,nmlfile,outfile,wrkdir,postdir,ndate,ifhr,jobconf):
    '''
      Generate job script for a unipost and submit it
      Same as run_a_program, just add run of copygb.exe with two extra
      arguments postdir & ndate

      nmlfile : namelist file can be None
      outfile : must provide a output file name
      wrkdir  : the program can be run in a directory different from the
                instance attribute of wrkdir
    '''

    if self.cmdmutex.acquire():
      self.serieno += 1
      myserieno = self.serieno
      self.cmdmutex.release()

    #cwdsaved = os.getcwd()
    os.chdir(wrkdir)

    cmdstr = executable
    if nmlfile :
      cmdstr += " < %s" % nmlfile

    if outfile :
      (jobname,ext) = os.path.splitext(outfile)
      jobname = os.path.basename(jobname)
      #cmdstr += " > %s" % outfile
    else :
      jobname = os.path.basename(executable)

    if jobconf.mpi :

      claimncpn = min(jobconf.claimncpn,self.hardncpn)
      nprocs = jobconf.nproc_x*jobconf.nproc_y
      cmdstr = 'srun -n %d %s' % (nprocs, cmdstr)

      (nodes,extra) = divmod(nprocs,claimncpn)
      if extra > 0 :
        nodes += 1

      ##nprocs = nodes*self.hardncpn

    else :
      nprocs = 1
      claimncpn = jobconf.claimncpn
      nodes  = 1

    runpart  = jobconf.jobqueue or self.defaultQueue
    if runpart == "radarq":
        runqueue = 'radar'
    else:
        runqueue = 'largequeue' if jobconf.ntotal > 288 else 'smallqueue'

    (hour,minute) = divmod(jobconf.claimmin,60)
    timestr = '%02d:%02d:00' % (hour,minute)

    claimncpn = jobconf.claimncpn

    ##fhr = ndate.split('_')[1].split(':')[0]
    fhr = "%02d"%ifhr

    scriptstr = '''#!/bin/bash
        #SBATCH -A %(queue)s
        #SBATCH -p %(partition)s
        #SBATCH -J %(jobname)s
        #SBATCH -N %(nodes)d -n %(claimncpn)d -c 1
        #SBATCH --ntasks-per-node=%(claimncpn)d
        #SBATCH -t %(claimtime)s
        #SBATCH -o %(wrkdir)s/%(jobname)s_%%j.out
        #SBATCH -e %(wrkdir)s/%(jobname)s_%%j.err

        time1=$(date '+%%s')
        echo "Job Started: $(date). Job Id:  $SLURM_JOBID"
        echo " "

        cd %(wrkdir)s

        rm -rf %(outfile)s

        set echo on

        %(cmdstr)s

        if [[ $? -eq 0 ]]; then
          touch done.%(jobname)s.${SLURM_JOBID}
        else
          touch error.%(jobname)s.${SLURM_JOBID}
        fi

        #if [[ -s "copygb_hwrf.txt" && -s "WRFPRS.GrbF%(fhr)s" ]]; then
        #  read nav < 'copygb_hwrf.txt'
        #  srun -n 1 %(postdir)s/copygb.exe -xg "${nav}" WRFPRS.GrbF%(fhr)s nsslvar_prd_%(ndate)s.grb
        #  rm WRFPRS.GrbF%(fhr)s
        #fi

        set echo off

        time2=$(date '+%%s')

        let diff=time2-time1
        let hour=diff/3600
        let diff=diff%%3600
        let min=diff/60
        let sec=diff%%60

        echo -n "Job   Ended: $(date). "
        printf 'Job run time:  %%02d:%%02d:%%02d' $hour $min $sec
        echo " "

        ''' %{ 'wrkdir' : wrkdir, 'jobname' : jobname,
               'cmdstr' : cmdstr, 'outfile' : outfile,
               'queue'  : runqueue, 'partition' : runpart,
               'claimtime' : timestr,
               'nodes'  : nodes,  'claimncpn': claimncpn,
               'postdir': postdir,'ndate'    : ndate, 'fhr' : fhr
              }

    scriptfile = '%s.%s' % (jobname,self.schjobext)
    scriptfull = os.path.join(wrkdir,scriptfile)

    batchFile = open(scriptfull,'w')
    batchFile.write(self.trim(scriptstr))
    batchFile.close()

    self.addlog(0,self.hostname,'''- %02d -  Jobscript "%s" generated.''' %(
                      myserieno,scriptfile ) )

    if self.showonly :
      self.addlog(0,self.hostname,'Preparing job script "%s" in %s.' % (scriptfile,wrkdir))

      job = JobID(jobname,wrkdir,self,jobconf)
      job["status"] = 0

    else :

      job = self.submit_a_job(jobname,wrkdir,jobconf)
      job.update_status()

    #os.chdir(cwdsaved)

    return job
  #enddef run_unipost

  ##====================================================================

  def submit_a_job(self,jobname,wrkdir,jobconf,tasks=None) :
    '''
    submit a job to SLURM on odin
    '''

    jobfile = os.path.join(wrkdir,'%s.%s'%(jobname,self.schjobext))

    #if djobs :
    #  bjoblst = ['sbatch', '-d', 'afterok:%s' % ':'.join(djobs), jobfile]
    #else :
    #  bjoblst = ['sbatch', jobfile]
    bjoblst = ['sbatch']

    if tasks is not None:
        bjoblst.extend(['-a',','.join(map(str,tasks))])
    elif jobconf.numens is not None:
        bjoblst.extend(['-a','0-%d'%jobconf.numens])

    bjoblst.append(jobfile)

    ##retout = subprocess.check_output(bjobstr,stdin=None,stderr=subprocess.STDOUT,cwd=wrkdir)
    retout = subprocess.Popen(bjoblst, stdout=subprocess.PIPE,cwd=wrkdir).communicate()[0]
    retout = retout.decode(encoding='utf-8', errors='strict')
    #print retout

    ## get jobid here
    jobidre = re.compile(r'Submitted batch job (\d+)')
    retlist = retout.splitlines()
    jobid = None
    for retstr in retlist :
      jobidmatch = jobidre.match(retstr)
      #print retstr, jobidmatch
      if jobidmatch :
        jobid = jobidmatch.group(1)
        break

    if jobid is None :
      print('Something is wrong with job (%s) submitting? Get: "%s".'%(jobname,retout),file=sys.stderr)
      self.addlog(1,self.hostname,'  Job <%s> is not submitted correctly.' % (jobname,)  )
      self.addlog(-1,self.hostname,'    $ %s\n    > "%s"' % ( ' '.join(bjoblst), retout )  )

      job = None
    else:
      job = JobID(jobname,wrkdir,self,jobconf,jobid,self.jobstatuscmd)

      self.addlog(  0,self.hostname,'Submitted %s.' % job  )
      self.addlog(999,self.hostname,'    $ %s' % ( ' '.join(bjoblst) )  )
      self.addlog(999,self.hostname,'    > %s' % ( retout )  )

    return job
  #enddef submit_a_job

  ##====================================================================

  def get_job_status(self,jobid) :
    '''
    Check job status using SQUEUE & SACCT
    '''

    if jobid is None :
      return 0

    #retout = subprocess.Popen(['squeue', '-j','%s' % jobid ],
    #                       stdout=subprocess.PIPE).communicate()[0]
    pipe = subprocess.PIPE
    #queryarg = ['squeue','-h','-o','"%10i %20u %.2t"','-j',jobid ]
    queryarg = ['squeue','-h','-o','"%10i %.2t"','-j',jobid ]
    outs  = subprocess.Popen(queryarg,stdout=pipe,stderr=pipe).communicate()
                                #sacct -j jobid -o "JobID,User,state"
    retout = outs[0]
    reterr = outs[1]
    #self.addlog(1,retout)
    timeoutre = re.compile(r'Socket timed out on send/recv operation' )
    while timeoutre.search(reterr):
      #print "STDOUT: %s"%retout
      #print "STDERR: %s"%reterr
      time.sleep(10)
      outs   = subprocess.Popen(queryarg,stdout=pipe,stderr=pipe).communicate()
      retout = outs[0]
      reterr = outs[1]
    #print retout
    ## get job status here

    #if self.debug :   ## debugging outputs
    #  if self.firstqstat :
    #    print retlist[0]
    #    print retlist[1]
    #    self.firstqstat = False
    #  else :
    #    print retlist[1]
    #jobstatre = re.compile(r'"%s +%s +(\w{1,2})"' % (jobid,os.getenv('USER')) )
    jobstatre = re.compile(r'"%s +(\w{1,2})"' % jobid )
    jobstatmatch = jobstatre.match(retout)
    if jobstatmatch :
      status = jobstatmatch.group(1)
      #self.addlog(1,'get job status %s'%status)
      if status == "CD" :  # (completed)
        jobstatus = 0
      elif status == "PD" :
        jobstatus = 1
      elif status == "R" :
        jobstatus = 2
      elif status == 'CA':  # (cancelled),
        jobstatus = 3
      elif status == 'CF':  # (configuring),
        jobstatus = 4
      elif status == 'CG':  # (completing),
        jobstatus = 5
      elif status == 'F':   # (failed),
        jobstatus = 6
      elif status == 'TO':  # (timeout)
        jobstatus = 7
      elif status == 'NF':  # (node failure).
        jobstatus = 8
      else :
        jobstatus = 9

    else :
      queryarg = ['sacct',  '-o', "JobID,state", '-n','-j', jobid]
      outs   = subprocess.Popen(queryarg,stdout=pipe,stderr=pipe).communicate()
      retout = outs[0]
      reterr = outs[1]
      #print retout
      #print reterr

      while timeoutre.search(reterr):
        #print "STDOUT: %s"%retout
        #print "STDERR: %s"%reterr
        time.sleep(10)
        outs   = subprocess.Popen(queryarg,stdout=pipe,stderr=pipe).communicate()
        retout = outs[0]
        reterr = outs[1]

      retlst = retout.split('\n')
      #print retlst[0]
      jobstatre = re.compile(r'%s +(\w+)' % jobid )
      jobstatmatch = jobstatre.match(retlst[0])
      if jobstatmatch:
        status = jobstatmatch.group(1)
        if status == 'COMPLETED':
          jobstatus = 0
        elif status == 'PENDING':
          jobstatus = 1
        elif status == 'RUNNING':
          jobstatus = 2
        else:
          jobstatus = 9
      else:
          self.addlog(-1,self.hostname,'job status is not matched, "%s"'%retlst[0])
          jobstatus = None

    return jobstatus

  #enddef get_job_status

  ######################################################################

  @staticmethod
  def fetchDefaultWorkingDir(tests=False) :
      ''' default working directory if not giving on the command line
      '''
      return '/scratch/ywang/real_runs'

  #enddef fetchDefaultWorkingDir

  ######################################################################

  @staticmethod
  def fetchNCARGRoot() :
      ''' Default NCL path ROOT'''

      ncargpath = os.environ.get('NCARG_ROOT')

      if ncargpath is None:
        ncargpath = '/scratch/software/NCL/default'

      return ncargpath

  #enddef fetchDefaultWorkingDir

#endclass configurator

if __name__ == "__main__":
  #
  # Test get job status
  #
  statusmap = { 0: 'COMPLETED', 1: 'PENDING', 2: 'RUNNING', 9: 'UNKNOWN'}

  cmd=configurator("./",False,False)
  a = cmd.get_job_status(sys.argv[1])
  print ("%d -> %s"%(a,statusmap[a]))
