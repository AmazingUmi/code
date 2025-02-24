%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('D:\code\matlab\underwateracoustic\bellhop_fundation\function');
clear pathstr;clear tmp;clear index;

% 设置音频路径
wav_folder = 'D:\database\shipsEar\shipsEar_classified_renamed_reclasified';
wav_subfolders = {'A_Workvessels','B_Mobilityboats','C_passengers','D_giantvessels'};
%环境噪声似乎不应该进行这样的扩展,'E_enviroments'

%% 记录不同的音频共同的频率
Analy_freq_all = [];
% :length(wav_subfolders)
tic
for j = 1:length(wav_subfolders)
    % 获取当前子文件夹路径
    subfolder_path = fullfile(wav_folder, wav_subfolders{j});
    % 获取子文件夹中的所有音频文件
    audio_files = dir(fullfile(subfolder_path, '*.wav'));

    for k = 1:length(audio_files)
        filename = fullfile(subfolder_path,audio_files(k).name );
        [signal, fs] = audioread(filename);%读取实际信号、采样频率
        dt = 1/fs;
        L = length(signal); %信号长度
        T = L/fs;
        t = (0:L-1)*dt; % 信号时间

        %切分信号,依据信号长度进行修正
        cut_Tlength = 2;%单位为秒（s）
        if mod(T, cut_Tlength)>=1.1
            N = ceil(T/cut_Tlength); %分段段数
            Nplus = 1;
        else
            N = floor(T/cut_Tlength); %分段段数
            Nplus = 0;
        end
        Nsignal = [];  Ndelay = []; cut_length = cut_Tlength * fs;
        for i = 1:N

            % Nt(i,:) = (i-1)/N*T:dt:i/N*T-dt;
            if Nplus == 1 && i == N
                Nsignal(i,:) = [signal((i-1)*cut_length+1:end);zeros(cut_length-length(signal((i-1)*cut_length+1:end)),1)];
            else
                Nsignal(i,:) = signal((i-1)*cut_length+1:i*cut_length);
            end
            Ndelay(i) = (i-1)*cut_length;
        end

        %分别对分段信号进行分解，获取其主要频率分量
        Analy_freq = [];
        Analyrecord = [];
        for i = 1:N
            mid_signal = Nsignal(i,:);
            signal_f = fft(mid_signal);  %此信号包含相位信息
            signal_f_2 = signal_f(1:cut_length/2+1);
            signal_f_3 = abs(signal_f_2)/cut_length; %信号幅值
            signal_f_3(2:end-1) = 2*signal_f_3(2:end-1);
            signal_f_3_phi = angle(signal_f_2);
            % signal_f(end+1) = signal_f(1);  %补充至频谱左右对称
            % signal_f_2 = 2*1/L*N*fftshift(abs(signal_f));
            % signal_f_3 = signal_f_2(L/2/N:end);
            f = (0:cut_length/2)/cut_length*fs;
            figure
            plot(f,signal_f_3);%绘制频谱图
            [sig_peaks, sig_locs] = sort(signal_f_3, 'descend');  % 找到峰值
            %过滤掉较小的幅值
            threshold = 0.1;
            sig_locs(sig_peaks<=threshold*sig_peaks(1)) = [];
            sig_peaks(sig_peaks<=threshold*sig_peaks(1)) = [];
            sig_freq = f(sig_locs);    % 主要频率 (取前两个为例)
            sig_amplitude = sig_peaks; % 对应的幅值
            sig_phase = signal_f_3_phi(sig_locs);
            Analyrecord(i).Amp = sig_amplitude; %每段信号各自的幅值
            Analyrecord(i).freq = sig_freq;
            Analyrecord(i).phase = sig_phase;
            Analy_freq = unique([Analy_freq,sig_freq]);%记录所有信号总的频率数
        end

        %保存信号信息
        sig_filename = [subfolder_path,'\',sprintf('%s_%d.mat',wav_subfolders{j},k)];
        save(sig_filename, 'fs', 't','L','T','dt','Ndelay','Analyrecord', 'Analy_freq')
        Analy_freq_all = unique([Analy_freq,Analy_freq_all]);
    end
end
Analy_freq_all_file = [wav_folder,'\Analy_freq_all.mat'];
save(Analy_freq_all_file, 'Analy_freq_all')

%% 将所有的信号数据.mat复制到同一个文件夹

% 设置目标文件夹路径，可以通过修改这个，创造不同精细程度的数据集

Signal_folder_path = 'D:\database\shipsEar\Shipsear_signal_folder';
% 获取源文件夹及其所有子文件夹中的.mat文件
files = dir(fullfile(wav_folder, '**', '*.mat'));  % '**'表示递归查找子文件夹中的文件

% 检查目标文件夹是否存在，如果不存在则创建
if ~exist(Signal_folder_path, 'dir')
    mkdir(Signal_folder_path);
end
% 遍历每个.mat文件并复制到目标文件夹
for i = 1:length(files)
    % 获取源文件的完整路径
    source_file = fullfile(files(i).folder, files(i).name);
    % 获取目标文件的完整路径
    target_file = fullfile(Signal_folder_path, files(i).name);
    % 复制文件到目标文件夹
    copyfile(source_file, target_file);
    % 显示复制的文件路径
    disp(['已复制文件: ', source_file, ' 到 ', target_file]);
end
toc