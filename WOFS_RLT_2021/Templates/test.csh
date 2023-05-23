#!/bin/csh 

cat >! fcstModel.sed << EOF
     /time_step_fract_num/c\
     time_step_fract_num        = 0,
     /time_step_fract_den/c\
     time_step_fract_den        = 1,
     /time_step/c\
     time_step                  = $ts,
EOF
