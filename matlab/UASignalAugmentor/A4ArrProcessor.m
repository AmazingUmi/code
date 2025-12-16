%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A4ARRPROCESSOR 声场到达结构处理工具
%   读取Bellhop计算的到达结构文件(.arr)，提取并保存声线信息
%
% 工作流程说明:
%   本脚本是信号增强处理链的第4步，配合A1、A2、A3脚本使用：
%   A1_WavTransformer  -> 提取音频信号的频率成分
%   A2_ENVmaker        -> 生成基础环境文件（各站点、各距离）
%   A3_ENVDuplicator   -> 为每个频率扩展环境文件
%   A4_ArrProcessor    -> 处理Bellhop计算结果，提取到达结构（本脚本）
%
% 功能说明:
%   1. 遍历所有环境文件夹（Shallow/Transition/Deep）
%   2. 读取每个环境文件对应的.arr文件（到达结构）
%   3. 提取声线的幅值、时延、相位信息
%   4. 应用幅值门限过滤弱声线
%   5. 保存为.mat和.json格式便于后续处理
%
% 输入文件:
%   - Analy_freq_all.mat: A1生成的频率成分数组
%   - test_{i}.arr: Bellhop计算的到达结构文件
%   - env_files_list.txt: 环境文件名列表
%
% 输出文件:
%   - ENV_ARR_less.mat: 到达结构数据（MATLAB格式）
%   - ENV_ARR_less.json: 到达结构数据（JSON格式）
%
% 数据结构:
%   ARR(m,n).Amp   - 声线幅值数组
%   ARR(m,n).Delay - 声线时延数组（秒）
%   ARR(m,n).phase - 声线相位数组（弧度）
%   ARR(m,n).freq  - 频率（Hz）
%   其中 m 为频率索引，n 为接收深度索引
%
% 作者: [猫猫头]
% 日期: [2025-12-15]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
pathstr = fileparts(tmp.Filename);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr, 'function'));
clear tmp index;

%% 参数配置
MAX_FREQ_LIMIT = 5000;      % 最大处理频率 (Hz)
AMP_THRESHOLD_RATIO = 0.05; % 幅值门限比例

%% 设置环境路径
fprintf('===== 开始处理到达结构文件 =====\n\n');

OriginEnvPackPath = fullfile(pathstr, 'data','OriginEnvPack');
SignalPath        = fullfile(pathstr, 'data','processed');
EnvClasses        = {'Shallow', 'Transition', 'Deep'};


% 加载频率数据
fprintf('加载频率数据...\n');
load(fullfile(SignalPath, 'Analy_freq_all.mat'), 'Analy_freq_all');
fprintf('频率数量: %d\n', length(Analy_freq_all));
fprintf('频率范围: %.1f - %.1f Hz\n\n', min(Analy_freq_all), max(Analy_freq_all));

% 文件名配置
EnvName       = 'EnvTemplate';
ListFileName  = 'env_files_list.txt';

% 统计变量
TotalProcessed = 0;

%% 批量处理到达结构文件
fprintf('===== 开始批量处理 =====\n\n');

for i = 1:length(EnvClasses)
    fprintf('--- 处理海域类型: %s ---\n', EnvClasses{i});
    
    EnvClassPath = fullfile(OriginEnvPackPath, EnvClasses{i});
    if ~exist(EnvClassPath, 'dir')
        fprintf('  警告: 文件夹不存在，跳过\n\n');
        continue;
    end
    
    % 获取所有站点文件夹
    contents = dir(EnvClassPath);
    EnvSiteNames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
    clear contents;
    fprintf('  站点数量: %d\n', length(EnvSiteNames));
    
    % 遍历每个站点
    for j = 1:length(EnvSiteNames)
        EnvSiteDir = fullfile(EnvClassPath, EnvSiteNames(j).name);
        fprintf('  处理站点: %s\n', EnvSiteNames(j).name);
        
        % 获取所有距离文件夹
        contents = dir(EnvSiteDir);
        EnvSiteRrNames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
        clear contents;
        
        % 遍历每个距离配置
        for k = 1:length(EnvSiteRrNames)
            EnvSiteRrDir = fullfile(EnvSiteDir, EnvSiteRrNames(k).name, EnvName);
            
            if ~exist(EnvSiteRrDir, 'dir')
                fprintf('    警告: 文件夹不存在 %s，跳过\n', EnvSiteRrDir);
                continue;
            end
            
            % 读取环境文件列表
            txt_file = fullfile(EnvSiteRrDir, ListFileName);
            if ~exist(txt_file, 'file')
                fprintf('    警告: 未找到文件列表，跳过\n');
                % continue;
            end
            
            ArrFileName = cellstr(readlines(txt_file));
            
            fprintf('    处理距离配置: %s (%d 个频率)\n', ...
                EnvSiteRrNames(k).name, length(ArrFileName));
            % 调用ArrReader处理到达结构
            ArrReader(ArrFileName, EnvSiteRrDir, MAX_FREQ_LIMIT, AMP_THRESHOLD_RATIO);
            TotalProcessed = TotalProcessed + 1;
        end
    end
    fprintf('\n');
end

fprintf('===== 处理完成 =====\n');
fprintf('总计处理: %d 个环境文件夹\n', TotalProcessed);
fprintf('每个文件夹处理: %d 个频率\n', length(Analy_freq_all));
fprintf('\n===== 全部完成 =====\n');
