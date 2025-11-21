%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);addpath([pathstr '\function']);

etopo_dir = 'targetETOPO.mat';   woa23_dir = 'target_WOA23_mat';
[ETOPO, WOA23] = load_data(etopo_dir, woa23_dir);
clear pathstr tmp index etopo_dir woa23_dir;
%% 目标信息
%经纬度范围
Lat = [5,25];
Lon = [105,125];
timeIdx = 1;
%声源点位
coordS.lon = 116; 
coordS.lat = 15;
depth = get_bathm(ETOPO, coordS.lat, coordS.lon);
%测线方向及长度
azi  = 0;
rmax = 30; 
%计算最远距离接收点经纬度
coordE = [];
[coordS, coordE, rmax, azi] = coord_proc(coordS, coordE, rmax, azi);
%% 
% 将两端点连线等间距划分，后续插值
N = max(rmax*2+1, 2);
lat = linspace(coordS.lat, coordE.lat, N);  
lon = linspace(coordS.lon, coordE.lon, N);
r=linspace(0,rmax,N);
[bathm, SSP] = get_env_new(ETOPO,WOA23,lat,lon,timeIdx);
plotssp_bty(r,bathm,SSP)%绘制二维ssp以及bty



