%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr(1:end-9),'underwateracoustic\bellhop_fundation\function'));
clear pathstr tmp index;
%% 设置环境路径
ENVall_folder = 'G:\database\Enhanced_shipsEar0405';
ENV_classes = {'Shallow', 'Transition', 'Deep'};

Signal_folder_path = 'G:\database\shipsEar\Shipsear_signal_folder0416';
load([Signal_folder_path,'\Analy_freq_all.mat']);
sig_mat_files = dir(fullfile(Signal_folder_path, '*.mat'));
sig_mat_files(1) = [];
Amp_source = 1e5; 
%% 
for i = 1:length(ENV_classes)
    ENV_class_path = fullfile(ENVall_folder,ENV_classes{i});
    contents = dir(ENV_class_path);
    ENV_single_foldernames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
    clear contents;
    for j = 1:length(ENV_single_foldernames)
        ENV_single_folder = fullfile(ENV_class_path,ENV_single_foldernames(j).name);
        contents = dir(ENV_single_folder);
        ENV_Rr_foldernames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
        clear contents;
        for k = 1:length(ENV_Rr_foldernames)
            ENV_Rr_folder = fullfile(ENV_single_folder,ENV_Rr_foldernames(k).name);
            NewSig_folder = fullfile(ENV_Rr_folder,'NewSig');
            if ~exist(NewSig_folder, 'dir')
                mkdir(NewSig_folder); % 创建文件夹
            end
            load(fullfile(ENV_Rr_folder,'ENV_ARR_less.mat'))
            if length(ARR(1,:)) ==3
                ReceiveDepth = [10, 20, 30];
            else
                ReceiveDepth = [25, 50, 100, 300];
            end
            for m = 1:length(ReceiveDepth)
                ARR_tmp = ARR(:,m);
                for n = 1:length(sig_mat_files)
                    load(fullfile(Signal_folder_path,sig_mat_files(n).name))
                    NewSig_name = fullfile(NewSig_folder,sprintf('%s_Rd_%d_new.mat',sig_mat_files(n).name(1:end-4),ReceiveDepth(m)));
                    
                    Analy_freq = round(Analy_freq,4);
                    % 提取信号段存在的频率
                    [~, idx] = ismember(Analy_freq,Analy_freq_all);
                    Arr_tmp = ARR_tmp(idx,:);
                    for p = 1:length(Arr_tmp)
                        maxdelay(p) = max(Arr_tmp(p).Delay);      %记录最大时延
                        mindelay(p) = min(Arr_tmp(p).Delay);      %记录最小时延
                    end
                    MAXdelay = max(maxdelay);
                    MINdelay = min(mindelay);
                    Ndelay_d = Ndelay(2)-Ndelay(1);               %分段信号长度
                    Analyrecord_Num = length(Analyrecord);        %分段信号总段数

                    % 信号时间过长，切掉部分空白值
                    tgsig_lth = ceil(MAXdelay- MINdelay+ max(Ndelay)+ 0.05+ Ndelay_d)*fs; %目标信号长度,最长时延-最短时延+原始信号长度+空白
                    tgt = (0:tgsig_lth-1)/fs; %目标信号时间序列
                    tgsig = 0*tgt; %目标信号初始化
                    
                    mid_t = (0:(Ndelay_d)*fs-1)/fs;  %中间信号时间序列
                    mid_L = length(mid_t);
                    tic

                    for p = 1:Analyrecord_Num
                        tar_freq = round(Analyrecord(p).freq,4)';
                        tar_amp = Analyrecord(p).Amp;
                        tar_pha = Analyrecord(p).phase;
                        [~, tar_f_loc] = ismember(tar_freq, Analy_freq_all);
                        num_tar = length(tar_freq);
                        Dsig = zeros(1,length(tgt));
                        for rn = 1:num_tar
                            delay0 = ARR_tmp(tar_f_loc(rn)).Delay;
                            amp0 = ARR_tmp(tar_f_loc(rn)).Amp';
                            phase0 = ARR_tmp(tar_f_loc(rn)).phase;
                            num_paths = length(amp0);
                            %生成中间信号
                            mid_signal = Amp_source*tar_amp(rn).*cos(2*pi*tar_freq(rn).*mid_t+tar_pha(rn));
                            [y_freq, M_length] = fdsiggenerate(mid_signal, fs, delay0, amp0, phase0);
                            be = floor((min(delay0)-MINdelay+Ndelay(p))*fs)+1; %确定信号初始位置
                            Dsig(be:be+M_length-1) = Dsig(be:be+M_length-1) + y_freq;
                        end
                        tgsig = tgsig + Dsig;
                        toc
                        kob=1;
                    end
           
                    save(NewSig_name,'tgsig','tgt','fs');
                    disp(['信号已保存为: ', NewSig_name]);
                    toc
                    kob=1;
                end
            end
        end
    end
end

