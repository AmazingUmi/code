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
index = strfind(tmp.Filename, '\');
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr, 'function'));
clear tmp index;

%% 设置环境路径和参数
fprintf('===== 开始接收信号合成 =====\n\n');

ENVall_folder      = fullfile(pathstr, 'data\OriginEnvPack');
Signal_folder_path = fullfile(pathstr, 'data\processed');
ENV_classes        = {'Shallow', 'Transition', 'Deep'};


% 加载频率数据
fprintf('加载频率数据...\n');
load(fullfile(Signal_folder_path, 'Analy_freq_all.mat'), 'Analy_freq_all');

% 加载所有信号的频率分量数据
sig_mat_files = dir(fullfile(Signal_folder_path, '*.mat'));
% 过滤掉 Analy_freq_all.mat
sig_mat_files = sig_mat_files(~strcmp({sig_mat_files.name}, 'Analy_freq_all.mat'));

fprintf('找到 %d 个信号文件\n', length(sig_mat_files));
for n = 1:length(sig_mat_files)
    sig_mat_struct(n) = load(fullfile(Signal_folder_path, sig_mat_files(n).name));
end

% 参数配置
Amp_source = 1e5;  % 源强度
fs = 52734;        % 采样率

fprintf('源强度: %.2e\n', Amp_source);
fprintf('采样率: %d Hz\n\n', fs);

%% 批量处理环境文件
fprintf('===== 开始批量合成接收信号 =====\n\n');

TotalProcessed = 0;

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
            ENV_Rr_folder = fullfile(ENV_single_folder, ENV_Rr_foldernames(k).name);
            
            % 检查到达结构文件是否存在
            arr_file = fullfile(ENV_Rr_folder, 'ENV_ARR_less.mat');
            if ~exist(arr_file, 'file')
                fprintf('    警告: 未找到到达结构文件，跳过\n');
                continue;
            end
            
            % 创建输出文件夹
            NewSig_folder = fullfile(ENV_Rr_folder, 'NewSig');
            if ~exist(NewSig_folder, 'dir')
                mkdir(NewSig_folder);
            end
            
            % 加载到达结构
            load(arr_file, 'ARR');
            
            % 根据接收深度数量确定深度数组
            if size(ARR, 2) == 3
                ReceiveDepth = [10, 20, 30];  % Shallow
            else
                ReceiveDepth = [25, 50, 100, 300];  % Transition / Deep
            end
            
            fprintf('    处理距离配置: %s (接收深度: %s)\n', ...
                ENV_Rr_foldernames(k).name, mat2str(ReceiveDepth));
            
            % 遍历每个接收深度
            for m = 1:length(ReceiveDepth)
                ARR_tmp = ARR(:, m);
                
                % 遍历每个信号文件
                for n = 1:length(sig_mat_files)
                    Analy_freq = sig_mat_struct(n).Analy_freq;
                    Analyrecord = sig_mat_struct(n).Analyrecord;
                    Ndelay = sig_mat_struct(n).Ndelay;
                    
                    % 生成输出文件名
                    NewSig_name = fullfile(NewSig_folder, sprintf('%s_Rd_%d_new.mat', ...
                        sig_mat_files(n).name(1:end-4), ReceiveDepth(m)));
                    
                    % 提取信号段存在的频率
                    [~, idx] = ismember(Analy_freq, Analy_freq_all);
                    Arr_tmp = ARR_tmp(idx, :);
                    numfreq = length(Arr_tmp);
                    
                    % 计算最大和最小时延
                    maxdelay = zeros(numfreq, 1);
                    mindelay = zeros(numfreq, 1);
                    for p = 1:numfreq
                        if ~isempty(Arr_tmp(p).Delay)
                            maxdelay(p) = max(Arr_tmp(p).Delay);
                            mindelay(p) = min(Arr_tmp(p).Delay);
                        end
                    end
                    
                    MAXdelay = max(maxdelay);
                    MINdelay = min(mindelay);
                    Ndelay_d = Ndelay(2) - Ndelay(1);  % 分段信号长度
                    Analyrecord_Num = length(Analyrecord);  % 分段信号总段数
                    
                    % 随机选择连续 N 段
                    if Analyrecord_Num >= 10
                        Nsel = 10;
                    else
                        Nsel = Analyrecord_Num;
                    end
                    maxStart = Analyrecord_Num - Nsel + 1;
                    startSeg = randi(maxStart);
                    selSegments = startSeg : (startSeg + Nsel - 1);
                    
                    % 初始化目标信号
                    tgsig_lth = ceil((MAXdelay - MINdelay + Nsel + 0.01) * fs);  % 目标信号长度
                    tgt = (0:tgsig_lth-1) / fs;  % 目标信号时间序列
                    tgsig = zeros(size(tgt));  % 目标信号初始化
                    
                    % 合成信号
                    for ii = 1:Nsel
                        p = selSegments(ii);
                        tar_freq = round(Analyrecord(p).freq, 4)';
                        tar_amp = Analyrecord(p).Amp;
                        tar_pha = Analyrecord(p).phase;
                        [~, tar_f_loc] = ismember(tar_freq, Analy_freq);
                        
                        num_tar = length(tar_freq);
                        Dsig = zeros(1, tgsig_lth);
                        
                        if tar_f_loc ~= 0
                            for rn = 1:num_tar
                                delay0 = Arr_tmp(tar_f_loc(rn)).Delay;
                                amp0 = Arr_tmp(tar_f_loc(rn)).Amp';
                                phase0 = Arr_tmp(tar_f_loc(rn)).phase;
                                originAmp = Amp_source * tar_amp(rn);
                                
                                % 生成时域信号
                                [y_time, M_length] = SigGenerateTD(tar_freq(rn), Ndelay_d, fs, ...
                                    originAmp, tar_pha(rn), delay0, amp0, phase0);
                                
                                % 确定信号初始位置
                                be = floor((min(delay0) - MINdelay + Ndelay(ii)) * fs) + 1;
                                Dsig(be:be+M_length-1) = Dsig(be:be+M_length-1) + y_time;
                            end
                        end
                        tgsig = tgsig + Dsig;
                    end
                    
                    % 取实部
                    tgsig = real(tgsig);
                    
                    % 剔除尾部零信号
                    lastIdx = find(tgsig ~= 0, 1, 'last');
                    if ~isempty(lastIdx)
                        tgsig = tgsig(1:lastIdx);
                        tgt = tgt(1:lastIdx);
                    end
                    
                    % 保存信号
                    save(NewSig_name, 'tgsig', 'tgt');
                    fprintf('      保存信号: %s (深度 %d m)\n', ...
                        sig_mat_files(n).name(1:end-4), ReceiveDepth(m));
                end
            end
            
            fprintf('    完成: 生成 %d 个深度 × %d 个信号 = %d 个接收信号\n', ...
                length(ReceiveDepth), length(sig_mat_files), ...
                length(ReceiveDepth) * length(sig_mat_files));
            TotalProcessed = TotalProcessed + 1;
        end
    end
    fprintf('\n');
end

fprintf('===== 接收信号合成完成 =====\n');
fprintf('总计处理: %d 个环境文件夹\n', TotalProcessed);
fprintf('每个文件夹生成: %d 个深度 × %d 个信号文件\n', ...
    length(ReceiveDepth), length(sig_mat_files));
fprintf('\n===== 全部完成 =====\n');
