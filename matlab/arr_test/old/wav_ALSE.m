%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('D:\code\matlab\underwateracoustic\bellhop_fundation\function');
clear pathstr;clear tmp;clear index;
%% lpc分析
wav_folder = 'D:\database\shipsEar\shipsEar_classified_renamed_reclasified\A_Workvessels\1.wav';
[input_signal, fs] = audioread(wav_folder);
L = length(input_signal); %信号长度
T = L/fs;
t = (0:L-1)/fs; % 信号时间

% 2. LPC分析
order = 10;  % LPC阶数
frame_size = 256;  % 每帧大小
hop_size = 128;  % 帧移

num_frames = floor(length(input_signal) / hop_size) - 1;

lpc_coeffs = zeros(num_frames, order + 1);
for n = 1:num_frames
    frame = input_signal((n-1)*hop_size+1:(n-1)*hop_size+frame_size);
    lpc_coeffs(n, :) = lpc(frame, order);  % LPC分析，得到预测系数
end

% 3. 噪声估计 (简单的谱减法)
% 使用短时傅里叶变换 (STFT) 计算信号的频谱
window_size = 1024;
[S, F, T] = stft(input_signal, fs, 'Window', hamming(window_size), 'OverlapLength', window_size/2, 'FFTLength', window_size);

% 计算噪声谱（简单的噪声估计方法：均值谱）
noise_spectrum = mean(abs(S), 2);

% 4. 谱增强
alpha = 0.7;  % 增益因子
enhanced_spectrum = S .* (1 - alpha * (abs(S) ./ noise_spectrum));  % 进行谱增强

% 5. 逆STFT重建信号
enhanced_signal = istft(enhanced_spectrum, fs, 'Window', hamming(window_size), 'OverlapLength', window_size/2, 'FFTLength', window_size);

% 6. 保存增强后的信号
% audiowrite('enhanced_output.wav', enhanced_signal, fs);