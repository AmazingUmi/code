%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
pathstr = fileparts(tmp.Filename);
cd(pathstr);
clear tmp index;

project_root = fileparts(pathstr);  % UASignalAugmentor 根目录
addpath(fullfile(project_root, 'function'));

%% 创建输出目录
OutputDir = '/Users/luyiyang/Database/testBin/EddyAnalyzer_output';
if ~exist(OutputDir, 'dir')
    mkdir(OutputDir);
end

%% 加载计算参数
fprintf('===== 加载计算参数 =====\n');
% 路径设置
ConfigFileDir = fullfile(project_root, 'data', 'Eddy', 'EddyFileConfig.mat');
SigFileDir    = fullfile(project_root, 'data', 'processed');
SigFreqDir    = fullfile(project_root, 'data', 'processed', 'Analy_freq_all.mat');
% 开始加载
Config = load(ConfigFileDir);
fprintf('已加载参数文件: %s\n', ConfigFileDir);
load(SigFreqDir, 'Analy_freq_all');
fprintf('已加载频率文件: %s\n', SigFreqDir);

%% 加载海洋环境数据
fprintf('===== 开始加载海洋环境数据 =====\n');
% 加载Munk声速剖面
MunkSSPDir = fullfile(project_root, 'data', 'Eddy', 'MunkSSP.mat');
load(MunkSSPDir, 'munkSSP');
fprintf('已加载Munk声速剖面: %s\n', MunkSSPDir);
% 计算地形数据
rmax = ceil(1.5 * max(Config.Receiver.ReceiveRange));
N = max(rmax + 1, 2);
BTY.r = linspace(0, rmax, N);            % 地形文件距离参数
BTY.d = max(munkSSP(:,1)) * ones(1, N);  % 理想环境下海底为恒定深度
% 计算声速数据
SSP.ssp_raw   = munkSSP;
SSProf0.z   = munkSSP(:,1);
SSProf0.c   = repmat(munkSSP(:,2), 1, N);
SSP.SSProf  = SSProf0;
fprintf('【声速剖面提取】以及【地形计算】完成\n\n');
% 暂存涡旋参数
EddyParams = Config.Cal.mesoscale.params;
% 输出路径设置
Outputdir = '/Users/luyiyang/Database/testBin/EddyAnalyzer_output';

NumOfrc = length(EddyParams.rcVector);
NumOfDC = length(EddyParams.DCVector);
for nrc = 1%:NumOfrc
    EddyParams.rc = EddyParams.rcVector(nrc);
    for nDC = 1%:NumOfDC
        EddyParams.DC = EddyParams.DCVector(nDC);
        ouputname  = sprintf('rc%s_DC%s',num2str(EddyParams.rc),num2str(EddyParams.DC));
        WithEddyDir = fullfile(Outputdir, 'EnvFilePack', ouputname);
        % 子目录
        if ~exist(WithEddyDir, 'dir')
            mkdir(WithEddyDir);
        end
        %%%%%%%%%%%%%%%%%%% 生成环境文件 %%%%%%%%%%%%%%%%%%
        fprintf('===== 生成环境文件 =====\n');
        EnvName = [];
        try
            % 生成环境文件
            fprintf('生成含涡环境文件...\n');
            cd(WithEddyDir);
            Config.Cal.mesoscale.type   = 'eddy';
            Config.Cal.mesoscale.params = EddyParams;
            FileMakerIdeal(BTY, SSP, 'WithEddy', Config);
            FreqDuplicator(WithEddyDir, EnvName, WithEddyDir, Analy_freq_all)
            fprintf('    完成: 生成 %d 组文件\n', length(Analy_freq_all));

        catch ME
            cd(pathstr);
            rethrow(ME);
        end
    end
end
cd(pathstr);
fprintf('环境文件生成完成\n');
%% 运行并行计算程序
%
%
% (base) ❯ ./BellParallelMac /Users/luyiyang/Database/testBin/EddyAnalyzer_output/EnvFilePack/rc10_DC-25
% 切换到工作目录: /Users/luyiyang/Database/testBin/EddyAnalyzer_output/WithoutEddy
% 程序运行时间: 14.3323秒
%
% code/matlab/UASignalAugmentor/CallBell git:master*  15s

%% 读取arr计算结果
ListFileName        = 'env_files_list.txt';
MAX_FREQ_LIMIT      = 5000;
AMP_THRESHOLD_RATIO = 0.05;
ListFileDir         = fullfile(WithEddyDir,ListFileName);
if ~exist(ListFileDir, 'file')
    fprintf('    警告: 未找到文件列表，跳过\n');
    % continue;
end
ArrFileName = cellstr(readlines(ListFileDir));

for nrc = 1%:NumOfrc
    a = EddyParams.rcVector(nrc);
    for nDC = 1%:NumOfDC
        b = EddyParams.DCVector(nDC);
        ouputname     = sprintf('rc%s_DC%s',num2str(a),num2str(b));
        WithEddyDir   = fullfile(Outputdir, 'EnvFilePack', ouputname);
        MatName       = [ouputname, '.mat'];
        ArrReader(ArrFileName, WithEddyDir, MAX_FREQ_LIMIT, AMP_THRESHOLD_RATIO, MatName);
    end
end
cd(pathstr);
%% 开始进行新信号生成
% 参数配置
Amp_source = 1e5;          % 源强度
fs         = 52734;        % 采样率

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

for nrc = 1%:NumOfrc
    a = EddyParams.rcVector(nrc);
    for nDC = 1%:NumOfDC
        b = EddyParams.DCVector(nDC);
        ouputname     = sprintf('rc%s_DC%s',num2str(a),num2str(b));
        WithEddyDir   = fullfile(Outputdir, 'EnvFilePack', ouputname);
        MatFileDir    = [WithEddyDir,'.mat'];
        % 读取Arr结果
        ArrWithEddy   = load(MatFileDir);
        OutputSigDir  = fullfile(OutputDir, 'SignalOutput', ouputname);
        if ~exist(OutputSigDir, 'dir')
            mkdir(OutputSigDir);
        end
        % 开始生成信号
        SignalPatchGenerator(ArrWithEddy.ARR, SigFilesList, ...
            SigFilesStruct, OutputSigDir, Analy_freq_all, Amp_source, fs);
    end
end





