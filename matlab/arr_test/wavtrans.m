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
wav_subfolders = {'Class A','Class B','Class C','Class D'};
wav_folder_total = 'D:\database\shipsEar\shipsEar_reclassified';
wav_folder{1} = 'train_raw_wav';%训练集
wav_folder{2} = 'val_raw_wav';%验证集
%环境噪声似乎不应该进行这样的扩展,'Class E'
Signal_folder_path = 'D:\database\shipsEar\Shipsear_signal_folder';
% 检查目标文件夹是否存在，如果不存在则创建
if ~exist(Signal_folder_path, 'dir')
    mkdir(Signal_folder_path);
end

%% 记录不同的音频共同的频率
Analy_freq_all = [];
threshold = 0.01;
tic
for m = 1:2
    % :length(wav_subfolders)
    for j = 1:length(wav_subfolders)   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % 获取当前子文件夹路径
        subfolder_path = fullfile(wav_folder_total,wav_folder{m}, wav_subfolders{j});
        % 获取子文件夹中的所有音频文件
        audio_files = dir(fullfile(subfolder_path, '*.wav'));

        for k = 1:length(audio_files)
            filename = fullfile(subfolder_path,audio_files(k).name);
            [signal, fs] = audioread(filename);%读取实际信号、采样频率
            dt = 1/fs;
            L = length(signal); %信号长度
            T = L/fs;
            t = (0:L-1)*dt; % 信号时间

            %切分信号,依据信号长度进行修正
            cut_Tlength = 2;
            N = floor(T/cut_Tlength);
            Ndelay = []; cut_length = cut_Tlength * fs;
            for i = 1:N
                Ndelay(i) = (i-1)*cut_Tlength;
            end
            %分别对分段信号进行分解，获取其主要频率分量
            Analy_freq = [];
            Analyrecord = [];

            for i = 1:N
                mid_signal =  signal((i-1)*cut_length+1:i*cut_length);
                signal_f = fft(mid_signal);  %此信号包含相位信息
                signal_f_2 = signal_f(1:cut_length/2+1);
                signal_f_3 = abs(signal_f_2)/cut_length; %信号幅值
                signal_f_3(2:end-1) = 2*signal_f_3(2:end-1);
                signal_f_3_phi = angle(signal_f_2);
                f = (0:cut_length/2)/cut_length*fs;
                % figure
                % plot(f,signal_f_3);%绘制频谱图

                % 频率成分提取
                [sig_peaks, sig_locs] = sort(signal_f_3,'descend');
                valid_idx = sig_peaks >= threshold*sig_peaks(1);
                sig_locs = sig_locs(valid_idx);
                sig_peaks = sig_peaks(valid_idx);
                sig_freq = f(sig_locs);
                sig_amplitude = sig_peaks;
                sig_phase = signal_f_3_phi(sig_locs);
                %滤除10Hz以下频率
                freq_idx = sig_freq >= 10;
                sig_amplitude = sig_amplitude(freq_idx);
                sig_freq = sig_freq(freq_idx);
                sig_phase = sig_phase(freq_idx);

                Analyrecord(i).Amp = sig_amplitude; %每段信号各自的幅值
                Analyrecord(i).freq = sig_freq;
                Analyrecord(i).phase = sig_phase;
                Analy_freq = unique([Analy_freq,sig_freq]);%记录所有信号总的频率数
            end

            %保存信号信息
            sig_filename = [Signal_folder_path,'\',sprintf('%s_%s_%s.mat',...
                wav_folder{m},wav_subfolders{j},audio_files(k).name(1:end-4))];
            save(sig_filename, 'fs','Ndelay','Analyrecord', 'Analy_freq')
            Analy_freq_all = unique([Analy_freq,Analy_freq_all]);
        end
    end
end
Analy_freq_all_file = [Signal_folder_path,'\Analy_freq_all.mat'];
save(Analy_freq_all_file, 'Analy_freq_all')

toc