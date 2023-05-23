#!/bin/csh -f
#
#set echo
if ( $#argv == 0 ) then
    @ yy = ( `date +%y` )
    @ mm = ( `date +%m` )
    @ dd = ( `date +%d` )
else
    @ yy = $1 / 10000
    @ mm = ( $1 - $yy * 10000 ) / 100
    @ dd = $1 % 100
endif
#
@ dd = $dd + 1
if ( ($dd == 29) && ($mm == 2) )then
        @ leap = $yy % 4
        if ( $leap == 0 ) set dd = 29
        if ( $leap != 0 ) then
           set dd = 1
           @ mm = $mm + 1
        endif
else if ( $dd == 31 ) then
    if (($mm == 4)||($mm == 6)||($mm == 9)||($mm == 11)) then
        @ mm = $mm + 1
        set dd = 1
    endif
else if ( $dd == 32 ) then
     if (($mm == 1)||($mm == 3)||($mm == 5)||($mm == 7)||($mm == 8)||($mm == 10)) then
        @ mm = $mm + 1
        set dd = 1
     else if ($mm == 12) then
        set mm =  1
        set dd = 1
        @ yy = $yy + 1
    endif
     endif
endif
#
if ( $yy < 10 ) set yy = 0$yy
if ( $mm < 10 ) set mm = 0$mm
if ( $dd < 10 ) set dd = 0$dd
set ymd = ${yy}${mm}${dd}
echo $ymd
#
