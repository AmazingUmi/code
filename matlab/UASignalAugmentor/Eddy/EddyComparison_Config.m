%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EDDYCOMPARISON_CONFIG 涡旋影响对比工具 - 参数配置与环境文件生成
%   1. 设置计算参数
%   2. 加载海洋环境数据 (ETOPO, WOA)
%   3. 调用 FileMaker 生成 Bellhop 环境文件 (.env, .bty, .ssp)
%   4. 保存参数供主程序调用
%
% 作者: [猫猫头]
% 日期: [2025-12-14]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 初始化
clear; clc;

% 获取当前脚本所在路径
if ~isempty(mfilename('fullpath'))
    current_file = mfilename('fullpath');
    [pathstr, ~, ~] = fileparts(current_file);
elseif matlab.desktop.editor.isEditorAvailable
    tmp = matlab.desktop.editor.getActive;
    pathstr = fileparts(tmp.Filename);
else
    pathstr = pwd;
end
cd(pathstr);

% 添加函数路径
addpath(fullfile(pathstr, '..', 'function'));
% 添加 Bellhop 读取函数路径 (如果需要)
bellhop_func_path = fullfile(pathstr, '..', '..', 'underwateracoustic', 'bellhop_fundation', 'function');
if exist(bellhop_func_path, 'dir')
    addpath(bellhop_func_path);
end

%% 设置计算参数
fprintf('===== 设置计算参数 =====\n');

% --- 声源配置 (Source) ---
Config.Source.timeIdx     = 13;         % 13-16: 季节, 17: 年平均
Config.Source.SourceRange = 0;          % 声源距离 (km)
Config.Source.SourceDepth = 50;         % 声源深度 (m)
Config.Source.azi         = 0;          % 方位角 (°)
Config.Source.freq        = 100;        % 频率 (Hz)

% --- 接收配置 (Receiver) ---
rmax = 100;                             % 最大距离 (km)
dr   = 1;                               % 距离间隔 (km)
Config.Receiver.ReceiveRange = 0:dr:rmax;
Config.Receiver.ReceiveDepth = 0:10:3000; % 接收深度 (m)

% --- 位置配置 (Loc) ---
Config.Loc.coordS.lon = 115;
Config.Loc.coordS.lat = 13;

% 计算终点坐标
[~, coordE, ~, ~] = coord_proc(Config.Loc.coordS, [], rmax, Config.Source.azi);
Config.Loc.coordE = coordE;

% --- 涡旋参数 ---
eddy_params.rc = 50;    % 涡心位置 (km)
eddy_params.zc = 600;   % 涡心深度 (m)
eddy_params.DR = 70;    % 水平尺度 (km)
eddy_params.DZ = 500;   % 竖直尺度 (m)
eddy_params.DC = -50;   % 强度 (m/s, 负=冷涡)
Config.EddyParams = eddy_params;

% --- Bellhop 运行模式 ---
run_types = {'CB', 'RB'}; 
Config.RunTypes = run_types;

% --- 基础计算配置 (Cal) ---
% 边界条件
Config.Cal.Bdry.Top.Opt = 'QVW';
Config.Cal.Bdry.Bot.Opt = 'A*';
Config.Cal.Bdry.Bot.HS.alphaR = 1600;
Config.Cal.Bdry.Bot.HS.betaR  = 0;
Config.Cal.Bdry.Bot.HS.rho    = 1.5;
Config.Cal.Bdry.Bot.HS.alphaI = 0.5;
Config.Cal.Bdry.Bot.HS.betaI  = 0;

% 波束参数 (基础)
Config.Cal.Beam.Nbeams = 40;
Config.Cal.Beam.deltas = 0;
Config.Cal.Beam.alpha = [-90, 90];

% Box.z 和 Box.r 在 FileMaker 中会自动设置，但也可以预设
% Config.Cal.Beam.Box.z = ...
% Config.Cal.Beam.Box.r = ...

fprintf('声源: (%.1f°E, %.1f°N), 深度=%d m\n', Config.Loc.coordS.lon, Config.Loc.coordS.lat, Config.Source.SourceDepth);
fprintf('方位角=%d°, 距离=%.1f km, 频率=%.1f Hz\n', Config.Source.azi, rmax, Config.Source.freq);
fprintf('运行模式: %s\n', strjoin(run_types, ', '));
fprintf('涡旋: 位置=(%.0f km, %.0f m), 尺度=(%.0f×%.0f km×m), 强度=%.1f m/s\n\n', ...
    eddy_params.rc, eddy_params.zc, eddy_params.DR, eddy_params.DZ, eddy_params.DC);

%% 保存参数
save_path = fullfile(pathstr, 'EddyComparison_Params.mat');
save(save_path, 'Config');
fprintf('参数已保存至: %s\n', save_path);
