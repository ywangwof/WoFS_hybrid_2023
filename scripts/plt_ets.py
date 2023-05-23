#!/usr/bin/env python3
##
##----------------------------------------------------------------------
##
## This file contains program to read and plot ets/fss scores generated
## by program neighbor_ets/neighbor_fss.
##
## ---------------------------------------------------------------------
##
## HISTORY:
##   Yunheng Wang (11/25/2020)
##   Initial version based on early works.
##
##
########################################################################
##
## Requirements:
##
##   o Python 3.8 or above
##
########################################################################

import csv
import numpy as np
import matplotlib.pyplot as plt

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

    def __eq__(self, obj):
        for k,v in self.items():
            if v != obj[k]:
                return False
        return True

    def __ne__(self, obj):
        for k,v in self.items():
            if v != obj[k]:
                return True
        return False

#endclass Dict2Obj

########################################################################

def decode_header(filename):
  '''
     Decode vscore_CREF_20200507_2100.ets/fss
  '''

  headers = Dict2Obj()
  with open(filename, 'r') as csvfile:
      reader = csv.reader(csvfile)
      row = next(reader)
      for el in row:
          dimstr = el.split('=')
          headers[dimstr[0].lstrip()] = int(dimstr[1])

      thres = []
      row = next(reader)
      for el in row:
          threstr = el.split('=')
          threslist = threstr[1].split()
          for tel in threslist:
              thres.append(float(tel))
      headers['thres'] = thres

      radius = []
      row = next(reader)
      for el in row:
          radstr = el.split('=')
          radlist = radstr[1].split()
          for tel in radlist:
              radius.append(float(tel))
      headers['radius'] = radius

      times = np.loadtxt(filename, skiprows = 3, usecols=0, max_rows=headers.ntime)
      headers['times'] = list(times)

  return headers

########################################################################

def plot_scores(name,dimsize,values,caselist,timesplt,timelabels):
    '''
    plot score "name"
    values is a list corresponding to files for the scores(nthres, ntimes, nradius)
    '''

    ntimes = len(timesplt)
    nfiles = len(values)

    for r in range(dimsize.nradius):  # each raidus create a file
        outfile = f"{name}_{dimsize.radius[r]}km.png"

        fig, ax = plt.subplots(2, 2, figsize=(11, 8))
        axs = ax.flat

        for n in range(dimsize.nthres):

            varplt = np.zeros((ntimes,nfiles))
            for f,value in enumerate(values):
                ts = f//nfiles*2
                for nt in range(dimsize.ntime):
                    varplt[nt+ts,f] = value[n,nt,r]

            axs[n].plot(timesplt,varplt,'.--',color='r',label=f"{name}")

            if n > 1: axs[n].set(xlabel="forecast hours",ylabel=f"{name} ({dimsize.thres[n]} dBZ)")
            else:     axs[n].set(                        ylabel=f"{name} ({dimsize.thres[n]} dBZ)")

            title = f'{name} at 20200507 raidus = {dimsize.radius[r]} km'
            axs[n].set_title(title,fontsize=8)

        print(f"Saving figure to {outfile} ...")
        fig.savefig(outfile, format='png')


#############################  Portral   ###############################

if __name__ == "__main__":

    filenames = [   "/scratch/ywang/test_runs/verif_ens/mixing/20200507/2100Z/vscore_CREF_20200507_2100.ets",
                    "/scratch/ywang/test_runs/verif_ens/norelax/20200507/2100Z/vscore_CREF_20200507_2100.ets",
                    "/scratch/ywang/test_runs/verif_ens/sampling/20200507/2100Z/vscore_CREF_20200507_2100.ets",
                    "/scratch/ywang/test_runs/verif_ens/mixing/20200507/2200Z/vscore_CREF_20200507_2200.ets",
                    "/scratch/ywang/test_runs/verif_ens/norelax/20200507/2200Z/vscore_CREF_20200507_2200.ets",
                    "/scratch/ywang/test_runs/verif_ens/sampling/20200507/2200Z/vscore_CREF_20200507_2200.ets",
                    "/scratch/ywang/test_runs/verif_ens/mixing/20200507/2300Z/vscore_CREF_20200507_2300.ets",
                    "/scratch/ywang/test_runs/verif_ens/norelax/20200507/2300Z/vscore_CREF_20200507_2300.ets",
                    "/scratch/ywang/test_runs/verif_ens/sampling/20200507/2300Z/vscore_CREF_20200507_2300.ets" ]

    cases = ["mxing","norelax","sampling"]

    timelabels = ["21","22","23","00","01","02","03","04","05"]

    plttimes = []
    for nt in range(0, 6*2+1):
        plttimes.append(0.5*nt)

    dims = decode_header(filenames[0])

    scores = []
    for filename in filenames:
        fdims = decode_header(filename)

        if fdims != dims:
            print(f'ERROR: {filename} contains difference dimension sizes.')
        scorein = np.loadtxt(filename, skiprows = 3, usecols=range(1,dims.nradius+1))
        scores.append(scorein.reshape(dims.nthres,dims.ntime,dims.nradius))

    plot_scores('ETS',dims,scores,cases,plttimes,timelabels)
