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
##   Yunheng Wang (05/15/2020)
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

import sys, os, re
from argparse import Namespace

import namelist

# Load the dictionary into a Namespace data structure.
# This step is not necessary, but cuts down the syntax needed to reference each item in the dict.
#

def make_namespace(d: dict):
    assert(isinstance(d, dict))

    ns = Namespace()
    for k, v in d.items():
        if isinstance(v, dict):
            leaf_ns = Namespace()
            ns.__dict__[k] = leaf_ns
            make_namespace(leaf_ns, v)
        else:
            ns.__dict__[k] = v
    return ns

###################################################################
##
## Given values in namelist.py string format and get the real values
## in Fortran format.
##
###################################################################

def getvaluelst(values,vartype,opts) :
    retlst = []
    prep0  = False
    for val in values :
      if type(val) is list :
        retlst.append(getvaluelst(val,vartype,opts))
      else :
        if vartype == 'int0' :
          retlst.append(int(val))
          prep0 = True
        else :
          retlst.append(vartype(val))
    if prep0 and opts.insert:
        if opts.verb:
            print(f"Inserting leaind 0 for {values}")
        retlst.insert(0,0)

    return retlst
#enddef getvaluelst

##========================== news3dvar =============================

def run_news3dvar(inmlfile,outnmlfile,opts) :
    '''
      Run or submit news3dvar job
    '''

    nmlgrp = namelist.decode_namelist_file(inmlfile)

    ##
    ## Trim run-time namelist with npass
    ##
    if opts.npass > 0:
        npass = opts.npass
    else:     # use npass from input file
        npass = nmlgrp['adas_const'].npass

    ################# Variables that depends on npass #############

    vardpass = {'adas_radar'  : { 'iuserad' : 'int0' }
               ,'adas_sng'    : { 'iusesng' : 'int0' }
               ,'adas_ua'     : { 'iuseua'  : 'int0' }
               ,'adas_cwp'    : { 'iusecwp' : 'int0' }
               ,'adas_tpw'    : { 'iusetpw' : 'int0' }
               ,'adas_conv'   : { 'iuseconv': int    }
               ,'adas_retrieval' : { 'iuseret' : 'int0' }
               ,'var_const'   : { 'maxin'           : int
                                 ,'vrob_opt'        : int
                                 ,'cldfirst_opt'    : int
                                 ,'qobsrad_bdyzone' : int }
               ,'var_refil'   : { 'ipass_filt' : int
                                 ,'hradius'    : float
                                 ,'vradius'    : float
                                 ,'vradius_opt' : int
                                }
               ,'var_diverge' : { 'wgt_div_h'  : float
                                 ,'wgt_div_v'  : float
                                }
               ,'var_smth'    : { 'wgt_smth'   : float }
               ,'var_thermo'  : { 'wgt_thermo' : float }
               ,'var_mslp'    : { 'mslp_err' : float }
               ,'var_consdiv' : { 'wgt_dpec' : float,
                                  'wgt_hbal' : float
                                }
               ,'var_ens'     : { 'vradius_opt_ens' : int,
                                  'hradius_ens'     : float,
                                  'vradius_ens'     : float
                                }
               ,'var_reflec'  : { 'ref_opt' : int,
                                  'wgt_ref' : float,
                                  'hradius_ref'     : float,
                                  'vradius_opt_ref' : int,
                                  'vradius_ref'     : float
                                }
               ,'var_lightning' : { 'iuselgt' : int
                                   }
               ,'var_aeri'      : { 'iuseaeri' : 'int0'
                                   }
              }

    nmlin = {}
    for nmlblk,nmlvars in vardpass.items() :
        for nmlvar,nmltype in nmlvars.items() :
            nmlvalues = nmlgrp[nmlblk][nmlvar]
            if len(nmlvalues) > npass :     ## Check sizes
                if opts.verb: print(f"{nmlvar} has more values than {npass}, deleting")
                del nmlvalues[npass:]
            elif len(nmlvalues) < npass :
                if opts.verb:
                    print(f"{nmlvar} does not have enough values for {npass}")
                if not opts.dry:
                    print('ERROR: No enough values for variable <%s>.' % nmlvar)
                    return False

            nmlin[nmlvar] = getvaluelst(nmlvalues,nmltype,opts)

    nmlin['npass'] = npass
    nmlgrp.merge(nmlin)
    if opts.dry:
        for key,val in nmlin.items():
            print(f"{key} -> {val}")
    else:
        if opts.inline:
            outnmlfile = inmlfile

        if outnmlfile is None:
            print("ERROR: output file is None.")
            return False

        nmlgrp.writeToFile(outnmlfile)

#enddef run_news3dvar

if __name__ == "__main__":
    '''Treat the namelist input for NEWS3DVAR based on npass'''

    import argparse

    parser = argparse.ArgumentParser(description="trim namelist file for news3dvar based on npass")
    parser.add_argument("-v", "--verbose", action="store_true", help="More messages while running")
    parser.add_argument("-n", "--dry",     action="store_true", help="Show variables to be changed only")
    parser.add_argument("-i", "--inline",  action="store_true", help="Make change in-place")
    parser.add_argument("-p", "--npass",   type=int,            help="nPass to be used")
    parser.add_argument("-t", "--insert",  action="store_true", help="Treat type of <int0>")

    parser.add_argument("infile",             help="Input namelist file")
    parser.add_argument("outfile", nargs='?', help="output namelist file" )

    args = parser.parse_args()

    options = { 'verb': args.verbose, 'dry': args.dry, 'inline': args.inline, 'insert': args.insert,
                'npass': args.npass }
    opts = make_namespace(options)

    run_news3dvar(args.infile,args.outfile,opts)
