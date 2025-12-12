%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SSPMAKE 声速剖面生成及中尺度现象添加工具
%   生成二维声速剖面数据，并可选择性地添加中尺度海洋现象（涡或内波）
%
% 功能说明:
%   1. 加载ETOPO地形数据和WOA23声速剖面数据
%   2. 设置目标位置、方位角和距离范围
%   3. 提取二维声速剖面数据
%   4. 可选添加中尺度现象（根据配置文件）
%   5. 绘制声速剖面图
%   6. 可选输出.ssp文件
%
% 作者: [猫猫头]
% 日期: [2025-12-09]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\');
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr, 'function'));
clear pathstr tmp index;

%% 加载海洋环境数据
fprintf('===== 加载海洋环境数据 =====\n');

OceanDataPath = fullfile(pathstr, 'data\OceanData');
ETOPOName     = 'ETOPO2022.mat';
WOAName       = 'woa23_%02d.mat';

[ETOPO, WOA] = load_data(OceanDataPath, ETOPOName, WOAName);
fprintf('数据加载完成\n\n');

clear OceanDataPath ETOPOName WOAName;
%% 设定位置和参数
fprintf('===== 设置计算参数 =====\n');

timeIdx = 13;  % 时间索引 (1-12:月份, 13-16:季节, 17:年平均)

% 声源点位
coordS.lon = 115;  % 经度 (°E)
coordS.lat = 13;   % 纬度 (°N)

% 测线方向及长度
azi  = 0;    % 方位角 (°)
rmax = 200;  % 最大距离 (km)
dr = 1;      % 距离间隔 (km)
n = rmax/dr+1;

fprintf('起始位置: 经度=%.2f°E, 纬度=%.2f°N\n', coordS.lon, coordS.lat);
fprintf('方位角: %d°, 最大距离: %d km\n\n', azi, rmax);

% 计算最远距离接收点经纬度
coordE = [];
[coordS, coordE, rmax, ~] = coord_proc(coordS, coordE, rmax, azi);
%% 提取声速剖面
fprintf('===== 提取声速剖面 =====\n');

lon = linspace(coordS.lon, coordE.lon, n);
lat = linspace(coordS.lat, coordE.lat, n);

% 读取声速剖面及地形
[~, ~, SSP] = get_env(ETOPO, WOA, lon, lat, timeIdx);

fprintf('声速剖面提取完成\n');
fprintf('深度点数: %d, 距离点数: %d\n\n', length(SSP.z), n);

clear coordE coordS lon lat;
%% 添加中尺度现象
fprintf('===== 添加中尺度现象 =====\n');

% 配置中尺度现象参数
phenomenon_type = 'eddy';  % 'none', 'eddy', 'internal_wave'

if strcmp(phenomenon_type, 'eddy')
    % 高斯涡参数
    params.rc = 100;  % 涡心水平位置 (km)
    params.zc = 600;  % 涡心竖直位置 (m)
    params.DR = 70;   % 涡水平尺度 (km)
    params.DZ = 400;  % 涡竖直尺度 (m)
    params.DC = -40;  % 涡的强度 (m/s, 负值为冷涡)
    fprintf('添加高斯涡: 位置=(%.0f km, %.0f m), 尺度=(%.0f km, %.0f m), 强度=%.1f m/s\n', ...
        params.rc, params.zc, params.DR, params.DZ, params.DC);
elseif strcmp(phenomenon_type, 'internal_wave')
    % 内波参数
    params.z0 = 1000;  % 内波基准深度 (m)
    params.L = 40;     % 特征长度 (km)
    params.rc = 100;   % 波峰中心所在距离 (km)
    params.DC = 500;   % 内波强度 (m)
    fprintf('添加内波: 基准深度=%.0f m, 特征长度=%.0f km, 强度=%.0f m\n', ...
        params.z0, params.L, params.DC);
else
    params = [];
    fprintf('不添加中尺度现象\n');
end

% 使用 add_mesoscale 函数添加中尺度现象
SSP = add_mesoscale(SSP, rmax, phenomenon_type, params);
fprintf('中尺度现象处理完成\n\n');
%% 输出结果
fprintf('===== 绘制声速剖面 =====\n');

r = linspace(0, rmax, n);
z = SSP.z;

% 绘图
figure;
pcolor(r, z, SSP.c);
shading interp; 
colormap(jet);
colorbar('YDir', 'Reverse');
set(gca, 'YDir', 'Reverse');
xlabel('Range (km)');
ylabel('Depth (m)');
title('声速剖面');
% caxis([1490, 1540]);

fprintf('绘图完成\n\n');

% 输出.ssp文件
% sspfile = 'test';
% write_ssp(sspfile, r, SSP);
% fprintf('SSP文件已保存: %s.ssp\n', sspfile);