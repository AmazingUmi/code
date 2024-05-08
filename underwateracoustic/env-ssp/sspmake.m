%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
etop_dir = 'etopo1.mat';   woa18_dir = 'WOA18_mat';
% 从数据集中加载地形数据和声速剖面数据
[ETOPO, WOA18] = load_data(etop_dir, woa18_dir);
%clear
clear etop_dir; clear woa18_dir; clear index; clear pathstr; clear tmp;
%% 设定位置

timeIdx = 13;
%声源点位
coordS.lon = 115; 
coordS.lat = 20;
%测线方向及长度
azi  = 90;
rmax = 200; 
dr = 5;
n = rmax/dr+1;
%计算最远距离接收点经纬度
coordE = [];
[coordS, coordE, rmax, ] = coord_proc(coordS, coordE, rmax, azi);

lon = linspace(coordS.lon, coordE.lon, n);
lat = linspace(coordS.lat, coordE.lat, n);

% 读取声速剖面及地形
[seaDepth, ssp_raw, SSP] = get_env(ETOPO, WOA18, lat, lon, timeIdx);
clear azi;clear lat;clear lon; clear ssp_raw;clear ETOPO;clear WOA18;
clear coordE;clear coordS;
%% 添加中尺度现象

%添加高斯涡
rc = 100; %涡心水平位置
zc = 200; %涡心竖直位置
DR = 50;  %涡水平尺度
DZ = 100; %涡竖直尺度
DC = 100; %涡的强度
dc = zeros(size(SSP.c));

r = linspace(0,rmax,n);
z = SSP.z;
m = length(z);
parfor i=1:n
    for j=1:m
        dc(j,i)=DC*exp(  -((r(i)-rc)/DR)^2  -((z(j)-zc)/DZ)^2   );
    end
end
ssp = dc + SSP.c;
