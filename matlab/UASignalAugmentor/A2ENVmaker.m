%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A2ENVMAKER 批量生成Bellhop环境文件
%   根据配置文件中的站点位置信息，批量生成不同位置、不同距离的Bellhop环境文件
%
% 功能说明:
%   1. 加载ETOPO地形数据和WOA23声速剖面数据
%   2. 读取站点配置文件（Config.mat）
%   3. 遍历所有站点位置和接收距离组合
%   4. 为每个组合生成完整的Bellhop环境文件集
%   5. 按照 ENV{i}/Rr{j}/EnvTemplate 的目录结构保存
%
% 输出文件结构:
%   OriginEnvPack/Shallow/ENV{i}/Rr{j}/EnvTemplate/
%       ├── ENV_{i}_Rr{Rr}Km.env
%       ├── ENV_{i}_Rr{Rr}Km.bty
%       ├── ENV_{i}_Rr{Rr}Km.ssp
%       ├── ENV_{i}_Rr{Rr}Km.trc
%       └── ENV_{i}_Rr{Rr}Km.brc
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

%% 加载海洋环境数据
fprintf('===== 开始加载海洋环境数据 =====\n');

% 数据路径配置
OceanDataPath = 'G:\code\matlab\UASignalAugmentor\data\OceanData';
ETOPOName     = 'ETOPO2022.mat';
WOAName       = 'woa23_%02d.mat';

% 加载ETOPO和WOA23数据
fprintf('加载 ETOPO 和 WOA23 数据...\n');
[ETOPO, WOA] = load_data(OceanDataPath, ETOPOName, WOAName);
fprintf('数据加载完成\n\n');

clear OceanDataPath ETOPOName WOAName;
%% 加载配置文件
fprintf('===== 加载配置文件 =====\n');

OriginEnvPackPath = 'G:\code\matlab\UASignalAugmentor\data\OriginEnvPack';

% 指定配置文件名
ConfigName = 'ConfigDeep.mat';  % 'ConfigShallow.mat'/'ConfigTransition.mat'/'ConfigDeep.mat'
Config_in = load(fullfile(OriginEnvPackPath, ConfigName));

fprintf('配置文件: %s\n', ConfigName);
fprintf('海域类型: %s\n', Config_in.Site_loc.zone);
fprintf('配置加载完成\n\n');

%% 配置输出参数
% 直接使用配置文件中的站点位置配置
loc_cal = Config_in.Site_loc;

% 构建输出配置结构体
Config_out.Cal      = Config_in.Cal;       % 计算参数（边界条件、波束参数等）
Config_out.Source   = Config_in.Source;    % 声源参数（位置、频率等）
Config_out.Receiver = [];                  % 接收器参数（待设置）
Config_out.Loc      = [];                  % 位置参数（待设置）

%% 批量生成环境文件
fprintf('===== 开始批量生成环境文件 =====\n');

% 提取站点经纬度和接收参数
lat = loc_cal.lat;
lon = loc_cal.lon;
Config_out.Receiver.ReceiveDepth = loc_cal.ReceiveDepth;
Config_out.Receiver.ReceiveRange = loc_cal.ReceiveRange;

fprintf('站点数量: %d\n', length(lat));
fprintf('接收距离数量: %d\n', length(loc_cal.ReceiveRange));
fprintf('接收深度: %s\n\n', mat2str(loc_cal.ReceiveDepth));

% 遍历所有站点
for i = 1:length(lat)
    fprintf('--- 处理站点 %d/%d ---\n', i, length(lat));
    fprintf('  位置: 经度=%.2f°E, 纬度=%.2f°N\n', lon(i), lat(i));
    
    % 设置起始坐标
    coordS.lon = lon(i);
    coordS.lat = lat(i);
    Config_out.Loc.coordS = coordS;
    
    % 创建站点文件夹
    ENV_folderPath = fullfile(loc_cal.outputPath, ['ENV', num2str(i)]);
    
    % 遍历所有接收距离
    for j = 1:length(loc_cal.ReceiveRange)
        Rr = loc_cal.ReceiveRange(j);
        fprintf('  接收距离 %d/%d: %.1f km\n', j, length(loc_cal.ReceiveRange), Rr);
        
        % 设置接收距离
        % Config_out.Receiver.ReceiveRange = Rr;
        
        % 创建环境文件输出文件夹
        ENV_folderPath_Rr = fullfile(ENV_folderPath, ['Rr', num2str(j)], 'EnvTemplate');
        if ~exist(ENV_folderPath_Rr, 'dir')
            mkdir(ENV_folderPath_Rr);
        end
        cd(ENV_folderPath_Rr);
        
        % 计算终点坐标（根据方位角和距离）
        Config_out.Loc.coordE = [];
        [coordS, Config_out.Loc.coordE, ~, ~] = coord_proc(coordS, ...
            Config_out.Loc.coordE, loc_cal.ReceiveRange, Config_out.Source.azi);
        
        % 生成环境文件
        EnvFileName = ['ENV_', num2str(i), '_Rr', num2str(Rr), 'Km'];
        FileMaker(ETOPO, WOA, EnvFileName, Config_out);
        
        fprintf('    文件已生成: %s\n', EnvFileName);
    end
    fprintf('\n');
end

fprintf('===== 环境文件模板生成完成 =====\n');
fprintf('海域类型: %s\n', Config_in.Site_loc.zone);
fprintf('总计: %d 个站点 × %d 个距离 = %d 组环境文件\n', ...
    length(lat), length(loc_cal.ReceiveRange), length(lat) * length(loc_cal.ReceiveRange));
