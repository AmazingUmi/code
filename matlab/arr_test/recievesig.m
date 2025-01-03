%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('E:\Umicode\matlab\underwateracoustic\bellhop_fundation\function');
clear pathstr;clear tmp;clear index;
%% 设置生成信号参数
ENVall_folder = 'E:\Database\Enhanced_shipsEar';%需要修正
Signal_folder = 'E:\Database\shipsEar\Shipsear_signal_folder';

contents = dir(ENVall_folder);
ENVall_subfolders = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
clear contents;
sig_mat_files = dir(fullfile(Signal_folder, '*.mat'));
sig_mat_files(18) = [];

% txtfilename = 'env_files_list.txt';
load(fullfile(Signal_folder,'Analy_freq_all.mat'))

%%
%创建文件夹
for j = 1:length(ENVall_subfolders)
    NewSig_foldername = fullfile(ENVall_folder,ENVall_subfolders(j).name,'Newsig');
    if ~exist(NewSig_foldername, 'dir')
        mkdir(NewSig_foldername); % 创建文件夹
        fprintf('文件夹"%s"已创建。\n', NewSig_foldername);
    else
        fprintf('文件夹"%s"已存在。\n', NewSig_foldername);
    end
end

% for k = 1:length(ENVall_subfolders)
for k = 1
    load(fullfile(ENVall_folder,ENVall_subfolders(k).name,'ENV_ARR.mat'))
    NewSig_foldername = fullfile(ENVall_folder,ENVall_subfolders(k).name,'Newsig');
    idx = [];
    Arr_tmp = [];
    for j = 1:length(sig_mat_files)
        load(fullfile(Signal_folder,sig_mat_files(j).name))
        NewSig_name = [NewSig_foldername,'\',sig_mat_files(j).name(1:end-4),sprintf('_new_%s.mat',num2str(k))];
        Arr_freq = [ARR.freq];
        [~, idx] = ismember(Arr_freq, Analy_freq);
        idx = find(idx > 0);
        Arr_tmp = ARR(idx);

        for i = 1:length(Analy_freq)

            maxdelay(i) = max(Arr_tmp(i).Delay);     %记录最大时延
            mindelay(i) = min(Arr_tmp(i).Delay);     %记录最小时延
        end
        %问题在于信号时间过长，应该切割掉部分空白值
        tgsig_lth = (max(maxdelay)-min(mindelay))*fs + length(t) + 1; %目标信号长度,最长时延-最短时延+原始信号长度+空白
        tgt = (0:tgsig_lth-1)*dt; %目标信号时间序列
        tgsig = 0*tgt; %目标信号初始化
        N = length(Analyrecord);
        for i = 1:N
            tar_freq = Analyrecord(i).freq;
            tar_amp = Analyrecord(i).Amp;
            tar_pha = Analyrecord(i).phase;
            [~, tar_f_loc] = ismember(tar_freq, Analy_freq);
            mid_t = (0:floor(L/N)-1)*dt;  %中间信号时间序列

            for n = 1:length(tar_freq)
                %生成中间信号
                mid_signal = tar_amp(n)*sin(2*pi*tar_freq(n)*mid_t+tar_pha(n));
                %对中间信号进行时延幅值拓展
                for m = 1:length(Arr_tmp(tar_f_loc(n)).Amp)
                    delay0 = Arr_tmp(tar_f_loc(n)).Delay;
                    amp0 = Arr_tmp(tar_f_loc(n)).Amp;
                    dsig = tgt*0;  %临时中间变量
                    be = floor((delay0(m)-min(mindelay)+Ndelay(i))*fs)+1; %确定信号初始位置
                    en = be+length(mid_t)-1; %确定信号结束位置
                    dsig(be:en) = mid_signal;
                    tgsig = tgsig+dsig*amp0(m);
                end
            end
        end
        save(NewSig_name,'tgsig','tgt','fs');
        disp(['信号已保存为: ', NewSig_name]);
    end

end

%%

% plot(tgt,tgsig)