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
Signal_folder_path = 'D:\database\shipsEar\Shipsear_signal_folder';
sig_mat_files = dir(fullfile(Signal_folder_path, '*.mat'));
sig_mat_files(1) = [];
Analy_freq_all = [];
Analy_freq_all_file = [Signal_folder_path,'\Analy_freq_all.mat'];

threshold = 0.05;
%% 幅值全局排序
tic
for i = 1:length(sig_mat_files)
    sig_filename = fullfile(Signal_folder_path,sig_mat_files(i).name);
    load(sig_filename)

    %内部变量初始化
    Nrecord = length(Analyrecord); 
    max_freq_length = 0; 

    %寻找频率个数最大值
    for j = 1:Nrecord
        max_freq_length = max(max_freq_length,length(Analyrecord(j).Amp));
    end

    %全局排序
    Amp_all = zeros(Nrecord,max_freq_length);
    for j = 1:Nrecord
        Amp_all(j,1:length(Analyrecord(j).Amp)) = Analyrecord(j).Amp;
    end
    [Amp_all_sorted, Amp_all_linear_indices] = sort(Amp_all(:),'descend');
    [indices_row, indices_col] = ind2sub(size(Amp_all), Amp_all_linear_indices); % 转二维索引
    valid_idx = Amp_all_sorted >= threshold*Amp_all_sorted(1);
    indices_row = indices_row(valid_idx);
    indices_col = indices_col(valid_idx);

    %对原始数据进行幅值
    indices_row_num = unique(indices_row);%剩余的段数
    sortedIndicesByRow = cell(length(indices_row_num),1);%用于记录不同段数中，对应的需要计算的idx
    num_row = [];
    for j = 1:length(indices_row_num)
        indices_idx = indices_row == indices_row_num(j);
        num_row(j) = indices_row_num(j);
        sortedIndicesByRow{j,1} = indices_col(indices_idx);
    end
    Analy_freq = [];
    for j = 1:Nrecord
        row = num_row == j;
        if max(row) == 0
            Analyrecord(j).Amp = 0;
            Analyrecord(j).freq = 0;
            Analyrecord(j).phase = 0;
        else
            Analyrecord(j).Amp = Analyrecord(j).Amp(sortedIndicesByRow{row,1});
            Analyrecord(j).freq = Analyrecord(j).freq(sortedIndicesByRow{row,1});
            Analyrecord(j).phase = Analyrecord(j).phase(sortedIndicesByRow{row,1});
            Analy_freq = unique([Analy_freq,Analyrecord(j).freq]);%记录所有信号总的频率数
            
        end
    end
    Analy_freq_all = unique([Analy_freq,Analy_freq_all]);
    save(sig_filename, 'fs','Ndelay','Analyrecord', 'Analy_freq')
end
save(Analy_freq_all_file, 'Analy_freq_all')
toc
%% test



