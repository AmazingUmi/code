%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A1WAVTRANSFORMER 音频信号频率提取工具
%   提取音频文件的频率成分，为后续环境文件生成提供频率参数
%
% 工作流程说明:
%   本脚本是信号增强处理链的第1步，配合A2和A3脚本使用：
%   A1_WavTransformer  -> 提取音频信号的频率成分（本脚本）
%   A2_ENVmaker        -> 生成基础环境文件（各站点、各距离）
%   A3_ENVDuplicator   -> 为每个频率扩展环境文件
%
% 功能说明:
%   1. 读取原始音频文件（.wav）并按类别组织
%   2. 使用wavfreq函数提取音频的频率成分、幅值和相位
%   3. 使用wavfilter函数按阈值筛选主要频率成分
%   4. 保存每个音频的分析结果（fs, Ndelay, Analyrecord, Analy_freq）
%   5. 汇总所有音频的频率成分并保存为Analy_freq_all.mat
%
% 输入:
%   - 原始音频文件: data/raw/Class X/*.wav
%
% 输出:
%   - 单个音频分析结果: data/processed/Class X_filename.mat
%       包含: fs, Ndelay, Analyrecord, Analy_freq
%   - 全局频率汇总: data/processed/Analy_freq_all.mat
%       包含: Analy_freq_all (所有音频的频率集合)
%
% 作者: [猫猫头]
% 日期: [2025-12-03]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
pathstr = fileparts(tmp.Filename);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr, 'function'));
clear tmp index;

%% 配置参数
fprintf('===== 开始音频信号频率提取 =====\n\n');

% 路径配置
subfolders   = {'Class A', 'Class B', 'Class C', 'Class D', 'Class E'};
input_path   = fullfile(pathstr,'data','raw');
output_path  = fullfile(pathstr,'data','processed');
FreqAllName = 'Analy_freq_all.mat';

% 检查目标文件夹是否存在，如果不存在则创建
if ~exist(output_path, 'dir')
    mkdir(output_path);
    fprintf('创建输出文件夹: %s\n', output_path);
end

% 信号处理参数
threshold   = 0.05;       % 幅值阈值（降低存储压力）
cut_Tlength = 1;          % 信号分段时间长度（秒）
FreqRange   = [10, 200]; % 频率范围（Hz）

fprintf('配置信息:\n');
fprintf('  输入路径: %s\n', input_path);
fprintf('  输出路径: %s\n', output_path);
fprintf('  类别数量: %d\n', length(subfolders));
fprintf('  频率范围: %.0f - %.0f Hz\n', FreqRange(1), FreqRange(2));
fprintf('  幅值阈值: %.2f\n', threshold);
fprintf('  分段长度: %.1f 秒\n\n', cut_Tlength);

%% 批量处理音频文件
fprintf('===== 开始批量处理音频文件 =====\n\n');

% 初始化全局频率数组
Analy_freq_all = [];
total_files = 0;

tic;

% 遍历所有类别
for j = 1:length(subfolders)
    fprintf('--- 处理类别: %s ---\n', subfolders{j});
    
    % 获取当前子文件夹路径
    current_path = fullfile(input_path, subfolders{j});
    
    % 检查文件夹是否存在
    if ~exist(current_path, 'dir')
        fprintf('  警告: 文件夹不存在，跳过\n\n');
        continue;
    end
    
    % 获取子文件夹中的所有音频文件
    audio_files = dir(fullfile(current_path, '*.wav'));
    fprintf('  音频文件数: %d\n', length(audio_files));
    
    % 遍历该类别下的所有音频文件
    for k = 1:length(audio_files)
        audioname = fullfile(current_path, audio_files(k).name);
        fprintf('  处理文件 %d/%d: %s\n', k, length(audio_files), audio_files(k).name);
        
        % 提取频率成分
        [fs, Ndelay, Analyrecord, ~] = wavfreq(audioname, FreqRange, cut_Tlength);
        
        % 按阈值筛选频率成分
        [Analyrecord, Analy_freq] = wavfilter(Analyrecord, threshold);
        
        fprintf('    采样频率: %d Hz\n', fs);
        fprintf('    提取频率数: %d\n', length(Analy_freq));
        
        % 保存单个音频的分析结果
        sig_filename = fullfile(output_path, sprintf('%s_%s.mat', ...
            subfolders{j}, audio_files(k).name(1:end-4)));
        save(sig_filename, 'fs', 'Ndelay', 'Analyrecord', 'Analy_freq');
        
        % 累积所有频率成分
        Analy_freq_all = unique([Analy_freq, Analy_freq_all]);
        total_files = total_files + 1;
    end
    fprintf('\n');
end

% 保存全局频率汇总
fprintf('===== 保存全局频率汇总 =====\n');
freq_all_path = fullfile(output_path, FreqAllName);
save(freq_all_path, 'Analy_freq_all');

elapsed_time = toc;

fprintf('\n===== 音频频率提取完成 =====\n');
fprintf('处理音频总数: %d 个文件\n', total_files);
fprintf('提取频率总数: %d 个频率\n', length(Analy_freq_all));
fprintf('频率范围: %.1f - %.1f Hz\n', min(Analy_freq_all), max(Analy_freq_all));
fprintf('全局频率文件: %s\n', freq_all_path);
fprintf('总耗时: %.2f 秒\n', elapsed_time);
fprintf('\n下一步: 运行 A2_ENVmaker 生成环境文件\n');