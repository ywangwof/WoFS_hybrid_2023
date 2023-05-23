import matplotlib.pyplot as P
import matplotlib
import numpy as N
import time as timeit
import sys
from optparse import OptionParser
from mpl_toolkits.basemap import Basemap

from time import strftime 

# HRRR Grid description

background_grid = (22.5, -105., 45., -75.)

# 
# SOUTHEAST
# upper left:  40.3191, -98.4864
# upper right:  37.6356, -75.9925
# lower right:  23.3686, -80.2597
# lower left:  25.522, -98.932
# 
# SOUTH
# upper left:  38.757, -108.312
# upper right:  37.9824, -85.7724
# lower right:  23.4201, -88.3926
# lower left:  24.0398, -107.04
# 
# CENTRAL
# upper left:  43.954, -107.949
# upper right:  42.9414, -83.6839
# lower right:  28.3025, -86.8428
# lower left:  29.1194, -106.662
# 
# NORTHEAST
# upper left:  49.2485, -92.1585
# upper right:  45.138, -67.0883
# lower right:  31.0891, -73.3912
# lower left:  34.4401, -93.912

HRRR_grid = { "SE": { 'grid_lats': ( 25.522,  23.3686,  37.6356,  40.3191),
                      'grid_lons': (-98.932, -80.2597, -75.9925, -98.4864),
                      'boundary_zone': ( 0.,  100., 200.),
                      'alphas':        ( 0.2, 0.4,  0.6),
                    },
              "SC": { 'grid_lats': (  24.0398, 23.4201,  37.9824,   38.757),
                      'grid_lons': (-107.04,  -88.3926, -85.7724, -108.312),
                      'boundary_zone': ( 0.,  100., 200.),
                      'alphas':        ( 0.2, 0.4,  0.6),
                    },
              "CP": { 'grid_lats': (  29.1194, 28.3025,  42.9414,   43.954),
                      'grid_lons': (-106.662, -86.8428, -83.6839, -107.949),
                      'boundary_zone': ( 0.,  100., 200.),
                      'alphas':        ( 0.2, 0.4,  0.6),
                    },
              "NP": { 'grid_lats': (  36.4470, 34.8041,  47.9372,   49.9149),
                      'grid_lons': (-106.219, -81.2196, -76.8972, -107.4062),
                      'boundary_zone': ( 0.,  100., 200.),
                      'alphas':        ( 0.2, 0.4,  0.6),
                    },
              "NE": { 'grid_lats': (  35.2481,  31.5255,  44.2604,  48.7421),
                      'grid_lons': ( -96.3312, -72.4002, -66.5531, -95.2896),
                      'boundary_zone': ( 0.,  100., 200.),
                      'alphas':        ( 0.2, 0.4,  0.6),
                    }
             }

            
_station_file         = 'conus2015.tbl'
_radar_file           = 'nexrad_stations.txt'
_default_WOFS_size   = 900.   # width of domain in km
#_default_WOFS_size   = 1005.   # width of domain in km
_default_grid_center  = "TCL"
_default_max_radars   = 7      # Not used....
radar_buf_dis         = 100000.

# constants

__r_earth              = 6367000.0
__truelat1, __truelat2 = 38.5, 38.5

#==================================================================================
def read_radar_location_file(_radar_file):
  
    f = open(_radar_file, 'r')
        
    header1 = f.readline()
    
    radar_locations_dict = {}
    
    one_sixty = 1./ 60.
    
    for line in f:
        col = line.split()
        lat = float(col[2]) + one_sixty*(float(col[3]) + one_sixty*float(col[4]))
        lon = float(col[5]) + one_sixty*(float(col[6]) + one_sixty*float(col[7]))
        alt = 0.001 * float(col[8])
        radar_locations_dict[col[0]] = (lat, -lon, alt)
    
    return radar_locations_dict
    
#==================================================================================
def read_radar_location_file2(_radar_file):
  
    f = open(_radar_file, 'r')
        
    header1 = f.readline()
    
    radar_locations_dict = {}
    
    one_sixty = 1./ 60.
    
    for line in f:
        col = line.split()
        lat = float(col[-5])
        lon = float(col[-4])
        alt = 0.0003048 * float(col[-3])
        radar_locations_dict[col[1]] = (lat, lon, alt)
    
    return radar_locations_dict

#==================================================================================
def read_sfc_station_file(_station_file):

    f = open(_station_file, 'r')
    
    sfc_stations_dict = {}

    for line in f:
        col = line.split()
        sfc_stations_dict[col[0]] = (0.01*float(col[5]), 0.01*float(col[6]))
    
    return sfc_stations_dict

#==================================================================================
             
def mybasemap(sw_lat, sw_lon, ne_lat, ne_lon, scale = 1.0, ticks = True, 
              resolution='l', area_thresh = 1000., shape_env = False, 
              counties=False, states = False, countries=False, coastlines=False,
              lat_lines=0, lon_lines=0, 
              pickle = False, ax=None, lon_0 = None, lat_0 = None):

    tt = timeit.clock()
    
    if lon_0 == None:
        lon_0=0.5*(sw_lon+ne_lon)
        
    if lat_0 == None:
        lat_0=0.5*(sw_lat+ne_lat)

    map = Basemap(llcrnrlon=sw_lon, llcrnrlat=sw_lat,  
                  urcrnrlon=ne_lon, urcrnrlat=ne_lat,  
#                  lat_0=lat_0, lon_0=lon_0,  
                  lat_0=lat_0, lon_0=-97.5,  
                  lat_1 = __truelat1, lat_2 = __truelat2,  
                  projection = 'lcc',       
                  resolution=resolution,    
                  area_thresh=area_thresh,  
                  suppress_ticks=ticks, ax=ax)

    if counties:
        map.drawcounties()
    
    if states:
        map.drawstates()
        
    if countries:
        map.drawcountries()
    
    if coastlines:
        map.drawcoastlines()
       
    if lat_lines > 0:
        lat_lines = N.arange(sw_lat, ne_lat, lat_lines)
        map.drawparallels(lat_lines, labels=[True, False, False, False])
       
    if lon_lines > 0:
        lon_lines = N.arange(sw_lon, ne_lon, lon_lines)
        map.drawmeridians(lon_lines, labels=[False, False, False, True])

# Shape file stuff

    if shape_env:

        for item in shape_env:
            items = item.split(",")
            shapefile  = items[0]
            color      = items[1]
            linewidth  = float(items[2])
            
            s = map.readshapefile(shapefile,'shapeinfo',drawbounds=False)

            for shape in map.shapeinfo:
                xx, yy = zip(*shape)
                #map.plot(xx,yy,color=color,linewidth=linewidth,ax=ax)
                map.plot(xx,yy,color='gray',linewidth=linewidth,ax=ax)

    return map

#//////////////////////////////////////////// MAIN ///////////////////////////////////////////////

print('\n------------------------------------------------------------------------------------\n')
print('  ==> BEGIN PROGRAM WOFS Grid and Radars')
print('\n------------------------------------------------------------------------------------\n')
        
# parse command line

parser = OptionParser()
parser.add_option("-s", "--station", dest="station", type="string", default=None, help = "Station name to center the WOFS grid on")
parser.add_option("-w", "--width",   dest="width",   type="int",    default=None, help = "Size of WOFS domain in km")
parser.add_option("-p", "--plot",    dest="plot",                   default=False, help = "Boolean flag to interactively plot domain", action="store_true")
parser.add_option(      "--nudge",   dest="nudge",   type="int",    default=None, nargs = 2, help="Nudge the box X/Y km from station point: DX DY")
parser.add_option("-r", "--region",  dest="region",  type="string", default="CP", help="Background HRRR region:  Valid regions are CP, NE, SE, SC, default is CP")

(options, args) = parser.parse_args()
 
if options.station == None:
    print("\n  !!!!! ERROR:  !!! FORGOT to put the 3-letter identifier for the WOFS grid center location on command line !!!\n ")
    parser.print_help()
    print
    sys.exit(1)
else:
    print("\n  WOFS grid center location supplied, using the input value of %s \n " % options.station)
    station_c = options.station    

if options.width == None:
    print("\n  No WOFS grid width supplied, using the default of %d km \n " % _default_WOFS_size)
    WOFS_size = 1000. * _default_WOFS_size
else:
    print("\n  WOFS grid width supplied, using the input value of %d km \n " % options.width)
    WOFS_size = 1000. * options.width
    
if options.nudge:
    x_nudge = 1000.*float(options.nudge[0])
    y_nudge = 1000.*float(options.nudge[1])
    print("\n  WOFS grid nudge supplied, moving the grid DX = %d  DY = %d km \n " % (options.nudge[0], options.nudge[1]))
else:
    x_nudge, y_nudge = 0.0, 0.0

print('\n------------------------------------------------------------------------------------\n')
print('  ==> HRRRe grid location is %s \n' % options.region)
print('\n------------------------------------------------------------------------------------\n')
          
print('\n------------------------------------------------------------------------------------\n')
print('  ==> Reading in data base information\n')
          
stations = read_sfc_station_file(_station_file)

print("  Read in sfc station file successfully\n")

radars = read_radar_location_file2(_radar_file)

print("  Read in radar file successfully\n")

print('------------------------------------------------------------------------------------\n')


fig, (ax1) = P.subplots(1, 1, sharey=True, figsize=(7,7))

# need the WOFS grid location for map projection

lat_c, lon_c = stations[station_c]

#  Okay, finished with setting things up - onto getting things done

print("  Input station: %s is located at %f  %f\n" % (station_c, stations[station_c][0], stations[station_c][1]))

#map = mybasemap(22.5, -110., 45., -72., states=True, countries=True, coastlines=True, ax=ax1, lat_0=lat_c, lon_0=lon_c)
map = mybasemap(21.13812, -122.7195, 47.85785, -60.84946, states=True, countries=True, coastlines=True, ax=ax1, lat_0=lat_c, lon_0=-97.5)

##Plot HRRR grid with boundary strips....
#
#x0, y0 = map(HRRR_grid[options.region]['grid_lons'],HRRR_grid[options.region]['grid_lats'])
#
#for n, item in enumerate(HRRR_grid[options.region]['boundary_zone']): 
#    
#    x, y = N.array(x0), N.array(y0)
#
#    strip = item*1000.
#    
#    x[0] = x[0] + strip
#    x[1] = x[1] - strip
#    x[2] = x[2] - strip
#    x[3] = x[3] + strip
#
#    y[0] = y[0] + strip
#    y[1] = y[1] + strip
#    y[2] = y[2] - strip
#    y[3] = y[3] - strip
#
#
#    x = N.append(x,x[0])
#    y = N.append(y,y[0])
#    
#    P.fill(x, y, color='b', alpha=HRRR_grid[options.region]['alphas'][n])

#Plot NEWS grid - create Lambert conformal map based on width and height of domain and center point

x0, y0 = map(lon_c, lat_c)

lon_c, lat_c = map(x0+x_nudge, y0+y_nudge, inverse=True)

if x_nudge > 0 or y_nudge > 0:
   print("  Grid center moved, new center is is located at %f  %f\n" % (lat_c, lon_c))

# Convert to radians to create corners

lat_c, lon_c = N.deg2rad(lat_c), N.deg2rad(lon_c)

glat = N.zeros(5)
glon = N.zeros(5)
  
glat[0] = lat_c - 0.5*(WOFS_size) / __r_earth
glat[1] = lat_c + 0.5*(WOFS_size) / __r_earth
glat[2] = lat_c + 0.5*(WOFS_size) / __r_earth
glat[3] = lat_c - 0.5*(WOFS_size) / __r_earth
glat[4] = lat_c - 0.5*(WOFS_size) / __r_earth
 
glon[0] = lon_c - 0.5*(WOFS_size) / (__r_earth * N.cos(glat[0]))
glon[1] = lon_c - 0.5*(WOFS_size) / (__r_earth * N.cos(glat[1]))
glon[2] = lon_c + 0.5*(WOFS_size) / (__r_earth * N.cos(glat[2]))
glon[3] = lon_c + 0.5*(WOFS_size) / (__r_earth * N.cos(glat[3]))
glon[4] = lon_c - 0.5*(WOFS_size) / (__r_earth * N.cos(glat[4]))

glon = N.rad2deg(glon)
glat = N.rad2deg(glat)

xg, yg = map(glon, glat)

P.fill(xg, yg, linewidth=2, color='g', alpha=0.2)

#P.title("27 April 2011 \n 100 km bounding boxes \n Radars (150 km range rings)", fontsize=18)
P.title("Radar locations within experimental WoFS grid shown as blue dots with 150-km range rings \n \n \n SYSTEM STATUS:  RUNNING", y=-0.25, fontsize=10)

title = ("3-km HRRRE background and nested experimental WoFS grid")

fig.suptitle(title, y=0.8, fontsize=14)

# search for radars inside the grid

radar_name= []
radar_lon = []
radar_lat = []
radar_alt = []

for key in radars:
    x, y = map(radars[key][1], radars[key][0]) 
    #if x <= max(xg) and x >= min(xg) and y<= max(yg) and y >= min(yg):
    if x-radar_buf_dis <= max(xg) and x+radar_buf_dis >= min(xg) and \
       y-radar_buf_dis <= max(yg) and y+radar_buf_dis >= min(yg):
        radar_lon.append(radars[key][1])
        radar_lat.append(radars[key][0])
        radar_alt.append(radars[key][2])
        radar_name.append(key)
          
        circle1 = P.Circle((x,y), 150000.,color='gray', linewidth=1, fill=False)
        fig.gca().add_artist(circle1)

#        circle = P.Circle((x,y), 2500.,color='blue', fill=False)
#        fig.gca().add_artist(circle)

        circle = P.scatter(x, y, 3, marker='o', color='blue')
        fig.gca().add_artist(circle)

event = strftime("%Y%m%d")
fout = 'radars.' + event + '.csh'

# Write out csh file.....
 
outfile = open(fout, 'w')
outfile.write("#!/bin/csh\n#\n")

nradars = len(radar_name)

outfile.write("setenv num_rad %d\n" % nradars)

outfile.write("set rad_lon = ( %s )\n" % (' '.join([str(x) for x in radar_lon]))) 

outfile.write("set rad_lat = ( %s )\n" % (' '.join([str(x) for x in radar_lat]))) 

outfile.write("set rad_alt = ( %s )\n" % (' '.join([str(x) for x in radar_alt]))) 

outfile.write("set rad_name = ( %s )\n" % (' '.join([x for x in radar_name])))

outfile.write("setenv cen_lat %f\n" % N.rad2deg(lat_c))

outfile.write("setenv cen_lon %f\n" % N.rad2deg(lon_c))

outfile.write("setenv lat_ll %f\n" % glat[0])
outfile.write("setenv lat_ur %f\n" % glat[1])
outfile.write("setenv lon_ll %f\n" % glon[0])
outfile.write("setenv lon_ur %f\n" % glon[2])

#outfile.write("setenv region %s\n" % options.region)

#outfile.write("setenv year %s\n" % date.year)

outfile.close()

print("\n  Found %d radars within domain\n" % nradars)

fout2 = 'WOFS_domain_' + event + '.png'

if options.plot:
    P.savefig(fout2)
    P.show()
else:
    P.savefig(fout2)

print('\n------------------------------------------------------------------------------------\n') 
print("\n  Wrote out plot file with name %s\n" % 'WOFS_grid_radar.png')
print("\n  Wrote out radar file to be sourced with name %s\n" % 'radars.csh')
print('\n------------------------------------------------------------------------------------\n')
print('  ==> END PROGRAM WOFS Grid and Radars')
print('\n------------------------------------------------------------------------------------\n')


