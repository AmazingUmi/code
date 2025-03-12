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
ENVall_folder = 'D:\database\results\Enhanced_shipsEar';
Signal_folder = 'D:\database\shipsEar\Shipsear_signal_folder';
load(fullfile(Signal_folder,'Analy_freq_all.mat'))

contents = dir(ENVall_folder);
ENVall_subfolders = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
clear contents;
sig_mat_files = dir(fullfile(Signal_folder, '*.mat'));
sig_mat_files(1) = [];

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
% 160 dB 对应的声压幅值
Amp_source = 5e4; 

%% 生成新信号
for k = 1:length(ENVall_subfolders)
    load(fullfile(ENVall_folder,ENVall_subfolders(k).name,'ENV_ARR.mat'))
    Arr_freq = round([ARR.freq],4);
    NewSig_foldername = fullfile(ENVall_folder,ENVall_subfolders(k).name,'Newsig');
    
    for j = 1:length(sig_mat_files)
        
        clear Analyrecord;
        Arr_tmp = []; Analy_freq = []; idx = [];
        maxdelay = []; mindelay = [];
        tgsig_lth = []; tgt = []; tgsig = [];


        load(fullfile(Signal_folder,sig_mat_files(j).name))
        NewSig_name = [NewSig_foldername,'\',sig_mat_files(j).name(1:end-4),sprintf('_new_ENV%s.mat',num2str(k))];
        Analy_freq = round(Analy_freq,4);
        [~, idx] = ismember(Analy_freq,Arr_freq);
        Arr_tmp = ARR(idx);%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        for i = 1:length(Arr_tmp)
            maxdelay(i) = max(Arr_tmp(i).Delay);     %记录最大时延
            mindelay(i) = min(Arr_tmp(i).Delay);     %记录最小时延
        end

        MAXdelay = max(maxdelay);
        MINdelay = min(mindelay);
        %问题在于信号时间过长，应该切割掉部分空白值
        tgsig_lth = ceil(MAXdelay-MINdelay + max(Ndelay)+2.1)*fs; %目标信号长度,最长时延-最短时延+原始信号长度+空白
        tgt = (0:tgsig_lth-1)/fs; %目标信号时间序列
        tgsig = 0*tgt; %目标信号初始化
        N = length(Analyrecord);
        mid_t = single((0:(Ndelay(2)-Ndelay(1))*fs-1)/fs);  %中间信号时间序列
        mid_L = length(mid_t);

        for i = 1:N
           tic
            tar_freq = round(Analyrecord(i).freq,4)';
            tar_amp = Analyrecord(i).Amp;
            tar_pha = Analyrecord(i).phase;
            [~, tar_f_loc] = ismember(tar_freq, Arr_freq);
            num_tar = length(tar_freq);
            %不同频率的中间信号矩阵,由于内存占用过大,转移至子循环中
            % mid_signal = Amp_source*tar_amp(:).*cos(2*pi*tar_freq(:).*mid_t+tar_pha(:));
            interval_tar = 30;

            for n = 1:interval_tar:150
                
                dsig = []; Dsig = []; be = [];
                indices = []; row_idx = []; lin_idx =[];
                num_int = 0;
                if n+interval_tar <= num_tar
                    for int = 1:interval_tar
                        delay0 = ARR(tar_f_loc(n+int-1)).Delay;
                        amp0 = ARR(tar_f_loc(n+int-1)).Amp';
                        num_paths = length(amp0);
                        %生成中间信号
                        mid_signal = Amp_source*tar_amp(n+int-1).*cos(2*pi*tar_freq(n+int-1).*mid_t+tar_pha(n+int-1));
                        dsig(num_int+1:num_int+num_paths , :) = amp0.*mid_signal;

                        be(num_int+1:num_int+num_paths) = floor((delay0-MINdelay+Ndelay(i))*fs)+1; %确定信号初始位置
                        % dsig(num_int+1:num_int+num_paths , :) = amp0.*mid_signal(n+int-1,:);
                        num_int = num_int + num_paths;
                    end
                else
                    for int = n:num_tar
                        delay0 = ARR(tar_f_loc(int)).Delay;
                        amp0 = ARR(tar_f_loc(int)).Amp';
                        num_paths = length(amp0);
                        %生成中间信号
                        mid_signal = Amp_source*tar_amp(int).*cos(2*pi*tar_freq(int).*mid_t+tar_pha(int));
                        dsig(num_int+1:num_int+num_paths , :) = amp0.*mid_signal;

                        be(num_int+1:num_int+num_paths) = floor((delay0-MINdelay+Ndelay(i))*fs)+1; %确定信号初始位置
                        % dsig(num_int+1:num_int+num_paths , :) = amp0.*mid_signal(int,:);
                        num_int = num_int + num_paths;
                    end
                end
                num_disg = length(be);
                for p = 1:num_disg
                    Dsig = zeros(1,length(tgt));
                    Dsig(be(p):be(p)+mid_L-1) = dsig(p , :);
                    tgsig = tgsig+Dsig;
                end
         
            end
            toc
            obr = 2;
        end

        save(NewSig_name,'tgsig','tgt','fs');
        disp(['信号已保存为: ', NewSig_name]);
        toc
    end

end

%% 可选操作
% 添加噪声
% v = 8; % 风速参数可独立设置
% env_sig = generate_env_noise(fs, length(tgsig), v);
% tgsig = tgsig+env_sig;

% 绘图
% plot(tgt,tgsig)
% figure
% plot(tgt,env_sig)