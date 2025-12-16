%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A5RECSIGSYNTHESIZER 接收信号合成工具
%   基于Bellhop到达结构和原始信号频率成分，合成不同海洋环境下的接收信号
%
% 工作流程说明:
%   本脚本是信号增强处理链的第5步，配合A1-A4脚本使用：
%   A1_WavTransformer  -> 提取音频信号的频率成分
%   A2_ENVmaker        -> 生成基础环境文件（各站点、各距离）
%   A3_ENVDuplicator   -> 为每个频率扩展环境文件
%   A4_ArrProcessor    -> 处理Bellhop计算结果，提取到达结构
%   A5_RecSigSynthesizer -> 合成接收信号（本脚本）
%
% 功能说明:
%   1. 加载到达结构数据（ENV_ARR_less.mat）
%   2. 加载原始信号的频率分量数据
%   3. 根据到达结构的时延、幅值、相位信息合成接收信号
%   4. 随机选择连续N段信号进行合成
%   5. 对每个接收深度生成对应的接收信号
%   6. 剔除尾部零信号，节省存储空间
%
% 输入文件:
%   - ENV_ARR_less.mat: A4生成的到达结构数据
%   - Analy_freq_all.mat: A1生成的频率成分数组
%   - {signal_name}.mat: 原始信号的频率分量数据，包含：
%       .Analy_freq: 频率数组
%       .Analyrecord: 分段记录（频率、幅值、相位）
%       .Ndelay: 分段时间索引
%
% 输出文件:
%   - {signal_name}_Rd_{depth}_new.mat: 合成的接收信号，包含：
%       .tgsig: 接收信号时域数据
%       .tgt: 对应的时间序列
%
% 关键参数:
%   - Amp_source: 源强度（默认1e5）
%   - Nsel: 选择的连续段数（默认10段或全部）
%   - fs: 采样率（Hz）
%   - ReceiveDepth: 接收深度数组（m）
%
% 作者: [猫猫头]
% 日期: [2025-12-09]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
pathstr = fileparts(tmp.Filename);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr, 'function'));
clear tmp index;

%% 设置环境路径和参数
fprintf('===== 开始接收信号合成 =====\n\n');
OriginEnvPackPath = fullfile(pathstr, 'data','OriginEnvPack');
SignalPath        = fullfile(pathstr, 'data','processed');
EnvClasses        = {'Shallow', 'Transition', 'Deep'};

% 加载全部信号的频率分布数据
fprintf('加载频率数据...\n');
load(fullfile(SignalPath, 'Analy_freq_all.mat'), 'Analy_freq_all');

% 加载所有信号的频率分量数据
SigFilesList = dir(fullfile(SignalPath, '*.mat'));
% 过滤掉 Analy_freq_all.mat
SigFilesList = SigFilesList(~strcmp({SigFilesList.name}, 'Analy_freq_all.mat'));
fprintf('找到 %d 个信号文件\n', length(SigFilesList));
SigFilesNum = length(SigFilesList);

if SigFilesNum > 0
    % 预加载第一个文件以确定结构体字段并预分配
    first_data = load(fullfile(SignalPath, SigFilesList(1).name));
    SigFilesStruct = repmat(first_data, 1, SigFilesNum);
    % 加载剩余文件
    for n = 2:SigFilesNum
        SigFilesStruct(n) = load(fullfile(SignalPath, SigFilesList(n).name));
    end
else
    SigFilesStruct = [];
end

% 参数配置
Amp_source = 1e5;  % 源强度
fs = 52734;        % 采样率

fprintf('源强度: %.2e\n', Amp_source);
fprintf('采样率: %d Hz\n\n', fs);

%% 批量处理环境文件
fprintf('===== 开始批量合成接收信号 =====\n\n');

TotalProcessed = 0;

for i = 1:length(EnvClasses)
    fprintf('--- 处理海域类型: %s ---\n', EnvClasses{i});
    
    EnvClassPath = fullfile(OriginEnvPackPath, EnvClasses{i});
    if ~exist(EnvClassPath, 'dir')
        fprintf('  警告: 文件夹不存在，跳过\n\n');
        continue;
    end
    
    % 获取所有站点文件夹
    contents = dir(EnvClassPath);
    contents = contents([contents.isdir]);
    EnvSiteNames = contents(~strncmp({contents.name}, '.', 1));
    clear contents;
    fprintf('  站点数量: %d\n', length(EnvSiteNames));
    
    % 遍历每个站点
    for j = 1:length(EnvSiteNames)
        EnvSiteDir = fullfile(EnvClassPath, EnvSiteNames(j).name);
        fprintf('  处理站点: %s\n', EnvSiteNames(j).name);
        
        % 获取所有距离文件夹
        contents = dir(EnvSiteDir);
        contents = contents([contents.isdir]); % 仅保留目录，减少后续处理量
        EnvSiteRrNames = contents(~strncmp({contents.name}, '.', 1)); % 快速排除 . 和 .. 及隐藏文件夹
        clear contents;
        
        % 遍历每个距离配置
        for k = 1:length(EnvSiteRrNames)
            EnvSiteRrDir = fullfile(EnvSiteDir, EnvSiteRrNames(k).name);
            
            % 检查到达结构文件是否存在
            arr_file = fullfile(EnvSiteRrDir, 'ENV_ARR_less.mat');
            if ~exist(arr_file, 'file')
                fprintf('    警告: 未找到到达结构文件，跳过\n');
                continue;
            end
            % 加载到达结构
            load(arr_file, 'ARR');

            % 创建输出文件夹
            OutputSigDir = fullfile(EnvSiteRrDir, 'NewSig');
            if ~exist(OutputSigDir, 'dir')
                mkdir(OutputSigDir);
            end
            
            ReceiveDepth = [ARR(1, :).rd];

            fprintf('    处理距离配置: %s (接收深度: %s)\n', ...
                EnvSiteRrNames(k).name, mat2str(ReceiveDepth));
            
            % 遍历每个接收深度
            for m = 1:length(ReceiveDepth)
                ARRSingleRD = ARR(:, m);
                
                % 遍历每个信号文件
                for n = 1:length(SigFilesList)
                    [~, SigBaseName] = fileparts(SigFilesList(n).name);
                    AnalyFreq   = SigFilesStruct(n).Analy_freq;
                    AnalyRecord = SigFilesStruct(n).Analyrecord;
                    Ndelay      = SigFilesStruct(n).Ndelay;
                    
                    % 生成输出文件名
                    NewSigName = fullfile(OutputSigDir, sprintf('%s_Rd_%d_new.mat', ...
                        SigBaseName, ReceiveDepth(m)));
                    
                    % 提取信号段存在的频率
                    [~, idx] = ismember(AnalyFreq, Analy_freq_all);
                    % 此RD下该信号所包含频率的到达结构
                    ArrRDSig = ARRSingleRD(idx, :);
                    
                    
                    % 合成信号
                    [TargSig, TargT] = TargSigGenerator(AnalyRecord, AnalyFreq, ...
                        ArrRDSig, Amp_source, fs, Ndelay);
                    
                    % 保存信号
                    save(NewSigName, 'TargSig', 'TargT');
                    fprintf('      保存信号: %s (深度 %d m)\n', ...
                        SigBaseName, ReceiveDepth(m));
                end
            end
            
            fprintf('    完成: 生成 %d 个深度 × %d 个信号 = %d 个接收信号\n', ...
                length(ReceiveDepth), length(SigFilesList), ...
                length(ReceiveDepth) * length(SigFilesList));
            TotalProcessed = TotalProcessed + 1;
        end
    end
    fprintf('\n');
end

fprintf('===== 接收信号合成完成 =====\n');
fprintf('总计处理: %d 个环境文件夹\n', TotalProcessed);
fprintf('每个文件夹生成: %d 个深度 × %d 个信号文件\n', ...
    length(ReceiveDepth), length(SigFilesList));
fprintf('\n===== 全部完成 =====\n');
