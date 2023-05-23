#!/usr/bin/env python
import logging
import subprocess as sp
import os, re
import urllib2
import time
import sys,getopt
import os.path
from datetime import datetime,timedelta
import threading

import argparse

########################################################################

def download_hrrr(fcsthour):
    try:
        logging.info('Starting downloading HRRR data forecast hour %d ...'%fcsthour)
        url1="http://www.ftp.ncep.noaa.gov/data/nccf/com/hrrr/prod/"

        dirstr    = "hrrr.%s" % (initdate)

        ff = fcsthour

        filename='hrrr.t%02dz.%s%02d.grib2' % (inithr,filepattern,ff)

        url="%s/%s/conus/%s" % (url1,dirstr,filename)
        logging.info("url: %s"%url)

        output=os.path.join(output_dir,filename)

        tCHUNK = 512*1024
        downstr = ' '
        try :
          req = urllib2.urlopen(url)
          with open(output,'wb') as fp :
            while True :
              fchunk = req.read(tCHUNK)
              if not fchunk : break
              fp.write(fchunk)
            downstr = ' ... '
        except urllib2.HTTPError as e:
          logging.error('HTTP Error with code: %d.' % e.code )
        except urllib2.URLError as e :
          logging.error('URL Error with reason: %s.' % e.reason )

        #downstr = ' '
        #if not os.path.isfile(output) :
        #    urllib.urlretrieve(url,output)
        #    downstr = ' ... '
        #    time.sleep(10)  # wait 10 second between each download

        #cmdarg=['curl','--retry','5','--retry-delay','10','-o',output,url]
        #sp.call(cmdarg)

        fsize = os.path.getsize(output)
        if fsize < expectfs :
            logging.info('%s size (%d) less than %dK.'% (output,fsize,expectfs/1024))
        else :
            logging.info('%s%s(%d)' % (output,downstr,fsize) )

    except Exception,x:
        logging.error('download HRRR data: %s' % x)
        return

########################################################################

def check_results(output_dir, hourlst):
    hourmss = []
    for ff in hourlst :   #range(0,hours,3):
        filename=os.path.join(output_dir,'hrrr.t%02dz.%s%02d.grib2' % (inithr,filepattern,ff))
        if os.path.isfile(filename) :
            if os.path.getsize(filename) < expectfs :
                os.unlink(filename)
                logging.error('The file %s size less than %dK, something is wrong. Should be re-downloaded.'%(filename,expectfs/1024))
                hourmss.append(ff)
        else:
            logging.error('File %s missed. Should be re-downloaded.'%(filename,))
            hourmss.append(ff)

    return hourmss


########################################################################

class CustomFormatter(argparse.RawTextHelpFormatter, argparse.ArgumentDefaultsHelpFormatter):
    pass

def parse_command_line():

  parser = argparse.ArgumentParser(description='Download HRRR from NCEP server',
                                   epilog='''        \t\t---- Yunheng Wang (2018-04-19).
                                          ''',
                                   formatter_class=CustomFormatter)

  parser.add_argument('date',nargs='?',
                      help='date (YYYYMMDDHH)',default=None)
  parser.add_argument('-wrk','--run_dir',
                      help='Work directory',default="/work/ywang/saved_data/HRRR")
  parser.add_argument('-d','--data',default="wrfprsf",
                      help='dataset pattern, one of [wrfnatf,wrfsfcf,wrfprsf,wrfsubhf]')

  parser.add_argument('-max','--max_try',default=12,type=int,
                    help='number of tries before abortion')
  parser.add_argument('-i','--delay',default=10,type=int,
                    help='delay between each file download try ')
  parser.add_argument('-s','--size',default=320000000,type=int,
                    help='expected file size in bytes')

  args = parser.parse_args()

  return args

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if __name__=='__main__':
# crontab -e:add below two lines:
# 10 15 * * * download_HRRR.py
# 10 03 * * * download_HRRR.py

    args = parse_command_line()

    run_dir=args.run_dir
    filepattern=args.data

    initdate=None
    if args.date is None:
        utcnow=datetime.utcnow()-timedelta(hours=1)
        initdate=utcnow.strftime("%Y%m%d")
        inithr=utcnow.hour
    else:
      dt=re.match('(\d{8})(\d{2})',args.date)
      initdate = dt.group(1)
      inithr   = int(dt.group(2))

    maxtries = args.max_try
    delaysec = args.delay         # delay between each file download try
    expectfs = args.size          # expected file size

    #print run_dir, filepattern, initdate, inithr,args.max_try,args.delay,args.size
    #sys.exit(0)

    os.chdir(run_dir)

    output_dir=os.path.join(run_dir,initdate)
    LOG_FILENAME=os.path.join(run_dir,'%s_%s%02d.log'%(filepattern,initdate,inithr))
    #print(LOG_FILENAME)
    if os.path.isfile(LOG_FILENAME):
        os.remove(LOG_FILENAME)
    logging.basicConfig(filename=LOG_FILENAME,level=logging.INFO,format='%(levelname)s: %(message)s')
    logging.info('The inittime is (%s %sZ) and data saves to "%s".'%(initdate,inithr,output_dir))
    logging.info('Beginning time: <%s>'%(datetime.now(),))

    #using while to re-downloading
    count=1
    totalcount = 19     # Download all 18 hour forecasts
    if inithr > 15:
        totalcount -= (inithr-15)
    hourlst = range(0,totalcount,1)  # 1-hour interval
    numbers = len(hourlst)

    while(count <= maxtries):
        logging.info('--- No. [%s] download try for "%s" at <%s> ---'%(count,filepattern,datetime.now()))
        if not os.path.exists(output_dir):
            os.mkdir(output_dir)

        #
        # Download Threading for each file
        #
        dwnP=[]
        for ff in hourlst:
            t = threading.Thread(target=download_hrrr, args = (ff,))
            t.start()
            dwnP.append(t)
            time.sleep(90)    # Start downloading next file in 90 seconds

        while threading.activeCount() > 1:
          for p in dwnP:
            if p.isAlive() : p.join(10)

        #
        # Verify downloads
        #
        hourmss=check_results(output_dir,hourlst)
        num = len(hourmss)
        if num == 0:
            logging.info('=== Download "%s" Successful at <%s> ===' % (filepattern,datetime.now(),) )
            break
        else:
            logging.info("### There are [%d] (of [%d]) files missed ###" % ( num,numbers ) )
            logging.info("    [%s]" % (','.join(map(str,hourmss)) ) )

            if count >= maxtries:
               logging.info('*** Download "%s" Failture at <%s> ***' % (filepattern,datetime.now(),) )
               break
            else :
               #sp.call('rm -rf %s'%(output_dir,),shell=True)
               hourlst = hourmss  # re-download missing hours only

            logging.info("### Will be retried in %d seconds from now (%s) ###" % ( delaysec,datetime.now() ) )

            count=count+1
            time.sleep(delaysec)
