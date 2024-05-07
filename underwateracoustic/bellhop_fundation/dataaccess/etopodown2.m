clc
clear
close all
Folder_Name = 'Data_Download';

% https://www.ngdc.noaa.gov/thredds/fileServer/global/ETOPO2022/15s/15s_bed_elev_netcdf/ETOPO_2022_v1_15s_N60W030_bed.nc
% 'https://www.ngdc.noaa.gov/thredds/fileServer/global/ETOPO2022/15s/15s_bed_elev_netcdf/ETOPO_2022_v1_15s_N60W030_bed.nc'
for i = 1:7
    for j = 1:13
        lat=0+5*(i-1);lat=num2str(lat);
        lon=0+5*(j-1);lon=num2str(lon);

        httpsUrl=['https://www.ngdc.noaa.gov/thredds/fileServer/global/ETOPO2022/15s/15s_bed_elev_netcdf/ETOPO_2022_v1_15s_N',lat, 'E0',lon,'_bed.nc']

    end
end