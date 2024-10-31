%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('E:\Umicode\matlab\underwateracoustic\bellhop_fundation\function');
addpath('E:\干活\715\10月开发\WOA18_mat');

etop_dir = 'etopo1.mat';   woa18_dir = 'WOA18_mat';
[ETOPO, WOA18] = load_data(etop_dir, woa18_dir);
clear etop_dir; clear woa18_dir; clear index; clear pathstr; clear tmp;
%% 读取声速
%目标点位
coordS.lon = 115;
coordS.lat = 13;
MouthIdx = 1;          % 声速剖面采样月份
[~, ssp_raw, ~] = get_env(ETOPO,WOA18,coordS.lat,coordS.lon, MouthIdx); % 获取平均声速剖面
depth = 0:1:max(ssp_raw(:,1));
ssp = interp1(ssp_raw(:,1),ssp_raw(:,2),depth);
h = figure;
plot(ssp,depth)
set(gca,'XAxisLocation','top');
set(gca,'YDir','reverse');
hold on
%% 计算反转点
dc = 0.5*(ssp(1:end-2)-ssp(3:end));
dd = depth(2:end-1);
ddc = dc(1:end-1).*dc(2:end);
loc = find(ddc<0);
yline(loc(1),'-.b','Surface Sound Channel Axis');
yline(loc(2),'-.r','Deep Sound Channel Axis');
ylim([-200,max(depth)]);

n1=num2str(coordS.lon) ;
n2=num2str(coordS.lat);
titlename=[n1,'°E,',n2,'°N','位置附近声道轴特性示意图'];
jpgname=['声道轴特性分析', '.png'];
t=title(titlename,'FontSize',10,'FontName','宋体');
print(h, jpgname,'-r600','-djpeg');%-r600可改为300dpi分辨率