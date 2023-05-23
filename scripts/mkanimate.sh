#!/bin/bash

function usage {
    echo " "
    echo "    USAGE: $(basename $0) [options] image_files [DEST_DIR]"
    echo " "
    echo "    PURPOSE: Generate Javascipt animation for a set of images"
    echo "             <image_files> are names of image files and there must be at least two images."
    echo "             It is better to be the same size (width & height) for each image."
    echo " "
    echo "             For example:  $(basename $0) *.gif > abc.html"
    echo " "
    echo "    OPTIONS:"
    echo "            -help          Print usage"
    echo "            -v             Verbose mode"
    echo "            -s BSD         Date command GNU or BSD"
    echo "            -w ####        Image width. By default, It is determined automatically"
    echo "                           based on the size of the first image file."
    echo "            -h ####        Height of the image. By default, It is determined automatically."
    echo "            -d dirname     If the images are in a directory other than"
    echo "                           the default (current working directory)"
    echo "            -o html_file   This file can also be specified by IO redirection"
    echo "                           (as example above). Otherwise, STDOUT is assumed."
    echo "            -t Title       A title string for the animation. It must be"
    echo "                           quoted within \" if it contains spaces or other "
    echo "                           special characters."
    echo "            -url URL_str   For cases when images will be loaded from a server."
    echo "                           For example: -url \"http://caps.ou.edu/~xxx/\""
    echo "                           then the image files can be on the CAPS web server,"
    echo "                           but be accessed locally using the generated html file"
    echo "            -f subdir      Forecast images to be found from [subdir]."
    echo "                           <image_files> should be comma separted field list"
    echo "                           should be quoted to avoid shell expansion."
    echo "            -a start,end   Analysis images to be found from [YYMMDD/HHMMZ/dom00/nclscripts0]."
    echo "                           <image_files> should be comma separted field list"
    echo "                           should be quoted to avoid shell expansion."
    echo " "
    echo "                                     -- By Y. Wang (2016.05.02)"
    echo " "
    exit $1
}

function joinNames {
  local d=$1;
  shift;
  echo -n "$1";
  shift;
  printf "%s" "${@/#/$d}";
}

imagedir="./"
imagecount=0
imagenames=()
imagewidth=0
imageheight=0

baseurl=""
title="Animation of Images"
outfile=""

dateformat="GNU" #"BSD", "GNU"

#-----------------------------------------------------------------------
#
# Handle command line arguments
#
#-----------------------------------------------------------------------

verbose=0

forecast=0
analysis=0

while [[ $# > 0 ]]
  do
  key="$1"

  case $key in
      -help)
        usage 0
        ;;
      -v)
        verbose=1
        ;;
      -d)
        imagedir="$2"
        shift      # past argument
        ;;
      -w)
        width=$2
        if [[ $width =~ ^[0-9]{1,5}$ ]]; then
            imagewidth=$width
            shift
        else
            echo ""
            echo "    ERROR: Image width number expected, get [$width]."
            usage -2
        fi
        ;;
      -h)
        height=$2
        if [[ $height =~ ^[0-9]{1,5}$ ]]; then
            imageheight=$height
            shift
        else
            echo ""
            echo "    ERROR: Image height number expected, get [$height]."
            usage -2
        fi
        ;;
      -o)
        outfile=$2
        shift
        ;;
      -s)
        dateformat=$2
        shift
        ;;
      -t)
        title=$2
        shift      # past argument
        ;;
      -url)
        baseurl=$2
        shift      # past argument
        ;;
      -f)
        forecast=1
        fsubdir=$2
        shift      # past argument
        ;;
      -a)
        range=$2
        if [[ $range =~ ^[0-9]{12},[0-9]{12}$ ]]; then
           ranges=(${range//,/ })
           if [[ ${ranges[1]} -lt ${ranges[0]} ]]; then
               echo ""
               echo "    ERROR: a < b is required, got \$a=${ranges[0]}, \$b=${ranges[1]}."
               usage -2
           fi
           shift
        fi
        analysis=1
        ;;
      -*)
        echo "Unknown option: $key"
        exit
        ;;
      *)
        imagenames+=($key)
        let imagecount++
        ;;
  esac
  shift # past argument or value
done

#-----------------------------------------------------------------------
#
# Prepare fields and image names
#
#-----------------------------------------------------------------------

currdate=$(date)
host=$(hostname)

#--------- Process forecast products --------------------

if [[ $forecast -eq 1 ]]; then
  pattern=${imagenames[0]}
  fields=(${pattern//,/ })
  defaultfield=${fields[0]}
  imagenames=( $(ls $fsubdir/$defaultfield*.png) )
  imagecount=${#imagenames[@]}

#--------- Process analysis products -------------------
elif [[ $analysis -eq 1 ]]; then
  pattern=${imagenames[0]}
  fields=(${pattern//,/ })
  defaultfield=${fields[0]}
  if [[ $dateformat == "GNU" ]]; then
      startd=${ranges[0]:0:8}    #${name:start:length}
      startt=${ranges[0]:8:4}
      starts=$(date -d "$startd $startt" +%s)
      endd=${ranges[1]:0:8}    #${name:start:length}
      endt=${ranges[1]:8:4}
      ends=$(date -d "$endd $endt" +%s)
  else
      startd=${ranges[0]:0:8}    #${name:start:length}
      startt=${ranges[0]:8:4}
      starts=$(date -j -f "%Y%m%d%H%M" "${ranges[0]}" +%s)
      ends=$(date -j -f "%Y%m%d%H%M" "${ranges[1]}" +%s)
  fi
  imagenames=( "$startd/${startt}Z/dom0/nclscripts/$defaultfield-000.png" )
  imagecount=${#imagenames[@]}

#--------- Regular images ------------------------------
else
  fields=($(basename ${imagenames[0]%-[0-9]*.png}))
  defaultfield=${fields[0]}
  imagecount=${#imagenames[@]}
fi
defaultimage=${imagenames[0]}

if [[ $imagecount -le 0 ]]; then
  echo "ERROR: no valid images was found."
  usage 1
fi

if [[ $imagewidth -eq 0 ]]; then
  imagewidth=$(identify -format '%w' ${defaultimage})
  if [[ $? -ne 0 ]]; then
      imagewidth=1224
  fi
fi

if [[ $imageheight -eq 0 ]]; then
  imageheight=$(identify -format '%h' ${defaultimage})
  if [[ $? -ne 0 ]]; then
      imageheight=1584
  fi
fi

if [[ -z $baseurl ]];then
  baseurlstr=""
else
  baseurlstr="<BASE href=\"$baseurl\">"
fi
titlestr="<h2 align=\"center\" id=\"title\">Animation of &lt;$defaultfield&gt;</h2>"

if [[ $verbose -eq 1 ]]; then
     echo "Processing $imagecount images and they are: [${imagenames[*]}]"
     echo "Image Width  = $imagewidth"
     echo "Image Height = $imageheight"
     echo "HTML title   = \"$titlestr\""
     echo "URL  base    = \"$baseurlstr\""
     echo "Images are in directory <$imagedir>"
fi

#-----------------------------------------------------------------------
#
# Ouput the html file
#
#-----------------------------------------------------------------------

if  [[ -z $outfile ]]; then
  exec 3>&1;
else
  exec 3>$outfile;
  if [[ $verbose -eq 1 ]]; then
     echo "Writting HTML to file <$outfile>."
  fi
fi

cat <<END_OF_HTML_CODE1 >&3
<HTML>
<HEAD>
$baseurlstr
<TITLE>$title</TITLE>
<style type="text/css">

.style31 {
  font-family: Verdana, Arial, Helvetica, Sans-serif;
  font-size: 10px;
  color:#666666;
  text-align: right;
  position:relative;
}

</style>

<SCRIPT language="javascript">
<!-- hide the script from old browsers

//============================================================
//                >> jsImagePlayer 1.0 <<
//            for Netscape3.0+, September 1996
//============================================================
//                  by (c)BASTaRT 1996, 1997
//             Praha, Czech Republic, Europe
//
// feel free to copy and use as long as the credits are given
//          by having this header in the code
//
//          contact: xholecko\@sgi.felk.cvut.cz
//          http://sgi.felk.cvut.cz/~xholecko
//
//============================================================
// Thanx to Karel & Martin for beta testing and suggestions!
//============================================================

// DESCRIPTION: preloads number of images named in format
//   "imagename#.ext" (where "#" stands for number and "ext"
//   for file extension of given filetype (gif, jpg, ...))
//   into cache and then provides usual movie player controls
//   for managing these images (i.e. frames). A picture
//   (loading.gif) is displayed while loading the movie.
//   To make it work just set up the variables below.
//   An image "loading.gif" is expected in the directory
//   where this page is located (it asks user to wait while
//   the animation is being downloaded).
//   Enjoy! BASTaRT. (it's spelled with a "T" ! :)
//  KNOWN BUG:  when page is located on a WWW Server that
//   cannot handle the POST form submit method, pressing Enter
//   after changing the frame number in the little input field
//   causes the page to reload and an alert window to appear.
//   This can be avoided by clicking with the mouse somewhere
//   outside the input field rather than hitting the Enter to
//   jump to the desired frame.
//
//**************************************************************************
//********* SET UP THESE VARIABLES - MUST BE CORRECT!!!*********************
//image_name = "gmeta.4km-vort.gifs/gmeta.4km-vort.";  //the base "path/name" of the image set without the numbers
//image_type = "gif";                 //"gif" or "jpg" or whatever your browser can display

fields=new Array('$(joinNames "', '" ${fields[@]})' );
fieldlength=${#fields[@]}

//!!! the size is very important - if incorrect, browser tries to
//!!! resize the images and slows down significantly
animation_height =  $imageheight;             //height of the images in the animation
animation_width =   $imagewidth;              //width of the images in the animation

//**************************************************************************
//**************************************************************************

END_OF_HTML_CODE1

if [[ $forecast -eq 1 ]]; then

  echo "imageNames = {" >&3

  for field in ${fields[@]}
  do
    imagenames=()
    imagenames=$(ls $fsubdir/$field*.png)
    if [[ $verbose -eq 1 ]]; then echo "Adding $fsubdir/$field*.png ..."; fi
    echo "'$field' : new Array('"$(joinNames "', '" ${imagenames[@]})"')," >&3
  done

  echo "}" >&3
elif [[ $analysis -eq 1 ]]; then

  echo "imageNames = {" >&3

  for field in ${fields[@]}
  do
      imagenames=()
      for (( i=$starts; i<=$ends; i+=300))
      do
          if [[ $dateformat == "GNU" ]]; then
              ddate=$(date -d @$i +%Y%m%d)
              dtime=$(date -d @$i +%H%M)
          else
              ddate=$(date -f "%s" -j $i +%Y%m%d)
              dtime=$(date -f "%s" -j $i +%H%M)
          fi
          if [[ $verbose -eq 1 ]]; then echo "Adding $ddate/${dtime}Z/dom00/nclscripts0/$field-000.png ..."; fi
          imagenames+=("$ddate/${dtime}Z/dom00/nclscripts0/$field-000.png")
      done
      echo "'$field' : new Array('"$(joinNames "', '" ${imagenames[@]})"')," >&3
  done

  echo "}" >&3
else
  echo "imageNames = {" >&3
  echo "'$defaultfield' : new Array('"$(joinNames "', '" ${imagenames[@]})"' )" >&3
  echo "}" >&3
fi

cat <<END_OF_HTML_CODE2 >&3

image_names =  imageNames["$defaultfield"];

first_image = 0;                             //first image number
last_image =  image_names.length-1;          //last image number

//=== THE CODE STARTS HERE - no need to change anything below ===
//=== global variables ====
theImages = new Array();
normal_delay = 200;
delay = normal_delay;  //delay between frames in 1/1000 seconds
delay_step = 100;
delay_max = 4000;
delay_min = 100;
current_image = first_image;     //number of the current image
timeID = null;
istatus = 0;            // 0-stopped, 1-playing
play_mode = 0;          // 0-normal, 1-loop, 2-swing
size_valid = 0;

//===> makes sure the first image number is not bigger than the last image number
/*
if (first_image > last_image)
{
   var help = last_image;
   last_image = first_image;
   first_image = help;
};
*/
//===> preload the images - gets executed first, while downloading the page
/*
for (var i = first_image; i <= last_image; i++)
{
   ii = i;
   if ( i < 1000 ) ii = "0" + i;
   if ( i < 100 ) ii = "00" + i;
   if ( i < 10 ) ii = "000" + i;

   theImages[i] = new Image();
   //theImages[i].onerror = my_alert("\\nError loading ",image_name,i,image_type,"!");
   //theImages[i].onabort = my_alert("\\nLoading of ",image_name,i,image_type," aborted!");

   theImages[i].src = image_name + ii + "." + image_type;
};
*/

for (var i = first_image; i <= last_image; i++)
{
  theImages[i]     = new Image();
  theImages[i].src = "$imagedir" + image_names[i];
};

//===> displays image depending on the play mode in forward direction
function animate_fwd()
{
   current_image++;
   if(current_image > last_image)
   {
      if (play_mode == 0)
      {
         current_image = last_image;
         istatus=0;
         return;
      };                           //NORMAL
      if (play_mode == 1)
      {
         current_image = first_image; //LOOP
      };
      if (play_mode == 2)
      {
         current_image = last_image;
         animate_rev();
         return;
      };
   };
   document.animation.src = theImages[current_image].src;
   document.control_form.frame_nr.value = current_image;
   timeID = setTimeout("animate_fwd()", delay);
}

//===> displays image depending on the play mode in reverse direction
function animate_rev()
{
   current_image--;
   if(current_image < first_image)
   {
      if (play_mode == 0)
      {
         current_image = first_image;
         istatus=0;
         return;
      };                           //NORMAL
      if (play_mode == 1)
      {
         current_image = last_image; //LOOP
      };
      if (play_mode == 2)
      {
         current_image = first_image;
         animate_fwd();
         return;
      };
   };
   document.animation.src = theImages[current_image].src;
   document.control_form.frame_nr.value = current_image;
   timeID = setTimeout("animate_rev()", delay);
}

//===> changes playing speed by adding to or substracting from the delay between frames
function change_speed(dv)
{
   delay+=dv;
   if(delay > delay_max) delay = delay_max;
   if(delay < delay_min) delay = delay_min;
}

//===> stop the movie
function stop()
{
   if (istatus == 1) clearTimeout (timeID);
   istatus = 0;
}

//===> "play forward"
function fwd()
{
   stop();
   istatus = 1;
   animate_fwd();
}

//===> jumps to a given image number
function go2image(number)
{
   stop();
   if (number > last_image) number = last_image;
   if (number < first_image) number = first_image;
   current_image = number;
   document.animation.src = theImages[current_image].src;
   document.control_form.frame_nr.value = current_image;
}

//===> "play reverse"
function rev()
{
   stop();
   istatus = 1;
   animate_rev();
}

//===> changes play mode (normal, loop, swing)
function change_mode(mode)
{
   play_mode = mode;
}

//===> sets everything once the whole page and the images are loaded (onLoad handler in <body>)
function launch()
{
   stop();
   current_image = first_image;
   document.animation.src = theImages[current_image].src;
   document.control_form.frame_nr.value = current_image;
   // this is trying to set the text (Value property) on the START and END buttons
   // to S(first_image number), E(last_image number). It's supposed (according to
   // JavaScrtipt Authoring Guide) to be a read only value but for some reason
   // it works on win3.11 (on IRIX it doesn't).
   document.control_form.start_but.value = " First(" + first_image + ") ";
   document.control_form.end_but.value = " Last(" + last_image + ") ";
   // this needs to be done to set the right mode when the page is manualy reloaded
   change_mode (document.control_form.play_mode_selection.selectedIndex);
}

//===> writes the interface into the code where you want it
function animation()
{
   document.write(" <P><IMG NAME=\\"animation\\" SRC=\\"anim/refl1.gif\\" HEIGHT=",animation_height, " WIDTH=", animation_width, "\\" ALT=\\"[jsMoviePlayer]\\">");
   document.write(" <FORM Method=POST Name=\\"control_form\\"> ");
   document.write("    <INPUT TYPE=\\"button\\" Name=\\"start_but\\" Value=\\"  START  \\" onClick=\\"go2image(first_image)\\"> ");
   document.write("    <INPUT TYPE=\\"button\\" Value=\\" -1 \\" onClick=\\"go2image(--current_image)\\"> ");
   document.write("    <INPUT TYPE=\\"button\\" Value=\\" < \\" onClick=\\"rev()\\"> ");
   document.write("    <INPUT TYPE=\\"button\\" Value=\\" [ ] \\" onClick=\\"stop()\\"> ");
   document.write("    <INPUT TYPE=\\"button\\" Value=\\" > \\" onClick=\\"fwd()\\"> ");
   document.write("    <INPUT TYPE=\\"button\\" Value=\\" +1 \\" onClick=\\"go2image(++current_image)\\"> ");
   document.write("    <INPUT TYPE=\\"button\\" Name=\\"end_but\\" Value=\\"   END   \\" onClick=\\"go2image(last_image)\\"> ");
   document.write(" <BR> ");
   document.write("    <SELECT NAME=\\"play_mode_selection\\" onChange=\\"change_mode(this.selectedIndex)\\"> ");
   document.write("       <OPTION SELECTED VALUE=0>play once ");
   document.write("       <OPTION VALUE=1>loop ");
   document.write("       <OPTION VALUE=2>swing ");
   document.write("    </SELECT> ");
   document.write("    <INPUT TYPE=\\"text\\" NAME=\\"frame_nr\\" VALUE=\\"0\\" SIZE=\\"5\\" ");
   document.write("     onFocus=\\"this.select()\\" onChange=\\"go2image(this.value)\\"> ");
   document.write("    &nbsp;<INPUT TYPE=\\"button\\" Value=\\" - \\" onClick=\\"change_speed(delay_step)\\"> speed ");
   document.write("    <INPUT TYPE=\\"submit\\" Value=\\" + \\" onClick=\\"change_speed(-delay_step)\\;return false\\"> ");
   document.write(" </FORM> ");
   document.write(" </P> ");
};

//===> writes animation fields
function animationfields()
{
  for (var i = 0; i < fieldlength; i++)
  {
       document.write("<li><a href='javascript:change_field(\""+fields[i]+"\")'>"+fields[i]+"</a></li>");
  };
};

//===> Change animation field on request
function change_field(fieldname)
{
  stop();

  image_names =  imageNames[fieldname];

  first_image = 0;                             //first image number
  last_image =  image_names.length-1;          //last image number
  current_image = first_image;

  theImages = new Array();
  for (var i = first_image; i <= last_image; i++)
  {
    theImages[i]     = new Image();
    theImages[i].src = image_names[i];
  };

  // this is trying to set the text (Value property) on the START and END buttons
  // to S(first_image number), E(last_image number). It's supposed (according to
  // JavaScrtipt Authoring Guide) to be a read only value but for some reason
  // it works on win3.11 (on IRIX it doesn't).
  document.control_form.start_but.value = " First(" + first_image + ") ";
  document.control_form.end_but.value = " Last(" + last_image + ") ";
  // this needs to be done to set the right mode when the page is manualy reloaded
  change_mode (document.control_form.play_mode_selection.selectedIndex);

  go2image(current_image)

  document.getElementById("title").innerHTML = "Animation of &lt;"+fieldname+"&gt;"

};

//=== THE CODE ENDS HERE - no need to change anything above === -->
</SCRIPT>
</HEAD>

<BODY onLoad="launch()">

$titlestr
<hr size="2px">

<table>
  <tr>
    <td valign="top" style="border-left: none;border-top: none;border-bottom: none;
    border-right-style: solid;
    border-right-width: 1px;
    border-right-color: #aabbaa;padding:40px">
      <h3>Fields</h3>
      <ul>
        <script>animationfields();</script>
      </ul>
    </td>
    <td align="center">

<!-- ************ HERE STARTS THE jsMoviePlayer(TM) PART ***************** -->
<FORM METHOD=POST Name="control_form">
<P>
<INPUT TYPE="button" Name="start_but" Value="  START  " onClick="go2image(first_image)">
<INPUT TYPE="button" Value=" -1 " onClick="go2image(--current_image)">
No:<INPUT TYPE="text" NAME="frame_nr" VALUE="0" SIZE="5"      onFocus="this.select()" onChange="go2image(this.value)">
<INPUT TYPE="button" Value=" +1 " onClick="go2image(++current_image)">
<INPUT TYPE="button" Name="end_but" Value="   END   " onClick="go2image(last_image)">
 &nbsp;&nbsp;
<SELECT NAME="play_mode_selection" onChange="change_mode(this.selectedIndex)">
<OPTION VALUE=0>play once
<OPTION SELECTED VALUE=1>loop
<OPTION VALUE=2>swing
</SELECT>
<INPUT TYPE="button" Value=" < " onClick="rev()">
<INPUT TYPE="button" Value=" [ ] " onClick="stop()">
<INPUT TYPE="button" Value=" > " onClick="fwd()">
<INPUT TYPE="button" Value=" - " onClick="change_speed(delay_step)"> speed
<INPUT TYPE="submit" Value=" + " onClick="change_speed(-delay_step);return false">
</P>
<IMG NAME="animation" SRC="$defaultimage" HEIGHT= "$imageheight" WIDTH= "$imagewidth" style="position:relative;top:-160px;z-index:-5;" ALT="[jsMoviePlayer]">
</FORM>
<!-- ************ HERE ENDS THE jsMoviePlayer(TM) PART ***************** -->
    </td>
  </tr>
</table>

</BODY>
</HTML>
<hr size="2px">
<div class="style31">Created on $currdate from $host.</div>
END_OF_HTML_CODE2

exit 0
