# The script requires module requests and bs4
# If you don't have these modules, use the following command to install
# The script works for python 3.6
# conda install -c conda-forge requests
# conda install -c conda-forge bs4

import os, requests
from bs4 import BeautifulSoup
from multiprocessing import Pool, Array

# This website provide the gerenal AWS download links by the Univeristy of Utah
# for 2021 GOES-16 GLM data. To look for links for different L1B and L2 products
# from GOES-R series (including 16 and 17 go check
# https://home.chpc.utah.edu/~u0553130/Brian_Blaylock/cgi-bin/goes16_download.cgi
url = 'https://home.chpc.utah.edu/~u0553130/Brian_Blaylock/cgi-bin/generic_AWS_download.cgi?DATASET=noaa-goes16&BUCKET=GLM-L2-LCFA/2021'

# The directory for saving GOES netcdf files
target_dir = '/work/sijie.pan/GOES-16/GLM'

# Need to specify the extension for download files
# For GLM data, it is "nc"
ext = 'nc'

# Julian day of the year for the date you interest
day = 118
#The script download the files between 15 - 03(next day) UTC
#You can modify the starth and endh to change the time
#e.g., for 15 - 03, starth=15, endh=27
#e.g., for 18 - 00, then starth=18, endh=25
starth = 17
endh = 27

#Set the number of processors used for parallelly download
#The number of processors should be less than the number of
#hours (endh - starth) to avoid potential disk io issues
nproc = 10


def get_list(url, ext) -> list:
    page = requests.get(url).text
    soup = BeautifulSoup(page, 'html.parser')
    url_list = []
    for node in soup.find_all("a"):
        aws_link = node.get('href')
        if aws_link and aws_link.endswith(ext):
            url_list.append(aws_link)
    return url_list


def download_queue(url_list) -> None:
    if not url_list:
        print("The list of url for {}{} is empty".format(self.day, self.hour))
        return None
        
    for iurl in url_list:
        filename = iurl[61:]
        print(filename)
        command = "curl " + iurl + " -o " + target_dir + "/" + filename
        os.system(command)


def get_and_download(url, ext):
    dl_list = get_list(url, ext)
    download_queue(dl_list)


if __name__ == "__main__":
    p=Pool(nproc)

    for hour in range(starth, endh):
        if hour == 24:
            day += 1
        if hour >= 24:
            hour -= 24

        currURL = url + "/" + str(day) + "/" + str(hour).zfill(2)
        result = p.apply_async(get_and_download, args=(currURL, ext,))

    p.close()
    p.join()
    print("Download processes have finished!")
