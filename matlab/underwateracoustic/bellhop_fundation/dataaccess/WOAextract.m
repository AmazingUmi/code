%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
pathstr = fileparts(tmp.Filename);
cd(pathstr);
addpath(pathstr);
clear pathstr tmp index;
%%
DATA_pathstr   = 'D:\database\others\WOA18';%原始数据集位置
Output_pathdir = "D:\database\others\WOA18_swellex";
Output_name    = 'woa18_%02d.mat';

if exist(Output_pathdir, 'dir') ~= 7
    mkdir(Output_pathdir);
end
%经纬度范围设置
LAT = [32-0.01,33+0.01];
LON = [-118-0.01,-117+0.01];
%% 
cd(DATA_pathstr);
%读取nc文件
for timeIdx = 0:16
    sal_file = sprintf('woa18_A5B7_s%02d_04.nc', timeIdx);
    temp_file = sprintf('woa18_A5B7_t%02d_04.nc', timeIdx);
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
    save(fullfile(Output_pathdir,sprintf(Output_name,timeIdx)),'Sal','Temp','Lat','Lon','Depth');
end
