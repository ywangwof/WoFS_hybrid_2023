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
##   Yunheng Wang (12/11/2015)
##   Initial version based on early works.
##
##
########################################################################
##
## Requirements:
##
##   o Python 3.6 or above
##
########################################################################

import os
import re
import glob
import shutil
import gzip
#import bz2
#import sys

import subprocess, threading
import time, math
from datetime import datetime, timedelta

import namelist
import prep_okmeso

from configBase import ExtMData, MyFileClass


class NSSLCase(threading.Thread):
    # classbegin
    '''
       This is to initialize a forecast/analysis workflow over one domain at
       a specific time on a specific date. It contains

       __init__  : initialize its instance
       run       : to run this case as a separate thread
       run_xxx   : running step for each program containing in this workflow
    '''

    ####################################################################
    ##
    ## Case intialization
    ##
    ####################################################################

    def __init__(self, caseconf, domainin, cmdconfig, bucket, programin=None):
        '''
           Initialize NSSL 3dvar case
        '''

        self.runcase = caseconf
        self.command = cmdconfig
        self.domain = domainin

        ## directory settings
        self.runDirs = self.runcase.rundirs

        ##
        ##---------------  Run-time arguments for programs --------------##
        ##
        programtorun = self.runcase.programs
        if programin is None:
            self.programs = programtorun
        elif programin in programtorun:
            i = programtorun.index(programin)
            self.programs = programtorun[i:]
        else:
            self.programs = [programin]

        self.runConfig = self.runcase.getRuntimeConfig(
            gridsize=(self.domain.nx, self.domain.ny))

        ##---------------  Observations ---------------------------------##
        ##
        ## Radar names to be analyzed
        self.radars = self.runcase.radars    # initially comes from configuration
        # if empty, will be determined based on domain
        ##---------------- looking for radar within domain --------------
        if len(self.radars) < 1:
            self.radars = [radar.name for radar in self.domain['radars']]

        self.procradars = 0

        ## Observations to be analyzed
        self.obstypes = self.runcase.getCaseObsType()

        self.cmprun = self.runcase.cmprun

        ##
        ##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        ##

        self.mutex = threading.Lock()
        self.kill_received = False
        self.bucket = bucket

        threading.Thread.__init__(self)

        self.name = f'case-{caseconf.caseNo}_{self.domain.id:02d}'
    # enddef

    ####################################################################
    ##
    ## Work flow
    ##
    ####################################################################

    def run(self):
        ''' main workflow '''

        try:
            self.caseDir = self.create_dirs()

            ## do analysis only
            if self.runcase.caseNo == 1:      # Analysis starting with external dataset

                if self.cmprun <= 0:
                    extdat = self.check_link_extm(self.runcase.extsrcs)
                    if extdat is None:
                        self.command.addlog(-1, "cntl.run",
                                            "ERROR: did not find external data source.")

                    if self.domain.isroot and self.check_job('ungrib'):
                        self.run_ungrib(extdat, False)

                    if self.check_job('geogrid'):
                        self.run_geogrid(extdat, True)

                    if self.check_job('metgrid'):
                        self.run_metgrid(extdat, True)

                    if self.check_job('tinterp'):
                        self.run_tinterp(extdat, True)

                    bkgfiles = self.run_real(
                        extdat, wait=False, outmet='tinterp')

                    if self.check_job('wrf'):
                        self.run_wrf(extdat, False)

                else:
                    _nothing, wrkdirs = self.runcase.getwrkdir(
                        self.caseDir, 'real', numens=self.runConfig['real'].numens)
                    bkgfiles = [MyFileClass(os.path.join(wrkdir.replace(
                        self.command.wrkdir, self.runcase.rundirs.cmpdir), 'wrfinput_d01'), True) for wrkdir in wrkdirs]

                validobs = self.check_wait_obs(
                    self.obstypes)  # prepare observation data

                if self.check_job('radremap') and len(validobs['radar']) > 0:
                    self.run_radar_remaps(validobs['radar'], bkgfiles[0])

                self.command.addlog(999, "domains", self.domain)
                ##
                ## run news3dvar
                ##
                anafiles = self.run_news3dvar(validobs, bkgfiles, True)

                ##
                ## Post-processing
                ##
                if self.check_job('nclplt') or self.check_job('unipost'):
                    self.run_post(afiles=anafiles)

                if self.check_job('wrfhybrid'):
                    bkgfile = self.run_wrfhybrid(1, True)

            ## WRF forecast after data analysis
            elif self.runcase.caseNo == 2:    # Forecast starting from an analysis

                if self.cmprun <= 0:   # we may want to run WPS
                    extdat = self.decode_ungribrun()

                    if self.check_job('metgrid'):
                        self.run_metgrid(extdat, True, condition=None)

                    if self.check_job('real'):
                        self.run_real(extdat, wait=True, outmet='metgrid1')
                else:
                    extdat = ExtMData(self.runcase.extsrcs[0], self.runcase.getExtConfig(
                        self.runcase.extsrcs[0]))

                if self.check_job('wrfdaupdate'):
                    self.run_wrfdaupdate(False, wait=True)

                bkgfiles = self.run_wrf(extdat, False)

                if self.check_job('nclplt') or self.check_job('unipost') or self.check_job('nclplt2d'):
                    self.run_post(afiles=[os.path.dirname(
                        bkgfile.name) for bkgfile in bkgfiles])

            ## do analysis and forecast
            elif self.runcase.caseNo == 3:    # Analysis and Forecast based on external dataset

                extdat = self.check_link_extm(self.runcase.extsrcs)
                if extdat is None:
                    self.command.addlog(-1, "cntl.run",
                                        "ERROR: did not find external data source.")

                if self.domain.isroot and self.check_job('ungrib'):
                    self.run_ungrib(extdat, False)

                if self.check_job('geogrid'):
                    self.run_geogrid(extdat, True)

                if self.check_job('metgrid'):
                    self.run_metgrid(extdat, True)

                if self.check_job('tinterp'):
                    self.run_tinterp(extdat, True)  # careful for error

                bkgfiles = self.run_real(extdat, wait=True, outmet='tinterp')

                validobs = self.check_wait_obs(
                    self.obstypes)  # prepare observation data

                if self.check_job('radremap') and len(validobs['radar']) > 0:
                    self.run_radar_remaps(validobs['radar'], bkgfiles[0])

                ##
                ## run news3dvar
                ##
                self.run_news3dvar(validobs, bkgfiles, True)

                if self.check_job('enrelax') and self.runcase.nens is not None:
                    self.run_enrelax(True)

                if self.check_job('wrfdaupdate'):
                    self.run_wrfdaupdate(False, wait=True)

                bkgfiles = self.run_wrf(extdat, False)

                if self.check_job('nclplt') or self.check_job('unipost') or self.check_job('nclplt'):
                    self.run_post(afiles=[os.path.dirname(
                        bkgfile.name) for bkgfile in bkgfiles])

            elif self.runcase.caseNo == 4:    # Analysis starting from early analysis cycle

                if self.runcase.hybrid > 100 and self.runcase.startTime.minute == 0: # we should run WPS
                    extdat = self.check_link_extm(self.runcase.extsrcs)

                    if extdat is None:
                        self.command.addlog(-1, "cntl.run",
                                            "ERROR: did not find external data source.")

                    if self.domain.isroot and self.check_job('ungrib'):
                        self.run_ungrib(extdat, False)

                    if self.check_job('metgrid'):
                        self.run_metgrid(extdat, True)

                    outmet='metgrid3'
                    #else:
                    #    if self.check_job('tinterp'):
                    #        self.run_tinterp(extdat, True)
                    #
                    #    outmet='tinterp'

                    self.run_real(extdat, wait=True, outmet=outmet)

                bkgfiles = self.get_cycle_bkgfile(1)    # WoFS member = 1

                validobs = self.check_wait_obs(
                    self.obstypes)  # prepare observation data

                if self.check_job('radremap') and len(validobs['radar']) > 0:
                    self.run_radar_remaps(validobs['radar'], bkgfiles[0])

                self.command.addlog(999, "domains", self.domain)

                ##
                ## run news3dvar
                ##
                anafiles = self.run_news3dvar(validobs, bkgfiles, True)

                if self.check_job('enrelax') and self.runcase.nens is not None:
                    self.run_enrelax(True)

                ## Post-processing
                ##
                if self.check_job('nclplt') or self.check_job('unipost'):
                    self.run_post(afiles=anafiles)

                if self.check_job('wrfhybrid'):
                    bkgfile = self.run_wrfhybrid(1, True)

            elif self.runcase.caseNo == 5:    # Forecast starting from an early cycle

                if self.cmprun <= 0:   # We may want to run WPS
                    do_preprocess = False
                    use_base      = True
                    if self.domain.cycle_num < 0:
                        use_base = True
                    elif self.domain.cycle_num > 900:
                        do_preprocess = True
                    else:
                        extdat = self.decode_ungribrun()
                        if self.runcase.endTime > extdat.endTime:
                            if self.runcase.hybrid > 100:
                                do_preprocess = False    # because WPS is run in caseNo = 4
                                if os.path.lexists(f"{self.caseDir}/real4"): os.unlink(f"{self.caseDir}/real4")
                                os.symlink(f"{self.caseDir}/real3_0",f"{self.caseDir}/real4")
                                use_base      = False
                            else:
                                do_preprocess = True

                    if do_preprocess:

                        extdat = self.check_link_extm(self.runcase.extsrcs)

                        if extdat is None:
                            self.command.addlog(-1, "cntl.run",
                                                "ERROR: did not find external data source.")

                        if self.domain.isroot and self.check_job('ungrib'):
                            self.run_ungrib(extdat, False)

                        if self.check_job('metgrid'):
                            self.run_metgrid(extdat, True)

                        self.run_real(extdat, wait=True, outmet='metgrid4')

                        if self.check_job('wrfdaupdate'):
                            self.run_wrfdaupdate(False, wait=True)

                    else:
                        if self.check_job('wrfdaupdate'):
                            self.run_wrfdaupdate(use_base, wait=True)
                else:
                    if self.check_job('wrfdaupdate'):
                        self.run_wrfdaupdate(True, wait=True)
                    extdat = ExtMData(self.runcase.extsrcs[0], self.runcase.getExtConfig(
                        self.runcase.extsrcs[0]))

                bkgfiles = self.run_wrf(extdat, True)

                if self.check_job('nclplt') or self.check_job('unipost') or self.check_job('nclplt2d'):
                    self.run_post(afiles=[os.path.dirname(
                        bkgfile.name) for bkgfile in bkgfiles])

            # Forecast lauched after cycles of anlysises
            elif self.runcase.caseNo in (6, 7):

                if self.domain.cycle_num >= 0 and self.cmprun <= 0:  # prepare boundary file

                    extdat = self.check_link_extm(self.runcase.extsrcs)

                    if extdat is None:
                        self.command.addlog(-1, "cntl.run",
                                            "ERROR: did not find external data source.")

                    if self.domain.isroot and self.check_job('ungrib'):
                        self.run_ungrib(extdat, False)

                    if self.check_job('metgrid'):
                        self.run_metgrid(extdat, True)

                    self.run_real(extdat, wait=True, outmet='metgrid5')
                else:
                    extdat = ExtMData(self.runcase.extsrcs[0], self.runcase.getExtConfig(
                        self.runcase.extsrcs[0]))

                if self.check_job('wrfdaupdate'):
                    self.run_wrfdaupdate(False, wait=True)

                bkgfiles = self.run_wrf(extdat, False)
                # self.run_rename(wrfdir=os.path.dirname(bkgfiles[0]))

                if self.check_job('nclplt') or self.check_job('joinwrf') or self.check_job('nclplt2d'):
                    self.run_post(afiles=[os.path.dirname(
                        bkgfile.name) for bkgfile in bkgfiles])

            elif self.runcase.caseNo == 27:    # Hybrid gain with NEWS-e

                if self.check_job('wrfhybrid'):
                    bkgfile = self.run_wrfhybrid(0, True)

                validobs = self.check_wait_obs(
                    self.obstypes)  # prepare observation data

                if self.check_job('radremap') and len(validobs['radar']) > 0:
                    self.run_radar_remaps(validobs['radar'], bkgfiles[0])

                ##
                ## run news3dvar
                ##
                anafiles = self.run_news3dvar(validobs, bkgfile, True)

                if self.check_job('wrfhybrid'):
                    bkgfile = self.run_wrfhybrid(1, True)

                ##
                ## Post-processing
                ##
                if self.check_job('nclplt') or self.check_job('unipost'):
                    self.run_post(afiles=anafiles)

        except Exception as ex:
            self.bucket.put(ex)
            self.kill_received = True

        return 0
    # enddef run

    ################## Post-processing #################################

    def check_job(self, jobname):
        ''' Check whether we should run this job '''

        if self.kill_received:
            return False

        dojob = (jobname in self.programs)
        return dojob
    # enddef check_job

    ################## run_radar_remaps ################################

    def run_radar_remaps(self, radars, bkgfile):
        '''
            call run_radremap one by one or all in different threads

            must block the workflow untill all processing are finished.

            write a ready file at last
        '''
        mpiconfig = self.runConfig['radremap']

        ##------------ Wait for backgrond file ready -----------------

        if not bkgfile.wait_ready(self.command, 3600, 20):   # bkgfile not ready
            self.command.addlog(-1, "run_radar_remaps",
                                f"{bkgfile.ready} not ready in 60 minutes.")

        bkgfile.rename(self.runcase.startTime,
                       self.runcase.ntimesample, self.runcase.timesamin)

	##------------ Run remap for each radar    -----------------

        if mpiconfig.shell:   # run_radremap one by one
            for radar in radars:
                self.run_radremap(radar, bkgfile, True)
        else:

            th88ds = []
            for radar in radars:
                radThread = threading.Thread(target=self.run_radremap,
                                             args=(radar, bkgfile, True))
                radThread.start()
                th88ds.append(radThread)

            for radThread in th88ds:
                radThread.join()

        readyfile = os.path.join(self.caseDir, 'radremap', 'radremap_Ready')
        with open(readyfile, 'w', encoding="utf8") as th88fl:
            th88fl.write(f"Process radars done on {datetime.now():%m-%d %H:%M:%s}.")

    # enddef run_radar_remaps

    ################## Post-processing #################################

    def run_rename(self, wrfdir, outime=None):
        '''
           Rename WRF outputs
        '''

        if self.command.showonly:
            return

        if outime is None:
            outname = 'wrfvar'
            if self.runcase.hybrid > 0:
                outname = "wrfhyb"

            endsecs = self.runcase.fcstSeconds
            outputintvl = 5*60

            # ------------- Loop over all files -------------------------------

            #errfile = os.path.join(wrfdir,"rsl.error.0000")
            #errset  = False
            for itime in range(0, endsecs+outputintvl, outputintvl):
                currtime = self.runcase.startTime + timedelta(seconds=itime)
                outfile = f'{outname}_d01_{currtime:%Y-%m-%d_%H_%M_%S}'
                expfile = f'{outname}_d01_{currtime:%Y-%m-%d_%H:%M:%S}'

                wrfoutfile = os.path.join(wrfdir, outfile)
                wrfexpfile = os.path.join(wrfdir, expfile)

                if not self.command.wait_for_a_file('Rename', wrfoutfile, 1200, 600, 5, skipread=False):
                    return

                os.rename(wrfoutfile, wrfexpfile)

                # cmds = [f"/opt/cray/pe/netcdf/4.6.3.2/bin/nccopy -7 -d 8 {wrfoutfile} {wrfexpfile}",
                #        f"rm -f {wrfoutfile}"]
                #p = subprocess.Popen('/bin/bash', stdin=subprocess.PIPE,stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                # for cmd in cmds:
                #    self.command.addlog(0,"RENAME",f"Command: {cmd}")
                #    p.stdin.write(f"{cmd}\n".encode())
                # p.stdin.close()
        else:
            outname = 'wrfout'

            # ------------- rename file at a specific time ----------------

            outfile = f'{outname}_d01_{outime:%Y-%m-%d_%H_%M_%S}'
            expfile = f'{outname}_d01_{outime:%Y-%m-%d_%H:%M:%S}'

            wrfoutfile = os.path.join(wrfdir, outfile)
            wrfexpfile = os.path.join(wrfdir, expfile)

            # if not self.command.wait_for_a_file('Rename',wrfoutfile,1200,600,5,skipread=False):
            #    return False

            os.rename(wrfoutfile, wrfexpfile)

    # enddef run_rename

    ################## Post-processing #################################

    def run_post(self, afiles):
        '''
           run post processing as requested
        '''

        # ------------- Wait for file ready --------------------------------
        afile = afiles[0]

        if afile is not None:
            if os.path.isfile(afile):     # afile is passed-in

                if self.check_job('nclplt'):
                    self.run_nclplt(afiles, self.runcase.startTime, False)

                if self.check_job('unipost'):
                    self.run_unipost(afile, 0, False)

                # ##
                # ## extract soundings
                # ##
                # if self.check_job('wrfextsnd') and rematch:
                #     self.run_wrfextsnd(anafile,False)

            elif os.path.isdir(afile):        # WRF forecasting

                endsecs = self.runcase.fcstSeconds
                #outputintvl = self.runcase.fcstOutput
                outputintvl = 600

                for itime in range(0, endsecs+outputintvl, outputintvl):
                    currtime = self.runcase.startTime + \
                        timedelta(seconds=itime)

                    if self.kill_received:
                        break

                    if self.check_job('joinwrf'):
                        self.run_joinwrf(currtime, False)

                    # if self.check_job('nclplt'):
                    #    outfiles = [os.path.join(wrfdir,'wrfout_d01_%s'%(currtime.strftime('%Y-%m-%d_%H:%M:%S'))) for wrfdir in afiles]
                    #    self.run_nclplt(outfiles,currtime,False)

                    #wrfmin = itime//60
                    # if self.check_job('unipost'):
                    #    self.run_unipost(outfile,wrfmin,False)
                    #
                    # if self.check_job('nclplt2d'):
                    #    if itime == 0:
                    #        out2dfile = os.path.join(wrfdir,
                    #                  'wrfo2d_d01_%s'%(currtime.strftime('%Y-%m-%d_%H:%M:%S')))
                    #        self.run_nclplt(afile=outfile,atime=currtime,wait=False,
                    #                        bfile=out2dfile,pltfields=['vor2d','ref2d'] )
                    #    else:
                    #        kstime = itime-outputintvl+300
                    #        ketime = itime + 300
                    #        for jtime in range(kstime,ketime,300):
                    #            time2d = self.runcase.startTime + timedelta(seconds=jtime)
                    #            out2dfile = os.path.join(wrfdir,
                    #                      'wrfo2d_d01_%s'%(time2d.strftime('%Y-%m-%d_%H:%M:%S')))
                    #            self.run_nclplt(afile=outfile,atime=time2d,wait=False,
                    #                            bfile=out2dfile,pltfields=['vor2d','ref2d'] )

    # enddef run_post

    ####################################################################
    ##
    ## Internal fucntions
    ##
    ####################################################################

    ####----------------------- case directory -----------------------##
    def create_dirs(self):

        wrkdatedir, wrktimedir, wrkdomndir = self.runcase.getCaseDir(
            self.domain.id, rootdir=self.command.wrkdir)

        while not os.path.lexists(wrkdatedir) and self.domain.isroot:        # date
            self.command.addlog(0, "cntl.dir", f"Making case dir <{wrkdatedir}>.")
            try:
                os.mkdir(wrkdatedir)
            except Exception:
                time.sleep(2)

        while not os.path.lexists(wrktimedir) and self.domain.isroot:        # time
            self.command.addlog(0, "cntl.dir", f"Making case time dir <{wrktimedir}>.")
            try:
                os.mkdir(wrktimedir)
            except Exception:
                time.sleep(2)

        while not os.path.lexists(wrkdomndir):      # domain no
            self.command.addlog(0, "cntl.dir", f"Making domain dir <{wrkdomndir}>.")
            try:
                os.mkdir(wrkdomndir)
            except Exception:
                time.sleep(2)

        return wrkdomndir

    ####--------------------- get_cycle_bkgfile ----------------------##

    def get_cycle_bkgfile(self, dartmbr=4):
        '''
        Find early forecast to use as background for this case.
        It is used for cycling anlysis.
        '''

        timestr = self.runcase.startTime.strftime('%Y-%m-%d_%H:%M:%S')

        if self.domain.cycle_num == -1:  # hybrid variance runs
            bkgdir  = os.path.join(self.runDirs['dartdir'], 'WRFOUT')
            bkgfile = os.path.join(bkgdir, f'wrffcst_d01_{timestr}_{dartmbr}')
            if self.command.wait_for_a_file('get_cycle_bkgfile', bkgfile, None, 600, 5, skipread=False):
                return bkgfile
            self.command.addlog(-1, 'cntl.cycle_bkgfile',
                                f'Time out for {bkgfile}.')

        if self.domain.cycle_num == 1:  # based on dom0x, special for the first cycle of runCase 4
            earlydomid = self.domain.id % 10
            earlyTime = self.runcase.eventDate
        elif self.domain.cycle_num == 901:  # based on dom1x, Ensemble spin-up specific
            earlydomid = self.domain.id % 10+10
            earlyTime = self.runcase.eventDate
        else:
            earlydomid = self.domain.id
            earlyTime = self.runcase.startTime - \
                timedelta(seconds=self.runcase.cyclelength)

        _nothing1, _nothing2, earlydomdir = self.runcase.getCaseDir(
            earlydomid, runtime=earlyTime, rootdir=self.command.wrkdir)

        wrfdirs = ('wrf4', 'wrf1', 'wrf2', 'wrf5')
        if self.runcase.nens is not None:
            numens = self.runcase.nens+1
            wrfdirs = [f"{wrfdir}_0" for wrfdir in wrfdirs]
        else:
            numens = 1

        #
        # Wait for WRF directory from early forecast cycle
        #
        maxwaittime = 10800
        waittime = 0
        foundtmpl = False
        while waittime < maxwaittime:
            for wrfdir in wrfdirs:
                earlydir = os.path.join(earlydomdir, wrfdir)

                self.command.addlog(0, 'cntl.cycle_bkgfile', f'Checking WRF directory <{earlydir}>.')
                if os.path.lexists(earlydir):
                    foundtmpl = True
                    break

            if foundtmpl:
                self.command.addlog(0, 'cntl.cycle_bkgfile', f'Use WRF directory <{earlydir}> for cycled analysis background.')
                break

            waittime += 10
            time.sleep(10)
        else:
            self.command.addlog(-1, "cntl.cycle_bkgfile",
                                f"Early cycle dir <{earlydir}> do not exist.")

        memdirs = [re.sub(r"_\d{1,3}$", f"_{iens}", earlydir) for iens in range(0, numens)]
        bkgfiles = [MyFileClass(os.path.join(
            memdir, f'wrfout_d01_{timestr}'), False) for memdir in memdirs]

        if (datetime.utcnow()-self.runcase.startTime) < timedelta(minutes=5):
            # wait for the file to be ready before continue if workflow time is nearly realtime
            bkgreadys = [bkgfile.ready for bkgfile in bkgfiles]

            self.command.addlog(0, "cntl.cycle_bkgfile",
                                f"Waiting for {bkgreadys} etc. ...")
            if self.command.wait_for_files('get_cycle_bkgfile', bkgreadys, None, 600, 5, skipread=True) < len(bkgfiles):
                self.command.addlog(-1, "cntl.cycle_bkgfile",
                                    f"Timeout for <{bkgreadys[0]}>.")

            for bkgfile in bkgfiles:
                bkgfile.status = True

        return bkgfiles

    ####----------------------- decode early ungrib run --------------##

    def decode_ungribrun(self):
        '''
           Should be called only by runcase = 2 & 5

           only decode control member (0)
        '''

        if self.runcase.caseNo == 5:
            ungrib_base = self.domain.cycle_base
        else:
            ungrib_base = os.path.dirname(self.caseDir)

        ensaffix = ""
        if self.runConfig.ungrib.numens is not None or self.runcase.hybrid > 100.:
            ensaffix = "_0"

        maxwaittime = 10800
        waittime = 0
        foundungrib = False
        while waittime < maxwaittime:
            for ungrbdir in ('ungrib2', 'ungrib4', 'ungrib5', 'ungrib0', 'ungrib3'):
                ungrib_path = os.path.join( ungrib_base, f"{ungrbdir}{ensaffix}")
                self.command.addlog(
                    0, 'cntl.decode_ungrb', 'Checking ungrib directory <%s>.' % (ungrib_path))
                if os.path.lexists(ungrib_path):
                    foundungrib = True
                    break
            if foundungrib:
                self.command.addlog(
                    0, 'cntl.decode_ungrb', 'Use ungrib date from directory <%s>.' % (ungrib_path))
                break
            waittime += 10
            time.sleep(10)

        # if not os.path.lexists(ungrib_path):
        if not self.command.wait_for_a_file('decode_ungribrun', ungrib_path, None, 600, 5, skipread=True):
            self.command.addlog(-1, 'cntl.decode_ungrb', f'Cannot find ungrib path <{ungrib_path}>.')

        namelist_file = os.path.join(ungrib_path, 'namelist.wps')

        self.command.addlog(999, "cntl.decode_ungrb",
                            f'<decode_ungribrun> waiting for {namelist_file} ...')
        self.command.wait_for_a_file(
            'decode_ungribrun', namelist_file, None, 600, 5, skipread=True)

        nmlgrp = namelist.decode_namelist_file(namelist_file)

        extdname = nmlgrp['ungrib'].prefix
        extconf = self.runcase.getExtConfig(extdname)
        extdat = ExtMData(extdname, extconf)

        extdat['startTime'] = datetime.strptime(
            (nmlgrp['share'].start_date)[0], '%Y-%m-%d_%H:%M:%S')
        extdat['endTime'] = datetime.strptime(
            (nmlgrp['share'].end_date)[0],  '%Y-%m-%d_%H:%M:%S')
        extdat['ungrib_path'] = ungrib_path

        return extdat
    # enddef decode_ungribrun

    ##========================== UNGRIB   ==============================

    def run_ungrib(self, extsrc, wait):
        ''' run ungrib.exe
        wait : whether to wait for the job to be finished
        '''

        tmplinput = self.runcase.getNamelistTemplate('ungrib')
        mpiconfig = self.runConfig['ungrib']

        if mpiconfig.mpi:
            executable = os.path.join(
                self.runDirs.wpsdir, 'ungrib', 'ungribp.exe')
        else:
            executable = os.path.join(
                self.runDirs.wpsdir, 'ungrib', 'ungrib.exe')

        wrkbas, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, "ungrib", numens=mpiconfig.numens)
        # os.path.join(os.path.dirname(self.caseDir),'ungrib%d'%(self.runcase.caseNo-1))

        nmlfiles = []
        for wrkdir in wrkdirs:
            if not os.path.lexists(wrkdir):
                os.mkdir(wrkdir)

            nmlfiles.append(os.path.join(wrkdir, 'namelist.wps'))

        ##-------------- make namelist file -------------------------------

        inittimestr = extsrc.startTime.strftime('%Y-%m-%d_%H:%M:%S')
        endtimestr = extsrc.endTime.strftime('%Y-%m-%d_%H:%M:%S')

        nmlin = {'start_date': [inittimestr, inittimestr],
                 'end_date': [endtimestr, endtimestr],
                 'interval_seconds': extsrc.hourIntvl*3600,
                 'prefix': extsrc.extapp
                 }

        nmlgrp = namelist.decode_namelist_file(tmplinput)
        nmlgrp.merge(nmlin)
        for nmlfile in nmlfiles:
            nmlgrp.writeToFile(nmlfile)
            # print "write to %s ..." % nmlfile

        ##----------- run the program from command line ----------------
        hhmmstr = self.runcase.startTime.strftime('%H%M')
        outfile = 'ungrb%d_%s.output' % (self.runcase.caseNo, hhmmstr)
        jobid = self.command.run_a_program(
            executable, None, outfile, wrkbas, mpiconfig)

        # -------------- wait for it to be done -------------------
        if not self.command.wait_job('ungrib', jobid, wait):
            self.command.addlog(-1, "UNGRIB", f'job failed: {jobid}')
            #raise SystemExit()

        return 0
    # enddef run_ungrib

    # ========================= GEOGRID  ===============================

    def run_geogrid(self, extsrc, wait):
        ''' run geogrid.exe '''

        executable = os.path.join(
            self.runDirs.wpsdir, 'geogrid', 'geogrid.exe')
        tmplinput = self.runcase.getNamelistTemplate('geogrid')

        mpiconfig = self.runConfig['geogrid']

        _wrkbas, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, 'geogrid', False, mpiconfig.numens)
        # os.path.join(self.caseDir,'geogrid')

        wrkdir = wrkdirs[0]
        if not os.path.lexists(wrkdir):
            os.mkdir(wrkdir)

        nmlfile = os.path.join(wrkdir, 'namelist.wps')

        # ---------------------- copy working files ------------------------

        geotbl = os.path.join(wrkdir, 'GEOGRID.TBL')
        if not os.path.lexists(geotbl):
            absfl = os.path.join(self.runDirs.wpsdir,
                                 'geogrid', 'GEOGRID.TBL.ARW')
            self.command.copyfile(absfl, geotbl, hardcopy=False)

        # -------------- make namelist file --------------------------------

        inittimestr = extsrc.startTime.strftime('%Y-%m-%d_%H:%M:%S')
        endtimestr = extsrc.endTime.strftime('%Y-%m-%d_%H:%M:%S')

        nmlin = {'start_date': [inittimestr, inittimestr],
                 'end_date': [endtimestr, endtimestr],
                 'interval_seconds': extsrc.hourIntvl*3600,
                 'opt_metgrid_tbl_path': './',
                 'opt_output_from_geogrid_path': './',
                 'e_we': self.domain.nx,
                 'e_sn': self.domain.ny,
                 'dx': self.domain.dx,
                 'dy': self.domain.dy,
                 'ref_lat': self.domain.ctrlat,
                 'ref_lon': self.domain.ctrlon,
                 'map_proj': self.domain.map_proj,
                 'truelat1': self.domain.truelat1,
                 'truelat2': self.domain.truelat2,
                 'stand_lon': self.domain.standlon,
                 'opt_geogrid_tbl_path': './',
                 }

        nmlgrp = namelist.decode_namelist_file(tmplinput)
        nmlgrp.merge(nmlin)
        nmlgrp.writeToFile(nmlfile)

        # ------------ run the program from command line -------------------
        outfile = 'geo%02d.output' % self.domain.id
        jobid = self.command.run_a_program(
            executable, None, outfile, wrkdir, mpiconfig)

        # -------------- wait for it to be done -------------------
        if not self.command.wait_job('geogrid', jobid, wait):
            self.command.addlog(-1, "GEOGRID", f'job failed: {jobid}')
            #raise SystemExit()

    # enddef run_geogrid

    # ========================= METGRID  ===============================

    def run_metgrid(self, extsrc, wait, condition=None):
        ''' run metgrid.exe '''

        executable = os.path.join(
            self.runDirs.wpsdir, 'metgrid', 'metgrid.exe')
        tmplinput = self.runcase.getNamelistTemplate('metgrid')

        mpiconfig = self.runConfig.metgrid

        wrkbas, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, 'metgrid', numens=mpiconfig.numens)

        nmlfiles = []
        for wrkdir in wrkdirs:
            if not os.path.lexists(wrkdir):
                os.mkdir(wrkdir)

            nmlfiles.append(os.path.join(wrkdir, 'namelist.wps'))

        # ---------------------- copy working files -----------------------

            mettbl = os.path.join(wrkdir, 'METGRID.TBL')
            if not os.path.lexists(mettbl):
                absfl = os.path.join(
                    self.runDirs.wpsdir, 'metgrid', 'METGRID.TBL.ARW.%s' % extsrc.extapp)
                self.command.copyfile(absfl, mettbl, hardcopy=False)

        # ------------------- wait for GEOGRID files ---------------------
        #
        # Alex specific with spin-up option, domain.id = 10
        #domainid = 10
        domainid = 0
        #
        # get event domain dir
        _nothing1, _nothing2, wrkdomndir = self.runcase.getCaseDir(
            domainid, runtime=self.runcase.eventDate, rootdir=self.command.wrkdir)
        geogrid_path, _nothing = self.runcase.getwrkdir(
            wrkdomndir, 'geogrid', False)

        geonmlfl = os.path.join(geogrid_path, 'namelist.wps')
        self.command.wait_for_a_file('run_metgrid', geonmlfl, None, 600, 5)
        nmlgrp = namelist.decode_namelist_file(geonmlfl)
        io_form_geogrid = nmlgrp['share'].io_form_geogrid
        if io_form_geogrid > 100 and mpiconfig.mpi:
            geofls = []
            for i in range(mpiconfig.ntotal):
                geofl1 = os.path.join(geogrid_path, 'geo_em.d01.nc_%04d' % i)
                geofls.append(geofl1)
        else:
            geofl1 = os.path.join(geogrid_path, 'geo_em.d01.nc')
            geofls = [geofl1]

        # ------------------- Wait for ungrib ready ----------------------

        fgname = extsrc.extapp

        if self.runcase.hybrid > 100 and extsrc.has_key("ungrib_path"):
            ungrib_paths = [extsrc.ungrib_path]
        else:
            ungrbconfig = self.runConfig.ungrib
            if self.runcase.caseNo == 2:
                _nothing, ungrib_paths = self.runcase.getwrkdir(
                    self.caseDir, 'ungrib0', False, numens=ungrbconfig.numens)
            else:
                _nothing, ungrib_paths = self.runcase.getwrkdir(
                    self.caseDir, 'ungrib', numens=ungrbconfig.numens)

        if self.runcase.caseNo == 1:
            endtime = extsrc.startTime + timedelta(hours=extsrc.hourIntvl)
        else:
            endtime = extsrc.endTime

        currtime = extsrc.startTime
        while currtime <= endtime:
            ungribfile = f'{fgname}:{currtime:%Y-%m-%d_%H}'
            ungribfiles = [os.path.join(ungrib_path, ungribfile)
                           for ungrib_path in ungrib_paths]

            self.command.addlog(
                999, "cntl.met", f"Waiting for {ungribfile} ...")

            if self.command.wait_for_files('run_metgrid', ungribfiles, None, 600, 5) == len(ungribfiles):
                for srcfl, wrkdir in zip(ungribfiles, wrkdirs):
                    relfl = os.path.join(wrkdir, ungribfile)
                    if os.path.lexists(relfl):  os.unlink(relfl)
                    os.symlink(srcfl, relfl)
            else:
                self.command.addlog(-2, "cntl.met",
                                    f'File "{ungribfile}" is missed')

            currtime = currtime + timedelta(hours=extsrc.hourIntvl)

        # --------------- make sure condition file is availabe ------------

        if condition is not None:
            self.command.addlog(
                999, "cntl.met", f"<run_metgrid> waiting for {condition} ...")
            self.command.wait_for_a_file(
                'run_metgrid', condition, None, 300, 10, skipread=True)

        # -------------- make namelist file --------------------------------

        inittimestr = extsrc.startTime.strftime('%Y-%m-%d_%H:%M:%S')
        endtimestr = endtime.strftime('%Y-%m-%d_%H:%M:%S')

        nmlin = {'start_date': inittimestr,
                 'end_date': endtimestr,
                 'interval_seconds': extsrc.hourIntvl*3600,
                 'opt_metgrid_tbl_path': './',
                 'opt_output_from_geogrid_path': geogrid_path,
                 'opt_output_from_metgrid_path': './',
                 'fg_name': [fgname]
                 }

        nmlgrp = namelist.decode_namelist_file(tmplinput)
        nmlgrp.merge(nmlin)
        for nmlfile in nmlfiles:
            nmlgrp.writeToFile(nmlfile)

        # ------------ run the program from command line ------------------
        hhmmstr = self.runcase.startTime.strftime('%H%M')
        outfile = 'met%d_%s.output' % (self.runcase.caseNo, hhmmstr)
        jobid = self.command.run_a_program(
            executable, None, outfile, wrkbas, mpiconfig)

        # -------------- wait for it to be done -------------------
        if not self.command.wait_job('metgrid', jobid, wait):
            self.command.addlog(-1, "METGRID", f'job failed: {jobid}')
            #raise SystemExit()

    # enddef run_metgrid

    # ========================= TINTERP ================================

    def run_tinterp(self, extsrc, wait):
        '''
          Run or submit TINTERP job from METGRID outputs

          NOTE: works with runCase 1 only. Support the forecast length is 5
                minutes and the starting time in 5-minute intervals.
        '''

        executable = os.path.join(self.runDirs.vardir, 'bin', 'tinterp')
        tmplinput = self.runcase.getNamelistTemplate('tinterp')

        mpiconfig = self.runConfig.tinterp
        if mpiconfig.mpi:
            executable += '_mpi'

        wrkbas, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, 'tinterp', False, mpiconfig.numens)
        for wrkdir in wrkdirs:
            # os.path.join(self.caseDir,'tinterp')
            if not os.path.lexists(wrkdir):
                os.mkdir(wrkdir)

        # ---------------- loop all external files ------------------------

        # Datetime objects of external two continous data files
        extTime1 = extsrc.startTime
        extTime2 = extsrc.startTime + timedelta(hours=extsrc.hourIntvl)

        file1 = 'met_em.d01.%s.nc' % extTime1.strftime('%Y-%m-%d_%H:%M:%S')
        file2 = 'met_em.d01.%s.nc' % extTime2.strftime('%Y-%m-%d_%H:%M:%S')

        # Expected datatime objects for this analysis/forecast

        expTime1 = self.runcase.startTime
        expTime2 = self.runcase.startTime + \
            timedelta(seconds=self.runcase.fcstSeconds)

        skiptinterp = (extTime1 == expTime1 and extTime2 == expTime2)
        # No time interpolation is ncessary, just link the original metgrid files

        #
        # NOTE: works with runCase 1 only. Support the forecast length is
        #      within [self.extmInitTime,+self.runcase.getCaseExtHours(extsrc,1)]
        #

        # Target domain time interval in seconds
        nouttime = 2
        outsecd1 = (expTime1 - extTime1).total_seconds()
        outsecd2 = (expTime2 - extTime1).total_seconds()
        outtime = [outsecd1, outsecd2]

        if extsrc.extapp.startswith('NAM') or extsrc.extapp in ('GFS', 'GEFS'):
            varlist = ['PRES', 'SM', 'ST', 'RH', 'VV', 'UU', 'TT',
                       'SM100200', 'SM040100', 'SM010040', 'SM000010',
                       'ST100200', 'ST040100', 'ST010040', 'ST000010',
                       'SKINTEMP', 'PSFC', 'SNOALB', 'SOILTEMP']
        elif extsrc.extapp.startswith('RAP'):
            # varlist  = ['PRES','RH','VV','UU','TT', 'SOILT','SOILM',
            #           'SOILM300','SOILM160','SOILM100','SOILM060','SOILM030',
            #           'SOILM010','SOILM004','SOILM001','SOILM000',
            #           'SOILT300','SOILT160','SOILT100','SOILT060','SOILT030',
            #           'SOILT010','SOILT004','SOILT001','SOILT000',
            #           'SKINTEMP','PSFC','SNOALB','SOILTEMP']
            varlist = ['PRES', 'RH', 'VV', 'UU', 'TT', 'SOILT', 'SOILM',
                       'SOILM300', 'SOILM160',
                       'SOILT300', 'SOILT160',
                       'SKINTEMP', 'PSFC', 'SNOALB', 'SOILTEMP']
        elif extsrc.extapp.startswith('HRRR'):
            # varlist  = ['PRES','RH','VV','UU','TT', 'SOILT','SOILM',
            #           'SOILM300','SOILM160','SOILM100','SOILM060','SOILM030',
            #           'SOILM010','SOILM004','SOILM001','SOILM000',
            #           'SOILT300','SOILT160','SOILT100','SOILT060','SOILT030',
            #           'SOILT010','SOILT004','SOILT001','SOILT000',
            #           'SKINTEMP','PSFC','SNOALB','SOILTEMP']
            varlist = ['PRES', 'PRESSURE', 'RH', 'VV', 'UU', 'TT', 'QG','QS','QR','QI','QC',
                       'GHT','SOILHGT','SOILT', 'SOILM',
                       'SOILM000', 'SOILM001', 'SOILM004', 'SOILM010', 'SOILM030',
                       'SOILM060', 'SOILM100', 'SOILM160', 'SOILM300',
                       'SOILT000', 'SOILT001', 'SOILT004', 'SOILT010', 'SOILT030',
                       'SOILT060', 'SOILT100', 'SOILT160', 'SOILM300',
                       'SKINTEMP', 'PSFC', 'PMSL', 'SNOALB', 'SOILTEMP','SNOWH','SNOW']

        metconfig = self.runConfig.metgrid
        if self.runcase.hybrid > 100 and self.runcase.caseNo == 4:
            if self.runcase.startTime.hour == self.runcase.wofstarthour:
                metdirs = [os.path.join(self.domain['cycle_base'], 'dom00',f'metgrid0_{n}') for n in range(0,metconfig.numens+1)]
            else:
                _nothing, metdirs = self.runcase.getwrkdir(
                f"{self.domain['cycle_base']}/dom20", 'metgrid', numens=metconfig.numens)

        else:
            _nothing, metdirs = self.runcase.getwrkdir(
                self.caseDir, 'metgrid', numens=metconfig.numens)

        nmlgrp = namelist.decode_namelist_file(tmplinput)
        nmlfile = 'ttrp-%02d.input' % self.domain.id

        for iens, wrkdir in enumerate(wrkdirs):

            absfile1 = os.path.join(metdirs[iens], file1)
            absfile2 = os.path.join(metdirs[iens], file2)
            absnmlfile = os.path.join(wrkdir, nmlfile)

            nmlin = {'hisfile':  [absfile1, absfile2],
                     'hisfmt':  1,
                     'nvarlist': len(varlist),
                     'varlist': varlist,
                     'outdir':  './',
                     'outfmt':  202,
                     'nouttime':  nouttime,
                     'outtime':  outtime,
                     'nproc_x':  mpiconfig.nproc_x,
                     'nproc_y':  mpiconfig.nproc_y,
                     }
            nmlgrp.merge(nmlin)
            nmlgrp.writeToFile(absnmlfile)
            if skiptinterp:  # Do not run tinterp, but just link the original metgrid files
                relfl1 = os.path.join(wrkdir, file1)
                relfl2 = os.path.join(wrkdir, file2)
                self.command.copyfile(absfile1, relfl1, hardcopy=False)
                self.command.copyfile(absfile1, relfl2, hardcopy=False)

        # -------------- run the program --------------------------
        if not skiptinterp:
            hhmmstr = self.runcase.startTime.strftime('%H%M')
            outfile = 'ttrp%d_%s.output' % (self.runcase.caseNo, hhmmstr)

            jobid = self.command.run_a_program(
                executable, nmlfile, outfile, wrkbas, mpiconfig)

        # -------------- wait for it to be done -------------------

            if not self.command.wait_job('tinterp', jobid, wait):
                self.command.addlog(-1, "TINTERP", f'job failed: {jobid}')
                #raise SystemExit()

    # enddef run_tinterp

    # ========================= REAL.exe ===============================

    def run_real(self, extsrc, wait, outmet='outmet', condition=None):
        '''
          Run or submit real.exe job
        '''

        executable = os.path.join(self.runDirs.wrfdir, 'main', 'real.exe')

        mpiconfig = self.runConfig['real']

        wrkbas, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, 'real', numens=mpiconfig.numens)

        nmlfiles = []
        for wrkdir in wrkdirs:
            if not os.path.lexists(wrkdir):
                os.mkdir(wrkdir)

            # clean rsl.*
            #subprocess.call('rm -rf rsl.*',shell=True,cwd=wrkdir)

            nmlfiles.append(os.path.join(wrkdir, 'namelist.input'))

        # ---------------------- copy working files ------------------------

        if mpiconfig.numens is None:
            metdirs = [os.path.join(self.caseDir, outmet)]
        else:
            metdirs = [os.path.join(self.caseDir, "%s_%d" % (outmet, iens))
                       for iens in range(0, mpiconfig.numens+1)]

        if self.runcase.caseNo in (1, 3) or (self.runcase.caseNo == 4 and  self.runcase.startTime.minute > 0):
            realstart = self.runcase.startTime
            realend = self.runcase.endTime
            extint = self.runcase.fcstSeconds
        else:
            realstart = extsrc.startTime
            realend = extsrc.endTime
            extint = extsrc.hourIntvl*3600

        fcstlength = realend-realstart

        for metdir, wrkdir in zip(metdirs, wrkdirs):
            ftime = realstart
            while ftime <= realend:
                fl = f'met_em.d01.{ftime:%Y-%m-%d_%H:%M:%S}.nc'

                basfl = os.path.join(metdir, fl)
                #li = basfl.rsplit('met_em.d')
                #readyfl = 'met_emReady.d'.join(li)
                # if self.command.wait_for_a_file('run_real',readyfl,1800,300,10,skipread=True):
                for absfl in glob.iglob('%s*' % basfl):
                    relfl = os.path.join(wrkdir, os.path.basename(absfl))
                    if not os.path.lexists(relfl):
                        self.command.copyfile(absfl, relfl, hardcopy=False)

                ftime = ftime+timedelta(seconds=extint)

        # --------------- make sure condition file is availabe ------------

        if condition is not None:
            # print "waiting for %s ..." %(condition)
            self.command.wait_for_a_file(
                'run_real', condition, None, 300, 10, skipread=True)

        # ---------------- make namelist file ----------------------------

        runday = fcstlength.days
        (runhr, runmn) = divmod(fcstlength.seconds, 3600)
        (runmn, runsc) = divmod(runmn, 60)

        nmlin = {'run_days':  runday,
                 'run_hours':  runhr,
                 'run_minutes':  runmn,
                 'run_seconds':  runsc,
                 'start_year':  realstart.year,
                 'start_month':  realstart.month,
                 'start_day':  realstart.day,
                 'start_hour':  realstart.hour,
                 'start_minute':  realstart.minute,
                 'start_second':  realstart.second,
                 'end_year':  realend.year,
                 'end_month':  realend.month,
                 'end_day':  realend.day,
                 'end_hour':  realend.hour,
                 'end_minute':  realend.minute,
                 'end_second':  realend.second,
                 'nproc_x':  mpiconfig.nproc_x,
                 'nproc_y':  mpiconfig.nproc_y,
                 'interval_seconds':  extint,
                 'auxinput1_inname':  'met_em.d<domain>.<date>',
                 'num_metgrid_levels': extsrc.nz,
                 'num_metgrid_soil_levels': extsrc.nzsoil,
                 'e_we':  self.domain.nx,
                 'e_sn':  self.domain.ny,
                 'dx':  self.domain.dx,
                 'dy':  self.domain.dy,
                 }
        iens = 0
        for nmlfile in nmlfiles:
            tmplinput = self.runcase.getNamelistTemplate(
                'real', mpiconfig.numens if mpiconfig.numens is None else iens)
            nmlgrp = namelist.decode_namelist_file(tmplinput)

            if extsrc.extname == 'HRRR':
                nmlin["p_top_requested"] = 5000
            elif extsrc.extname in ('HRRRX', 'HRRRE'):
                nmlin["p_top_requested"] = 2000

            nmlgrp.merge(nmlin)
            nmlgrp.writeToFile(nmlfile)
            iens += 1

        # -------------- run the program --------------------------

        hhmmstr = self.runcase.startTime.strftime('%H%M')
        outfile = 'real%d_%s.output' % (self.runcase.caseNo, hhmmstr)

        if self.check_job('real'):
            jobid = self.command.run_a_program(
                executable, None, outfile, wrkbas, mpiconfig)

            # -------------- wait for it to be done -------------------
            # print 'checking real with ', status,jobid,wait
            if not self.command.wait_job('real', jobid, wait):
                self.command.addlog(-1, "REAL", f'job failed: {jobid}')
                #raise SystemExit()

        # -------------- Pack output file for analysis background ---------

        wrfinputfs = [MyFileClass(os.path.join(
            wrkdir, 'wrfinput_d01'), False) for wrkdir in wrkdirs]

        return wrfinputfs
    # enddef run_real

    # %%%%%%%%%%%%%%%%%  Link 9 km real from early run  %%%%%%%%%%%%%%%%

    def link_wait_real(self, wrfdir, iens):
        '''find valid real output from an early run'''

        ##
        # --------------------- find a valid real run ----------------

        if self.command.showonly:
            return True

        realconfig = self.runConfig.real
        _nothing, realdirs = self.runcase.getwrkdir(
            self.caseDir, 'real', numens=realconfig.numens)
        # os.path.join(self.caseDir,'real%d'%(self.runcase.caseNo-1))

        realdir = realdirs[iens]
        if not os.path.lexists(realdir):
            self.command.addlog(-1, "LINK",
                                f'Directory {realdir} does not exist!')
            #raise SystemExit()

        maxwaitime = 30*60
        waitime = 0
        realdone = False
        while not realdone and waitime < maxwaitime:
            self.command.addlog(
                0, "cntl.wreal", 'Waiting for real rsl.error.0000. \n')
            filename = os.path.join(realdir, 'rsl.error.0000')
            if os.path.lexists(filename):
                fh = open(filename, 'r')
                for line in fh:
                    if line.find('real_em: SUCCESS COMPLETE REAL_EM INIT') >= 0:
                        realdone = True
                        break
            time.sleep(10)
            waitime += 10

        if waitime >= maxwaitime:
            self.command.addlog(-1, "cntl.wreal",
                                'Waiting for real (rsl.out.0000 in %s) excceeded %d seconds.\n' % (
                                    realdir, waitime))

        # --------------------- Link wrfinput and wrfbdy  ----------------

        # if self.runcase.maxdom == 2  :
        ##  realfiles = ['wrfinput_d01','wrfinput_d02','wrfbdy_d01']
        # else :
        realfiles = ['wrfinput_d01', 'wrfbdy_d01']

        for fl in realfiles:
            relfl = os.path.join(wrfdir, fl)
            if not os.path.lexists(relfl):
                absfl = os.path.join(realdir, fl)
                os.symlink(absfl, relfl)

        return True
    # enddef link_wait_real

    # ========================= WRF.exe ================================

    def run_wrf(self, extsrc, wait):
        '''
          Run or submit wrf.exe job
        '''

        executable = os.path.join(self.runDirs.wrfdir, 'main', 'wrf.exe')

        mpiconfig = self.runConfig['wrf']

        # ---------------- make preparation for a WRF run -----------------

        # runfiles = ['CAM_ABS_DATA',    'RRTM_DATA', 'ETAMPNEW_DATA.expanded_rain',
        #            'CAM_AEROPT_DATA', 'RRTM_DATA_DBL', 'URBPARM.TBL',
        #            'co2_trans',       'RRTMG_LW_DATA', 'VEGPARM.TBL',
        #            'ETAMPNEW_DATA',   'RRTMG_LW_DATA_DBL', 'ETAMPNEW_DATA_DBL',
        #            'ozone.formatted', 'RRTMG_SW_DATA',     'GENPARM.TBL',
        #            'ozone_lat.formatted',  'RRTMG_SW_DATA_DBL',  'grib2map.tbl',
        #            'ozone_plev.formatted', 'SOILPARM.TBL', 'gribmap.txt',
        #            'LANDUSE.TBL',      'tr67t85', 'tr49t67', 'tr49t85' ]
        #            'freezeH2O.dat',    'qr_acr_qg.dat',  'qr_acr_qs.dat' ]
        runfiles = ['aerosol.formatted', 'aerosol_lat.formatted', 'aerosol_lon.formatted',
                    'aerosol_plev.formatted', 'CCN_ACTIVATE.BIN', 'ETAMPNEW_DATA',
                    'GENPARM.TBL', 'gribmap.txt', 'LANDUSE.TBL',
                    'ozone.formatted', 'ozone_lat.formatted', 'ozone_plev.formatted',
                    'RRTM_DATA', 'RRTMG_LW_DATA',
                    'RRTMG_SW_DATA', 'SOILPARM.TBL', 'tr49t67', 'tr49t85', 'tr67t85',
                    'VEGPARM.TBL', 'forecast_vars_d01.txt']
        #'freezeH2O.bin','qr_acr_qg.bin', 'qr_acr_qs.bin',
        #
        #            #'CAM_ABS_DATA',    'ETAMPNEW_DATA.expanded_rain',
        #            #'CAM_AEROPT_DATA', 'RRTM_DATA_DBL', 'URBPARM.TBL',
        #            #'co2_trans',
        #            #'RRTMG_LW_DATA_DBL', 'ETAMPNEW_DATA_DBL',
        #            #'RRTMG_SW_DATA_DBL',  'grib2map.tbl',

        wrkbas, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, 'wrf', numens=mpiconfig.numens)
        for iens, wrkdir in enumerate(wrkdirs):
            if not os.path.lexists(wrkdir):
                os.mkdir(wrkdir)

            if self.runcase.caseNo == 1:     # did not run wrfdaupdate
                if not self.link_wait_real(wrkdir, iens):
                    return None

            # ------------------------ copy working files ----------------

            for fl in runfiles:
                relfl = os.path.join(wrkdir, fl)
                if not os.path.lexists(relfl):
                    absfl = os.path.join(self.runDirs.wrfdir, 'run', fl)
                    self.command.copyfile(absfl, relfl, hardcopy=False)

        # --------------- make namelist file ------------------------------

        nmlfiles = [os.path.join(wrkdir, 'namelist.input')
                    for wrkdir in wrkdirs]

        history_interval = self.runcase.fcstOutput//60
        history_begin = 0
        # fcstSeconds already contain time sampling
        history_end = self.runcase.fcstSeconds//60
        numsample = self.runcase.ntimesample//2
        # forward forecast only the last output is needed
        if self.runcase.caseNo in (2, 5):
            history_interval = self.runcase.timesamin   # good as long as not 0
            history_begin = self.runcase.fcstSeconds//60 - 2*numsample*self.runcase.timesamin
            history_end = self.runcase.fcstSeconds//60
        elif self.runcase.caseNo in (6, 7):
            history_interval = self.runcase.timesamin
            history_begin = self.runcase.fcstOutput//60 - numsample*self.runcase.timesamin
            history_end = self.runcase.fcstOutput//60 + numsample*self.runcase.timesamin

        endTime = self.runcase.endTime
        fcstleng = self.runcase.fcstSeconds
        (runday, runhr) = divmod(fcstleng, 24*3600)
        (runhr, runmn) = divmod(runhr, 3600)
        (runmn, runsc) = divmod(runmn, 60)

        nmlin = {'run_days':  runday,
                 'run_hours':  runhr,
                 'run_minutes':  runmn,
                 'run_seconds':  runsc,
                 'start_year':  self.runcase.startTime.year,
                 'start_month':  self.runcase.startTime.month,
                 'start_day':  self.runcase.startTime.day,
                 'start_hour':  self.runcase.startTime.hour,
                 'start_minute':  self.runcase.startTime.minute,
                 'start_second':  self.runcase.startTime.second,
                 'end_year':  endTime.year,
                 'end_month':  endTime.month,
                 'end_day':  endTime.day,
                 'end_hour':  endTime.hour,
                 'end_minute':  endTime.minute,
                 'end_second':  endTime.second,
                 'interval_seconds':  self.runcase.fcstSeconds,
                 'nproc_x':  mpiconfig.nproc_x,
                 'nproc_y':  mpiconfig.nproc_y,
                 # 'history_outname'    :  'wrfout_d<domain>_<date>',
                 'history_begin':  history_begin,
                 'history_end':  history_end,
                 'history_interval':  history_interval,
                 'e_we':  self.domain.nx,
                 'e_sn':  self.domain.ny,
                 'dx':  self.domain.dx,
                 'dy':  self.domain.dy,
                 }

        for iens, nmlfile in enumerate(nmlfiles):
            tmplinput = self.runcase.getNamelistTemplate(
                'wrf', iens if mpiconfig.numens is not None else None)
            nmlgrp = namelist.decode_namelist_file(tmplinput)

            if extsrc.extname == 'HRRR':
                nmlin["p_top_requested"] = 5000
            elif extsrc.extname in ('HRRRX', 'HRRRE'):
                nmlin["p_top_requested"] = 2000

            nmlgrp.merge(nmlin)

            if self.runcase.caseNo in (6, 7):
                nmlgrp["time_control"].iofields_filename = "forecast_vars_d01.txt"
                nmlgrp["time_control"].ignore_iofields_warning = ".true."
                if self.runcase.hybrid > 0:
                    nmlgrp["time_control"].auxhist7_outname = "wrfhyb_d<domain>_<date>"
                else:
                    nmlgrp["time_control"].auxhist7_outname = "wrfvar_d<domain>_<date>"
                nmlgrp["time_control"].frames_per_auxhist7 = 1
                nmlgrp["time_control"].io_form_auxhist7 = 2
                nmlgrp["time_control"].gsd_diagnostics = 1
                nmlgrp["time_control"].auxhist7_interval = 10
                nmlgrp["time_control"].reset_interval1 = 10
                nmlgrp["physics"].prec_acc_dt = 10

            nmlgrp["time_control"].nocolons = ".true."

            nmlgrp.writeToFile(nmlfile)

        # -------------- run the program from command line -------------------

        if self.check_job('wrf'):

            for wrkdir in wrkdirs:  # clean rsl.*
                subprocess.call(
                    'rm -rf rsl.* wrfoutReady_d01* wrfinputReady_d01', shell=True, cwd=wrkdir)

            hhmmstr = self.runcase.startTime.strftime('%H%M')
            outfile = 'wrf%d_%s.output' % (self.runcase.caseNo, hhmmstr)
            jobid = self.command.run_a_program(
                executable, None, outfile, wrkbas, mpiconfig)

            # -------------- wait for it to be done -------------------
            if not self.command.wait_job('wrf', jobid, wait, 12*3600):
                self.command.addlog(-1, "WRF", f'job failed: {jobid}')
                #raise SystemExit()

        # -------------- wait for it to be done -------------------
        filetime = self.runcase.startTime.strftime('%Y-%m-%d_%H:%M:%S')

        wrfifiles = [MyFileClass(os.path.join(
            wrkdir, 'wrfout_d01_%s' % filetime), False) for wrkdir in wrkdirs]

        return wrfifiles

    # enddef run_wrf
    # ========================== JOINWRF =============================

    def run_joinwrf(self, currTime=None, wait=False):

        executable = os.path.join(self.runDirs.vardir, 'bin', 'joinwrfh')
        tmplinput = self.runcase.getNamelistTemplate('joinwrf')

        jconf = self.runConfig['joinwrf']
        # if jconf.mpi : executable += '_mpi'    # serial only
        wrfconf = self.runConfig['wrf']

        # ---------------- make working directory -------------------------

        wrkbas, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, 'wrf', numens=wrfconf.numens)

        for wrkdir in wrkdirs:
            if not os.path.lexists(wrkdir):
                os.mkdir(wrkdir)

        wrfnmlf = os.path.join(wrkdirs[0], 'namelist.input')
        if not self.command.wait_for_a_file('JOIN', wrfnmlf, None, 300, 5):
            self.command.addlog(-1, "JOIN", f'File {wrfnmlf} not found')

        nmlwrf = namelist.decode_namelist_file(wrfnmlf)

        if self.runcase.caseNo in (6, 7):
            if self.runcase.hybrid > 0:
                fileheader = "wrfhyb"
            else:
                fileheader = "wrfvar"
            fileformat = nmlwrf['time_control'].io_form_auxhist7
        else:
            fileheader = 'wrfout'
            fileformat = nmlwrf['time_control'].io_form_history

        if fileformat != 102:
            return    # do not need to run joinwrf

        # ---------------- make namelist file ------------------------

        if currTime is None:
            startTime = self.runcase.startTime
            currTime = self.runcase.startTime + \
                timedelta(seconds=self.runcase.fcstSeconds)
        else:
            startTime = currTime

        fileready = f"{fileheader}_d01_{currTime:%Y-%m-%d_%H:%M:%S}_ready"
        wrfiles = [os.path.join(wrkdir, fileready) for wrkdir in wrkdirs]
        if self.command.wait_for_files('JOIN', wrfiles, 2, 2, 1) == len(wrkdirs):
            self.command.addlog(0, "JOIN", f'Found {fileready}')
            return

        lastpath = wrfconf.ntotal-1
        wrfile = f"{fileheader}_d01_{currTime:%Y-%m-%d_%H:%M:%S}_{lastpath:04}"
        wrfiles = [os.path.join(wrkdir, wrfile) for wrkdir in wrkdirs]
        if self.command.wait_for_files('JOIN', wrfiles, 7200, 600, 5) != len(wrkdirs):
            self.command.addlog(-1, "JOIN", 'WRF output Files not ready')

        # arbitrary number of seconds
        s = self.runcase.fcstOutput
        # hours
        hours = s // 3600
        # remaining seconds
        s = s - (hours * 3600)
        # minutes
        minutes = s // 60
        # remaining seconds
        seconds = s - (minutes * 60)
        # total time
        interval = f'00_{int(hours):02}:{int(minutes):02}:{int(seconds):02}'
        # result: 03:43:40

        nmlgrp = namelist.decode_namelist_file(tmplinput)

        nmlin = {'start_time_str': startTime.strftime('%Y-%m-%d_%H:%M:%S'),
                 'history_interval': interval,
                 'end_time_str': currTime.strftime('%Y-%m-%d_%H:%M:%S'),

                 'filename_header': fileheader,
                 'nproc_xin': wrfconf.nproc_x,
                 'nproc_yin': wrfconf.nproc_y,
                 }

        nmlgrp.merge(nmlin)

        ftime = int((currTime-self.runcase.startTime).total_seconds())
        nmlfile = f'joinwrf_{ftime//60:03}.input'
        nmlfiles = [os.path.join(wrkdir, nmlfile) for wrkdir in wrkdirs]

        for iens, absnmlfile in enumerate(nmlfiles):
            nmlgrp['wrfdfile'].dir_extd = wrkdirs[iens]
            nmlgrp.writeToFile(absnmlfile)

        # -------------- run the program --------------------------

        outfile = f'joinwrf{self.runcase.caseNo}_{ftime//60:03}.output'

        jobid = self.command.run_joinwrf(
            executable, nmlfile, outfile, wrkbas, jconf)

        # -------------- wait for it to be done -------------------
        if not self.command.wait_job('joinwrf%02d' % self.domain.id, jobid, wait):
            self.command.addlog(-1, "JOIN", f'job failed: {jobid}')
            #raise SystemExit()

    # enddef run_joinwrf

    # ======================== radremap   ==============================

    def run_radremap(self, radname, bkgfile, wait):
        ''' run radremap.exe
        wait : whether to wait for the job to be finished

        It uses background file bkgfile
        '''

        executable = os.path.join(self.runDirs.vardir, 'bin', 'radremap')
        tmplinput = self.runcase.getNamelistTemplate('radremap')

        mpiconfig = self.runConfig['radremap']
        if mpiconfig.mpi:
            executable += '_mpi'

        _nothing, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, 'radremap', False, None)
        # os.path.join(self.caseDir,'radremap')
        wrkdir = wrkdirs[0]
        radinfo = os.path.join(wrkdir, 'radarinfo.dat')

        radconf = self.runcase.getObsConfig('radar')

        if self.mutex.acquire():
            if not os.path.lexists(wrkdir):
                os.mkdir(wrkdir)

            # -------------- Copy radarinfo.dat ---------------------------

            if not os.path.lexists(radinfo):
                infosrc = os.path.join(
                    self.runDirs.inputdir, radconf.radarinfo)
                self.command.copyfile(infosrc, radinfo, hardcopy=False)
            self.mutex.release()

        # -------------- Perpare for data files -------------------------

        hhmmstr = self.runcase.startTime.strftime('%H%M')
        runname = 'rad%d%s_%s' % (self.runcase.caseNo, radname, hhmmstr)
        nmlfile = os.path.join(wrkdir, '%s.input' % runname)

        timstr = self.runcase.startTime.strftime('%Y%m%d%H%M')

        # -------------- make namelist file ------------------------------

        inittimestr = self.runcase.startTime.strftime('%Y-%m-%d.%H:%M:%S')
        timstr = self.runcase.startTime.strftime('%Y%m%d%H%M%S')
        reftime = self.runcase.startTime.strftime('%Y%m%d_%H%M')

        nmlgrp = namelist.decode_namelist_file(tmplinput)
        if nmlgrp["radremapopt"].nlistfil == 1:
            radlist = 'RADR_%s%s.list' % (radname, timstr)
            radfile = 'xxxx'

            if not os.path.lexists(os.path.join(wrkdir, radlist)):
                # print radfile
                self.command.addlog(-1, "cntl.radar",
                                    'Radar list for %s is not found.' % radname)
        else:
            radlist = 'xxxx'
            radfile = 'RADR_%s%s.raw' % (radname, timstr)

            if not os.path.lexists(os.path.join(wrkdir, radfile)):
                # print radfile
                self.command.addlog(-1, "cntl.radar",
                                    'Radar file for %s is not found.' % radname)

        nmlin = {'initime': inittimestr,
                 'inifile': bkgfile.name,
                 'inigbf': 'xxxxxx',
                 'radname': radname,
                 'radfname': './%s' % radfile,
                 'listfil': ['./%s' % radlist],
                 'rad98opt': 0,
                 'ref_time': reftime,
                 'runname': runname,
                 'nproc_x':  mpiconfig.nproc_x,
                 'nproc_y':  mpiconfig.nproc_y,
                 'max_fopen': mpiconfig.nproc_x*mpiconfig.nproc_y
                 }

        nmlgrp.merge(nmlin)
        nmlgrp.writeToFile(nmlfile)

        # ------------ run the program from command line -----------------
        outfile = '%s.output' % runname
        jobid = self.command.run_a_program(
            executable, nmlfile, outfile, wrkdir, mpiconfig, inarg='-input')

        # -------------- wait for it to be done -------------------
        if not self.command.wait_job('radremap_%s' % radname, jobid, wait):
            #raise SystemExit()
            pass

        if self.mutex.acquire():
            self.procradars += 1
            self.mutex.release()

    # enddef run_radremap

    # ========================== news3dvar =============================

    def run_news3dvar(self, obsfiles, bkgfiles, wait):
        '''
          Run or submit news3dvar job
        '''

        executable = os.path.join(self.runDirs.vardir, 'bin', 'news3dvar')

        mpiconfig = self.runConfig['news3dvar']
        if mpiconfig.mpi:
            executable += '_mpi'

        tmplinput = self.runcase.getNamelistTemplate(
            'news3dvar', mpiconfig.numens)

        # ---------------- Check files and directory -----------------------

        wrkbas, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, 'news3dvar', False, mpiconfig.numens)
        for wrkdir in wrkdirs:
            if not os.path.lexists(wrkdir):
                os.mkdir(wrkdir)

            calpath = os.path.join(wrkdir, 'calib')
            if not os.path.lexists(calpath):
                calbas = os.path.join(self.runDirs.inputdir, 'calib')
                self.command.copyfile(calbas, calpath, hardcopy=False)

        # -------------- Prepare for rtma_random_flips ----------------------
        randomfiles = [os.path.join(wrkdir, "random_flips")
                       for wrkdir in wrkdirs]
        randomsrc = os.path.join(self.runDirs.inputdir, "rtma_random_flips")

        timstr = self.runcase.startTime.strftime('%Y%m%d%H%M')

        # ---------------- get event date string -------------------------

        eventdate = self.runcase.eventDate.strftime('%Y%m%d')

        # ---------------- Waiting for DART files ------------------------
        inittime = False
        if self.runcase.startTime == self.runcase.eventDate:
            inittime = True

        if mpiconfig.numens is not None:

            cov_factor = self.runcase.hybrid
            bkgdir = re.sub(r"_\d{1,3}$", "",
                            os.path.dirname(bkgfiles[0].name))
            ensdirname = '%s_%%0N' % bkgdir
            nensemble = mpiconfig.numens

            if self.domain.cycle_num > 0:
                ensfileopt = 2        # WRF output file
            else:
                ensfileopt = 1        # WRF input file

            # Waiting for background files, just in case
            bkgstatus = [bkgfile.status for bkgfile in bkgfiles]
            if not all(bkgstatus):
                bkgreadys = [bkgfile.ready for bkgfile in bkgfiles]
                if self.command.wait_for_files('run_news3dvar', bkgreadys, None, 120, 3, skipread=True) < len(bkgfiles):
                    self.command.addlog(-1, "cntl.3dvar",
                                        'Not all background files are ready, please check ....')

                for bkgfile in bkgfiles:
                    bkgfile.ready = True

            for bkgfile in bkgfiles:
                bkgfile.rename(self.runcase.startTime,
                               self.runcase.ntimesample, self.runcase.timesamin)

        elif self.runcase.hybrid > 100 and self.runcase.startTime.minute == 0:

            time_wrf = self.runcase.startTime.strftime('%Y-%m-%d_%H:%M:%S')

            waittime = 7200      # initial time wait longer for files
            waitready = 600

            failens = False
            jconf = self.runConfig['real']
            realbase,realdirs = self.runcase.getwrkdir(self.caseDir, 'real', numens=jconf.numens)

            afiles = [os.path.join(realdirs[n], 'wrfinput_d01') for n in range(1, jconf.numens+1)]

            self.command.addlog(
                0, "cntl.3dvar", 'Looking for ensemble files in %s ...' % os.path.dirname(afiles[0]))
            if self.command.wait_for_files('run_news3dvar', afiles, None, waitready, 5, skipread=False) < len(afiles):
                failens = True
                failfl = os.path.join(os.path.dirname(
                    os.path.dirname(self.caseDir)), f'{time_wrf}_ENS.fail')
                self.command.addlog(
                    1, "cntl.3dvar", 'Generating <%s> ....' % failfl)
                with open(failfl, 'w') as f:
                    f.write(
                        f"First for {time_wrf} at {datetime.now():%Y-%m-%d.%H:%M:%S}.")

            ensdirname = f'{realbase}_%0N'   # use in news3dvar.input
            ensfileopt = 1

            nensemble = jconf.numens

            cov_factor = self.runcase.hybrid-100.0
            if failens:
                cov_factor = 0.0

        elif self.runcase.hybrid > 0 and self.runcase.hybrid < 100:

            failfl = os.path.join(os.path.dirname(os.path.dirname(self.caseDir)),
                                  '%s_NEWSe.fail' % eventdate)
            time_wrf = self.runcase.startTime.strftime('%Y-%m-%d_%H:%M:%S')

            if self.runcase.startTime == self.runcase.eventDate:
                ensdirname = 'ic%0N'   # use in news3dvar.input
                ensfileopt = 3
                waittime = 7200      # initial time wait longer for files
                waitready = 600
            else:
                subdirt = (self.runcase.startTime -
                           timedelta(minutes=15)).strftime('%Y%m%d%H%M')
                ensfileopt = 4
                ensdirname = subdirt
                waittime = 3600
                waitready = 300

            failwof = False
            if not os.path.lexists(failfl):
                nen = 36
                flagdir = os.path.join(self.runDirs['dartdir'], eventdate)
                if inittime:
                    afiles = [os.path.join(
                        flagdir, f'ic{n:d}', 'wrfinput_d01_ic') for n in range(1, nen+1)]
                else:
                    afiles = [os.path.join(
                        flagdir, subdirt, f'wrffcst_d01_{time_wrf}_{n:d}') for n in range(1, nen+1)]

                self.command.addlog(
                    0, "cntl.3dvar", 'Looking for ensemble files in %s ...' % os.path.dirname(afiles[0]))
                #self.command.addlog(0,"cntl.3dvar",'%s'%('\n'.join([os.path.basename(afile) for afile in afiles])) )
                if self.command.wait_for_files('run_news3dvar', afiles, None, waitready, 5, skipread=False) < len(afiles):
                    failwof = True
                    self.command.addlog(
                        1, "cntl.3dvar", 'Generating <%s> ....' % failfl)
                    with open(failfl, 'w') as f:
                        f.write(
                            f"First for {time_wrf} at {datetime.now():%Y-%m-%d.%H:%M:%S}.")
            else:
                self.command.addlog(
                    1, "cntl.3dvar", 'Found  <%s> ....' % failfl)
                failwof = True

            ensdirname = os.path.join(
                self.runDirs['dartdir'], eventdate, ensdirname)
            nensemble = 36

            cov_factor = self.runcase.hybrid
            if failwof:
                cov_factor = 0.0
        else:
            cov_factor = 0
            ensdirname = 'None'
            nensemble = 1
            ensfileopt = 1        # Will not use, can be anything

        # ---------------- Set observation files  ---------------------

        nradfile  = 0; radfnames = []
        nsngfile  = 0; sngfname  = []; sngtmchk = []
        nconvfil  = 0; convfname = []
        nuafile   = 0; uafnames  = []
        ncwpfile  = 0; cwpfname  = []
        nlgtfile1 = 0; lgtfname  = []
        nlgtfile2 = 0

        raddir = os.path.join(self.caseDir, 'radremap')

        for (obskey, files) in obsfiles.items():
            if obskey == 'radar':
                datstr = self.runcase.startTime.strftime('%Y%m%d.%H%M')
                for radname in files:
                    radfname = os.path.join(raddir,'%s.%s.nc' % (radname,datstr))
                    if os.path.lexists(radfname) or self.command.showonly:
                        radfnames.append(radfname)
                    else:  # actual run, check whether each radar file exists
                        self.command.addlog(
                            1, "cntl.3dvar", f"radar file: {radfname} not found")
                nradfile = len(radfnames)
                self.command.addlog(
                    0, "cntl.3dvar", 'Analysis will use %d radar data files.' % nradfile)
            elif obskey == 'ua':
                nuafile = len(files)
                uafnames = files
            elif obskey == 'sng':
                nsngfile = len(files)
                for filelst in files:
                    sngfname.append(filelst[0])
                    sngtmchk.append(filelst[1])
            elif obskey == 'conv':
                nconvfil = len(files)
                for filelst in files:
                    convfname.append(filelst)
            elif obskey == 'cwp':
                ncwpfile = len(files)
                cwpfname = files
            elif obskey == 'lightning1':
                nlgtfile1 = len(files)
                if nlgtfile1 > 0:
                    lgtfname += files
            elif obskey == 'lightning2':
                nlgtfile2 = len(files)
                if nlgtfile2 > 0:
                    lgtfname += files

        # ---------------- VAD checking  ---------------------
        if '88vad' in self.obstypes and 'radar' in obsfiles:
            datstr = self.runcase.startTime.strftime('%y%m%d.%H%M')
            vadfiles = []
            for radname in obsfiles['radar']:
                vadfile = os.path.join(raddir, '%s.%s.vad' % (radname, datstr))
                if os.path.lexists(vadfile) or self.command.showonly:
                    vadfiles.append(vadfile)
                else:
                    self.command.addlog(
                        1, "cntl.3dvar", f"VAD file: {vadfile} not found")

            uafnames += vadfiles
            nuafile += len(vadfiles)
            self.command.addlog(
                0, "cntl.3dvar", 'Analysis will use %d VAD data files.' % len(vadfiles))

        if nradfile <= 0 : radfnames = ['xxxx']
        if nuafile  <= 0 : uafnames  = ['xxxx']
        if ncwpfile <= 0 : cwpfname  = ['xxxx']
        if nsngfile <= 0 :
            sngfname = ['xxxx']
            sngtmchk = ['none']
        if nconvfil <= 0 : convfname = ['xxxx']
        nlgtfile = nlgtfile1+nlgtfile2
        if nlgtfile <= 0 : lgtfname = ['xxxx']

        skip3dvar = False
        if nradfile+nuafile+nsngfile+nconvfil+ncwpfile+nlgtfile == 0:
            self.command.addlog(
                1, "cntl.3dvar", 'No observation was found. news3dvar skipped.')
            skip3dvar = True

            # return anafiles

        # ---------------- make namelist file ------------------------------

        ###################################################################
        ##
        # Given values in namelist.py string format and get the real values
        # in Fortran format.
        ##
        ###################################################################

        def getvaluelst(values, vartype):
            retlst = []
            prep0 = False
            for val in values:
                if isinstance(val, list):
                    retlst.append(getvaluelst(val, vartype))
                else:
                    if vartype == 'int0':
                        retlst.append(int(val))
                        prep0 = True
                    else:
                        retlst.append(vartype(val))
            if prep0:
                retlst.insert(0, 0)

            return retlst
        # enddef getvaluelst

        ###################################################################

        vardpass = {'adas_radar'  : { 'iuserad' : 'int0' },
                    'adas_sng'    : { 'iusesng' : 'int0' },
                    'adas_ua'     : { 'iuseua'  : 'int0' },
                    'adas_cwp'    : { 'iusecwp' : 'int0' },
                    'adas_tpw'    : { 'iusetpw' : 'int0' },
                    'var_aeri'    : { 'iuseaeri': 'int0' },
                    'adas_conv'   : { 'iuseconv': int    },
                    'var_lightning':{ 'iuselgt' : int    },
                    'var_const'   : { 'maxin'           : int,
                                      'vrob_opt'        : int,
                                      'cldfirst_opt'    : int,
                                      'qobsrad_bdyzone' : int,
                                      'pseudo_qs'       : int,
                                      'pseudo_qv'       : int,
                                      'pseudo_pt'       : int,
                                    },
                    'var_refil'   : { 'ipass_filt'      : int,
                                      'hradius'         : float,
                                      'vradius'         : float,
                                      'vradius_opt'     : int,
                                    },
                    'var_diverge' : { 'wgt_div_h'       : float,
                                      'wgt_div_v'       : float,
                                    },
                    'var_smth'    : { 'wgt_smth'        : float },
                    'var_thermo'  : { 'wgt_thermo'      : float },
                    'var_mslp'    : { 'mslp_err'        : float },
                    'var_consdiv' : { 'wgt_dpec'        : float,
                                      'wgt_hbal'        : float
                                    },
                    'var_ens'     : { 'vradius_opt_ens' : int,
                                      'hradius_ens': float,
                                      'vradius_ens': float
                                    },
                    'var_reflec'  : { 'ref_opt'         : int,
                                      'wgt_ref'         : float,
                                      'hradius_ref'     : float,
                                      'vradius_opt_ref' : int,
                                      'vradius_ref'     : float
                                    }
        }

        nmlfile = 'news3dvar.input'
        nmlfiles = [os.path.join(wrkdir, nmlfile) for wrkdir in wrkdirs]

        for iens, absnmlfile in enumerate(nmlfiles):
            tmplinput = self.runcase.getNamelistTemplate(
                'news3dvar', mpiconfig.numens if mpiconfig.numens is None else iens)
            nmlgrp = namelist.decode_namelist_file(tmplinput)

            if nmlgrp["obs_ref"].refsrc == 1:
                obsconf = self.runcase.getObsConfig('mrms')
                mrmsfiles = self.check_wait_mrms(
                    self.runcase.startTime, obsconf, wrkdirs[0])
                #assert(len(mrmsfiles) == 33)
            else:
                mrmsfiles = ['xxxx']

            if not bkgfiles[iens].wait_ready(self.command):
                self.command.addlog(-1, "news3dvar",
                                    f"{bkgfiles[iens].ready} not ready in 10 minutes.")
            bkgfiles[iens].rename(
                self.runcase.startTime, self.runcase.ntimesample, self.runcase.timesamin)

            nmlin = { 'initime'     : self.runcase.startTime.strftime('%Y-%m-%d.%H:%M:00'),
                      'inifile'     : bkgfiles[iens].name,
                      'modelopt'    : 2,
                      'inigbf'      : 'xxxxxx',
                      #'hdmpfmt'     : hdmpfmt
                      'runname'     : '%s_%s' % (self.runcase.runname,timstr),
                      'refile'      : mrmsfiles[0],
                      'nradfil'     : nradfile,
                      'radfname'    : radfnames,
                      'nsngfil'     : nsngfile,
                      'sngfname'    : sngfname,
                      'sngtmchk'    : sngtmchk,
                      'nconvfil'    : nconvfil,
                      'convfname'   : convfname,
                      'nuafil'      : nuafile,
                      'uafname'     : uafnames,
                      'ncwpfil'     : ncwpfile,
                      'cwpfname'    : cwpfname,
                      'nlgtfil'     : nlgtfile,
                      'lightning_files': lgtfname,
                      'dirname'     : './',
                      'nproc_x'     : mpiconfig.nproc_x,
                      'nproc_y'     : mpiconfig.nproc_y,
                      'max_fopen'   : mpiconfig.nproc_x*mpiconfig.nproc_y,
                      'ensdirname'  : ensdirname,
                      'ensfileopt'  : ensfileopt,
                      'nensmbl'     : nensemble,
                      'iensmbl'     : iens,
                      'ntimesample' : self.runcase.ntimesample,
                      'stimesample' : self.runcase.timesamin*60,
                      'cov_factor'  : cov_factor,
                      'icycle'      : self.domain.cycle_num
                    }

            ##
            # Trim run-time namelist with npass
            ##
            npass = nmlgrp['adas_const'].npass

            for nmlblk, nmlvars in vardpass.items():
                for nmlvar, nmltype in nmlvars.items():
                    nmlvalues = nmlgrp[nmlblk][nmlvar]
                    if len(nmlvalues) > npass:  # Check sizes
                        del nmlvalues[npass:]
                    elif len(nmlvalues) < npass:
                        self.command.addlog(-1, "cntl.3dvar",
                                            'ERROR: No enough values for variable <%s>.' % nmlvar)

                    nmlin[nmlvar] = getvaluelst(nmlvalues, nmltype)

            ##
            # To eliminate empty passes
            ##
            delpass = []
            for ipass in range(0, npass):
                dopass = False

                #print(f"{ipass}: iuserad  => {nmlin['iuserad'][ipass] }")
                #print(f"{ipass}: iuseua   => {nmlin['iuseua'][ipass]  }")
                #print(f"{ipass}: iuseconv => {nmlin['iuseconv'][ipass]}")
                #print(f"{ipass}: iuselgt  => {nmlin['iuselgt'][ipass] }")
                #print(f"{ipass}: iusesng  => {nmlin['iusesng'][ipass] }")
                #print(f"{ipass}: iusecwp  => {nmlin['iusecwp'][ipass] }")

                if nradfile > 0:
                    if nmlin['vrob_opt'][ipass] > 0 or nmlin['ref_opt'][ipass] > 0:
                        if any(nmlin['iuserad'][ipass]):
                            dopass = True
                            #print(f"Turn on {ipass} by rad")

                if nuafile > 0:
                    if any(nmlin['iuseua'][ipass]):     # all data sources
                        dopass = True
                        #print(f"Turn on {ipass} by ua")

                if nconvfil > 0:
                    if nmlin['iuseconv'][ipass] > 0:
                        dopass = True
                        #print(f"Turn on {ipass} by conv")

                if nlgtfile > 0:
                    if any(nmlin['iuselgt'][ipass]):
                        dopass = True
                        #print(f"Turn on {ipass} by lgt")

                if nsngfile > 0:
                    if any(nmlin['iusesng'][ipass]):
                        dopass = True
                        #print(f"Turn on {ipass} by sng")
                        #print(f"{nsngfile} -> {sngfname}")

                if ncwpfile > 0:
                    if any(nmlin['iusecwp'][ipass]):
                        dopass = True
                        #print(f"Turn on {ipass} by cwp")

                if nmlin["cldfirst_opt"][ipass] > 0 or nmlin["pseudo_qs"][ipass] > 0:
                    dopass = True

                if not dopass:
                    delpass.append(ipass)

            while len(delpass) > 0:
                if len(delpass) == npass:
                    self.command.addlog(
                        1, "3DVAR", "No valid observation found. Skip 3DVAR")
                    skip3dvar = True
                    break

                for nmlblk, nmlvars in vardpass.items():
                    for nmlvar, nmltype in nmlvars.items():
                        #print(f"before: {nmlvar} => {nmlin[nmlvar]}")
                        nmlvalues = nmlin[nmlvar]
                        nmlin[nmlvar] = [ele for idx, ele in enumerate(
                            nmlvalues) if idx not in delpass]
                        #print(f"after:  {nmlvar} => {nmlin[nmlvar]}")
                nmlgrp['adas_const'].npass = npass-len(delpass)
                break

            #
            # To write the namelist file at run-time based on nmlgrp & nmlin
            #
            nmlgrp.merge(nmlin)
            # if iens == 0:
            #    #nmlgrp["var_ens"].ntimesample = 1    # control member always uses 1
            #    if inittime: nmlgrp["var_ens"].kgain_factor = 1.0      # control member always uses 1 at inittime
            # else:   # other no control members
            #    #nmlgrp["var_ens"].ntimesample = self.runcase.ntimesample
            #    nmlgrp["var_ens"].cov_factor = 0.0      # control member always uses 1 at inittime
            #
            nmlgrp.writeToFile(absnmlfile)

            # -------------- Copy rtma_random_flips ----------------------

            if nmlgrp["var_refil"].filt_type == 2:
                if not os.path.lexists(randomfiles[iens]):
                    self.command.copyfile(
                        randomsrc, randomfiles[iens], hardcopy=False)

        # -------------- run the program  ----------------
        if self.check_job('news3dvar') and not skip3dvar:

            for wrkdir in wrkdirs:  # clean work file beforehand
                subprocess.call(
                    'rm -rf wrfoutReady_d01* wrfinputReady_d01', shell=True, cwd=wrkdir)

            hhmmstr = self.runcase.startTime.strftime('%H%M')
            outfile = 'n3dvar%d_%s.output' % (self.runcase.caseNo, hhmmstr)
            jobid = self.command.run_a_program(
                executable, nmlfile, outfile, wrkbas, mpiconfig)

        # -------------- wait for it to be done -------------------
            if not self.command.wait_job('news3dvar', jobid, wait):
                self.command.addlog(-1, "3DVAR", f'job failed: {jobid}')
                #raise SystemExit()

        # define generated analysis file name
        anafiles = [os.path.join(wrkdir, os.path.basename(bkgfile.name))
                    for wrkdir, bkgfile in zip(wrkdirs, bkgfiles)]

        if skip3dvar:
            for anafile, bkgfile in zip(anafiles, bkgfiles):
                anaready = re.sub(r'wrf(out|input)_d01',
                                  r'wrf\g<1>Ready_d01', anafile)
                self.command.copyfile(bkgfile.name, anafile, False)
                self.command.copyfile(bkgfile.name, anaready, False)

        return anafiles
    # enddef run_news3dvar

    # ========================== NCLPLT ================================

    def run_nclplt(self, afiles, atime, wait, bfile=None, pltfields=None):

        executable = os.path.join(self.command.fetchNCARGRoot(), 'bin', 'ncl')
        jconf = self.runConfig['nclplt']

        # ---------------- make working directory -------------------------

        wrkbas, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, 'nclscripts', numens=jconf.numens)
        # os.path.join(self.caseDir,'nclscripts%d'%(self.runcase.caseNo-1))
        iens = 0
        for wrkdir in wrkdirs:
            if not os.path.lexists(wrkdir):
                os.mkdir(wrkdir)

            afile = afiles[iens]
            li = afile.rsplit('wrfout_d')
            # if afile contain "wrfout_d", it will
            flready = 'wrfoutReady_d'.join(li)
            # be replaced with "wrfoutReady_d". Otherwise, flready is the same as afile

            self.command.wait_for_a_file(
                'run_nclplt', flready, None, 1800, 10, skipread=True)

            # self.command.wait_for_a_file('run_nclplt',afiles[iens],60,300,5,skipread=True)
            iens += 1

        fminu = int((atime - self.runcase.startTime).total_seconds())//60

        #outdir = os.path.join(wrkdir,'out%03d' % fminu)
        # if not os.path.lexists(outdir) :
        #  os.mkdir(outdir)

        # ---------------- Plot each field --------------------------------

        #LOCTime    = atime + timedelta(hours=-6.0)
        #LOCtimestr = LOCTime.strftime('%Y-%m-%d_%H:%M:%S')
        LOCtimestr = atime.strftime('%Y-%m-%d_%H:%M:%S')

        ncargroot = self.command.fetchNCARGRoot()

        if pltfields is None:
            pltfields = self.runcase.fields

        for field in pltfields:
            fmatch = re.match(r'agl([hDZv])([0-9\.]{3,4})km', field)
            if fmatch:
                ncltmpl = os.path.join(self.runDirs.inputdir, 'nclscripts',
                                       'plt_agl%s3km.ncl' % fmatch.group(1))
                hghtln = "heights = (/ %f /)" % float(fmatch.group(2))
                fieldshort = "%s%s" % (fmatch.group(1), fmatch.group(2)[:1])
            else:
                ncltmpl = os.path.join(
                    self.runDirs.inputdir, 'nclscripts', 'plt_%s.ncl' % field)
                hghtln = " "
                fieldshort = field[:2]
            timeln = 'timescst = "%s"' % LOCtimestr
            hhmmstr = self.runcase.startTime.strftime('%H%M')

            if bfile is not None:
                bfileline = 'b = addfile("%s.nc","r")' % bfile
            else:
                bfileline = ' '

            if fminu > 0:
                forastr = '''
             jobtype    = "Forecast"
             dbzvarn    = "dbzp"
             smooth_opt = 3
          '''
            else:
                forastr = '''
             jobtype    = "Analysis"
             dbzvarn    = "dbz"
             smooth_opt = 0
          '''

            nclscpt = 'p%d%s_%s-%03d.ncl' % (self.runcase.caseNo,
                                             fieldshort, hhmmstr, fminu)
            iens = 0
            for wrkdir in wrkdirs:
                nclfile = os.path.join(wrkdir, nclscpt)
                nclhndl = open(nclfile, 'w')
                nclstr = '''
             load "%(NCARG_ROOT)s/lib/ncarg/nclscripts/csm/gsn_code.ncl"
             ;load "%(NCARG_ROOT)s/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
             load "%(CUMTmpl)s/nclscripts/WRFUserARW.ncl"

             ;external DIV "%(CUMTmpl)s/nclscripts/wrfdivergence.so"
             ;external VOR "%(CUMTmpl)s/nclscripts/wrfvorticity.so"

             begin
               a = addfile("%(wrffile)s.nc","r")
               %(bfileline)s
               wks_type = "%(outtype)s"
               wks_type@wkWidth  = 1224
               wks_type@wkHeight = 1584
               wks = gsn_open_wks(wks_type,"%(field)s")

               %(timeline)s
               %(heightline)s
               %(forastr)s
          ''' % {'wrffile': afiles[iens], 'bfileline': bfileline,
                 'outtype': 'png',  'forastr': forastr,
                 'field': '%s-%03d' % (field, fminu), 'heightline': hghtln, 'timeline': timeln,
                 'NCARG_ROOT': ncargroot,
                 'CUMTmpl': self.runDirs.inputdir
                 }

                nclhndl.write(self.command.trim(nclstr))
                with open(ncltmpl, 'r') as ncltmph:
                    for line in ncltmph:
                        if line.startswith(';;;'):
                            continue
                        ##line = line.replace('CUMTmpl',self.runDirs.inputdir)
                        nclhndl.write(line)

                ##
                ## Attach special map outlines as needed
                ##
                ##flag = 0
                ##if not field.endswith('ew') and not field.endswith('ns'):
                ##  ## Check NCARG version
                ##  ncargver = subprocess.check_output("%s/bin/ncargversion"%ncargroot,
                ##             stdin=None,stderr=subprocess.STDOUT,shell=None,cwd=wrkdir)
                ##  vermatch = re.search(r'Version (\d).(\d).\d',ncargver)
                ##  if vermatch:
                ##    majorver = int(vermatch.group(1))
                ##    minorver = int(vermatch.group(2))
                ##    ##print majorver, minorver
                ##    if majorver >= 6:
                ##       if minorver >= 1: flag = 2
                ##       else:             flag = 1
                ##
                ##if flag > 0:
		##  attachlines = """     cityplot = attach_citys(wks,plot,"%s/somewhere_shp",%d)
                ##
                ##                """ % (self.runDirs.inputdir,flag)
                ##  nclhndl.write(attachlines)

                nclhndl.write(
                    self.command.trim(""";--- draw the map and the shapefile outlines ---
                                               draw(plot)
                                               frame(wks)
                                             end do
                                          end
                                   """)
                )

                nclhndl.close()

                iens += 1

            # Now execute the ncl script
            jobid = self.command.run_ncl_plt(
                executable, nclscpt, wrkbas, jconf)

            if not self.command.wait_job('nclplt', jobid, wait):
                self.command.addlog(-1, "NCL", f'job failed: {jobid}')
                #raise SystemExit()

    # enddef run_nclplt

    # ========================== UNIPOST ===============================

    def run_unipost(self, afile, wrfmin, wait):

        executable = os.path.join(self.runDirs.uppdir, 'bin', 'unipost.exe')
        tmplinput = self.runcase.getNamelistTemplate('unipost')

        jconf = self.runConfig['unipost']

        # ---------------- make working directory -------------------------

        _nothing, wrkupdir = self.runcase.getwrkdir(self.caseDir, 'postprd')
        # os.path.join(self.caseDir,'postprd%d'%(self.runcase.caseNo-1))
        if not os.path.lexists(wrkupdir):
            os.mkdir(wrkupdir)

        wrkdir = os.path.join(wrkupdir, 'fcst-%03d' % wrfmin)
        if not os.path.lexists(wrkdir):
            os.mkdir(wrkdir)

        timestr = self.runcase.startTime.strftime('%Y-%m-%d_%H:%M:%S')

        # ---------------- Link working files ----------------------------

        srcfiles = [os.path.join(self.runDirs.wrfdir, "run", "ETAMPNEW_DATA.expanded_rain"),
                    os.path.join(self.runDirs.wrfdir, "run", "ETAMPNEW_DATA"),
                    os.path.join(self.runDirs.uppdir, "src",  "lib","g2tmpl","params_grib2_tbl_new"),
                    os.path.join(self.runDirs.uppdir, "parm", "post_avblflds.xml"),
                    os.path.join(self.runDirs.uppdir, "parm", "postcntrl.xml")
                    ]
        runfiles = ["hires_micro_lookup.dat", "nam_micro_lookup.dat", "params_grib2_tbl_new",
                    "post_avblflds.xml", "postcntrl.xml"
                    ]

        for i, runfile in enumerate(runfiles):
            relfl = os.path.join(wrkdir, runfile)
            if not os.path.lexists(relfl):
                self.command.copyfile(srcfiles[i], relfl)

        # --------------- make namelist file ------------------------------

        prdcntl = os.path.join(wrkdir, 'fort.14')
        if os.path.lexists(prdcntl):
            os.unlink(prdcntl)

        self.command.copyfile(tmplinput, prdcntl, hardcopy=True)

        stdnml = os.path.join(wrkdir, 'itag')

        nmlfile = open(stdnml, 'w')
        nmlstr = '''
                %(wrffile)s
                netcdf
                %(ndate)s
                NCAR
                ''' % {'wrffile': afile,
                       'ndate': timestr
                       }

        nmlfile.write(self.command.trim(nmlstr))
        nmlfile.close()

        # Now execute the unipost script
        outfile = os.path.join(wrkdir, 'unipost.output')
        jobid = self.command.run_unipost(executable, '', outfile,
                                         wrkdir, os.path.join(
                                             self.runDirs.uppdir, 'bin'),
                                         timestr, wrfmin, jconf)

        if not self.command.wait_job('unipost', jobid, wait):
            self.command.addlog(-1, "UPP", f'job failed: {jobid}')
            #raise SystemExit()

    # enddef run_unipost

    # ========================== WRFEXTSND =============================

    def run_wrfextsnd(self, afile, wait):

        executable = os.path.join(self.runDirs.vardir, 'bin', 'wrfextsnd')
        tmplinput = self.runcase.getNamelistTemplate('wrfextsnd')

        jconf = self.runConfig['wrfextsnd']

        # ---------------- make working directory -------------------------

        wrkdir = os.path.join(self.caseDir, 'extsnd')
        if not os.path.lexists(wrkdir):
            os.mkdir(wrkdir)

        timestr = self.runcase.startTime.strftime('%Y-%m-%d_%H:%M:%S')

        # --------------- make namelist file ------------------------------

        nmlfile = os.path.join(wrkdir, 'wrfextsnd.input')

        nmlgrp = namelist.namelistGroup.fromFile(tmplinput)
        nmlin = { 'dir_extd'          : os.path.dirname(afile),
                  'init_time_str'     : timestr,
                  'io_form'           : 7,
                  'grid_id'           : 2,
                  'start_time_str'    : timestr,
                  'history_interval'  : '00_01:00:00',
                  'end_time_str'      : timestr,
                  'locopt'            : 1,
                  'nsnd'              : 1,
                  'stid'              : [  'GUNKNOWN' ],
                  'istnm'             : [    83538 ],
                  'slat'              : [    22.69 ],
                  'slon'              : [   114.34 ],
                  'selev'             : [      0.0 ],
                  'dir_output'        : wrkdir,
                  'outsnd'            : 2,
                  'outsfc'            : 1,
                  'nproc_x'           : jconf.nproc_x,
                  'nproc_y'           : jconf.nproc_y,
                  'max_fopen'         : jconf.nproc_x*jconf.nproc_y
                }

        nmlgrp.merge(nmlin)
        nmlgrp.writeToFile(nmlfile)

        # -------------- run the program from command line ----------------

        outfile = 'wrfextsnd.output'
        jobid = self.command.run_a_program(executable, nmlfile,
                                           outfile, wrkdir, jconf)

        # -------------- wait for it to be done -------------------
        if not self.command.wait_job('wrfextsnd', jobid, wait):
            self.command.addlog(-1, "SND", f'job failed: {jobid}')
            #raise SystemExit()

    # enddef run_wrfextsnd

    # ========================== WRFHYBRID =============================

    def run_wrfhybrid(self, runmode, wait):

        executable = os.path.join(self.runDirs.vardir, 'bin', 'wrfhybrid')
        tmplinput = self.runcase.getNamelistTemplate('wrfhybrid')

        jconf = self.runConfig['wrfhybrid']
        if jconf.mpi : executable += '_mpi'

        # ---------------- make working directory -------------------------

        wrkdir = os.path.join(self.caseDir, 'wrfhybrid%d' % runmode)
        if not os.path.lexists(wrkdir):
            os.mkdir(wrkdir)

        timestr = self.runcase.startTime.strftime('%Y-%m-%d_%H:%M:%S')
        wofstimestr = self.runcase.startTime.strftime('%Y%m%d%H%M')
        eventdate = self.runcase.eventDate.strftime('%Y%m%d')

        flagdir = os.path.join(self.runDirs['dartdir'], eventdate,'flags')
        wofsdir = os.path.join(self.runDirs['dartdir'], eventdate,wofstimestr)

        if runmode == 0:
            outdir = './'
            outbkg = '.TRUE.'
            outrct = '.FALSE.'
            outnew = '.FALSE.'
        else:
            outdir = wofsdir
            outbkg = '.FALSE.'
            outrct = '.FALSE.'
            outnew = '.TRUE.'

        inputfilename = 0
        if self.runcase.startTime == self.runcase.eventDate:
            inputfilename = 2

        # ---------------- Waiting for DART files -------------------------
        nen = 36
        if runmode == 0:
            afiles = []
            for n in range(1, nen+1):
                afile = os.path.join(flagdir, 'wrf_done%d' % n)
                afiles.append(afile)

            if self.command.wait_for_files('run_wrfhybrid', afiles, None, 300, 5, skipread=True) < len(afiles):
                self.command.addlog(-1, "WRFHYBRID",
                                    "Time out waiting for wrf_done.")

        else:
            flagfile = os.path.join(flagdir, f'done.filter_{wofstimestr}')
            self.command.wait_for_a_file(
                'run_wrfhybrid', flagfile, None, 300, 5, skipread=True)

        # --------------- make namelist file ------------------------------

        nmlfile = os.path.join(wrkdir, 'wrfhybrid.input')

        nmlgrp = namelist.decode_namelist_file(tmplinput)
        nmlin = {'program_mode'      : runmode,
                 'nproc_x'           : jconf.nproc_x,
                 'nproc_y'           : jconf.nproc_y,
                 'alpha'             : 0.5,
                 'nen'               : nen,
                 'dir_extm'          : wofsdir,
                 'filename_convention_d': inputfilename,
                 'init_time_str_m'   : timestr,

                 'start_time_str_m'  : timestr,
                 'end_time_str_m'    : timestr,
                 'outdir'            : outdir,

                 'dir_extd': '../news3dvar',

                 'out_bkg_mean': outbkg,
                 'out_rct_mean': outrct,
                 'out_memb_new': outnew
                 }

        nmlgrp.merge(nmlin)
        nmlgrp.writeToFile(nmlfile)

        # -------------- run the program from command line ----------------

        outfile = 'wrfhybrid.output'
        jobid = self.command.run_a_program(executable, nmlfile,
                                           outfile, wrkdir, jconf)

        # -------------- wait for it to be done -------------------
        if not self.command.wait_job('wrfhybrid', jobid, wait):
            self.command.addlog(-1, "HYBRID", f'job failed: {jobid}')
            #raise SystemExit()

        if runmode == 0:
            retfile = 'wrfinput_d01'
            bfile = os.path.join(flagdir, 'NEWSVAR.run')
            with open(bfile, 'w') as f:
                f.write('NEWSVAR is running\n')
        else:
            retfile = 'dart_memamean/wrfinput_d01'
            bfile = os.path.join(flagdir, f'done.hybrid_{wofstimestr}')
            with open(bfile, 'w') as f:
                f.write(f'HYBRID at {timestr} is done\n')

        return os.path.join(wrkdir, retfile)
    # enddef run_wrfhybrid

    # ========================  run_wrfdaupdate ========================

    def run_wrfdaupdate(self, use_base, wait):
        '''
          Run WRFDAUPDATE to prepare for a WRF forecast
          use_base : use background from earlier base run
        '''

        executable = os.path.join(self.runDirs.vardir, 'bin', 'wrfdaupdate')
        tmplinput = self.runcase.getNamelistTemplate('wrfdaupdate')

        mpiconfig = self.runConfig.wrfdaupdate

        wrkbas, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, 'wrf', numens=mpiconfig.numens)
        # background directory
        _nothing, tmpldirs = self.runcase.getwrkdir(
            self.caseDir, 'real', numens=self.runConfig.real.numens)
        # var directory
        _nothing, dadirs = self.runcase.getwrkdir(
            self.caseDir, 'news3dvar', False, self.runcase.nens)

        # -------------- Waiting for DA namelist and decode bkgfile ---
        # decode bkgfile from var namelist, and set bkgfiles

        danmls = [os.path.join(dadir, 'news3dvar.input') for dadir in dadirs]
        danmld = re.sub(r'_\d{1,3}$', '_*', dadirs[0])
        self.command.addlog(
            0, "cntl.daup", f"Waiting for news3dvar.input from {danmld} ...")
        if self.command.wait_for_files('cntl.daup', danmls, None, 600, 5) < len(danmls):
            self.command.addlog(-1, "cntl.daup",
                                f"Cannot find all news3dvar.input after {7200/3600} hours")

        bkgfiles = []
        for danml in danmls:
            nmlgrp = namelist.decode_namelist_file(danml)
            bkgfile = nmlgrp['initialization'].inifile
            bkgfiles.append(bkgfile)

            hdmpfmt = nmlgrp['history_dump'].hdmpfmt

        # -------------- Waiting for DA output ------------------------
        # wait var to finish, and set da_files

        if self.runcase.enrelax_in_workflow() and self.runcase.nens is not None:
            dadir_ctr = dadirs[0]
            dadirs = [os.path.join(self.caseDir, 'enrelax', f'mem_{iens}') for iens in range(
                1, self.runcase.nens+1)]
            dadirs.insert(0, dadir_ctr)

        da_files = [os.path.join(dadir, os.path.basename(bkgfile))
                    for dadir, bkgfile in zip(dadirs, bkgfiles)]
        dareadys = [re.sub(r'wrf(out|input)_d01',
                           r'wrf\g<1>Ready_d01', dafile) for dafile in da_files]
        dareadyf = os.path.basename(dareadys[0])
        dareadyd = re.sub(r'_\d{1,3}$', '_*', os.path.dirname(dareadys[0]))
        self.command.addlog(
            0, "cntl.daup", f"Waiting for {dareadyf} in {dareadyd} ...")
        if self.command.wait_for_files('cntl.daup', dareadys, None, 600, 5, skipread=True) < len(dareadys):
            self.command.addlog(-1, "cntl.daup",
                                f"Cannot find {dareadyf} after {3600/60} minutes")

        # ---------- To determine a real directory for templates ------
        if self.cmprun > 0:        # decode from self.runcase.cmpdir instead
            cmprundirs = [wrkdir.replace(
                self.command.wrkdir, self.runcase.rundirs.cmpdir) for wrkdir in wrkdirs]
            for i, wrkdir in enumerate(cmprundirs):
                if not os.path.lexists(wrkdir):
                    self.command.addlog(
                        0, "cntl.daup", f"Dir: {wrkdir} not exist.")
                    if wrkdir.find("wrf4") > 0:
                        newwrkdir = wrkdir.replace("wrf4", "wrf5")
                        if os.path.lexists(newwrkdir):
                            cmprundirs[i] = newwrkdir
                        else:
                            self.command.addlog(-1, "cntl.daup",
                                                f"Dir: {newwrkdir} not exist also.")
                    else:
                        self.command.addlog(-1, "cntl.daup",
                                            f"Dir: {wrkdir} not exist.")

            cmpdanmlfs = [os.path.join(wrkdir, 'wrfdaupdate.input')
                          for wrkdir in cmprundirs]

            tmplwinps = []
            tmplwbdys = []
            for cmpdanmlf in cmpdanmlfs:
                danml = namelist.decode_namelist_file(cmpdanmlf)
                tmplwinps.append(danml["input"].wrf_input_in)
                tmplwbdys.append(danml["input"].wrf_bdy_in)

        else:                  # actual run
            if self.runcase.nens is None:
                realdirs = ['dom20/real4', 'dom20/real5', 'dom00/real1']
            else:
                realdirs = ['dom20/real4_0', 'dom20/real5_0',
                            'dom00/real1_0', 'dom10/real2_0']

            if use_base:                 # for cycling forward forecast
                maxwaittime = 7200
                waittime = 0
                foundtmpl = False
                while waittime < maxwaittime:
                    for realdir in realdirs:    # found for control member only
                        tmpldir = os.path.join(
                            self.domain['cycle_base'], realdir)
                        self.command.addlog(
                            0, 'cntl.daup', 'Checking template directory <%s>.' % (tmpldir))
                        if os.path.lexists(tmpldir):
                            foundtmpl = True
                            break

                    if foundtmpl:
                        self.command.addlog(
                            0, 'cntl.daup', 'Use REAL file in directory <%s> for templates.' % (tmpldir))
                        break
                    waittime += 10
                    time.sleep(10)

                if not os.path.lexists(tmpldir):
                    self.command.addlog(-1, 'cntl.daup',
                                        'template directory <%s> do not exist.' % (tmpldir))

                if self.runcase.nens is None:
                    tmpldirs = [tmpldir]
                else:
                    tmpldirs = [re.sub(r"_0$", f"_{iens}", tmpldir) for iens in range(
                        0, self.runcase.nens+1)]

                # wait for real to be done
                #self.command.addlog(0,"cntl.daup",f"Checking for <rsl.error.0000> in tmpldir ...")
                #maxwaitime = 30*60
                #waitime = 0
                #realdone = False
                # while not realdone and waitime < maxwaitime :
                #  filename = os.path.join(tmpldir,'rsl.error.0000')
                #  if os.path.lexists(filename) :
                #    fh = open(filename,'r')
                #    for line in fh:
                #      if line.find('real_em: SUCCESS COMPLETE REAL_EM INIT') >= 0 :
                #        realdone = True
                #        break
                #  time.sleep(10)
                #  waitime += 10

            # ------- Wait for templates file to be ready and readible ----
            tmplwinps = [os.path.join(tmpldir, 'wrfinput_d01')
                         for tmpldir in tmpldirs]
            tmplwbdys = [os.path.join(tmpldir, 'wrfbdy_d01')
                         for tmpldir in tmpldirs]
            tmplwbdyd = re.sub(r'_\d{1,3}$', '_*',
                               os.path.dirname(tmplwbdys[0]))

            self.command.addlog(
                0, "cntl.daup", f"Waiting for wrfbdy_d01 in {tmplwbdyd} etc. ...")
            if self.command.wait_for_files('cntl.daup', tmplwbdys, None, 300, 5) < len(tmplwbdys):
                self.command.addlog(-1, "cntl.daup",
                                    f"Cannot find wrfinput_d01/wrfbdy_d01 after {600/60} minutes")

        # -------------- Prepare to run wrfdaupdate -------------------

        for wrkdir in wrkdirs:
            if not os.path.lexists(wrkdir):
                os.mkdir(wrkdir)

        nmlfile = 'wrfdaupdate.input'
        nmlfiles = [os.path.join(wrkdir, nmlfile) for wrkdir in wrkdirs]

        # ---------------- Check skip Conditions ------------------------
        skipdaupdate = False
        if self.runcase.skipwrfdaupdate:  # try to skip wrfdaupdate as possible
            if hdmpfmt == 1:
                skipdaupdate = True

        # ---------------- make namelist file ------------------------

        nextime = self.runcase.startTime + \
            timedelta(seconds=self.runcase.fcstSeconds)
        endtstr = nextime.strftime('%Y-%m-%d_%H:%M:%S')

        nmlgrp = namelist.decode_namelist_file(tmplinput)
        perturb_ic = nmlgrp['perturb'].perturb_ic
        perturb_lbc = nmlgrp['perturb'].perturb_lbc

        nmlin = {'end_time_str': endtstr,

                 'update_lateral_bdy': '.true.',
                 'update_input': '.true.',
                 'update_input_copy_td': '.true.',

                 'define_bdy': '.TRUE.',
                 'copy_input': '.TRUE.',

                 'outdir': './'
                 }

        nmlgrp.merge(nmlin)
        iens = 0
        for absnmlfile in nmlfiles:
            nmlgrp['input'].wrf_bdy_in = tmplwbdys[iens]
            nmlgrp['input'].wrf_input_in = tmplwinps[iens]
            nmlgrp['input'].da_file = da_files[iens]
            nmlgrp['input'].wrf_td_in = bkgfiles[iens]

            if iens == 0:  # To prevent control member from perturbing
                nmlgrp['perturb'].perturb_ic = 0
                nmlgrp['perturb'].perturb_lbc = 0
            else:          # recover the value from namelist template
                nmlgrp['perturb'].perturb_ic = perturb_ic
                nmlgrp['perturb'].perturb_lbc = perturb_lbc

            nmlgrp.writeToFile(absnmlfile)
            if skipdaupdate:
                inputfile = os.path.join(wrkdirs[iens], 'wrfinput_d01')
                bdyfile = os.path.join(wrkdirs[iens], 'wrfbdy_d01')
                self.command.copyfile(
                    da_files[iens], inputfile, hardcopy=False)
                self.command.copyfile(
                    tmplwbdys[iens], bdyfile,  hardcopy=False)
            iens += 1

        # -------------- run the program --------------------------
        if not skipdaupdate:

            for wrkdir in wrkdirs:  # clean legacy work file
                subprocess.call('rm -rf wrfinput_d01 wrfbdy_d01',
                                shell=True, cwd=wrkdir)

            hhmmstr = self.runcase.startTime.strftime('%H%M')
            outfile = 'daup%d_%s.output' % (self.runcase.caseNo, hhmmstr)

            jobid = self.command.run_a_program(
                executable, nmlfile, outfile, wrkbas, mpiconfig)

        # -------------- wait for it to be done -------------------
            if not self.command.wait_job('daupdate%02d' % self.domain.id, jobid, wait):
                self.command.addlog(-1, "DAUP", f'job failed: {jobid}')
                #raise SystemExit()

    # enddef run_wrfdaupdate

    # ========================== ENRELAX2PR =============================

    def run_enrelax(self, wait):

        executable = os.path.join(self.runDirs.vardir, 'bin', 'enrelax2pr')
        tmplinput = self.runcase.getNamelistTemplate('enrelax')

        jconf = self.runConfig['enrelax']
        if jconf.mpi : executable += '_mpi'

        # ---------------- make working directory -------------------------

        wrkdir = os.path.join(self.caseDir, 'enrelax')
        if not os.path.lexists(wrkdir):
            os.mkdir(wrkdir)
            os.mkdir(f"{wrkdir}/gnuplot")
            for iens in range(1, self.runcase.nens+1):
                os.mkdir(f"{wrkdir}/mem_{iens}")

        timestr = self.runcase.startTime.strftime('%Y-%m-%d.%H:%M:%S')

        _nothing, dadirs = self.runcase.getwrkdir(
            self.caseDir, 'news3dvar', False, self.runcase.nens)
        danml = os.path.join(dadirs[0], 'news3dvar.input')

        self.command.addlog(0, "cntl.enrelax", f"Waiting for {danml} ...")
        if not self.command.wait_for_a_file('cntl.enrelax', danml, None, 600, 5):
            self.command.addlog(-1, "cntl.enrelax",
                                f"Cannot find {danml} after {14400/3600} hours")
        nmlgrp = namelist.decode_namelist_file(danml)
        bkgfile = nmlgrp['initialization'].inifile

        # --------------- make namelist file ------------------------------

        hisfile = os.path.join(
            dadirs[0], f"wrfout_d01_{self.runcase.startTime:%Y-%m-%d_%H:%M:%S}")
        indir_e = re.sub(r"_\d{1,3}$", "_%0N", os.path.dirname(bkgfile))
        indir_a = re.sub(r"_\d{1,3}$", "_%0N", dadirs[0])

        nmlfile = os.path.join(wrkdir, 'enrelax2pr.input')

        assimtime = int(self.runcase.startTime.strftime('%H%M'))

        nmlgrp = namelist.namelistGroup.fromFile(tmplinput)
        nmlin = { 'nensmbl'           : self.runcase.nens,
                   'initime'           : timestr,
                   'hisfile'           : hisfile,
                   'rdinname_e'        : indir_e,
                   'rdinname_a'        : indir_a,
                   'assim_time'        : assimtime,
                   'iter'              : self.domain.cycle_num,
                   'dirname'           : f"{wrkdir}/mem_%0N",
                   'nproc_x'           : jconf.nproc_x,
                   'nproc_y'           : jconf.nproc_y,
                    #'max_fopen'         : jconf.nproc_x*jconf.nproc_y
                }

        nmlgrp.merge(nmlin)
        nmlgrp.writeToFile(nmlfile)

        # -------------- run the program from command line ----------------

        outfile = 'enrelax2pr.output'
        jobid = self.command.run_a_program(executable, nmlfile,
                                           outfile, wrkdir, jconf)

        # -------------- wait for it to be done -------------------
        if not self.command.wait_job('enrelax', jobid, wait):
            self.command.addlog(-1, "ENRELAX", f'job failed: {jobid}')
            #raise SystemExit()

    # enddef run_enrelax

    # %%%%%%%%%%%%%%%%%%%%%%  link extm  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    def check_link_extm(self, extdnames):
        ''' Link external data set'''

        # whether we want to do the actual work
        dowrk = self.domain.isroot

        mpiconfig = self.runConfig.ungrib
        _nothing, extmdirs = self.runcase.getwrkdir(
            self.caseDir, 'ungrib', numens=mpiconfig.numens)
        # os.path.join(os.path.dirname(self.caseDir),'ungrib%d'%(self.runcase.caseNo-1))
        for extmdir in extmdirs:
            if not os.path.lexists(extmdir):
                os.mkdir(extmdir)

        appext = None
        # link external grib files
        seclength = self.runcase.fcstSeconds
        # if self.runcase.caseNo == 1:
        #    seclength = max(self.runcase._cfg.fcstlngth[0],self.runcase._cfg.fcstlngth[1],
        #                    self.runcase._cfg.fcstlngth[3],self.runcase._cfg.fcstlngth[4] )

        for extdname in extdnames:

            extconf = self.runcase.getExtConfig(extdname)
            # forecast frequency and forecast file interval
            srcHour, extHour = extconf.extintvals

            extsrc = ExtMData(extdname, extconf)

            if 'srcTime' not in extsrc.keys():
                time1 = self.runcase.startTime

                if extdname == 'HRRRE':
                    initHour = 12
                    time2 = self.runcase.eventDate.replace(
                        hour=initHour, minute=0, second=0, microsecond=0)

                else:
                    # realtime use only data 2 hours ago
                    time2 = self.runcase.startTime - \
                        timedelta(hours=extconf.offset)
                    initHour = time2.hour//srcHour*srcHour

                # print extHour, srcHour, initHour

                exttime = time2.replace(
                    hour=initHour, minute=0, second=0, microsecond=0)
                # forecast starts from here
                expHour = int((time1-exttime).total_seconds()//3600)
                # find the earliest available external model forecast
                startHour = expHour//extHour*extHour
                # relative to exttime
                # offset to be added back from startHour
                expSec = (time1-(exttime+timedelta(hours=startHour))
                          ).total_seconds()
                lengthHr = (seclength+expSec)/3600
                # relative to exttime
                endHour = startHour + math.ceil(lengthHr/extHour)*extHour

            else:
                exttime = extsrc.srcTime
                startHour = int(
                    (extsrc.startTime - extsrc.srcTime).total_seconds()//3600)//extHour*extHour
                endHour = int(
                    (extsrc.endTime - extsrc.srcTime).total_seconds()//3600)//extHour*extHour

            n1total = int(endHour-startHour)//extHour+1
            ntotal = n1total
            if mpiconfig.numens is not None:
                ntotal *= (mpiconfig.numens+1)

            maxwaittime = extconf.waitparms.exist
            # just to check available external files
            if not self.check_job('ungrib'):
                maxwaittime = extconf.waitparms.tick   # wait one tick to speed up checking

            if mpiconfig.numens is None:
                mids = [1]         # use member 1 for HRRRE with control run, other, should be 0
            else:
                if extdname == 'HRRRE':
                    # use member 1 for HRRRE, otherwise, it has no meaning
                    mids = [1] + [(mid-1)%18 + 1 for mid in range(1, mpiconfig.numens+1)]
                else:
                    mids = [*range(0, mpiconfig.numens+1)]

            numtry = 0
            while numtry < extconf.numtry:
                numtry += 1

                itotal = 0

                extdats = [os.path.join(extconf.extdir, extconf.extsubdir.format(
                    exttime, iens=memid)) for memid in mids]
                extfiles = []
                for nj in range(startHour, endHour+1, extHour):
                    ij = nj - startHour
                    fls = [extconf.filext.format(
                        exttime, no=nj, iens=memid) for memid in mids]
                    absfls = [os.path.join(extdat, fl)
                              for fl, extdat in zip(fls, extdats)]
                    extfiles.append(absfls)

                extsub = re.sub(r"{iens:.*}", "*", extconf.extsubdir)
                extdat = os.path.join(extconf.extdir, extsub.format(exttime))
                self.command.addlog(
                    0, "cntl.extm", f"Waiting for {extdname}:{exttime:%Y%m%d_%H:%M:%S} in {extdat} ...")
                allextfils = [
                    extfile for extmfiles in extfiles for extfile in extmfiles]
                itotal = self.command.wait_for_files('link_extm', allextfils,
                                                     None, extconf.waitparms.ready, extconf.waitparms.tick,
                                                     expectSize=extconf.waitparms.size)

                if itotal < ntotal:
                    self.command.addlog(0, "cntl.extm",
                                        f"= Found {itotal}/{ntotal} files {extdname}:{exttime:%Y%m%d_%H:%M:%S} in {extdat}")
                    exttime = exttime - timedelta(hours=srcHour)
                    startHour = startHour + srcHour
                    endHour = startHour + (n1total-1)*extHour
                    # continue   ## next numtry
                else:
                    self.command.addlog(0, "cntl.extm",
                                        f"= Try {numtry} - Found all {ntotal} files {extdname}:{exttime:%Y%m%d_%H:%M:%S} in {extdat}")
                    appext = extconf.appext
                    extsrc['srcTime'] = exttime
                    extsrc['startTime'] = exttime + timedelta(hours=startHour)
                    extsrc['endTime'] = exttime + timedelta(hours=endHour)
                    break  # break out numtry
            else:
                continue  # next extdname
            break

        #
        # Finally, find one set of files.
        # Link them into ungrib directory
        #
        if itotal == ntotal:
            if dowrk:
                for idx, extmfiles in enumerate(extfiles):
                    self.command.addlog(
                        0, "EXTM", f"{appext} files for all members - {idx:03}:")
                    for memid, filepath in enumerate(extmfiles):
                        self.command.addlog(
                            0, "EXTM", f"member {memid:03} - {filepath}")

                aord = ord('A')

                for ij, extmfiles in enumerate(extfiles):
                    (ii, i1) = divmod(ij, 26)
                    (i3, i2) = divmod(ii, 26)
                    if i3 >= aord+26:
                        raise ValueError('RAN OUT OF GRIB FILE SUFFIXES!')
                    flname = 'GRIBFILE.%s%s%s' % (
                        chr(i3+aord), chr(i2+aord), chr(i1+aord))
                    # print flname
                    for extmdir, extfile in zip(extmdirs, extmfiles):
                        destfl = os.path.join(extmdir, flname)
                        if os.path.lexists(destfl):
                            os.unlink(destfl)
                        self.command.copyfile(extfile, destfl)
        else:
            self.command.addlog(-1, "EXTM", "Cannot find valid GRIB files.")

        #
        # For HRRRE 2021, use analysis at 1400Z
        #
        if self.runcase.caseNo == 1 and appext == "HRRRE" and dowrk:
            if mpiconfig.numens is None:
                mids = [0]
            else:
                mids = [mid for mid in range(0, mpiconfig.numens+1)]
            extconf = self.runcase.getExtConfig('HRRRDAS')
            absfls = [os.path.join(extconf.extdir,  extconf.extsubdir.format(exttime, iens=mid),
                                   extconf.filext.format(iens=mid)) for mid in mids]
            self.command.addlog(
                0, "EXTM", f"Replace <{appext}> files with <HRRRDAS> at {exttime:%Y%m%d_%H:%M:%S}")
            for memid, absfl in enumerate(absfls):
                self.command.addlog(0, "EXTM", f"member {memid:03} - {absfl}")
                if self.command.wait_for_a_file('cntl.hrrrdas', absfl, None, 600, 5):
                    flname = os.path.join(extmdirs[memid], 'GRIBFILE.AAA')
                    if os.path.lexists(flname):
                        os.unlink(flname)
                    self.command.copyfile(absfl, flname)
                else:
                    self.command.addlog(-1, "EXTM", "Cannot find %s" % (absfl))

        ##
        # link Vtable
        ##
        if appext is not None and dowrk:
            absfl = os.path.join(self.runDirs.wpsdir,
                                 'ungrib', 'Variable_Tables', 'Vtable.'+appext)
            for extmdir in extmdirs:
                vtable = os.path.join(extmdir, 'Vtable')
                if os.path.lexists(vtable):
                    os.unlink(vtable)
                self.command.copyfile(absfl, vtable, hardcopy=False)

        if appext is None:
            extsrc = None

        return extsrc
    # enddef check_link_extm

    # %%%%%%%%%%%%%%%%%  Preprocess Observation data %%%%%%%%%%%%%%%%%%%

    def check_wait_obs(self, obses):
        ''' Preprocess observations '''

        _nothing, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, 'news3dvar', False, self.runConfig.news3dvar.numens)
        # os.path.join(self.caseDir,'news3dvar')
        for wrkdir in wrkdirs:
            if not os.path.lexists(wrkdir):
                os.mkdir(wrkdir)

        # get time strings
        startime = self.runcase.startTime

        # --------------- find each observations -----------------------

        retobs = {'radar': [], 'ua': [], 'sng': [], 'conv': [], 'cwp': [],
                  'lightning1': [], 'lightning2': []}

        for obstype in obses:
            obsconf = self.runcase.getObsConfig(obstype)

            if obstype == 'radar':
                retobs['radar'] = self.check_wait_radar(startime, obsconf)
                #retobs['radar'] = self.check_wait_radar_radial(startime,obsconf.datdir)
                continue

            if obstype == '88vad':
                continue

            if obstype == "lightning1":
                retobs['lightning1'] = self.check_wait_ENTLN(
                    obstype, startime, obsconf, wrkdirs[0])
                continue

            if obstype == "lightning2":
                retobs['lightning2'] = self.check_wait_GLM(
                    obstype, startime, obsconf, wrkdirs[0])
                continue

            if obsconf.typeof in ('ua', 'cwp', 'conv'):
                retobs[obsconf.typeof] = self.check_wait_datfile(
                    obstype, startime, obsconf, wrkdirs[0])
            elif obsconf.typeof == 'sng':
                retobs['sng'] = self.check_wait_sng(
                    obstype, startime, obsconf, wrkdirs[0])
            else:
                self.command.addlog(-1, "cntl.obs",
                                    '    Error: unsupport obs type %s ... ' % (obsconf.typeof))

        ##
        # Log the observation files
        ##
        validobs = {}
        for (obskey, files) in retobs.items():
            if len(files) > 0:
                if isinstance(files[0], list):
                    filelst = [fl[0] for fl in files]
                else:
                    filelst = files
                self.command.addlog(
                    0, "cntl.obs", f'Found {len(files)} {obskey} files and they are:')
                for fn in filelst:
                    self.command.addlog(0, "cntl.obs", '        %s' % fn)

                validobs[obskey] = files
            else:
                self.command.addlog(
                    0, "cntl.obs", 'Found 0 "%s" files.' % (obskey))
                validobs[obskey] = []

        return validobs
    # enddef check_wait_obs

    # %%%%%%%%%%%%%%%%%  Wait for radar data %%%%%%%%%%%%%%%%%%%%%%%%%%%

    def check_wait_radar(self, startime, obsconf):
        ''' Wait for radar data'''

        _nothing, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, 'radremap', False, None)
        wrkdir = wrkdirs[0]
        if not os.path.lexists(wrkdir):
            os.mkdir(wrkdir)

        # fixed file name for easy process
        timstr = startime.strftime('%Y%m%d%H%M%S')

        radars = []
        waittime = 0
        time0 = time.time()
        if self.cmprun == 1 or self.cmprun == -1 or self.cmprun == -2:
            cmpraddir = wrkdir.replace(
                self.command.wrkdir, self.runcase.rundirs.cmpdir)
            radfls = glob.glob(os.path.join(cmpraddir, f"RADR_*{timstr}.raw"))
            for radfl in radfls:
                radflb = os.path.basename(radfl)
                radfile = os.path.join(wrkdir, radflb)
                self.command.copyfile(radfl, radfile, hardcopy=False)
                radar = radflb.partition("RADR_")[2].partition(timstr)[0]
                radars.append(radar)
        else:
            retro = False
            if datetime.utcnow()-startime > timedelta(minutes=5):
                retro = True

            # ---------------- looking for radar files ----------------------
            while waittime <= obsconf.maxwait:  # wait x minutes for complete radar set
                #radarsToCheck = set(self.radars).difference(set(radars))
                radarsToCheck = [
                    radar for radar in self.radars if radar not in radars]
                for radname in radarsToCheck:
                    radfound = False
                    radfile = os.path.join(
                        wrkdir, 'RADR_%s%s.raw' % (radname, timstr))
                    if os.path.lexists(radfile):
                        self.command.addlog(
                            0, "cntl.radar", 'Found radar data file %s ... ' % radfile)
                        radfound = True
                    else:
                        ##
                        # look for radar data files
                        ##
                        # in minutes, find in (-10, 10) range
                        for timemin in obsconf.timerange:
                            currTime = startime+timedelta(minutes=timemin)
                            datfile1 = os.path.join(obsconf.datdir,
                                                    obsconf.subdir.format(
                                                        radar=radname, time=currTime),
                                                    obsconf.filename.format(radar=radname, time=currTime))

                            self.command.addlog(
                                0, "cntl.radar", 'Looking for radar data file %s ... ' % datfile1)

                            datafls = glob.glob(datfile1)
                            #assert(len(datafls) <= 1)
                            if len(datafls) >= 1:
                                self.command.addlog(
                                    0, "cntl.radar", 'Found radar data file %s ... ' % datafls[0])
                                if not self.command.wait_for_a_file("check_wait_radar", datafls[0], 10, 180, 2):
                                    break
                                self.command.copyfile(
                                    datafls[0], radfile, hardcopy=True)
                                radfound = True
                                break  # timemin loop

                    if radfound:
                        radars.append(radname)

                if len(radars) < len(self.radars) and not retro:
                    time.sleep(10)
                    waittime += 10
                else:
                    break

        waittime   = time.time()-time0
        logmessage = f"Found {len(radars)} radar files after {waittime} seconds and they are [{', '.join(radars)}]"
        self.command.addlog(0, "cntl.radar", logmessage)
        # self.runcase.setCaseRadars(self.domID,radars)
        self.domain['usedradars']  = radars
        self.domain['search_done'] = True

        return radars
    # enddef check_wait_radar

    # %%%%%%%%%%%%%%%%%  Wait for radar radial velocity data %%%%%%%%%%%

    def check_wait_radar_radial(self, startime, obsdir):
        ''' Wait for radar data'''

        #import getradial

        _nothing, wrkdirs = self.runcase.getwrkdir(
            self.caseDir, 'radremap', False, None)
        wrkdir = wrkdirs[0]
        if not os.path.lexists(wrkdir):
            os.mkdir(wrkdir)

        # fixed file name for easy process
        timstr = startime.strftime('%Y%m%d%H%M%S')

        # ---------------- looking for radar within domain --------------

        #filelist = getradial.get_radial_list(startime,obsdir,self.radars)
        #
        # for radar in filelist.keys():
        #   if len(filelist[radar]) > 0:
        #       radlistfile = os.path.join(wrkdir,"RADR_%s%s.list" % (radar,timstr))
        #       raddir = os.path.join(wrkdir,radar)
        #       if not os.path.lexists(raddir): os.makedirs(raddir)
        #       with open(radlistfile,'w') as lfile:
        #            for fl in filelist[radar]:
        #                (radrelpath,radfname) = os.path.split(fl)
        #                flpaths = radrelpath.split(os.sep)
        #                (radfhead,radfext) = os.path.splitext(radfname)
        #                radfname = "%s_%s%s" %(radfhead,flpaths[2],radfext)
        #                absfile = os.path.join(obsdir,fl)
        #                wrkfile = os.path.join(raddir,radfname)
        #                if not os.path.lexists(wrkfile):
        #                    self.command.copyfile(absfile,wrkfile,hardcopy=True)
        #                print >> lfile, wrkfile
        #   else:
        #       filelist.pop(radar,None)
        #radars = filelist.keys()

        #
        # Run from backup
        #
        #filelist = getradial.get_radial_list(startime,obsdir,self.radars)
        #
        datestr = startime.strftime('%Y%m%d')
        radars = []
        for radar in self.radars:
            filelist = os.path.join(
                obsdir, datestr, "RADR_%s%s.list" % (radar, timstr))
            if os.path.lexists(filelist):
                wrklist = os.path.join(
                    wrkdir, "RADR_%s%s.list" % (radar, timstr))
                self.command.copyfile(filelist, wrklist, hardcopy=True)

                raddir = os.path.join(wrkdir, radar)
                if not os.path.lexists(raddir):
                    os.makedirs(raddir)

                lines = [line.rstrip('\n') for line in open(filelist)]

                for fl in lines:
                    (_nothing, radfname) = os.path.split(fl)
                    wrkfile = os.path.join(raddir, radfname)
                    self.command.copyfile(fl, wrkfile, hardcopy=True)
                radars.append(radar)

        self.command.addlog(0, "cntl.radar", 'Found %d radar files and they are [%s] ' % (
            len(radars), ', '.join(radars)))
        # self.runcase.setCaseRadars(self.domID,radars)
        self.domain['usedradars'] = radars
        self.domain['search_done'] = True

        return radars
    # enddef check_wait_radar_radial

    # %%%%%%%%%%%%%%%%%  Wait for satellite %%%%%%%%%%%%%%%%%%%%%%%%%%%%

    def check_wait_datfile(self, obstype, startime, obsconf, wrkdir):
        '''Prepare satellite CWP, Bufr, sounding (ua) data file
        '''

        retobsfl = []

        if obstype == "satcwp":
            currTime = startime-timedelta(minutes=(startime.minute % 15))
        elif obstype == "bufr":
            currTime = startime.replace(
                microsecond=0, second=0, minute=0)  # round to whole hour
        elif obstype == "ua":
            currTime = startime
        else:
            self.command.addlog(-1, "cntl.datfile",
                                "ERROR:unsupported obstype: %s" % obstype)

        if self.cmprun == 1 or self.cmprun == -1:
            cmpobsdir = wrkdir.replace(
                self.command.wrkdir, self.runcase.rundirs.cmpdir)
            obsfls = glob.glob(os.path.join(
                cmpobsdir, re.sub(r"{.*}", "*", obsconf.filename)))
            for datfile in obsfls:
                obsfileRe = os.path.basename(datfile)
                obsfileAb = os.path.join(wrkdir, obsfileRe)
                self.command.copyfile(datfile, obsfileAb, hardcopy=False)
                retobsfl.append(obsfileAb)
        else:
            obsfound = False
            baddatfl = False
            retro = False
            # ---------- looking for original observation files -----------
            if (datetime.utcnow()-startime) > timedelta(minutes=10):  # Not a real-time run
                retro = True

            waittime = 0
            while waittime < obsconf.maxwait:  # wait 10 seconds for each data set
                obsfileRe = obsconf.filename.format(currTime)
                obsfileAb = os.path.join(wrkdir, obsfileRe)

                if os.path.lexists(obsfileAb):
                    self.command.addlog(
                        0, "cntl.datfile", 'Found data file for %s as %s ... ' % (obstype, obsfileAb))
                    obsfound = True
                else:
                    for minrng in obsconf.timerange:
                        currTime = startime + timedelta(minutes=minrng)
                        obsfileRe = obsconf.filename.format(currTime)
                        datfile = os.path.join(obsconf.datdir,
                                               obsconf.subdir.format(currTime),
                                               obsfileRe)
                        self.command.addlog(
                            0, "cntl.datfile", 'Looking for data file %s ... ' % (datfile))

                        # -------- Preprocessing each datfile to get obsfile ---
                        if os.path.lexists(datfile):
                            obsfileAb = os.path.join(wrkdir, obsfileRe)
                            if os.path.lexists(obsfileAb):
                                os.unlink(obsfileAb)
                            #
                            # Wait dat file for it to be ready
                            #
                            if not self.command.wait_for_a_file('wait_datfile', datfile, 60, 60, 2, expectSize=obsconf.expsize):
                                baddatfl = True
                                break
                            #
                            # Everything is good now
                            #
                            self.command.copyfile(
                                datfile, obsfileAb, hardcopy=True)
                            self.command.addlog(
                                0, "cntl.datfile", 'Found data file %s ... ' % (datfile))
                            obsfound = True
                            break

                # Continue waiting or exit
                if obsfound:
                    retobsfl.append(obsfileAb)
                    break  # waittime loop
                if baddatfl or retro:
                    break

                # real-time run wait for maxwaittime seconds
                time.sleep(10)
                waittime += 10

        return retobsfl
    # enddef check_wait_datfile

    # %%%%%%%%%%%%%%%%%  Wait for surface obs %%%%%%%%%%%%%%%%%%%%%%%%%%

    def check_wait_sng(self, obstype, startime, obsconf, wrkdir):
        ''' Prepare surface observations'''

        # ---------- looking for original observation files -----------
        retobsfl = []

        if self.cmprun == 1 or self.cmprun == -1:
            obspattern = re.sub(r"{.*}", "*", obsconf.filename)
            ofilefix = ""
            if obstype == 'auto':
                ofilefix = ".lso"

            cmpobsdir = wrkdir.replace(
                self.command.wrkdir, self.runcase.rundirs.cmpdir)
            obsfls = glob.glob(os.path.join(
                cmpobsdir, f"{obspattern}{ofilefix}"))
            #print(os.path.join(cmpobsdir, obspattern))
            for datfile in obsfls:
                obsfileRe = os.path.basename(datfile)
                obsfileAb = os.path.join(wrkdir, obsfileRe)
                m = re.search(r"([0-9]{12})", obsfileRe)
                # print(m.group(1))
                if m:
                    filedt = datetime.strptime(m.group(1), '%Y%m%d%H%M')
                    if abs((filedt-startime)) < timedelta(hours=1):   # found the nearest one
                        # print((filedt-self.runcase.startTime).total_seconds())
                        obsfile1hr = os.path.join(cmpobsdir, obsconf.filename.format(
                            filedt-timedelta(hours=1))+ofilefix)
                        # print(obsfile1hr)
                        if os.path.lexists(obsfile1hr):
                            obsfile1hrRe = os.path.basename(obsfile1hr)
                            obsfile1hrAb = os.path.join(wrkdir, obsfile1hrRe)
                            self.command.copyfile(
                                obsfile1hr, obsfile1hrAb, hardcopy=False)
                        else:
                            obsfile1hrAb = 'none'
                        # print(obsfileAb,obsfile1hrAb)
                        self.command.copyfile(
                            datfile, obsfileAb, hardcopy=False)
                        retobsfl.append([obsfileAb, obsfile1hrAb])

        else:

            retro = False
            if (datetime.utcnow()-startime) > timedelta(minutes=10):
                retro = True

            obsfound = False
            if obstype == 'surf':

                waittime = 0
                while waittime < obsconf.maxwait:

                    # if startime.minute >= 15:
                    #    break    # waittime, break for next obstype

                    currTime = startime.replace(
                        microsecond=0, second=0, minute=0)  # round to whole hour

                    obsfileRe = obsconf.filename.format(currTime)
                    obsfileAb = os.path.join(wrkdir, obsfileRe)

                    currTime = startime - timedelta(hours=1)   # 1 hour ealier
                    obsfile1hrAb = os.path.join(
                        wrkdir, obsconf.filename.format(currTime))

                    if os.path.lexists(obsfileAb) and os.path.lexists(obsfile1hrAb):
                        self.command.addlog(
                            0, "cntl.sng", 'Found data file for %s as %s ... ' % (obstype, obsfileAb))
                        obsfound = True
                    else:
                        for minrng in obsconf.timerange:
                            currTime = startime + timedelta(minutes=minrng)

                            obsfileRe = obsconf.filename.format(currTime)
                            datfile = os.path.join(obsconf.datdir,
                                                   obsconf.subdir.format(
                                                       currTime),
                                                   obsfileRe)
                            self.command.addlog(
                                0, "cntl.sng", 'Looking for data file %s ... ' % (datfile))

                            # -------- Preprocessing each datfile to get obsfile ---
                            if os.path.lexists(datfile):
                                obsfileAb = os.path.join(wrkdir, obsfileRe)
                                if not self.command.wait_for_a_file('wait_sng', datfile, 60, 60, 2, expectSize=obsconf.expsize):
                                    break
                                self.command.copyfile(
                                    datfile, obsfileAb, hardcopy=True)
                                self.command.addlog(
                                    0, "cntl.sng", 'Found data file %s ... ' % (obsfileAb))
                                obsfound = True
                                break

                        # SNG needs 1 hour early obseration for time check
                        if obsfound:
                            currTime = currTime - timedelta(hours=1)

                            datfile1hrRe = obsconf.filename.format(currTime)
                            datfile1hr = os.path.join(obsconf.datdir,
                                                      obsconf.subdir.format(
                                                          currTime),
                                                      datfile1hrRe)
                            self.command.addlog(
                                0, "cntl.sng", 'Looking for data file %s ... ' % (datfile1hr))

                            if os.path.lexists(datfile1hr):
                                obsfile1hrAb = os.path.join(
                                    wrkdir, datfile1hrRe)
                                self.command.copyfile(
                                    datfile1hr, obsfile1hrAb, hardcopy=True)
                                self.command.addlog(
                                    0, "cntl.sng", 'Found data file %s ... ' % (obsfile1hrAb))
                                obsfound = True
                            else:
                                obsfile1hrAb = 'None'

                    # Continue waiting or exit
                    if obsfound:
                        # retobsfl.append([obsfileAb,obsfile1hrAb])
                        retobsfl.append([obsfileAb, " "])
                        break  # waittime loop

                    if retro:
                        break

                    time.sleep(10)
                    waittime += 10

            elif obstype == 'auto':    # Convert OK mesonet to LSO format

                stnfilename = os.path.join(
                    self.runDirs.inputdir, obsconf.stnfile)
                lonmin, latmin, lonmax, latmax = prep_okmeso.findRange(
                    stnfilename)

                if self.domain.checkRange(latmin, latmax, lonmin, lonmax, 100):
                    waittime = 0
                    while waittime < obsconf.maxwait:

                        currTime = startime
                        obsfileRe = obsconf.filename.format(currTime)
                        obsfileAb = os.path.join(wrkdir, "%s.lso" % obsfileRe)

                        time5min = startime.minute % 5
                        mystartime = startime - \
                            timedelta(minutes=time5min)   # round to 5 minutes

                        # round to 5 minutes
                        currTime = mystartime - timedelta(hours=1)
                        obsfile1hrRe = obsconf.filename.format(currTime)
                        obsfile1hrAb = os.path.join(
                            wrkdir, "%s.lso" % obsfile1hrRe)

                        # and os.path.lexists(obsfile1hrAb):
                        if os.path.lexists(obsfileAb):
                            self.command.addlog(0, "cntl.auto", 'Found data file for %s as %s and %s ... ' % (
                                obstype, obsfileAb, obsfile1hrAb))
                            obsfound = True
                        else:
                            for minrng in obsconf.timerange:
                                currTime = mystartime + \
                                    timedelta(minutes=minrng)

                                obsfileRe = obsconf.filename.format(currTime)
                                datfile = os.path.join(obsconf.datdir,
                                                       obsconf.subdir.format(
                                                           currTime),
                                                       '%s.mdf' % obsfileRe)
                                self.command.addlog(
                                    0, "cntl.auto", 'Looking for data file %s ... ' % (datfile))

                                # -------- Preprocessing each datfile to get obsfile ---
                                if os.path.lexists(datfile):
                                    obsfileAb = os.path.join(
                                        wrkdir, '%s.lso' % (obsfileRe))
                                    if not self.command.wait_for_a_file('wait_sng', datfile, 60, 60, 2, expectSize=obsconf.expsize):
                                        break
                                    # self.command.copyfile(datfile,obsfileAb,hardcopy=True)
                                    prep_okmeso.meso2lso(
                                        datfile, stnfilename, obsfileAb)
                                    self.command.addlog(
                                        0, "cntl.auto", 'Found data file %s ... ' % (obsfileAb))
                                    obsfound = True
                                    break

                            # SNG needs 1 hour early obseration for time check
                            if obsfound:
                                currTime = currTime - timedelta(hours=1)

                                datfile1hrRe = obsconf.filename.format(
                                    currTime)
                                datfile1hr = os.path.join(obsconf.datdir,
                                                          obsconf.subdir.format(
                                                              currTime),
                                                          '%s.mdf' % datfile1hrRe)
                                self.command.addlog(
                                    0, "cntl.auto", 'Looking for data file %s ... ' % (datfile1hr))

                                if os.path.lexists(datfile1hr):
                                    obsfile1hrAb = os.path.join(
                                        wrkdir, '%s.lso' % (datfile1hrRe))
                                    # self.command.copyfile(datfile1hr,obsfile1hrAb,hardcopy=True)
                                    prep_okmeso.meso2lso(
                                        datfile1hr, stnfilename, obsfile1hrAb)
                                    obsfound = True
                                else:
                                    obsfile1hrAb = 'None'

                        # Continue waiting or exit
                        if obsfound:
                            retobsfl.append([obsfileAb, obsfile1hrAb])
                            break  # waittime loop

                        if retro:
                            break

                        time.sleep(10)
                        waittime += 10
                else:
                    self.command.addlog(
                        0, "cntl.sng", "WARNING: OK mesonet is outside of the domain. Skipping ...")
            else:
                self.command.addlog(-1, "cntl.sng",
                                    'Error: unsupport obs type %s ... ' % (obstype))

        return retobsfl
    # enddef check_wait_sng

    # %%%%%%%%%%%%%%%%%  Wait for lightning file %%%%%%%%%%%%%%%%%%%%%%%

    def check_wait_ENTLN(self, obstype, startime, obsconf, wrkdir):
        ''' Prepare ENTLN lightning observations'''

        # ---------- looking for original observation files -----------
        obsfound = False
        retobsfl = []

        obsdir = obsconf.datdir

        retro = False
        if (datetime.utcnow()-startime) > timedelta(minutes=10):  # Not a real-time run
            retro = True

        waittime = 0
        while waittime < obsconf.maxwait:
            currTime = startime-timedelta(minutes=(startime.minute % 5))
            timstr = currTime.strftime('%y%j')
            obsfileRe = '%s_entln.nc' % (timstr)
            obsfileAb = os.path.join(wrkdir, obsfileRe)
            if os.path.lexists(obsfileAb):
                self.command.addlog(
                    0, "cntl.lgt", 'Found ENTLN data file for %s as %s ... ' % (obstype, obsfileAb))
                obsfound = True
            else:
                for minrng in obsconf.timerange:
                    currTime = currTime + timedelta(minutes=minrng)
                    timstrsrc = currTime.strftime('%y%j')
                    timstrsrc2 = currTime.strftime('%y%j')
                    obsfileRe = '%s_entln.nc' % (timstrsrc)
                    datfile = os.path.join(obsdir, obsfileRe)
                    self.command.addlog(
                        0, "cntl.lgt", 'Looking for ENTLN data file %s ... ' % (datfile))
                    # -------- Preprocessing each datfile to get obsfile ---
                    if self.runDirs['obsvar'][obstype]['prepro']:
                        subprocess.call('ncrcat %(obsdir)s/%(yd)s17050005r %(obsdir)s/%(yd)s17[1-5][05]0005r %(obsdir)s/%(yd)s18000005r %(outfile)s' % {
                                        'obsdir': obsdir, 'outfile': obsfileRe, 'yd': timstrsrc2}, shell=True, cwd=wrkdir)

                        obsfileAb = os.path.join(wrkdir, obsfileRe)
                    if os.path.lexists(obsfileAb):
                        obsfound = True
                        break

                    if os.path.lexists(datfile):
                        if os.path.lexists(obsfileAb):
                            os.unlink(obsfileAb)
                        self.command.copyfile(
                            datfile, obsfileAb, hardcopy=True)
                        obsfound = True
                        break

            # Continue waiting or exit
            if obsfound:
                retobsfl.append(obsfileAb)
                break  # waittime loop

            if retro:
                break

            time.sleep(10)
            waittime += 10

        return retobsfl
    # enddef check_wait_ENTLN

    # %%%%%%%%%%%%%%%%%  Wait for lightning file (GLM)%%%%%%%%%%%%%%%%%%

    def check_wait_GLM(self, obstype, startime, obsconf, wrkdir):
        ''' Prepare GLM lightning observations'''

        #ncopath= "/scratch/software/Odin/python/anaconda2/bin"

        # ---------- looking for original observation files -----------
        retobsfl = []

        retro = False
        if (datetime.utcnow()-startime) > timedelta(minutes=10):  # Not a real-time run
            retro = True

        if self.cmprun == 1 or self.cmprun == -1:
            cmpobsdir = wrkdir.replace(
                self.command.wrkdir, self.runcase.rundirs.cmpdir)
            glmfls = glob.glob(os.path.join(
                cmpobsdir, re.sub(r"{.*}", "*", obsconf.filename)))
            for datfile in glmfls:
                obsfileRe = os.path.basename(datfile)
                obsfileAb = os.path.join(wrkdir, obsfileRe)
                self.command.copyfile(datfile, obsfileAb, hardcopy=False)
                retobsfl.append(obsfileAb)
        else:
            obsfound = False
            waittime = 0
            while waittime < obsconf.maxwait:
                currTime = startime-timedelta(minutes=(startime.minute % 5))
                obsfileRe = obsconf.filename.format(currTime)
                obsfileAb = os.path.join(wrkdir, obsfileRe)

                if os.path.lexists(obsfileAb):
                    self.command.addlog(
                        0, "cntl.lgt", 'Found GLM data file for %s as %s ... ' % (obstype, obsfileAb))
                    obsfound = True
                else:
                    for minrng in obsconf.timerange:
                        currTime = currTime + timedelta(minutes=minrng)

                        obsfileRe = obsconf.filename.format(currTime)
                        datfile = os.path.join(obsconf.datdir,
                                               obsconf.subdir, obsfileRe)

                        self.command.addlog(
                            0, "cntl.lgt", 'Looking for GLM data file %s ... ' % (datfile))

                        if os.path.lexists(datfile):
                            obsfileAb = os.path.join(wrkdir, obsfileRe)
                            if not self.command.wait_for_a_file('wait_lightning', datfile, 60, 60, 2):
                                break
                            self.command.copyfile(
                                datfile, obsfileAb, hardcopy=True)
                            self.command.addlog(
                                0, "cntl.GLM", 'Found data file %s ... ' % (obsfileAb))
                            obsfound = True
                            break

                # Continue waiting or exit
                if obsfound:
                    retobsfl.append(obsfileAb)
                    break  # waittime loop

                if retro:
                    break
                # real-time run wait for maxwaittime seconds
                time.sleep(10)
                waittime += 10

        return retobsfl
    # enddef check_wait_GLM

    # %%%%%%%%%%%%%%%%%  Wait for MRMS files %%%%%%%%%%%%%%%%%%%%%%%%

    def check_wait_mrms(self, startime, obsconf, wrkdir):
        ''' Prepare mrms data in grib2 format'''

        mrmslvls = ['00.50', '00.75', '01.00', '01.25', '01.50',
                    '01.75', '02.00', '02.25', '02.50', '02.75', '03.00', '03.50',
                    '04.00', '04.50', '05.00', '05.50', '06.00', '06.50', '07.00',
                    '07.50', '08.00', '08.50', '09.00', '10.00', '11.00', '12.00',
                    '13.00', '14.00', '15.00', '16.00', '17.00', '18.00', '19.00']

        # ---------- looking for original observation files -----------
        obsfound = False
        foundfiles = []

        currTime = startime
        obsfileRe = [obsconf.filename.format(
            currTime, level=lvl) for lvl in mrmslvls]
        obsfileAb = [os.path.join(wrkdir, fileRe) for fileRe in obsfileRe]

        obsfound = True
        for fileAb in obsfileAb:
            if os.path.lexists(fileAb):
                foundfiles.append(fileAb)
            else:
                obsfound = False
                foundfiles = []
                break

        if obsfound:
            self.command.addlog(
                0, "cntl.mrms", 'Found all MRMS files at %s ... ' % currTime)
        else:      # search for file in earlier time

            retro = False
            if (datetime.utcnow()-startime) > timedelta(minutes=10):
                retro = True

            waittime = 0
            while waittime < obsconf.maxwait:
                for minrng in obsconf.timerange:
                    currTime = startime + timedelta(minutes=minrng)
                    timstrsrc = currTime.strftime('%Y%m%d-%H%M')
                    ldmdir = obsconf.subdir.format(currTime)

                    obsfileRe = [obsconf.filename.format(
                        currTime, level=lvl) for lvl in mrmslvls]
                    obsfileAb = [os.path.join(wrkdir, fileRe)
                                 for fileRe in obsfileRe]

                    obsfileSr = ['MRMS_MergedReflectivityQC_%s_%s??.grib2.gz' % (
                        lvl, timstrsrc) for lvl in mrmslvls]
                    datfiles = [os.path.join(
                        obsconf.datdir, ldmdir, fileSr) for fileSr in obsfileSr]
                    self.command.addlog(
                        0, "cntl.mrms", 'Looking for %s ... ' % (datfiles[0]))

                    # -------- Preprocessing each datfile to get obsfile ---
                    i = 0
                    for datfile in datfiles:     # each level
                        datafls = glob.glob(datfile)
                        #assert(len(datafls) <= 1)
                        if len(datafls) >= 1:
                            if not self.command.wait_for_a_file('wait_mrms', datafls[0], 60, 120, 2, expectSize=obsconf.expsize):
                                break
                            with gzip.open(datafls[0], 'rb') as f_in:
                                with open(obsfileAb[i], 'wb') as f_out:
                                    shutil.copyfileobj(f_in, f_out)
                            # self.command.copyfile(srcfile,obsfileAb[i],hardcopy=False)
                            self.command.addlog(
                                0, "cntl.mrms", 'Found data file %s ... ' % datafls[0])
                            foundfiles.append(obsfileAb[i])
                        else:
                            foundfiles = []
                            break
                        i += 1

                    if len(foundfiles) == len(mrmslvls):
                        obsfound = True
                        break

                # Continue waiting or exit
                if obsfound or retro:
                    break  # waittime loop

                time.sleep(10)
                waittime += 10

        return foundfiles
    # enddef check_wait_mrms

# endclass
