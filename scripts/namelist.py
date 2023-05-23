#!/usr/bin/env python3
## ---------------------------------------------------------------------
##
## This is a python program/module that decode Fortran namelist file
## and do simple processing, write in simple format, compare two
## namelist files, etc.
##
## ---------------------------------------------------------------------
##
## HISTORY:
##
##   Yunheng Wang (05/18/2012)
##   Initial version based on early works for multiple China projects.
##
##
########################################################################
##
## Requirements:
##
##   o Python 3.6 or above
##
########################################################################

import re, sys
from collections.abc import MutableSequence

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class VariableValue(MutableSequence):
    """
    Extend the list built-in for namelist variable values

    Added features are:

      o Comment for this variable
      o type of this variable

    All variable values are converted into a string and wrapped in a list,
    even for value of one element.

    """

    def __init__(self,alist,var_name='',comment=None):
        super(VariableValue,self).__init__()

        if type(alist) is not list:
              raise ValueError('Passed in Value "%s" for variable <%s> is not a list.'%(repr(alist),var_name))
        if len(alist) <= 0:
              raise ValueError('Value for variable <%s> cannot be empty "%s".'%(var_name,repr(alist)))

        self._inner_list = alist
        self.varname = var_name
        self.comment = comment
        self.data = self._inner_list

    def __len__(self):
        return len(self._inner_list)

    def __delitem__(self, index):
        self._inner_list.__delitem__(index)

    def insert(self, index, value):
        self._inner_list.insert(index, value)

    def __setitem__(self, index, value):
        self._inner_list.__setitem__(index, value)

    def __getitem__(self, index):
        return self._inner_list.__getitem__(index)

    def append(self,value):
        self._inner_list.append(value)

    def extend(self,value):
        self._inner_list.extend(value)

    def __repr__(self):
        return '%s' % repr(self._inner_list)

    def __str__(self):
        if isinstance(self._inner_list[0],list) :
          lstr = ''
          for el in self._inner_list :
            lstr += str(self.unpack(el))+', '
          return lstr
        else :
          return ','.join(self._inner_list)
    #endif

    ####################################################################

    @property
    def value(self) :
      '''
          return unpacked value as python internal data type

          get rid of list symbol for single value
      '''

      if len(self._inner_list) > 1:
          newvalue = []

          for valel in self._inner_list:
             newel = self.unpack(valel)
             newvalue.append(newel)

      else:

          #assert(len(self._inner_list[0])==1)
          valnml = self._inner_list[0]
          #print valnml
          newvalue = self.unpack(valnml)

      return newvalue

    ####################################################################

    @property
    def datatype(self):
        '''
           Detect the value type as:
           int, str, float, bool, arrayofint1d, listint2d, ...
        '''
        outtyp = ''

        dim = 0
        if len(self._inner_list) > 1:
            outtyp = 'arrayof_'
            dim = 1

        valnml = self._inner_list[0]
        #
        # check dimension
        #
        while isinstance(valnml,list):
            dim += 1
            valnml = valnml[0]

        if dim > 0: outtyp += '%dd_'%dim

        assert(isinstance(valnml,str))

        if valnml.startswith("'") and valnml.endswith("'"):
          outtyp += 'str'
        elif valnml.startswith('"') and valnml.endswith('"'):
          outtyp += 'str'
        elif self.isbool(valnml):
          outtyp += 'bool'
        elif valnml.isdigit():
          outtyp += 'int'
        elif re.match(r'[\d.+Eeg\-]+',valnml):
          outtyp += 'float'
        else:
          raise TypeError("Invalid namelist variable value <%s>."%valnml)

        return outtyp

    ####################################################################

    def isequal(self,varvalue):
        '''
           compare itself with "varvalue"

           = False  Not equal
           = True   equal
        '''

        lenself = len(self)
        lenin   = len(varvalue)
        if lenself > lenin or lenself < lenin:
            iret = False
        else:
            iret = self.valueCMPList(self.data,varvalue.data)

        return iret

    ##==================================================================
    @classmethod
    def unpack(cls,valnml):
          '''
             unpack a single value from string
          '''
          if isinstance(valnml,list):
              newvalue = []
              for valel in valnml:
                 newel = cls.unpack(valel)
                 newvalue.append(newel)
              return newvalue

          else:
              assert(isinstance(valnml,str))
              if valnml.startswith("'") and valnml.endswith("'"):
                  return valnml.strip("'")
              elif valnml.startswith('"') and valnml.endswith('"'):
                  return valnml.strip('"')
              elif cls.isbool(valnml):
                  if valnml.lower() in ('.t.', '.true.'):
                      return True
                  else:
                      return False
              elif valnml.isdigit():
                  return int(valnml)
              elif re.match(r'[\d.+Eeg\-]+',valnml):
                  return float(valnml)
              else:
                  raise TypeError("Invalid variable value <%s>."%valnml)

    #enddef

    ##==================================================================

    @classmethod
    def pack(cls,valuein) :
      ''' Pack passing in value (one element) for namelist variable

          Note that it still does not wrap scale value into a list as
          required in "append".
      '''

      if isinstance(valuein,list):
          newvalue = []
          for el in valuein:
              newel = cls.pack(el)
              newvalue.append(newel)
      elif type(valuein) in [int,float] :  ## number should be converted to string
        newvalue =str(valuein)
      elif cls.isastring(valuein) :        ## str should be double wrapped
        newvalue = "'%s'"%valuein
      elif cls.isbool(valuein) :           ## frotran boolean should be wrapped
        newvalue = "%s"%valuein
      elif valuein is None :
        newvalue = 'None'
      else :
        raise ValueError('''Unsupport namelist variable value "%s" - %s.'''%(valuein,type(valuein)))

      return newvalue
    #enddef

    ##==================================================================

    @classmethod
    def pack4nml(cls,valuein) :
      ''' Pack passing in value for namelist variable
      '''

      newvalue = []
      if isinstance(valuein,list) :         ## list is set as a list
        for el in valuein :
          newel = cls.pack(el)
          newvalue.append(newel)

      else:
          newvalue.append(cls.pack(valuein))

      return newvalue
    #enddef

    ##==================================================================

    @staticmethod
    def isastring(valin) :
      ''' Check whether the passing value is a character string
      '''
      if not isinstance(valin,str) :
        return False

      if VariableValue.isbool(valin):
        return False
      else :
        return True

    #enddef

    ##====================================================================

    @staticmethod
    def isbool(valin) :
      ''' Check whether the passing value is a boolean string
      '''
      if not isinstance(valin,str) :
        return False

      if valin.lower() in ('.true.','.false.','.t.','.f.') :
        return True
      else :
        return False

    #enddef

    ##====================================================================

    @staticmethod
    def valueCMPList(list1,list2) :
      ''' compare two lists, return True if same otherwise return False '''

      if len(list1) == len(list2) :
        if isinstance(list1[0],list) :      # Value is a list or a list of lists
          retl = map(VariableValue.valueCMPList,list1,list2)
          if False in retl :
            ret = False
          else :
            ret = True
        else :
          if VariableValue.isbool(list1[0]): # Value is Bool
              if list1[0].lower() in ('.true.','.t.') and list2[0].lower() in ('.true.','.t.'):
                  ret = True
              elif list1[0].lower() in ('.false.','.f.') and list2[0].lower() in ('.false.','.f.'):
                  ret = True
              else:
                  ret = False
          else:  # others, integer, string, float etc.
              ret = (list1 == list2)
      else :
        ret = False

      return ret
    #enddef valueCMPList

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class namelistBlock(dict) :
    """
    Extend the dict built-in for namelist handling
    Added features are:

      o Ordered keys
      o Comment for this namelist block
      o Append method, should be used to add new key

    All variable values are converted into a string and wrapped in a list,
    even for value of one element.

    Uses key as attribute. Note that it is assumed that keys are all Fortran
    variable name and it will not conflict with the namespace of builtin
    dict method attributes

    There are two sets of references:
        1. dict notation gets and sets "VariableValue" instance,
           which has attributes: value, data, datatype, comment, varname etc.
        2. (preferred) attr notation gets and sets Python/Fortran internal data type
           (int, float, str, list)

    String representation:
        1. str()  To get Fortran namelist file output (readable)
        2. repr() To get internal representation, for debugging etc.
    """

    def __init__(self,name='',comment=None) :
      dict.__init__(self)
      self._order   = []
      self._name    = name
      self._comment = comment
 #  enddef

    ####################################################################

    def keys(self) :
      return self._order
    #enddef

    ######################################################################

    def getComment(self,key=None) :
      if not key :
        return self._comment
      else :
        return self[key].comment
    #enddef

    ######################################################################

    def append(self,key,value,comment=None) :
      '''
          "value" must be a list, all elements in the list must be string
          string value is extra wrapped within ' and '

          It only append values to existing key or create new (key, value) pair.
          To replace value of existing key, use either
             o the dict notation, self[key] = value,
               value must be already wrapped as mentioned above
             o the attribute notation, self.key = value
               value will be in normal Fortran format.

      '''
      multidim = False   ## maximum to process 2 dimensions
      indx1 = 0
      #print 'Adding key :',key
      #                        1            2       3 4
      regroups = re.match(r'([\w_ ]+)\(([\d:]{1,2})(,(\d{1,2})){0,2}\)',key)
      if  regroups:
        key = (regroups.group(1)).strip()
        if regroups.group(2) == ':': indx1 = 0
        else:                        indx1 = int(regroups.group(2))
        if regroups.group(3) :
          multidim = True
          indx2 = int(regroups.group(4))

      if key in self:
        if multidim :
          if indx2 > len(self[key]):
            self[key].append(value)
          else :
            self[key][indx2-1].extend(value)
        else :
          if indx1 > 1: assert(indx1-1 == len(self[key]))
          self[key].extend(value)
      else :
        if multidim:
            valuelist = [value]
        else :
            if indx1 > 1: key = '%s(%d)' % (key, indx1)
            valuelist = value

        varvalue = VariableValue(valuelist,key,comment)

        self.__setitem__(key,varvalue)
        self._order.append(key)
    #enddef

    ####################################################################

    def __dir__(self):
          return self.keys()

    ####################################################################

    def __getattr__(self, key):
      try:
          return self[key].value
      except KeyError:
          print ('''Variable "%s" is not a member of this namelist block: <%s>.''' % (key,self._name))
          raise AttributeError(key)

    ####################################################################

    def __setattr__(self, key, value):
      if key in ['_comment', '_order', '_keycomments', '_name']:
          super(namelistBlock,self).__setattr__(key,value)
      else:
          valnml = VariableValue.pack4nml(value)

          if key in self.keys():
              self[key] = VariableValue(valnml,key)
          else:
              self.append(key,valnml,'new variable')

    ####################################################################

    def __setitem__(self, key, value):

        if isinstance(value,VariableValue):
            super(namelistBlock,self).__setitem__(key, value)
        else:
            raise ValueError('''Value "%s" is not an instance of class VariableValue.'''%value)

    ####################################################################

    def item (self, key):
      ''' return one (key,value) pair as a string'''

      value_list = self[key]
      # value_list is an instance of VariableValue
      # but it can be used as a list

      outstr = ''
      if isinstance(value_list[0],list) :
          indx2 = 0
          for value in value_list :
              indx2 += 1
              outstr += '%s(:,%d) = %s,\n  ' % (key,indx2,','.join(value))
      else :
          outstr += '%s = %s,' % (key,', '.join(value_list))

      return outstr

    ######################################################################

    def __repr__(self):
      ''' repr() for debugging'''

      outstr = '&%s\n'%self._name
      for var_name in self.keys() :
          outstr += '  %s = %s\n'%(var_name,repr(self[var_name]))

      outstr += '/\n\n'

      return outstr

    ######################################################################

    def __str__(self):
      ''' print or str()'''

      outstr = '&%s\n'%self._name
      for var_name in self.keys() :
          outstr += '  %s\n'%self.item(var_name)

      outstr += '/\n\n'

      return outstr

    ##==================================================================

    @classmethod
    def clone_from_dict(cls,dictin):
      '''
         Create a namelistBlock from "dict"
      '''

      nmlblk = cls('indict','Namelist block from python dictionary')

      for key,value in dictin.items():
          #nmlblk.__setattr__(key, value)
          nmlval = VariableValue.pack4nml(value)
          nmlblk.append(key,nmlval)

      return nmlblk

#endclass

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class namelistGroup(dict) :
    '''
    Contain all namelist blocks in one file

    Added features:
      _order : list to return ordered keys, i.e. namelist block names,
               value is the namelist block corresponding to this name.
    '''

    def __init__(self,filename=None) :
      dict.__init__(self)
      self._order   = []
      self._srcfile = filename
      self.merge    = self.merge1dict    # to keep backward compatible
    #enddef

    ######################################################################

    def keys(self) :
      return self._order
    #enddef

    ######################################################################

    def __setitem__(self,key,value) :
      dict.__setitem__(self,key,value)
      self._order.append(key)
    #enddef

    ######################################################################

    def __repr__(self):
      '''repr() for debugging, formally representation of the object'''

      outstr = ''
      for nml_name in self.keys() :
          outstr += repr(self[nml_name])

      return outstr

    ######################################################################

    def __str__(self):
      ''' print or str(), for readable output'''

      outstr = ''
      for nml_name in self.keys() :
          outstr += str(self[nml_name])

      return outstr

    ######################################################################

    @classmethod
    def create_from_dict(cls,indict):
        '''
           Create a namelistGroup from double level dictionary

        '''

        nmlgrp = cls('dict')

        for nml_name in indict.keys() :       ## loop over all namelist blocks, it is a "dict" again
            nmlgrp[nml_name] = namelistBlock.clone_from_dict(indict[nml_name])

        return nmlgrp

    ######################################################################

    def merge1dict(self,indict,nblkname=None,forceadd=False):
      '''
      Merge 1-level dictionary to this file.

      Merge the give varaibles in a dict (indict) into this namelsit group.
      all keys in indict must exists in the namelist variables, otherwise
      a warning is issued.
      '''

      if isinstance(indict,namelistBlock):
        inblk = indict
      else:
        inblk = namelistBlock.clone_from_dict(indict)
        #print inblk

      set1 = set(inblk.keys())

      for nml_name in self.keys() :       ## loop over all namelist blocks
        nml_block = self[nml_name]
        set0 = set(nml_block.keys())      ## variable set of this namelist block
        setc = set0.intersection(set1)    ## Keys to be updated
        if len(setc) > 0 :                ## this block contains variable to be merged
          for var in setc :
            nml_block[var] = inblk[var]
            #print "%s -> <%s>" % (var, nml_block[var])

        set1 = set1.difference(setc)      ## Keys left to be merged with other namelis block
        if len(set1) <= 0 : break

      #
      # extra variables from input dict
      #
      if len(set1) > 0 :
        if forceadd and nblkname in self.keys():
          sys.stderr.write('WARNING: Unknown variables \"%s\" while merging namelist <%s>. Adding...\n'%(','.join(set1),inblk._name))
          for var in set1:
            newvalue = inblk[var]
            self[nblkname].append(var,newvalue,'New from %s'%inblk._name)

            #print >> sys.stderr, nml_block.getComment(var)
        else:
          sys.stderr.write('WARNING: Unknown variables \"%s\" while merging namelist <%s>. Ignored.\n'%(','.join(set1),inblk._name))
          #sys.stderr.write('WARNING: Unknown variables \"%s\" while merging namelist. Ignored.\n'%(','.join(set1)))
    #enddef

    ######################################################################

    def merge2dict(self,indict,forceadd=False):
      '''
      Merge 2-level dictionary to this file.

      Merge the given dictionary (indict) into this namelsit group.
      all keys in "indict" must be a name of namelistBlock in this namelistGroup
      otherwise warning will be issued.
      '''

      if isinstance(indict,namelistGroup):
          ingrp = indict
      else:
          ingrp = namelistGroup.create_from_dict(indict)

      for nml_name in ingrp.keys() :       ## loop over all namelist blocks, it is a "dict" again
        if nml_name in self.keys():         ## make sure indict key is valid
            nml_block = self[nml_name]
            for key,value in ingrp[nml_name].items():

                  if key in nml_block.keys():         # make sure variable is valid
                         nml_block[key] = value
                  elif forceadd:
                         nml_block.append(key,value.data)
                         sys.stderr.write('WARNING: Variables \"%s\" in namelist <%s> is not in the namelist file <%s>. Adding...\n'%(
                                           key, nml_name,self._srcfile))
                  else:
                         sys.stderr.write('WARNING: Variables \"%s\" in namelist <%s> is not in the namelist file <%s>. Ignored.\n'%(
                                           key, nml_name,self._srcfile))

        else:
          sys.stderr.write('WARNING: name \"%s\" from passed in dict is not in the namelist file <%s>. Ignored.\n'%(nml_name,self._srcfile))

    #enddef

    ######################################################################

    def writeToFile(self,file_name,file_handle=False) :
      '''Write a run-time namelist file.'''

      if not file_handle :
        nml_file = open(file_name,'w')
      else :
        nml_file = file_name

      nml_file.write(str(self))

      if not file_handle : nml_file.close()
    #enddef writeToFile

#endclass

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class namelistCMPGroup(dict) :

    def __init__(self,nmlgrpL,nmlgrpR) :
      dict.__init__(self)
      self.__setitem__('namelistL',[])
      self.__setitem__('namelistR',[])
      self.__setitem__('namelistC',{})

      setL = set(nmlgrpL.keys())
      setR = set(nmlgrpR.keys())

      set0 = setL-setR
      set1 = setR-setL
      setC = setL & setR

      if len(set0) > 0 :
        self['namelistL'].extend(set0)

      if len(set1) > 0:
        self['namelistR'].extend(set1)

      for nml_name in setC :  ## loop over all common namelist blocks

        nmlC = { 'varL': [],
                 'varR': [],
                 'varC': [],
                 'varS': []
                }

        nmlL = nmlgrpL[nml_name]
        nmlR = nmlgrpR[nml_name]

        varL = set(nmlL.keys())
        varR = set(nmlR.keys())

        var0 = varL-varR
        var1 = varR-varL
        varC = varL & varR

        if len(var0) > 0 :
          nmlC['varL'].extend(var0)

        if len(var1) > 0:
          nmlC['varR'].extend(var1)

        if len(varC) > 0 :         ## this block contains common variables
          for var in varC :
            valueL = nmlL[var]
            valueR = nmlR[var]
            if valueL.isequal(valueR):
                nmlC['varS'].append(var)
            else :
                nmlC['varC'].append(var)

        self['namelistC'][nml_name] = nmlC
    #enddef

    ######################################################################

    def output(self,ofile,grp1,grp2,color=True) :
      ''' Print the comparison results '''

      if color :
        cprint = self.colorprint
      else :
        cprint = self.nprint

      left  = cprint("left ",'magenta')
      right = cprint("right",'cyan')

      print('\n','='*100, file = ofile)
      leftstr = '''%s : "%s"''' % (left,  grp1._srcfile)
      leftpad = 50-len(leftstr)
      print(' '*20,leftstr,' '*leftpad,''' %s : "%s"''' % (right, grp2._srcfile), file = ofile)
      print(  '='*100, file = ofile)

      if len(self['namelistL']) > 0 :
        print(' '*20,'++++ namelist only in %s +++++' % left, file = ofile)
        print(' '*20, cprint(self['namelistL'],'red'), file = ofile)

      if len(self['namelistR']) > 0 :
        print(' '*60,'++++ namelist only in %s ++++' % right, file = ofile)
        print(' '*60, cprint(self['namelistR'],'blue'), file = ofile)

      if len(self['namelistL']) > 0  or len(self['namelistR']) > 0 :
          print(  '-'*100, file = ofile)

      for nml in self['namelistC'].keys() :

        nmlC = self['namelistC'][nml]

        prnthead = False
        headnml  = '&%s' % cprint(nml,'yellow').center(20,' ')
        if len(nmlC['varL']) > 0  or len(nmlC['varR']) > 0 or len(nmlC['varC']) > 0:
            prnthead = True

        if prnthead: print('\n%s' % headnml, file = ofile)

        if len(nmlC['varL']) > 0 :
          print(' '*20,'<<<< variable(s) only in %s >>>>' % left, file = ofile)
          for var in nmlC['varL'] :
            print(' '*20,cprint(var,'magenta').ljust(14),' = %s' % grp1[nml][var], file = ofile)

        if len(nmlC['varR']) > 0 :
          print(' '*60,'>>>> variable(s) only in %s <<<<' % right, file = ofile)
          for var in nmlC['varR'] :
            #print(('%s = %s' % (list2str(grp2[nml][var]),cprint(var,'cyan'))).rjust(80), file = ofile)
            print(' '*60,cprint(var,'cyan').ljust(14), ' = %s' % grp2[nml][var], file = ofile)

        if len(nmlC['varL']) > 0  or len(nmlC['varR']) > 0  :
              print('    ','-'*96, file = ofile)

        if len(nmlC['varC']) > 0:              ## there is a difference
          for var in nmlC['varC']:
              ioffset = len(var)-14 if len(var)>14 else 0
              strleft  = cprint(str(grp1[nml][var]),'magenta',38-ioffset)
              strright = cprint(str(grp2[nml][var]),'cyan',38)
              print(f'  {str(var).ljust(14)}= {strleft} ; {strright}', file = ofile)
          #print(' ', file = ofile)

        if prnthead: print(cprint('/','yellow'), file = ofile)
    #enddef

    ##====================================================================

    @staticmethod
    def colorprint(field, color = 'white',length=None, ):
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
      #field = ('{:%s%ds}'%(align,length)).format(field)
      outfield = field
      if length :
        if len(field) > length :
            outfield = field[:length-4]+' ...'
        else:
            outfield = field.ljust(length)


      outfield = '[01;%dm%s[00m' % ( Term_colors[color], outfield )
      ##field = '{:20s}'.format(field)
      return outfield
    #enddef colorprint

    ##====================================================================

    @staticmethod
    def nprint(field, color = 'white', length=None,):
      """Return the 'field' in collored terminal form"""

      outfield = field
      if length :
        if len(field) > length :
            outfield = field[:length-4]+' ...'
        else:
            outfield = field.ljust(length)

      return outfield
    #enddef nprint

#endclass

##
########################################################################
##
## Process namelist file
##
########################################################################
##
def decode_namelist_file(file_name,debug=False,dictionary=False) :
  '''read and parse a namelist file

     note that each variable is a string
     value is also string, but enclosed within a list
     string wrapped within ' and '.

  '''
  nml_grp = namelistGroup(file_name)  ## Contain the whole namelist file

  #debug = False
  if dictionary :
    nml_name = 'global'
    nml_block = namelistBlock(name=file_name)
    inmlblock = True
  else :
    inmlblock = False

  var_name   = ''          # working array
  value_list = None        # we are sure one variable is completed only when
  var_pend   = False       # the next variable name is found.

  var_names   = []         # Collect all variables and values for output
  value_lists = {}
  with open(file_name) as fp:
    for txtline in fp:
        line = txtline.strip()
        if line.startswith('!')  :      ## comment ignore
           pass  ## do nothing at present
        elif line.startswith('&') and line[1:4] != 'end' :    ## start a namelist block
          nml_name = line[1:]
          nml_block = namelistBlock(name=nml_name)
          inmlblock = True
        elif line.startswith('/') or line[:4] == '&end' :    ## close a namelist block
          if var_pend:
                var_names.append(var_name.lower())
                value_lists[var_name.lower()] = value_list
                var_pend = False

          for varname in var_names:
            nml_block.append(varname, value_lists[varname])
            if debug : print ('adding %s as %s' % (varname, value_lists[varname]))

          nml_grp[nml_name] = nml_block
          inmlblock = False

          var_names   = []         # Clear old namelist block
          value_lists = {}

        else :
          if not inmlblock or not line: continue
                                          ## ignore everything outside a namelist block
                                          ## and blank line inside a namelist block

          (var_name,value_list,var_pend) = decode_one_line(line,var_pend,var_name,value_list,
                                           var_names,value_lists,debug)

  if dictionary :    ## contain only var = value pairs
        if var_pend:
            var_names.append(var_name.lower())
            value_lists[var_name.lower()] = value_list
            var_pend = False

        for varname in var_names:
            nml_block.append(varname, value_lists[varname])
            if debug : print('adding %s as %s' % (varname, value_lists[varname]))

        nml_grp[nml_name] = nml_block

  return nml_grp
#enddef

########################################################################

def decode_one_line(linein,varpend,varin,valuein,var_names,value_lists,debug=False):
      '''
         Decode one source line, this line can be
            o. var = value,
            o. var(1,2) = value,
            o. var1 = value1, var2 = value2, .....
            o. var = 'string, value',    # "," within string
            o. value1, value2, ...       # to complete earlier line

          return var_name,value_list,var_pend
      '''

      var_name   = varin
      value_list = valuein
      var_pend   = varpend

      linelist = linein.split(',')      ## variable line

      var_no   = 0                  ## how many variables contained in one line?
      var_pre  = ''
      str_con  = False              ## in case , is within a string
      multidim = False

      #debug = (nml_name == 'jobname')

      if debug : print("=== line <%s> :" % linein)
      for element in linelist :

        if debug: print("--- element <%s> :" % element)

        if str_con :                   ## value is still not complete
          value += ",%s" % element
          if value.endswith("'") :
            if value_list is None :
              value_list = [value]         ## initialize the variable value list
            else :
              value_list.append(value)

            str_con = False
          continue

        element = element.strip()
        if element == ''           : continue     ## skip empty element
        if element.startswith('!') : break        ## skip all following elements

        if (element.find('=') > 0) :     ## find a variable
          if (var_no > 0 or var_pend) :  ## Already find a variable before, so save it to "nmlblock"
            var_names.append(var_name.lower())
            value_lists[var_name.lower()] = value_list
            #nmlblock.append(var_name.lower(),value_list)
            if debug : print('adding "%s" as <%s>' % (var_name, value_list))
            value_list = None
            var_pend   = False

          [var_name,value] = element.split('=',1)
          var_name = var_name.strip()
          var_no += 1
          var_pend = True

          if var_pre :                    ## prepend "var(1," (decoded early) to "1)" (current)
            var_name = var_pre + ',' + var_name
            var_pre = ''
            multidim = False

          value = value.strip()
          if value.startswith("'") and not value.endswith("'") :  ## string value to be continued
            str_con = True
          else :
            value_list = [value]           ## initialize the variable value list
        else :                             ## pure value part, or multiple dimension variable names
          regroups = re.match(r'[\w_]+\([:\d]+',element)
          if regroups :
            multidim = True
            var_pre  = element            ## handle 2D variable, var(1,
            continue

          regroups = re.match(r'\d+',element)
          if regroups and multidim :
            var_pre += ','+element
          else :
            if element.startswith("'") and not element.endswith("'") :
              ## string value to be continued
              str_con = True
              value = element
            else :
              value_list.append(element)     ## append variable values

      return (var_name,value_list,var_pend)

##
########################################################################
##
## Merge a namelistGroup to a namelist file
##
########################################################################
##
def merge_namelist_file(file_name, nmlgrp_in, outfhdl, debug=False, forceadd=False) :
  '''read and parse a namelist file, merge with variable values in <nmlgrp_in>,
     Then, output a new file.

     Note: it is guarantee that all file variables are in <nmlgrp_in> because
           "nmlgrp_in" was originally decoded from the same file.

     The purpose of this method is to keep the comments and format in
     the original file, but replace variable values with those in <nmlgrp_in>.

  '''

  inmlblock = False
  var_names = []                   # var processed so far, to avoid duplication
  var_pend = False                 # var pending for output
  var_found= None
  value    = ''
  for txtline in file(file_name) :
    line = txtline.strip()
    if line.startswith('!')  :      ## comment ignore
       print >> outfhdl, line       ## just print
    elif line.startswith('&') and line[1:4] != 'end' :    ## start a namelist block
      nml_name = line[1:]
      inmlblock = True
      var_names = []
      var_found = None
      print >> outfhdl, line        ## print namelist block name
    elif line.startswith('/') or line[:4] == '&end' :    ## close a namelist block
      if var_pend and var_found not in var_names :   ## 2. WRITE at last within namelist block
        print >> outfhdl, '  %s'%nmlgrp_in[nml_name].item(var_found)
        var_pend = False

      if forceadd:
        set1 = set(nmlgrp_in[nml_name].keys())
        set1 = set1.difference(set(var_names))
        for var_name_in in set1:
          print >> outfhdl, '  %s'%nmlgrp_in[nml_name].item(var_name_in)

      inmlblock = False
      print >> outfhdl, '/'
    else :
      if not inmlblock :            ## everything outside a namelist block
        print >> outfhdl, line
        continue

      #debug = (nml_name == "jobname" )
      if not line : continue        ## ignore blank lines

      if debug : print("=== line <%s> :" % line)

      linelist = line.split(',')      ## variable line
      str_con  = False
      multidim = False
      var_pre  = False

      for element in linelist :

        if debug: print("--- element <%s> :" % element)

        if str_con :                       ## value is still not complete
          value += ",%s" % element
          if value.endswith("'") :
            str_con = False
          continue

        element = element.strip()
        if element == ''           : continue     ## skip empty element
        if element.startswith('!') :              ## ignore all following elements
          break

        if (element.find('=') > 0) :       ## find a variable

          [var_new,value] = element.split('=',1)
          var_new = var_new.strip()

          if var_pre :                   ## prepend var(1, to 1)
            var_pre = False
            multidim = False
          else :                         ## 1. Found new variable
            regroups = re.match(r'([\w_]+)\s*\([:\d]+\)',var_new)
            if regroups :
              var_found = regroups.group(1).lower()
            else :
              var_found = var_new.lower()
            var_pend = True
            if debug : print ('Found variable %s' % (var_found))

          value = value.strip()
          if value.startswith("'") and not value.endswith("'") :  ## string value to be continued
            str_con = True
        else :
          regroups = re.match(r'([\w_]+)\s*\([:\d]+',element)
          if regroups :       ## handle 2D variable, var(1,
            multidim = True
            var_pre  = True
            var_found = regroups.group(1).lower()
            var_pend = True   ## 2. Found new variable
            continue

          regroups = re.match(r'\d+',element)
          if regroups and multidim :
            var_pre = True
          else :
            if element.startswith("'") and not element.endswith("'") :
              str_con = True

        if var_pend and var_found not in var_names :
                                         ## 1. WRITE previous variable found
          if debug : print ('Writing variable %s ...' % (var_found))
          #nmlgrp_in.writevar(outfhdl,nml_name,var_found)
          print >>outfhdl, ('  %s'%nmlgrp_in[nml_name].item(var_found))
          var_names.append(var_found)
          var_pend = False

  return
#enddef merge_namelist_file

##======================================================================
## USAGE
##======================================================================
def usage( istatus = 0 ) :
  '''-------------------------------------------------------------------
  Print Usage and then exit
  -------------------------------------------------------------------'''

  version  = '4.0'
  lastdate = '2020.03.05'

  print ("""\n  Usage: %s [options] FILE1 [FILE2]\n
     \tFILE1     A Fortran namelist file
     \tFILE2     Another namelist file or var-value flat file
     \t          for comparison or merging
     \n  OPTIONS:\n
     \tOption \t\tDefault   Instruction
     \t-------\t\t--------  -----------
     \t-v, --verbose \t \t  Verbose
     \t-h, --help    \t \t  Print this help
     \t-o, --output  \tstdout    Ouput file name
     \t-k, --keep    \t \t  Keep FILE1 comments
     \t-f, --force   \t \t  Add new variables from FILE2 if not exist in FILE1
     \t              \t \t
     \t-p, --print   \t \t  Print namelist file (Default action)
     \t              \t \t
     \t-c, --diff    \t \t  Compare two namelist files, FILE1 is the base
     \t              \t \t
     \t-m, --merge   \t  \t  Merge FILE2 to FILE1, FILE2 is a namelist file
     \t              \t \t
     \t-s, --set     \t  \t  Set FILE1 with values from FILE2. FILE2 contains
     \t              \t  \t  variable and value pairs only, but not embeded
     \t              \t  \t  within namelist blocks
     """ % (os.path.basename(cmd)), file=sys.stderr)
  print('  For questions or problems, please contact yunheng@ou.edu (v%s, %s).\n' % (version,lastdate),file=sys.stderr)

  sys.exit(istatus)
#enddef usage

##======================================================================
## Parse command line arguments
##======================================================================

def parseArgv(argv) :

  '''-------------------------------------------------------------------
  Parse command line arguments
  -------------------------------------------------------------------'''

  options = {'debug': False, 'output' : None,  'keep1' : False,
             'force': False, 'action' : None }

  ##
  ## Decode command options
  ##
  try:
    opts, args = getopt.getopt(argv,'hvcmskfo:p',
             ['help','verbose','diff','merge','set','keep1','force','output','print'])

    for opt, arg in opts :
      if opt in ('-h','--help'):
        usage(0)
      elif opt in ( '-v', '--verbose'):
        options['debug'] = True
      elif opt in ( '-k', '--keep'):
        options['keep1'] = True
      elif opt in ( '-f', '--force'):
        options['force'] = True
      elif opt in ( '-o', '--output'):
        options['output'] = arg
      elif opt in ( '-p', '--print'):
        options['action'] = 'print'
      elif opt in ( '-c', '--diff'):
        options['action'] = 'diff'
      elif opt in ( '-m', '--merge'):
        options['action'] = 'merge'
      elif opt in ( '-s', '--set'):
        options['action'] = 'set'

  except getopt.GetoptError:
    print('  ERROR: Unknown option (%s).' %opt,file=sys.stderr)
    usage(2)

  ##
  ## Decode command line arguments
  ##
  if options['action'] is None:
    options['action'] = 'print'

  if options['action'] in ['diff','merge','set']:
    expected = 2
  else :
    expected = 1

  if (len(args) == expected ) :
    argfiles = args
    if len(args) == 2 and os.path.isdir(args[1]):
        filename = os.path.basename(args[0])
        argfiles[1] = os.path.join(args[1],filename)

  else :
    print('\n  ERROR: wrong number of command line arguments, expected %d, got %d.' % (
             expected,len(args) ), file=sys.stderr)
    usage(1)

  return (options,argfiles)
#enddef parseArgv


##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
##
## Entance Point
##
##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

if (__name__ == '__main__') :

  import os, getopt

  cmd  = os.path.basename(sys.argv[0])
  (opts,args) = parseArgv(sys.argv[1:])

  ## Decode a nameliss file to get a namelist group
  nmlfile = args[0]
  nmlgrp = decode_namelist_file(nmlfile,opts['debug'])

  ## Merge in variables we want to change, which is provide as a python dict
  ##newnml = {'nproc_x'  : 20,
  ##          'abc'      : 33,
  ##          'vertx'    : [[10,20],[0.1,0.2]],
  ##          'setconts' : [[1,2],[3,4]]
  ##         }
  ##
  ##nmlgrp.merge(newnml)

  output = True

  if opts['action'] == 'print' :

    output = True

  elif opts['action'] == 'diff' :

    nmlgrp1 = decode_namelist_file(args[1],opts['debug'])
    ## compare two namelist groups
    nmlcmp = namelistCMPGroup(nmlgrp,nmlgrp1)

    if opts['output'] is None :
      nmlcmp.output(sys.stdout,nmlgrp,nmlgrp1,True)
    else :
      outhdl = open(opts['output'],'w')
      nmlcmp.output(outhdl,nmlgrp,nmlgrp1,False)
      outhdl.close()

    output = False        ## done

  elif opts['action']  == 'merge':

    nmlgrp1 = decode_namelist_file(args[1],opts['debug'])
    nmlgrp.merge2dict(nmlgrp1,opts['force'])

    output = True         ## output

  elif opts['action'] == 'set':

    nmlgrp1 = decode_namelist_file(args[1],opts['debug'],True)
    for nml_name,nml_block in nmlgrp1.items():
      nmlgrp.merge1dict(nml_block)

    output = True

  ##
  ## Output the namelist file
  ##

  if output :

    if opts['output'] is None :
      outhdl = sys.stdout
    else :
      outhdl = open(opts['output'],'w')

    if opts['keep1'] :
      merge_namelist_file(nmlfile, nmlgrp, outhdl, opts['debug'],opts['force'])
    else :    ## Output the base namelist
      nmlgrp.writeToFile(outhdl,True)

    if opts['output'] is not None : outhdl.close()
