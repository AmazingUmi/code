%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CONFIGMAKER 海洋声学环境配置文件生成器
%   用于配置水声传播计算所需的真实海洋环境参数，包括站点位置、声源参数和计算设置
%
% 功能说明:
%   1. 定义浅海、过渡区、深海三种海域的站点位置和接收参数
%   2. 配置声源参数（位置、频率、时间索引等）
%   3. 设置Bellhop声场计算参数（边界条件、波束参数等）
%   4. 生成配置文件保存为Config.mat
%
% 输出文件:
%   Config.mat - 包含Site_loc、Source、Cal三个结构体
%
% 作者: [猫猫头]
% 日期: [2025-12-03]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\');
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath([pathstr '\function']);
clear pathstr tmp index;

%% 路径设置
OriginEnvPackPath = 'G:\code\matlab\UASignalAugmentor\data\OriginEnvPack';
ConfigOutputPath  = 'G:\code\matlab\UASignalAugmentor\data\OriginEnvPack';
OutputName = 'Config';

% 初始化配置结构体
Site_loc = struct();
Source   = struct();
Cal      = struct();

%% 目标点位配置 (Site_loc)
% 定义三种海域类型的站点位置和接收参数
ZoneName = 'Deep';         %'Shallow'、'Transition'、'Deep'
if strcmp(ZoneName, 'Shallow')
    % 1. 浅海区域 (Shallow Sea)
    Site_loc.zone         = 'Shallow';
    Site_loc.outputPath   = fullfile(OriginEnvPackPath, 'Shallow');
    Site_loc.lat          = [19.50, 7.10, 23.30, 11.00, 9.50, 20.20];  % 纬度 (°N)
    Site_loc.lon          = [107.00, 117.80, 118.20, 121.00, 107.50, 112.00];  % 经度 (°E)
    Site_loc.ReceiveRange = [1, 5, 10];     % 接收距离 (km)
    Site_loc.ReceiveDepth = [10, 20, 30];   % 接收深度 (m)

elseif strcmp(ZoneName, 'Transition')
    % 2. 过渡区域 (Transition Sea)
    Site_loc.zone         = 'Transition';
    Site_loc.outputPath   = fullfile(OriginEnvPackPath, 'Transition');
    Site_loc.lat          = [18.80, 8.20, 20.40, 15.10, 14.10, 17.00];  % 纬度 (°N)
    Site_loc.lon          = [114.30, 118.50, 117.60, 123.00, 110.10, 112.40];  % 经度 (°E)
    Site_loc.ReceiveRange = [5, 30, 60];          % 接收距离 (km)
    Site_loc.ReceiveDepth = [25, 50, 100, 300];   % 接收深度 (m)

elseif strcmp(ZoneName, 'Deep')
    % 3. 深海区域 (Deep Sea)
    Site_loc.zone         = 'Deep';
    Site_loc.outputPath   = fullfile(OriginEnvPackPath, 'Deep');
    Site_loc.lat          = [17.80, 21.90, 13.90, 6.00, 18.00, 11.90];  % 纬度 (°N)
    Site_loc.lon          = [117.90, 122.50, 116.20, 123.00, 124.00, 113.00];  % 经度 (°E)
    Site_loc.ReceiveRange = [5, 30, 60];          % 接收距离 (km)
    Site_loc.ReceiveDepth = [25, 50, 100, 300];   % 接收深度 (m)
end
%% 声源配置 (Source)
% 定义声源位置、频率和时间参数

% 声源位置参数
Source.SourceRange = 0;         % 声源距离 (km)
Source.SourceDepth = 10;        % 声源深度 (m)
Source.azi         = 0;         % 测线方位角 (°)

% 频率参数
Source.freq        = 500;       % 计算中心频率 (Hz)
Source.freqvec     = 500;       % 反射系数计算宽带频率 (Hz)

% 时间参数
Source.timeIdx     = 1;         % 声速剖面时间索引 (1-12:月份, 13-16:季节, 17:年平均)

%% 计算参数配置 (Cal)
% 定义Bellhop声场计算的边界条件和波束参数

% 海况参数
Cal.top_sea_state_level = 0;    % 海况等级 (0-9)

% 中尺度现象参数
Cal.mesoscale.type = 'none';    % 不添加中尺度现象
Cal.mesoscale.params = [];      % 中尺度现象参数
 
% === 边界条件 (Bdry) ===
% 上边界 (海面)
Cal.Bdry.Top.Opt = 'CFFT';      % Bellhop上边界选项 (CFFT: 粗糙海面)

% 下边界 (海底)
Cal.Bdry.Bot.Opt = 'F*';        % Bellhop下边界选项 (F*: 声速梯度)

% 海底半空间参数 (HS: Half-Space)
Cal.Bdry.Bot.HS.alphaR = 1500;  % 海底纵波声速 (m/s)
Cal.Bdry.Bot.HS.betaR  = 0;     % 海底横波声速 (m/s)
Cal.Bdry.Bot.HS.rho    = 1;     % 海底密度 (g/cm³)
Cal.Bdry.Bot.HS.alphaI = 0;     % 海底纵波衰减 (dB/λ)
Cal.Bdry.Bot.HS.betaI  = 0;     % 海底横波衰减 (dB/λ)

% 底质参数
Cal.bottom_option    = 'F*';    % 底边界选项 (2字符)
Cal.bottom_base_type = 'IMG';   % 底质类型
Cal.bottom_alpha_b   = 0.05;    % 底质吸收系数

% === 波束参数 (Beam) ===
Cal.Beam.RunType = 'AB';        % 运行类型 (AB: 到达结构)
Cal.Beam.Nbeams  = 0;           % 波束数量 (0=自动)
Cal.Beam.alpha   = [-90, 90];   % 波束角度范围 (°)
Cal.Beam.deltas  = 0;           % 步长 (m, 0=自动)
Cal.Beam.epmult  = 0.3;         % 精度乘数
Cal.Beam.rLoop   = 1;           % 距离循环
Cal.Beam.Nimage  = 1;           % 镜像数量
Cal.Beam.Ibwin   = 1;           % 波束窗口
Cal.Beam.Type    = 'CS';        % 波束类型 (CS: 圆锥扇形)

%% 保存配置文件
fprintf('正在保存配置文件..\n');
OutputName = [OutputName, ZoneName, '.mat'];
save(fullfile(ConfigOutputPath, OutputName), 'Site_loc', 'Cal', 'Source');
fprintf('配置文件已保存: %s\n', fullfile(ConfigOutputPath, OutputName));
fprintf('包含变量: Site_loc, Source, Cal\n');