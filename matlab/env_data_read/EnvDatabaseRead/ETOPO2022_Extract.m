%%初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr); %addpath([pathstr '\function']);
%% 
ETPPath = 'D:\database\others\OceanDataBase\ETOPO2022\DATA';
OutPath = 'D:\database\others\OceanDataBase\pytest_dir\matpack';
Outname = 'ETOPO2022';

delta = 0.010;  %范围边界余量
LAT = [5-delta, 25+delta]; 
LON = [105-delta, 125+delta];

cd(ETPPath);


LAT_N = (15*(floor(LAT(1)/15)+1)):15:(15*ceil(LAT(2)/15));
LON_N = (15*floor(LON(1)/15)):15:(15*(ceil(LON(2)/15)-1));

Lat1 = zeros(length(LAT_N)*3600, 1);
Lon1 = zeros(length(LON_N)*3600, 1);
Z = zeros(length(LON_N)*3600, length(LAT_N)*3600);
for i_lat = 1:length(LAT_N)
    for i_lon = 1:length(LON_N)
        if LAT_N(i_lat) >= 0
            lat_str = sprintf('N%02d', LAT_N(i_lat));
        else
            lat_str = sprintf('S%02d', abs(LAT_N(i_lat)));
        end
        if LON_N(i_lon) >= 0
            lon_str = sprintf('E%03d', LON_N(i_lon));
        else
            lon_str = sprintf('W%03d', abs(LON_N(i_lon)));
        end
        
        filename = sprintf('ETOPO_2022_v1_15s_%s%s_surface.nc', lat_str, lon_str);
        lat = ncread([ETPPath, '\',  filename], 'lat');
        lon = ncread([ETPPath, '\',  filename], 'lon');
        z = ncread([ETPPath, '\',  filename], 'z');
        
        if i_lat == 1
            Lon1((i_lon-1)*3600+1:i_lon*3600) = lon;
        end
        Z((i_lon-1)*3600+1:i_lon*3600, (i_lat-1)*3600+1:i_lat*3600) = z;
    end
    Lat1((i_lat-1)*3600+1:i_lat*3600) = lat;
end

idx_x = Lon1>=LON(1) & Lon1<=LON(end);
idx_y = Lat1>=LAT(1) & Lat1<=LAT(end);
Lon = Lon1(idx_x);
Lat = Lat1(idx_y);
Altitude = Z(idx_x, idx_y);
Dimension = "Lon × Lat";
save([OutPath, '\', Outname], 'Lon', 'Lat', 'Altitude', 'Dimension');
