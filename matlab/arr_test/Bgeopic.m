%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);addpath([pathstr '\function']);
addpath(fullfile(pathstr(1:end-9),'underwateracoustic\bellhop_fundation\function'));
clear pathstr tmp index;
% 加载环境数据
EnviromentsDATA_PATH  = 'G:\database\EnviromentsDATA';
etop_dir = [EnviromentsDATA_PATH,'\targetETOPO.mat'];
woa23_dir = [EnviromentsDATA_PATH,'\target_WOA23_mat'];
[ETOPO, WOA23] = load_data_new(etop_dir, woa23_dir);
clear etop_dir woa23_dir EnviromentsDATA_PATH;
%% 点位经纬度设置 [三选一]
sign = 3; %shallow sea = 1, Transition zone = 2, Deepsea = 3
% 目标点位参数
if sign == 1
    % Shallow Sea
    ENVall_folder = fullfile('G:\database\Enhanced_shipsEar0405','Shallow');
    lat = [19.50 7.10 23.30 11.00 9.50 20.20];
    lon = [107.00 117.80 118.20 121.00 107.50 112.00];
    ReceiveRange = [1, 5, 10];    % 接收距离
    ReceiveDepth = [10, 20, 30];
elseif sign ==2
    % Transition zone
    ENVall_folder = fullfile('G:\database\Enhanced_shipsEar0405','Transition');
    lat = [18.80 8.20 20.40 15.10 14.10 17.00];
    lon = [114.30 118.50 117.60 123.00 110.10 112.40];
    ReceiveRange = [5, 30, 60];
    ReceiveDepth = [25, 50, 100, 300];
else
    % Deep Sea
    ENVall_folder = fullfile('G:\database\Enhanced_shipsEar0405','Deep');
    lat = [17.80 21.90 13.90 6.00 18.00 11.90];
    lon = [117.90 122.50 116.20 123.00 124.00 113.00];
    ReceiveRange = [5, 30, 60];
    ReceiveDepth = [25, 50, 100, 300];
end



%% 绘图
% 经纬度范围
Lat = [5,25];
Lon = [105,125];
azi  = 0;
rmax = max(ReceiveRange);
% 地理信息展示
plotgeomap(Lat, Lon);
for i = 1:length(lat)
    plot(lon(i), lat(i), 'o', 'LineWidth', 1.5, 'DisplayName', ['s',num2str(i)]);
    legend;
end

% 海底地形展示
figure
for i = 1:length(lat)
    coordS.lon = lon(i);
    coordS.lat = lat(i);
    coordE = [];
    [coordS, coordE, rmax, azi] = coord_proc(coordS, coordE, rmax, azi);
    N = max(rmax+1, 2);    % N:默认以1km的间隔将区间划分网格需要的网格点数，至少两个点
    lat_vector = linspace(coordS.lat, coordE.lat, N);
    lon_vector = linspace(coordS.lon, coordE.lon, N);
    r=linspace(0,rmax,N);
    subplot(3,2,i)
    [bathm, SSP] = get_env_new(ETOPO,WOA23,lat_vector,lon_vector,1);
    plotssp_bty(r,bathm,SSP)%绘制二维ssp以及bty
end
