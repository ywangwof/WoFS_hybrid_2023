#!/usr/bin/env python3
## ---------------------------------------------------------------------
## This software is in the public domain, furnished "as is", without
## technical support, and with no warranty, express or implied, as to
## its usefulness for any purpose.
## ---------------------------------------------------------------------
##
## This is a python library for general utilities
##
## ---------------------------------------------------------------------
##
## HISTORY:
##   Yunheng Wang (05/18/2012)
##   Initial version.
##
##
########################################################################
##
## Requirements:
##
########################################################################

import os, time, re, sys
import shutil, threading, logging

from datetime import datetime, timedelta

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class baseConfigurator :
  #classbegin
  '''
  this is a container for running programs from command lines
  '''

  ##----------------------- Initialization      -----------------------
  def __init__(self,wrkdir,norun,debug):
    self.showonly = norun               ## not actually run the executable
    self.wrkdir   = os.path.realpath(wrkdir)
    self.debug    = debug
    self.needcopy = False
    #self.lsofbin  = '/usr/sbin/lsof'
    self.jobstatuscmd = None

    self.logpath  = None

    self.serieno = 0

    self.cmdmutex     = threading.Lock()
    self.keep_waiting = True
  #enddef

  def setuplog(self,logdir,runname,runtime,debug,justfordelete=False):
    '''
    set up logging path
    '''

    logfile = self.getlogpath(logdir,runname,runtime,justfordelete)
    logger=logging.getLogger('')

    #        Level    Numeric value
    #        CRITICAL   50
    #        ERROR      40
    #        WARNING    30
    #        INFO       20
    #        DEBUG      10
    #        NOTSET      0

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
    logging.getLogger('').addHandler(console)

    logging.warning(f"Logging to <{logfile}> ....")
  #enddef setuplog

  ##------------------------------- Do log      -----------------------

  def addlog(self,icode,logname,message) :

      logger=logging.getLogger(logname)
      #logger=logging.getLogger("")
      if icode == 0 :     ## just a status message
        #print >> self.logfile, message
        logger.info(message)
      elif icode == 999:  ## debug message
        logger.debug(message)
      elif icode < 0 :    ## fatal error
        #print >> self.logfile, '* ' + message
        logger.error('* ' + message)
        if not self.showonly: raise runException( message )
        ##sys.exit(icode)
      else:               ## Warnings or other message
        logger.warning('# ' + message)
        #print >> self.logfile, message

      #self.logfile.flush()
  #enddef addlog

  ##----------------------- Delete log file  -----------------------
  def deletelogfile(self) :

    if self.logpath is not None:
      if self.showonly:
        print ("Deleting %s ......" % self.logpath)
      else:
      ##print "Deleting %s ......" % self.logpath
        os.unlink(self.logpath)

  #enddef

  ##----------------------- Ending of the module -----------------------
  def finalize(self) :
    '''
       To be implemented for each environment
    '''
    #self.logfile.close()

  #enddef

  ########################################################################

  def run_a_program(self,executable,nmlfile,outfile,wrkdir,jobconf,inarg=None):
    '''
       To be implemented for each environment
    '''
  #enddef

  ######################################################################

  def run_convert(self,name,files,wrkdir,framenames) :
    '''
    To be implemented with each runtime envrionment
    '''
  #enddef

  ######################################################################

  def getlogpath(self,logdir,runname,runtime,justfordelete=False) :
    '''
    Create log directory and/or construct a log file name
    '''

    filename = '%s%s.log'%(runname,runtime)

    if logdir is None:
       logdir = os.path.join(self.wrkdir,'log')

    if not os.path.lexists(logdir):
      if not justfordelete:
        os.mkdir(logdir)
      else:
        logdir = self.wrkdir

    logpath = os.path.join(logdir,filename)

    numlog = 0
    if not justfordelete:
      while os.path.lexists(logpath) :
        numlog += 1
        logpath = os.path.join(logdir,'%s%s.log%02d'%(runname,runtime,numlog))

    return logpath
  #enddef getlogpath

  ######################################################################

  def trim(self,docstring):
      '''
      trim string to keep the right indentation.
      '''
      maxint = 1000
      if not docstring:
          return ''

      ## Convert tabs to spaces (following the normal Python rules)
      ## and split into a list of lines:
      lines = docstring.expandtabs().splitlines()
      ## Determine minimum indentation (first line doesn't count):
      indent = maxint
      for line in lines[1:]:
          stripped = line.lstrip()
          if stripped:
              indent = min(indent, len(line) - len(stripped))
      ## Remove indentation (first line is special):
      trimmed = [lines[0].strip()]
      if indent < maxint:
          for line in lines[1:]:
              trimmed.append(line[indent:].rstrip())
      ## Strip off trailing and leading blank lines:
      ##while trimmed and not trimmed[-1]:
      ##    trimmed.pop()
      while trimmed and not trimmed[0]:
          trimmed.pop(0)
      ## Return a single string:
      return '\n'.join(trimmed)

  #enddef trim

  def copyfile(self,srcfile,destfile,isdir=False,hardcopy=None) :
    '''Compute nodes do not have access to the template files on some platforms
       So we have to copy the file instead of symbolic link.'''

    if hardcopy is None:
      copyorlink = self.needcopy
    else:
      copyorlink = hardcopy

    if copyorlink :
      if isdir :
        shutil.copytree(srcfile,destfile,False)
      else :
        shutil.copy(srcfile,destfile)
    else :
      if os.path.lexists(destfile): os.unlink(destfile)
      os.symlink(srcfile,destfile)

  #enddef copyfile

  ################# Check job status ###################################

  def wait_job(self,jobname,job,waitonjob,maxwaittime = 5*3600) :
    '''
    Check the job (jobid)'s status and wait for it if requested.
    '''
    if self.showonly : return True

    errmsg = 'Unknown Problem'
    retstatus = False
    #print '%s waitonjob = %s' % (jobname, waitonjob)
    if job.status is not None:
      if waitonjob :       ## we should wait here

        #print '%s jobstatus = %d' % (jobname, jobstatus)
        self.addlog(0,"CMD",'Waiting for   <%s> to finish ...' % ( jobname ) )

        waitstatus = job.wait(maxwaittime)

        if waitstatus is None:   ## we have waitted too long
            retstatus = False
            errmsg = 'Waiting for "%s" exceeded %d minutes.' % (jobname,maxwaittime/60)
            self.addlog(1,"CMD", '\n  *** %s ***\n' % errmsg  )
        elif waitstatus == 0 :        ## job is done normally
            self.addlog(0,"CMD",'Job <%s> done.' % jobname  )
            retstatus = True
        else :                        ## bad thing happened with jobname
            errmsg = 'Job "%s" failed at try = %d' % (jobname,job.numtry)
            self.addlog(1,"CMD", ' *** %s ***' % errmsg  )
            #self.addlog(0,"CMD",'Resubmitting (try: %d) Job <%s> ...' % (job.numtry+1,jobname)  )
            if job.resubmit() :      # resubmit successfully
                retstatus = self.wait_job(jobname,job,waitonjob,maxwaittime)
            else:
                errmsg = 'Job "%s" failed after %d tries.' % (jobname,job.numtry)
                self.addlog(1,"CMD", '\n  *** %s ***\n' % errmsg  )
                retstatus = False
      else :                          ## job is submited and may be running
            retstatus = True
    else :                            ## job did not submited right
      errmsg = 'Job "%s" failed with status = %d' % (jobname,job.status)
      self.addlog(1,"CMD", '\n  *** %s ***\n' % errmsg  )
      retstatus = False

    return retstatus

  #enddef wait_job


  ################# Waiting for file ready #############################

  def wait_for_a_file(self,jobname,filepath,
                      maxwaitexist=10800,maxwaitready=3600,waittick=10,
                      skipread=False,expectSize=0):
    """
       Checks if a file is ready for reading/copying.

       For a file to be ready it must exist and is not writing by
       any other processe.
    """

    if self.showonly:
        return True

    wait_time = 0

    if maxwaitexist is None:
       maxwaitexist = sys.maxsize

    ##
    ## First, make sure file exists
    ##
    #  If the file doesn't exist, wait waittick seconds and try again
    #  until it's found.
    #

    self.addlog(999,'CMD',f"Waiting for <{filepath}> ...." )
    while wait_time < maxwaitexist and self.keep_waiting:
        if os.path.exists(filepath): break

        time.sleep(waittick)
        wait_time += waittick
    else:   ## We have waitted too long
        self.addlog(1,'CMD',f'Job "{jobname}" waiting for file <{filepath}> exceeded {maxwaitexist} seconds.\n')
        return False

    ##
    ## Secondly, file should be stable for manipulating if requested for a check
    ##
    #  Check whether other process is writing this file
    #  If the file exists but is changing continuously, wait "waittick" seconds
    #  and check again until it's stable within "waittick" seconds.
    #
    if maxwaitready is None:
       maxwaitready = sys.maxsize

    multiple = 24      # multipulor of wait tick for which file is condisdered old
                       # so not further stability checking
    if not skipread:
        epoch   = datetime.utcfromtimestamp(0)
        currUTC = datetime.utcnow()
        last    = os.path.getmtime(filepath)
        fileage = (currUTC-epoch).total_seconds()-last
        if fileage < multiple*waittick:  # only wait for newer file
          wait_time = 0
          while wait_time < maxwaitready and self.keep_waiting:
                time.sleep(waittick)
                wait_time += waittick
                current=os.path.getmtime(filepath)
                if last == current:
                  if expectSize > 0:
                    fsize = os.path.getsize(filepath)
                    if fsize < expectSize*1024:
                      self.addlog(999,'CMD',f"<{filepath}> is still too small ({fsize} bytes) after {wait_time} seconds. Keep Waiting ...")
                      continue
                    self.addlog(999,'CMD',f"<{filepath}> now has size ({fsize} bytes) after {wait_time} seconds.")

                  self.addlog(0,'CMD',f"<{filepath}> is now ready after {wait_time} seconds.")
                  break

                self.addlog(999,'CMD',f"<{filepath}> is actively changing after {wait_time} seconds." )
                last = current

          else :   ## We have waitted too long
                self.addlog(1,'CMD', f'Job "{jobname}" waiting for file <{filepath}> ready exceeded {maxwaitready} seconds.\n')
                return False
        else:
          #self.addlog(999,'CMD',"<%s> is (%d seconds) old > %d * tick (%d seconds). No further checking."%(filepath,fileage,multiple,waittick) )
          self.addlog(999,'CMD',f"<{filepath}> ready." )

    return True

  #enddef wait_for_a_file

  ################# Waiting for file ready #############################

  def wait_for_files(self,jobname,files,
                      maxwaitexist=10800,maxwaitready=3600,waittick=10,
                      skipread=False,expectSize=0):
    """
       Checks if a list of files are ready for reading/copying.

       For a file to be ready it must exist and is not writing by
       any other processe.
    """

    if self.showonly:
        return len(files)

    if maxwaitexist is None:
       maxwaitexist = sys.maxsize

    wait_time = 0

    ##
    ## First, make sure file exists
    ##
    #  If the file doesn't exist, wait waittick seconds and try again
    #  until it's found.
    #

    basefile   = os.path.basename(files[0])
    dirname    = re.sub(r"_\d{1,3}$","_*",os.path.dirname(files[0]))

    while wait_time < maxwaitexist and self.keep_waiting:
        filexist = [os.path.exists(filepath) for filepath in files]
        if filexist.count(True) == len(files): break

        miss = [ idx for idx, exist in enumerate(filexist) if not exist ]
        status_str = f"exists:{filexist.count(True)}; miss:{miss}"
        self.addlog(999,'CMD',f"Checking {basefile} ({status_str}) \n{' '*15}from {dirname} at {wait_time} seconds:")
        #for idx, exist in enumerate(filexist):
        #    if not exist:
        #        self.addlog(999,'CMD',f"{idx:02d}: {os.path.basename(files[idx])} not exist ...")
        time.sleep(waittick)
        wait_time += waittick
    else:   ## We have waitted too long
        self.addlog(1,'CMD',f'Job "{jobname}" waiting for {basefile} from {dirname} exceeded {maxwaitexist} seconds.\n')
        for idx, exist in enumerate(filexist):
            if not exist:
                self.addlog(1,'CMD',f"{idx:02d}: {os.path.basename(files[idx])} not exist.")
        return filexist.count(True)
    ##
    ## Secondly, file should be stable for manipulating if requested for a check
    ##
    #  Check whether other process is writing this file
    #  If the file exists but is changing continuously, wait "waittick" seconds
    #  and check again until it's stable within "waittick" seconds.
    #
    multiple = 24     # multipulor of wait tick for which file is condisdered old
                      # so not further stability checking
    if skipread:
        return filexist.count(True)

    epoch   = datetime.utcfromtimestamp(0)
    currUTC = datetime.utcnow()
    lasts   = [os.path.getmtime(filepath) for filepath in files]
    fileages= [(currUTC-epoch).total_seconds()-last for last in lasts]

    tasks = []
    waitfiles = []
    for idx, fileage in enumerate(fileages):
        if fileage < multiple*waittick:  # only wait for newer file
            tasks.append(idx)
            waitfiles.append(files[idx])

    if len(waitfiles) > 0:
        lasts     = [os.path.getmtime(filepath) for filepath in waitfiles]
        wait_time = 0
        while wait_time < maxwaitready and self.keep_waiting:
            time.sleep(waittick)
            wait_time += waittick
            currents = [os.path.getmtime(filepath) for filepath in waitfiles]
            readys   = [last == current for last, current in zip(lasts, currents)]
            if readys.count(True) == len(waitfiles):
                if expectSize > 0:
                    fsizes = [os.path.getsize(filepath) for filepath in waitfiles]
                    readys = [fsize > expectSize*1024 for fsize in fsizes]
                    if readys.count(True) == len(waitfiles):
                        #self.addlog(999,'CMD',f"Checking ({basefile}) in <{dirname}> after {wait_time} seconds." )
                        self.addlog(999,'CMD',f"All {basefile} in <{dirname}> are ready after {wait_time} seconds.")
                        #for idx, filepath in enumerate(waitfiles):
                        #    self.addlog(999,'CMD',f"{idx:02d}: <{os.path.basename(filepath)}> now has size ({fsizes[idx]} bytes)." )
                    else:
                        smallsize = [idx for idx, ready in zip(tasks,readys) if not ready]
                        self.addlog(999,'CMD',f"Files from {smallsize} in {dirname} are not large enough after {wait_time} seconds. Keep Waiting ...")
                        #for idx, sizeready in enumerate(readys):
                        #    if not sizeready:
                        #        self.addlog(999,'CMD',f"<{waitfiles[idx]}> is still too small ({fsizes[idx]} bytes) after {wait_time} seconds. Keep Waiting ..." )
                        continue

                self.addlog(0,'CMD',f"Files {basefile} in <{dirname}> are now stable after {wait_time} seconds:")
                #for filepath in waitfiles:
                #    self.addlog(0,'CMD',f"<{os.path.basename(filepath)}> is now ready.")
                #break
                return len(files)

            changing = [idx for idx, ready in zip(tasks,readys) if not ready]
            self.addlog(999,'CMD',f"Files from {changing} in {dirname} are actively changing after {wait_time} seconds.")
            #for idx, ready in enumerate(readys):
            #    if not ready:
            #        self.addlog(999,'CMD',f"<{waitfiles[idx]}> is actively changing after {wait_time} seconds.")
            lasts = currents

        else :   ## We have waitted too long
            for idx,ready in enumerate(readys):
                if not ready:
                    self.addlog(1,'CMD', f'Job "{jobname}" waiting for file <waitfiles[idx]> ready exceeded {maxwaitready} seconds.\n')
            return readys.count(True)

    else:
        #self.addlog(999,'CMD',"<%s> is (%d seconds) old > %d * tick (%d seconds). No further checking."%(filepath,fileage,multiple,waittick) )
        #for filepath in files:
        #    self.addlog(999,'CMD',f"{filepath} is ready." )
        self.addlog(999,'CMD',f"All {basefile} in {dirname} are ready." )
        return len(files)

  #enddef wait_for_files

#endclass baseConfigurator

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
# class to hold job id and name etc.
#
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class JobID(dict):

    def __init__(self,name,wrkdir,machine,jobconf,jobid=None,sfunction=None) :
        ''' Only initialize JobID at creation
            Once created, only "status" can be changed using attribute method

            sfunction a procedure that accept jobid as input and
                      return an integer
                      = 0, job is done
                      < 0, job abortion with error
                      > 0, job is running or pending
        '''
        dict.__init__(self)

        self['name']    = name
        self['wrkdir']  = wrkdir   # job script directory
        self['cmd']     = machine
        self['config']  = jobconf

        self['id']      = jobid

        self['status']  = None
        self['numtry']  = 1
        self['statuscmd'] = sfunction   # function to check job status

        if jobconf.numens is not None:
            self['tasks'] = list(range(0,jobconf.numens+1))
            self['failtasks'] = []

        #if machine is not None:
        #    self['script']  = "%s.%s"% (name,machine.schjobext)
        #else:
        #    self['script']  = "%s.qsub"% (name)

    def __getattr__(self,key):
          return self[key]

    #def __setattr__(self,key,value):
    #    if key in ("numtry",):
    #        self[key] = value
    #    else:
    #        raise KeyError("Only job <numtry> can be set")

    def get_status(self):
         '''
         Check job status, return the "status" attribute
         '''

         self.update_status()
         return self.status
    #enddef get_status

    def retrieve_status_message(self):
         '''
         Check job status, return the "status" attribute
         '''

         if self.status is None:
             message = 'UNKNOWN'
         elif self.status < -1:
             message = 'Error'
         elif self.status == 0:
             message = 'Done'
         elif self.status == -1:
             message = 'Failed ' +self["status_ens"]
         elif self.status == 1:
             message = 'Running '+self["status_ens"]
         elif self.status == 9:
             message = 'Pending '+self["status_ens"]
         elif self.status == 10:
             message = 'RESUB'
         else:
             message = 'SURPRISE'

         return message
    #enddef retrieve_status_message

    def update_status(self):
          '''
          Update the job status

          if "statuscmd" presents, use it (cmd.get_job_status)
          else use file detect method by default

          return  0 : job done
                 -6 : job error
                 -1 : some job fail
                  1 : running  (all tasks started)
                  9 : pending
                 10 : just resubmitted
               None : other UNKNOWN conditions
          '''

          if self.id is None :
              self["status"] = None
          else:
              if self.statuscmd is None:
                  if self.config.numens is None:  # one single job
                    startfile = os.path.join(self.wrkdir,f'start.{self.name}.{self.id}')
                    donefile  = os.path.join(self.wrkdir,f'done.{self.name}.{self.id}')
                    errorfile = os.path.join(self.wrkdir,f'error.{self.name}.{self.id}')
                    #if outlog: self.cmd.addlog(999,'JobID',"Checking for file %s"%donefile)
                    if os.path.lexists(donefile):
                        self["status"] = 0
                        if os.path.lexists(startfile): os.unlink(startfile)
                    elif os.path.lexists(errorfile):
                        self["status"] = -6
                        if os.path.lexists(startfile): os.unlink(startfile)
                    elif os.path.lexists(startfile):
                        self["status"] = 1
                    else:
                        self["status"] = 9

                    self["status_ens"] = ""

                  else:   # job array
                    wrkdir = re.sub(r"_\d{1,3}$","",self.wrkdir)

                    donefiles  = [os.path.join(f"{wrkdir}_{iens}",f'done.{self.name}.{self.id}_{iens}')  for iens in self.tasks]
                    startfiles = [os.path.join(f"{wrkdir}_{iens}",f'start.{self.name}.{self.id}_{iens}') for iens in self.tasks]
                    errorfiles = [os.path.join(f"{wrkdir}_{iens}",f'error.{self.name}.{self.id}_{iens}') for iens in self.tasks]
                    #if outlog: self.cmd.addlog(999,'JobID',f"Waiting for {self.name}, current STATUS: {self.status}")

                    done = [os.path.lexists(donefile)   for donefile  in donefiles  ]
                    errr = [os.path.lexists(errfile)    for errfile   in errorfiles ]
                    start = [os.path.lexists(startfile) for startfile in startfiles ]

                    self["status_ens"] = f"(done:{done.count(True)}; fail:{[i for i,x in zip(self.tasks,errr) if x]}; start:{start.count(True)})"

                    if done.count(True) == len(self.tasks):
                        self["status"] = 0
                        for startfile in startfiles:
                            if os.path.lexists(startfile): os.unlink(startfile)
                        self["failtasks"]=[]
                    elif errr.count(True) == len(self.tasks):
                        self["status"] = -6
                        for startfile in startfiles:
                            if os.path.lexists(startfile): os.unlink(startfile)
                        self["failtasks"] = self.tasks
                    elif done.count(True)+errr.count(True) == len(self.tasks):  # partially failed
                        self["status"] = -1
                        for startfile in startfiles:
                            if os.path.lexists(startfile): os.unlink(startfile)
                        self["failtasks"]=[i for i,x in zip(self.tasks,errr) if x]
                    elif start.count(True) == len(self.tasks):
                        self["status"] = 1
                        self["failtasks"]=[i for i,x in zip(self.tasks,done) if not x]
                    else:
                        self["status"] = 9

              else:
                  self["status"] = self.statuscmd(self.id)
    #enddef update_status

    def wait(self,maxwaittime):
        '''
             return status
               = 0, done
               < 0, somethine wrong
               = None,  exceed maxwaittime
        '''

        #
        # Wait for job to start (=1), fail (< 0) or finish (=0)
        # otherwise (pending > 1), keep waiting
        #
        maxwaitsec = maxwaittime
        waitime = 0
        while waitime <= maxwaitsec and self.status > 1 :
           time.sleep(5)
           waitime += 5
           if waitime%20 == 0: self.cmd.addlog(999,'JobID',f"Waiting for <{self.name}> to start, STATUS: {self.retrieve_status_message()}")
           self.update_status()  # output waiting log every 20 seconds

        retstatus = None if waitime > maxwaitsec else self.status
        #
        # We know the job is started, wait for it to finish
        #
        if self.status == 1:                    # all tasks started
            waitime = 0
            maxwaitsec = self.config.claimmin*60
            while waitime <= maxwaitsec and self.status > 0:
                time.sleep(5)
                waitime += 5
                if waitime%10 == 0: self.cmd.addlog(999,'JobID',f"Waiting for <{self.name}> to finish, STATUS: {self.retrieve_status_message()}")
                self.update_status()  # output waiting log every 20 seconds
            retstatus = self.status

        return retstatus
    #enddef wait

    def resubmit(self):
        '''
            return True  if resubmitted
            return False if numtry >= maxtry
        '''
        if self.numtry < self.config.numtry:
            if "failtasks" in self.keys():
                tasks = self.failtasks
                wrkdir = re.sub(r"_\d{1,3}$","",self.wrkdir)
                errorfiles = [os.path.join(f"{wrkdir}_{iens}",f'error.{self.name}.{self.id}_{iens}') for iens in tasks]
                for errorfile in errorfiles:
                    if os.path.lexists(errorfile): os.unlink(errorfile)

                startfiles = [os.path.join(f"{wrkdir}_{iens}",f'start.{self.name}.{self.id}_{iens}') for iens in self.tasks]
                for startfile in startfiles:
                    if os.path.lexists(startfile): os.unlink(startfile)
            else:
                tasks = None
                errorfile = os.path.join(self.wrkdir,'error.%s'%self.id)
                if os.path.lexists(errorfile): os.unlink(errorfile)

                startfile = os.path.join(self.wrkdir,'start.%s'%self.id)
                if os.path.lexists(startfile): os.unlink(startfile)

            newjob = self['cmd'].submit_a_job(self.name,self.wrkdir,self.config,tasks=tasks)
            self["id"]        = newjob.id
            self["status"]    = 10
            self["tasks"]     = tasks
            self["failtasks"] = []
            self["numtry"]   += 1
            retvalue = True
        else:
            retvalue = False

        return retvalue
    #enddef resubmit

    ##################### outputString #################################
    def __str__(self):
      ''' print or str()'''

      if self.numtry > 1:
        outstring = 'job <%s> (try %d), jobid <%s>.' % (self.name,self.numtry,self.id)
      else:
        outstring = 'job <%s>, jobid <%s>.' % (self.name,self.id)

      return outstring

#endclass JobID

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class ConfDict(dict):
    '''Get object from Dict for configuration file '''

    #def __init__(self, config):
    #    super().__init__(config)

    def __getattr__(self, k):
        v = self[k]
        if isinstance(v, dict):
            return ConfDict(v)
        return v

    def __setattr__(self, k, v):
        raise Exception("ConfDict attribute <%s> read only."%k)

    @classmethod
    def fromfilename(cls, filename):
        import yaml
        with open(filename,'r') as f:
            config = yaml.safe_load(f)
        return cls(config)

#endclass ConfDict

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class ExtMData(dict):

    def __init__(self, srcname,extconf):
        super().__init__()
        self['extname'  ] = srcname
        self['hourFreq' ] = extconf.extintvals[0]           # srcHour
        self['hourIntvl'] = extconf.extintvals[1]           # extHour
        self['nz'       ] = extconf.extlvls[0]
        self['nzsoil'   ] = extconf.extlvls[1]
        self['extapp'   ] = extconf.appext

    def has_key(self,k):
        return k in self.keys()

    def __getattr__(self, k):
        v = self[k]
        return v

    def __setattr__(self, k, v):
        raise Exception("ExtMData attribute <%s> read only."%k)

#end class extmdata

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class runException(Exception):
  '''Run-time exception'''
  def __init__(self,message_in):
    Exception.__init__(self)
    #print >> sys.stderr, "ERROR: %s" % message_in
    self.message = message_in
  #enddef

  ####################### outputString #################################
  def __str__(self):
      ''' print or str()'''
      return self.message
#endclass

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class MPIConf :
  #classbegin

  def __init__(self,mpimode=False,nx=1,ny=1,queuename='normal',
                    claimtime=30,ncpn=1,exclusive=False,niotasks=0,shell=False,numens=None,numtry=1) :
    self.mpi        = mpimode
    self.nproc_x    = nx
    self.nproc_y    = ny
    self.ntotal     = nx*ny+niotasks

    self.jobqueue   = queuename
    self.claimmin   = claimtime
    self.claimncpn  = ncpn

    self.exclusive  = exclusive
    self.shell      = shell
    self.numens     = numens
    self.numtry     = numtry
  #enddef

  def setmpi(self,mpimode,nx,ny,niotasks=0):
    ''' Reset MPI config process partition
    '''

    self.mpi = mpimode
    if self.mpi :
      self.nproc_x = nx
      self.nproc_y = ny
      self.ntotal  = nx*ny+niotasks
    else :
      self.nproc_x = 1
      self.nproc_y = 1
      self.ntotal  = 1
  #enddef

  def getmpi(self) :
    ''' Retrieve MPI process partition
    '''
    return (self.mpi,self.nproc_x, self.nproc_y,self.ntotal)
  #enddef getmpi

  def check_nprocin(self,stuple) :
    '''number of processor in "stuple" must be dividible with the
    current mpi configuration
    where stuple = (True/False, nprocx_in, nprocy_in) '''

    if not stuple[0] :
      return True

    if stuple[1] % self.nproc_x != 0 :
      return False

    if stuple[2] % self.nproc_y != 0 :
      return False

    return True
  #enddef check_nprocin

  def check_dims(self,stuple) :
    '''number of processor in "stuple" must be dividible with the
    current mpi configuration
    where stuple = (True/False, nprocx_in, nprocy_in) '''

    if not self.mpi:
      return True

    if (stuple[0]-1) % self.nproc_x != 0:
      return False

    if (stuple[1]-1) % self.nproc_y != 0:
      return False

    return True
  #enddef check_dims

  def updatempi(self,mpiconfig) :
    self.mpi     = mpiconfig.mpi
    self.nproc_x = mpiconfig.nproc_x
    self.nproc_y = mpiconfig.nproc_y
    self.ntotal  = mpiconfig.ntotal

    self.jobqueue   = mpiconfig.jobqueue
    self.claimmin   = mpiconfig.claimmin
    self.claimncpn  = mpiconfig.claimncpn

    self.exclusive = mpiconfig.exclusive
    self.shell     = mpiconfig.shell
    self.numens    = mpiconfig.numens
  #enddef updatempi

  ####################### outputString ###############################
  def __str__(self):
      ''' print or str()'''

      outstring = '[%s, %s, %s, %s, %s, %s]'%(self.mpi, self.nproc_x, self.nproc_y, self.jobqueue, self.claimmin, self.claimncpn)

      return outstring

#endclass

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Custom file with name and status

class MyFileClass:
    def __init__(self, filename, filestatus, fileready=None):
        self.name  = filename       # absolute path
        self.status = filestatus    # True, ready for read
                                    # False, not ready for read
        if fileready is None:
            #self.ready = re.sub(r'wrf(out|input)_d01', r'wrf\g<1>Ready_d01', bkgfile)
            self.ready = re.sub(r'wrf(out)_d01', r'wrf\g<1>Ready_d01', filename)
        else:
            self.ready = fileready  # file name of the ready file

        self.donerename = False

    #------------- rename file at the given time ----------------
    def rename(self,fileTime,ntsample,mtsample,outname='wrfout'):

        if self.donerename: return

        sTime = fileTime - timedelta(minutes=mtsample*(ntsample//2))
        eTime = fileTime + timedelta(minutes=mtsample*(ntsample//2))
        fTime = sTime

        wrfdir  = os.path.dirname(self.name)
        while fTime <= eTime:

            outfile = f'{outname}_d01_{fTime:%Y-%m-%d_%H_%M_%S}'
            myfile  = f'{outname}_d01_{fTime:%Y-%m-%d_%H:%M:%S}'
            wrffile = os.path.join(wrfdir,outfile)
            expfile = os.path.join(wrfdir,myfile)
            readyfile = os.path.join(wrfdir,f'{outname}Ready_d01_{fTime:%Y-%m-%d_%H:%M:%S}')

            if os.path.lexists(wrffile):
                #expfile = f'{outname}_d01_{fileTime:%Y-%m-%d_%H:%M:%S}'
                #assert(expfile in self.name)
                #newfile = os.path.join(wrfdir,expfile)
                if not os.path.lexists(readyfile): raise runException(f"File {wrffile} not ready")
                os.rename(wrffile,expfile)
            fTime += timedelta(minutes=mtsample)

        self.donerename = True

    #------------- Wait for ready file ----------------
    def wait_ready(self,command,appeartime=600,readytime=20):

        if not self.status:
            if self.name == self.ready:  # same file, wrfinput_d01
                retval = command.wait_for_a_file('MyFileClass',self.ready,appeartime,180,5,skipread=False)
            else:
                retval = command.wait_for_a_file('MyFileClass',self.ready,appeartime,readytime,5,skipread=True)
            self.status = retval

        return self.status
#endclass

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Custom formatter
class MyLogFormatter(logging.Formatter):
    '''Working with LOG '''

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
      cfield = '[01;%dm%s[00m' % ( Term_colors[color], str(field) )
      return cfield
    #enddef  cprint

if __name__ == "__main__":
  #
  # Test get job status
  #
  statusmap = { 0: 'COMPLETED', 1: 'PENDING', 2: 'RUNNING', 9: 'UNKNOWN'}

  cmd=baseConfigurator("./",False,False)
  cmd.setuplog('./','runname','runtime',True)

  #a = cmd.wait_for_a_file('get_cycle_bkgfile','abc',600,600,5,skipread=False,expectSize=100)
  #print (a)


  t = datetime.strptime('2020-05-13_23:15:00','%Y-%m-%d_%H:%M:%S')
  t1 = t - timedelta(minutes=15)
  b = f"/scratch/wof/realtime/{t:%Y%m%d}/{t1:%Y%m%d%H%M}/wrffcst_d01_{t:%Y-%m-%d_%H:%M:%S}"

  bs = [f"{b}_{i}" for i in range(1,37)]

  a = cmd.wait_for_files('ABC',bs,10,600,5,skipread=False,expectSize=100)
  print (f"Ready files: {a}")
