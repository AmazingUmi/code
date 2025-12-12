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
% 日期: [2025-12-03]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\');
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr, 'function'));
clear tmp index;

%% 设置环境路径
fprintf('===== 开始处理到达结构文件 =====\n\n');

ENVall_folder = fullfile(pathstr, 'data\OriginEnvPack');
Signal_path   = fullfile(pathstr,'data\processed');
ENV_classes   = {'Shallow', 'Transition', 'Deep'};


% 加载频率数据
fprintf('加载频率数据...\n');
load(fullfile(Signal_path, 'Analy_freq_all.mat'), 'Analy_freq_all');
fprintf('频率数量: %d\n', length(Analy_freq_all));
fprintf('频率范围: %.1f - %.1f Hz\n\n', min(Analy_freq_all), max(Analy_freq_all));

% 文件名配置
envfilename = 'EnvTemplate';
txtfilename = 'env_files_list.txt';

% 统计变量
TotalProcessed = 0;

%% 批量处理到达结构文件
fprintf('===== 开始批量处理 =====\n\n');

for i = 1:length(ENV_classes)
    fprintf('--- 处理海域类型: %s ---\n', ENV_classes{i});
    
    ENV_class_path = fullfile(ENVall_folder, ENV_classes{i});
    if ~exist(ENV_class_path, 'dir')
        fprintf('  警告: 文件夹不存在，跳过\n\n');
        continue;
    end
    
    % 获取所有站点文件夹
    contents = dir(ENV_class_path);
    ENV_single_foldernames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
    clear contents;
    fprintf('  站点数量: %d\n', length(ENV_single_foldernames));
    
    % 根据海域类型设置接收深度数量
    if i == 1  % Shallow
        RDN = 3;
    else       % Transition / Deep
        RDN = 4;
    end
    
    % 遍历每个站点
    for j = 1:length(ENV_single_foldernames)
        ENV_single_folder = fullfile(ENV_class_path, ENV_single_foldernames(j).name);
        fprintf('  处理站点: %s\n', ENV_single_foldernames(j).name);
        
        % 获取所有距离文件夹
        contents = dir(ENV_single_folder);
        ENV_Rr_foldernames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
        clear contents;
        
        % 遍历每个距离配置
        for k = 1:length(ENV_Rr_foldernames)
            ENV_Rr_folder = fullfile(ENV_single_folder, ENV_Rr_foldernames(k).name, envfilename);
            
            if ~exist(ENV_Rr_folder, 'dir')
                fprintf('    警告: 文件夹不存在 %s，跳过\n', ENV_Rr_folder);
                continue;
            end
            
            % 读取环境文件列表
            txt_file = fullfile(ENV_Rr_folder, txtfilename);
            if ~exist(txt_file, 'file')
                fprintf('    警告: 未找到文件列表，跳过\n');
                continue;
            end
            
            newfilename = cellstr(readlines(txt_file));
            newfilename(end) = [];  % 删除最后的空行
            
            fprintf('    处理距离配置: %s (%d 个频率)\n', ...
                ENV_Rr_foldernames(k).name, length(newfilename));
            
            % 初始化到达结构数组
            ARR = [];
            
            % 并行处理每个频率的.arr文件
            parfor m = 1:length(newfilename)
                % 中间变量初始化
                amp0 = [];
                idx = [];
                delay0 = [];
                phase0 = [];
                
                % 读取到达结构文件
                arr_file = fullfile(ENV_Rr_folder, [newfilename{m}, '.arr']);
                if ~exist(arr_file, 'file')
                    warning('未找到文件: %s', arr_file);
                    continue;
                end
                
                [Arr, Pos] = read_arrivals_asc(arr_file);
                
                % 提取频率信息
                freq = Pos.freq;
                
                % 只处理5000 Hz以下的频率
                if freq <= 5000
                    % 遍历每个接收深度
                    for n = 1:RDN
                        % 按时延排序
                        [delay0, idx] = sort(abs(Arr(n).delay));
                        amp0 = abs(Arr(n).A(idx));
                        phase0 = angle(Arr(n).A(idx));
                        
                        % 应用幅值门限过滤弱声线
                        threshold = 0.05;
                        idx = amp0 >= threshold * max(amp0);
                        delay0 = delay0(idx);
                        phase0 = phase0(idx);
                        amp0 = amp0(idx);
                        
                        % 保存到达结构
                        ARR(m, n).Amp = amp0;          % 记录幅值
                        ARR(m, n).Delay = delay0;      % 记录时延
                        ARR(m, n).phase = phase0;      % 记录相位
                        ARR(m, n).freq = freq;         % 记录频率
                    end
                end
            end
            
            % 保存为.mat格式
            mat_file = fullfile(ENV_Rr_folder, 'ENV_ARR_less.mat');
            save(mat_file, 'ARR');
            fprintf('    保存MAT文件: ENV_ARR_less.mat\n');
            
            % 保存为.json格式
            jsonStr = jsonencode(ARR);
            json_file = fullfile(ENV_Rr_folder, 'ENV_ARR_less.json');
            fid = fopen(json_file, 'w');
            if fid == -1
                warning('无法创建JSON文件: %s', json_file);
            else
                fwrite(fid, jsonStr, 'char');
                fclose(fid);
                fprintf('    保存JSON文件: ENV_ARR_less.json\n');
            end
            
            TotalProcessed = TotalProcessed + 1;
        end
    end
    fprintf('\n');
end

fprintf('===== 处理完成 =====\n');
fprintf('总计处理: %d 个环境文件夹\n', TotalProcessed);
fprintf('每个文件夹处理: %d 个频率\n', length(Analy_freq_all));
fprintf('\n===== 全部完成 =====\n');
