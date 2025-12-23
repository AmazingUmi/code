%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EXTRA_EddyConfigMaker 涡旋环境配置文件生成器
%   用于配置带有中尺度涡旋的水声传播计算环境参数，包括接收参数、声源参数和涡旋模型参数
%
% 功能说明:
%   1. 配置接收参数 (Receiver)
%   2. 配置声源参数 (Source)
%   3. 设置Bellhop计算参数，特别是中尺度涡旋参数 (Cal.mesoscale)
%   4. 生成配置文件保存为 EddyFileConfig.mat
%
% 输出文件:
%   EddyFileConfig.mat - 包含 Loc, Source, Cal, Receiver 结构体
%
% 作者: [猫猫头]
% 日期: [2025-12-20]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
pathstr = fileparts(tmp.Filename);
cd(pathstr);
clear tmp index;

% 添加路径
addpath(pathstr);
% 添加项目函数路径
project_root = fileparts(pathstr);  % UASignalAugmentor 根目录
addpath(fullfile(project_root, 'function'));

%% 路径设置
ConfigOutputPath  = fullfile(project_root, 'data', 'Eddy');
OutputDir         = fullfile(ConfigOutputPath, 'EddyFileConfig.mat');

% 检查输出目录是否存在
if ~exist(ConfigOutputPath, 'dir')
    mkdir(ConfigOutputPath);
end
% 初始化配置结构体
Loc      = struct();
Source   = struct();
Cal      = struct();
Receiver = struct();

%% 接收位置配置 (Receiver)
Receiver.ReceiveRange = 63;          % 接收距离 (km)
Receiver.ReceiveDepth = 150;         % 接收深度 (m)

%% 声源配置 (Source)
% 定义声源位置、频率和时间参数
% 声源位置参数
Source.SourceRange = 0;         % 声源距离 (km)
Source.SourceDepth = 10;        % 声源深度 (m)
Source.azi         = 0;         % 测线方位角 (°)
% 频率参数
Source.freq        = 300;          % 计算中心频率 (Hz)
Source.freqvec     = Source.freq;  % 反射系数计算宽带频率 (Hz)
% 时间参数
Source.timeIdx     = 13;         % 声速剖面时间索引 (1-12:月份, 13-16:季节, 17:年平均)


%% 计算参数配置 (Cal)
% 定义Bellhop声场计算的边界条件和波束参数
% 中尺度现象参数
Cal.mesoscale.type = 'eddy';
% --- 涡旋参数 ---
EddyParams.rcVector = 10:10:50;      % 涡心位置 (km)
EddyParams.zc = 150;                 % 涡心深度 (m)
EddyParams.DR = 60;                  % 水平尺度 (km)
EddyParams.DZ = 500;                 % 竖直尺度 (m)
EddyParams.DCVector = [-25:10:25, 0];     % 强度 (m/s, 负=冷涡)
Cal.mesoscale.params = EddyParams;

% === 边界条件 (Bdry) ===
% 上边界 (海面)
Cal.Bdry.Top.Opt = 'QVWT';      % Bellhop上边界选项 (CFFT: 粗糙海面)

% 下边界 (海底)
Cal.Bdry.Bot.Opt = 'A';         % Bellhop下边界选项 (F*: 声速梯度)

% 海底半空间参数 (HS: Half-Space)

Cal.Bdry.Bot.HS.alphaR = 1610;                   % 海底纵波声速 (m/s)
Cal.Bdry.Bot.HS.betaR  = 0;                      % 海底横波声速 (m/s)
Cal.Bdry.Bot.HS.rho    = 1.7;                    % 海底密度 (g/cm³)
Cal.Bdry.Bot.HS.alphaI = 0.39 * (Source.freq/1000)^1.71 * ...
    Cal.Bdry.Bot.HS.alphaR/Source.freq;          % 海底纵波衰减 (dB/λ)
Cal.Bdry.Bot.HS.betaI  = 0;                      % 海底横波衰减 (dB/λ)



% === 波束参数 (Beam) ===
Cal.Beam.RunType = 'AB';        % 运行类型 (AB: 到达结构)
Cal.Beam.Nbeams  = 0;           % 波束数量 (0=自动)
Cal.Beam.alpha   = [-90, 90];   % 波束角度范围 (°)
Cal.Beam.deltas  = 0;           % 步长 (m, 0=自动)
Cal.Beam.epmult  = 0.3;         % 精度乘数
Cal.Beam.rLoop   = 1;           % 距离循环
Cal.Beam.Nimage  = 1;           % 镜像数量
Cal.Beam.Ibwin   = 1;           % 波束窗口

%% 保存配置文件
fprintf('正在保存配置文件..\n');
save(OutputDir, 'Loc', 'Cal', 'Source', 'Receiver');
fprintf('配置文件已保存: %s\n', OutputDir);
fprintf('包含变量: Loc, Source, Cal, Receiver\n');