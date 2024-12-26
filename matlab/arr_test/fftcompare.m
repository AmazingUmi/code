%验证滤除部分频率对信号特征的影响

%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('D:\code\matlab\underwateracoustic\bellhop_fundation\function');
clear pathstr;clear tmp;clear index;
%% 读取原始时域信号
filename = 'D:\database\shipsEar\shipsEar_classified_renamed_reclasified\A_Workvessels\1.wav';
[signal, fs] = audioread(filename);%读取实际信号、采样频率
signal = signal';
signal(fs+1:end) = [];
signal = signal./max(signal);
dt = 1/fs;
L = length(signal); %信号长度
T = L/fs;
t = (0:L-1)*dt; % 信号时间
%%
threshold = 0.01;

signal_f = fft(signal);  %此信号包含相位信息
signal_f_2 = signal_f(1:L/2);
signal_f_3 = 2*1/L*abs(signal_f_2); %信号幅值
signal_f_3_phi = atan(imag(signal_f_2)./real(signal_f_2));
% signal_f(end+1) = signal_f(1);  %补充至频谱左右对称
% signal_f_2 = 2*1/L*N*fftshift(abs(signal_f));
% signal_f_3 = signal_f_2(L/2/N:end);
f = (1:T*fs/2);
% figure
% plot(f,signal_f_3);%绘制频谱图
[sig_peaks, sig_locs] = sort(signal_f_3, 'descend');  % 找到峰值
%过滤掉较小的幅值
sig_locs(sig_peaks<=threshold*sig_peaks(1)) = [];
sig_peaks(sig_peaks<=threshold*sig_peaks(1)) = [];
sig_freq = f(sig_locs);    % 主要频率 (取前两个为例)
sig_amplitude = sig_peaks; % 对应的幅值
sig_phase = signal_f_3_phi(sig_locs);

%% 
recover_sig = 0 *t ;
tic
for k = 1:length(sig_freq)
    mid_signal = sig_amplitude(k)*sin(2*pi*sig_freq(k)*t+sig_phase(k));
    recover_sig = recover_sig + mid_signal;
end
toc
%% 

% d_sig = signal - recover_sig;
% plot(d_sig)
% 假设原始信号和恢复信号已经定义
% signal 和 recover_sig 是同一长度的列向量

% 1. 计算均方误差 (MSE)
MSE = mean((signal - recover_sig).^2);

% 2. 计算信噪比 (SNR)
signal_power = sum(signal.^2);   % 原始信号的功率
noise_power = sum((signal - recover_sig).^2);  % 噪声的功率
SNR = 10 * log10(signal_power / noise_power);

% % 3. 计算结构相似性指数 (SSIM)
% [ssim_value, ssim_map] = ssim(recover_sig, signal);  % 计算 SSIM 和局部 SSIM 图
% fprintf('SSIM: %.4f\n', ssim_value);

% 4. 计算频域失真度
% 对信号和恢复信号进行FFT变换
N = length(signal);
X_signal = fft(signal);
X_recover = fft(recover_sig);

% 频域失真度 = |X(f) - X'(f)|
freq_distortion = sum(abs(X_signal - X_recover)) / N;

% 打印结果
fprintf('MSE: %.4f\n', MSE);
fprintf('SNR: %.4f dB\n', SNR);
fprintf('频域失真度: %.4f\n', freq_distortion);

% 可视化
figure;
subplot(2, 1, 1);
plot(signal);
title('Original Signal');

subplot(2, 1, 2);
plot(recover_sig);
title('Recovered Signal');
