#!/bin/csh

cd namelists.WOFS.fcst

set n = 1
while ( $n <= 36 )

      @ n2 = ${n} + 36

      cp namelist.input.member$n namelist.input.member${n2}

@ n++
end

exit (0)

