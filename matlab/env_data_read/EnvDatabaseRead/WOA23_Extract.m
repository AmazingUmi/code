%%初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr); %addpath([pathstr '\function']);
%% 
%WOA数据说明：00代表全年平均，01-12代表各月平均，13-16代表季平均，13对应1-3月平均
WOAPath = 'D:\database\others\OceanDataBase\WOA23';
OutPath = 'D:\database\others\OceanDataBase\pytest_dir\matpack';
Outname = 'woa23_%02d.mat';

delta = 0.010;  %范围边界余量
LAT = [5-delta, 25+delta]; 
LON = [105-delta, 125+delta];

cd(WOAPath);
% 用ncread函数读取*.nc文件
for timeIdx = 0:16
sal_file = sprintf('woa23_decav91C0_s%02d_04.nc', timeIdx);
temp_file = sprintf('woa23_decav91C0_t%02d_04.nc', timeIdx);
lon_woa = ncread(sal_file, 'lon');
lat_woa = ncread(sal_file, 'lat');
depth_woa = ncread(sal_file, 'depth');
depth = reshape(depth_woa,[1,1,length(depth_woa)]);
Sal = ncread(sal_file, 's_an');
Temp = ncread(temp_file, 't_an');

%C = 1449.2 + 4.6*T - 0.055*T^2 + 0.00029*T^3 + 
%(1.34 - 0.01*T)(S-35) + 0.017*D

% 计算声速
%C = 1449.2 + 4.6*Temp - 0.055*Temp.^2 + 0.00029*Temp.^3 + ...
%    (1.34-0.01*Temp).*(Sal-35) + 0.017*depth;

lat_idx = (lat_woa >= LAT(1)) & (lat_woa <= LAT(end)); 
lon_idx = (lon_woa >= LON(1)) & (lon_woa <= LON(end));

Sal = Sal(lon_idx, lat_idx, :);
Temp = Temp(lon_idx, lat_idx, :);
Lat = lat_woa(lat_idx);
Lon = lon_woa(lon_idx);
Depth =  depth_woa;
save([OutPath, '\',  sprintf(Outname, timeIdx)],'Sal', 'Temp', 'Lat', 'Lon', 'Depth');
end