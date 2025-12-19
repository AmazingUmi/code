%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
pathstr = fileparts(tmp.Filename);
cd(pathstr);
addpath(fullfile(pathstr, 'function'));
clear tmp index;

%% 创建输出目录
OutputDir = 'E:\database\EddyAnalyzer_output';
if ~exist(OutputDir, 'dir')
    mkdir(OutputDir);
end
%有涡子目录
WithEddyDir = fullfile(OutputDir, 'WithEddy');
if ~exist(WithEddyDir, 'dir')
    mkdir(WithEddyDir);
end
%无涡子目录
WithoutEddyDir = fullfile(OutputDir, 'WithoutEddy');
if ~exist(WithoutEddyDir, 'dir')
    mkdir(WithoutEddyDir);
end

%% 加载海洋环境数据
fprintf('===== 开始加载海洋环境数据 =====\n');
% 数据集路径配置
OceanDataPath = fullfile(pathstr, 'data', 'OceanData');
ETOPOName     = 'ETOPO2022.mat';
WOAName       = 'woa23_%02d.mat';
% 加载ETOPO和WOA23数据
fprintf('加载 ETOPO 和 WOA23 数据...\n');
[ETOPO, WOA] = load_data(OceanDataPath, ETOPOName, WOAName);
fprintf('数据加载完成\n\n');

%% 加载计算参数
fprintf('===== 加载计算参数 =====\n');
ConfigFileDir = fullfile(pathstr, 'data', 'Eddy', 'EddyFileConfig.mat');
SigFileDir    = fullfile(pathstr, 'data', 'processed');
SigFileAllDir    = fullfile(pathstr, 'data', 'processed', 'Analy_freq_all.mat');
Config = load(ConfigFileDir);
fprintf('已加载参数文件: %s\n', ConfigFileDir);
load(SigFileAllDir, 'Analy_freq_all');
fprintf('已加载频率文件: %s\n', SigFileAllDir);
% 暂存涡旋参数
EddyParams = Config.Cal.mesoscale.params;
fprintf('涡旋: 位置=(%.0f km, %.0f m), 尺度=(%.0f×%.0f km×m), 强度=%.1f m/s\n\n', ...
    EddyParams.rc, EddyParams.zc, EddyParams.DR, EddyParams.DZ, EddyParams.DC);

%% 生成无涡和含涡的两组环境文件
fprintf('===== 生成环境文件 =====\n');
EnvName = [];
try
    % 1. 生成无涡环境文件
    fprintf('生成无涡环境文件...\n');
    cd(WithoutEddyDir);
    Config.Cal.mesoscale.type   = 'none';
    Config.Cal.mesoscale.params = [];
    FileMaker(ETOPO, WOA, 'NoEddy', Config);
    FreqDuplicator(WithoutEddyDir, EnvName, WithoutEddyDir, Analy_freq_all, ...
        Config.Cal.top_sea_state_level, Config.Cal.bottom_base_type, Config.Cal.bottom_alpha_b)
    fprintf('    完成: 生成 %d 组文件\n', length(Analy_freq_all));

    % 2. 生成含涡环境文件
    fprintf('生成含涡环境文件...\n');
    cd(WithEddyDir);
    Config.Cal.mesoscale.type   = 'eddy';
    Config.Cal.mesoscale.params = EddyParams;
    FileMaker(ETOPO, WOA, 'WithEddy', Config);
    FreqDuplicator(WithEddyDir, EnvName, WithEddyDir, Analy_freq_all, ...
        Config.Cal.top_sea_state_level, Config.Cal.bottom_base_type, Config.Cal.bottom_alpha_b)
    fprintf('    完成: 生成 %d 组文件\n', length(Analy_freq_all));

catch ME
    cd(pathstr);
    rethrow(ME);
end
cd(pathstr);
fprintf('环境文件生成完成\n');
%% 运行并行计算程序
%
%
% (base) ❯ ./BellParallelMac /Users/luyiyang/Database/testBin/EddyAnalyzer_output/WithoutEddy
% 切换到工作目录: /Users/luyiyang/Database/testBin/EddyAnalyzer_output/WithoutEddy
% 程序运行时间: 14.3323秒
%
% code/matlab/UASignalAugmentor/CallBell git:master*  15s

%% 读取arr计算结果
ListFileName        = 'env_files_list.txt';
ListFileDir         = fullfile(WithoutEddyDir,ListFileName);
MAX_FREQ_LIMIT      = 5000;
AMP_THRESHOLD_RATIO = 0.05;

if ~exist(ListFileDir, 'file')
    fprintf('    警告: 未找到文件列表，跳过\n');
    % continue;
end
ArrFileName = cellstr(readlines(ListFileDir));

ArrReader(ArrFileName, WithoutEddyDir, MAX_FREQ_LIMIT, AMP_THRESHOLD_RATIO, 'WithoutEddy.mat');
ArrReader(ArrFileName, WithEddyDir, MAX_FREQ_LIMIT, AMP_THRESHOLD_RATIO, 'WithEddy.mat');
%% 开始进行新信号生成
% 路径指向
ArrWithoutEddyDir = fullfile(OutputDir, 'WithoutEddy.mat');
ArrWithEddyDir    = fullfile(OutputDir, 'WithEddy.mat');
% 读取Arr结果
ArrWithEddy    = load(ArrWithEddyDir);
ArrWithoutEddy = load(ArrWithoutEddyDir);
% 参数配置
Amp_source = 1e5;          % 源强度
fs         = 52734;        % 采样率
% 输出路径
OutputSigWithoutEddyDir = fullfile(OutputDir, 'SignalWithoutEddy');
OutputSigWithEddyDir    = fullfile(OutputDir, 'SignalWithEddy');
if ~exist(OutputSigWithoutEddyDir, 'dir')
    mkdir(OutputSigWithoutEddyDir);
end
if ~exist(OutputSigWithEddyDir, 'dir')
    mkdir(OutputSigWithEddyDir);
end
% 加载原始信号
% 加载所有信号的频率分量数据
SigFilesList = dir(fullfile(SigFileDir, '*.mat'));
% 过滤掉 Analy_freq_all.mat
SigFilesList = SigFilesList(~strcmp({SigFilesList.name}, 'Analy_freq_all.mat'));
fprintf('找到 %d 个信号文件\n', length(SigFilesList));
SigFilesNum = length(SigFilesList);
if SigFilesNum > 0
    % 预加载第一个文件以确定结构体字段并预分配
    first_data = load(fullfile(SigFileDir, SigFilesList(1).name));
    SigFilesStruct = repmat(first_data, 1, SigFilesNum);
    % 加载剩余文件
    for n = 2:SigFilesNum
        SigFilesStruct(n) = load(fullfile(SigFileDir, SigFilesList(n).name));
    end
else
    SigFilesStruct = [];
end

% 开始生成信号
SignalPatchGenerator(ArrWithEddy.ARR, SigFilesList, ...
                SigFilesStruct, OutputSigWithEddyDir, Analy_freq_all, Amp_source, fs);
SignalPatchGenerator(ArrWithoutEddy.ARR, SigFilesList, ...
                SigFilesStruct, OutputSigWithoutEddyDir, Analy_freq_all, Amp_source, fs);