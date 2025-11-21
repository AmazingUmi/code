%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr(1:end-9),'underwateracoustic\bellhop_fundation\function'));
clear pathstr tmp index;
cd('D:\code\matlab\underwateracoustic\bellhop_fundation');
clear pathstr;clear tmp;clear index;
etop_dir = 'etopo1.mat';   woa18_dir = 'WOA18_mat';
% 从数据集中加载地形数据和声速剖面数据
[ETOPO, WOA18] = load_data(etop_dir, woa18_dir);
%clear
clear etop_dir; clear woa18_dir; clear index; clear pathstr; clear tmp;
%% 
%经纬度范围
Latbe = [115.5,113.5];%待选区域范围
Laten = [116.5,114.5];
%数据范围
%zone1: 13.67,22.25     109.0,117,66
%zone2: -10.916,3.583   83.0,100.16

%目标海区范围
%1 [115.63,116.58] [17.35,19.23]
%2 [113.70,114.68] [13.67,15.22]
%3 [115.17,116.93] [16.32,17.28]
%4 [109.77,111.58] [13.68,15.68]
Lat = [6,25];%大图区域范围
Lon = [109,125];

%绘大图
plotgeomap(Lat, Lon);
rectangle('Position',[115.63,17.35,0.95,1.88],'EdgeColor','r','LineWidth',1.5);
rectangle('Position',[113.70,13.67,0.98,1.55],'EdgeColor','g','LineWidth',1.5);
rectangle('Position',[115.17,16.32,1.76,0.96],'EdgeColor','y','LineWidth',1.5);
rectangle('Position',[109.77,13.68,1.81,2],'EdgeColor','w','LineWidth',1.5);
xlim([109,125]);ylim([6,25]);

lon1 = [115.63,116.58];lat1 = [17.35,19.23];
plotgeomap(lat1, lon1);
lon2 = [113.70,114.68];lat2 = [13.67,15.22];
plotgeomap(lat2, lon2);
lon3 = [115.17,116.93];lat3 = [16.32,17.28];
plotgeomap(lat3, lon3);
lon4 = [109.77,111.58];lat4 = [13.68,15.68];
plotgeomap(lat4, lon4);
%% 

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
%地理信息展示

plot(coordS.lon, coordS.lat, 'ro', 'LineWidth', 1.5, 'DisplayName', 'S');
plot(coordE.lon, coordE.lat, 'x' , 'LineWidth', 1.5, 'DisplayName', 'E');
legend;
clear Lat; clear Lon;

n=ceil(rmax)+1;
lat=linspace(coordS.lat,coordE.lat,n);
lon=linspace(coordS.lon,coordE.lon,n);
r=linspace(0,rmax,n);
depth = get_bathm(ETOPO, lat, lon);
figure
plot(r,-depth);
xlabel('range/km');
ylabel('depth/m');