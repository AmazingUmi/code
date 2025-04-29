%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr(1:end-9),'underwateracoustic\bellhop_fundation\function'));
clear pathstr tmp index;

%% 路径设置
Signal_folder_path = 'G:\database\shipsEar\Shipsear_signal_folder0416';
sig_mat_files = dir(fullfile(Signal_folder_path, '*.mat'));
sig_mat_files(1) = [];
Analy_freq_all = [];
Analy_freq_all_file = fullfile(Signal_folder_path, 'Analy_freq_all.mat');

threshold = 0.05;

%% 幅值全局排序
tic
for i = 1:length(sig_mat_files)
    sig_filename = fullfile(Signal_folder_path, sig_mat_files(i).name);
    load(sig_filename)  % 加载变量：fs, Ndelay, Analyrecord, Analy_freq
    
    % 内部变量初始化
    Nrecord = length(Analyrecord); 
    max_freq_length = 0; 

    % 寻找频率个数最大值
    for j = 1:Nrecord
        max_freq_length = max(max_freq_length, length(Analyrecord(j).Amp));
    end

    % 全局排序：组装所有的幅值
    Amp_all = zeros(Nrecord, max_freq_length);
    for j = 1:Nrecord
        Amp_all(j, 1:length(Analyrecord(j).Amp)) = Analyrecord(j).Amp;
    end
    [Amp_all_sorted, Amp_all_linear_indices] = sort(Amp_all(:), 'descend');
    [indices_row, indices_col] = ind2sub(size(Amp_all), Amp_all_linear_indices); % 转二维索引
    valid_idx = Amp_all_sorted >= threshold * Amp_all_sorted(1);
    indices_row = indices_row(valid_idx);
    indices_col = indices_col(valid_idx);

    % 对每一段数据按照行数进行归类，准备筛选有效的幅值索引
    indices_row_num = unique(indices_row); % 剩余的段数
    sortedIndicesByRow = cell(length(indices_row_num), 1); % 记录各段需要计算的idx
    num_row = [];
    for j = 1:length(indices_row_num)
        indices_idx = indices_row == indices_row_num(j);
        num_row(j) = indices_row_num(j);
        sortedIndicesByRow{j,1} = indices_col(indices_idx);
    end

    % 处理 Analyrecord 中每一段数据，根据排序索引进行筛选，同时收集所有频率
    Analy_freq = [];
    for j = 1:Nrecord
        row = num_row == j;
        if max(row) == 0
            % 当前段不满足条件，置为0
            Analyrecord(j).Amp = 0;
            Analyrecord(j).freq = 0;
            Analyrecord(j).phase = 0;
        else
            % 按照筛选索引更新
            Analyrecord(j).Amp = Analyrecord(j).Amp(sortedIndicesByRow{row,1});
            Analyrecord(j).freq = Analyrecord(j).freq(sortedIndicesByRow{row,1});
            Analyrecord(j).phase = Analyrecord(j).phase(sortedIndicesByRow{row,1});
            Analy_freq = unique([Analy_freq, Analyrecord(j).freq]); % 累计所有信号总的频率
        end
    end
    Analy_freq_all = unique([Analy_freq, Analy_freq_all]);
    
    % 保存更新后的数据到 .mat 文件
    save(sig_filename, 'fs', 'Ndelay', 'Analyrecord', 'Analy_freq')
    
    % % 同时保存JSON文件
    % % 构造一个结构体存放需要保存的变量
    % dataStruct.fs = fs;
    % dataStruct.Ndelay = Ndelay;
    % dataStruct.Analyrecord = Analyrecord;
    % dataStruct.Analy_freq = Analy_freq;
    % 
    % % 转换为 JSON 格式字符串
    % jsonStr = jsonencode(dataStruct);
    % 
    % % 生成 JSON 文件名，与 .mat 文件同名（后缀改为 .json）
    % json_filename = fullfile(Signal_folder_path, sprintf('%s.json', sig_mat_files(i).name(1:end-4)));
    % 
    % % 写入 JSON 文件
    % fid = fopen(json_filename, 'w');
    % if fid == -1
    %     error('无法打开文件进行写入: %s', json_filename);
    % end
    % fprintf(fid, '%s', jsonStr);
    % fclose(fid);
    
end

% 保存全局频率数据 Analy_freq_all 到 .mat 文件
save(Analy_freq_all_file, 'Analy_freq_all')
%% 
% 
% dataStruct.Analy_freq_all = Analy_freq_all;
% 
% % 转换为 JSON 格式字符串
% jsonStr = jsonencode(dataStruct);
% 
% % 生成 JSON 文件名，与 .mat 文件同名（后缀改为 .json）
% json_filename = sprintf('%s.json', Analy_freq_all_file(1:end-4));
% 
% 
% % 写入 JSON 文件
% fid = fopen(json_filename, 'w');
% if fid == -1
%     error('无法打开文件进行写入: %s', json_filename);
% end
% fprintf(fid, '%s', jsonStr);
% fclose(fid);
% 
% 
% %% 将 Analy_freq_all 输出为 .txt 文件
% txt_filename = fullfile(Signal_folder_path, 'Analy_freq_all.txt');
% fid = fopen(txt_filename, 'w');
% if fid == -1
%     error('无法打开文件进行写入: %s', txt_filename);
% end
% fprintf(fid, '%f\n', Analy_freq_all);  % 每个频率写成一行
% fclose(fid);
