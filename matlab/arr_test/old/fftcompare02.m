%% 验证滤除部分频率对信号特征的影响
%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\');
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('D:\code\matlab\underwateracoustic\bellhop_fundation\function');
clear pathstr; clear tmp; clear index;

%% 读取原始时域信号
filename = 'D:\database\shipsEar\shipsEar_classified_renamed_reclasified\A_Workvessels\1.wav';
[signal, fs] = audioread(filename);
signal = signal';
% 截取前1秒数据并归一化
if length(signal) >= fs
    signal = signal(1:fs);
else
    error('信号长度不足1秒');
end
signal = signal ./ max(abs(signal)); %归一化
L = length(signal);
T = L/fs;
t = (0:L-1)/fs;

%% 频谱分析
signal_f = fft(signal);
signal_f_2 = signal_f(1:L/2+1);%此信号包含相位信息
signal_f_3 = abs(signal_f_2/L);
signal_f_3(2:end-1) = 2*signal_f_3(2:end-1);%非直流分量乘2
signal_f_3_phi = angle(signal_f_2);
f = (0:L/2)*fs/L;

%% 频率成分提取
threshold = 0.01; % 调整阈值观察不同效果
[sig_peaks, sig_locs] = sort(signal_f_3,'descend');
valid_idx = sig_peaks >= threshold*max(sig_peaks);
sig_locs = sig_locs(valid_idx);
sig_peaks = sig_peaks(valid_idx);
sig_freq = f(sig_locs);
sig_amplitude = sig_peaks;
sig_phase = signal_f_3_phi(sig_locs);

%% 信号重构
recover_sig = zeros(size(t));
for k = 1:length(sig_freq)
    recover_sig = recover_sig + sig_amplitude(k)*cos(2*pi*sig_freq(k)*t + sig_phase(k));
end

%% 评估指标计算
% 时域指标
MSE = mean((signal - recover_sig).^2);
MAE = mean(abs(signal - recover_sig));
DTW_score = dtw(signal, recover_sig);

% 频域指标
f_edges = [0 500 5000 fs/2];
[Pxx_orig, f_bands] = pwelch(signal, hamming(1024), 512, 1024, fs);
[Pxx_rec, ~] = pwelch(recover_sig, hamming(1024), 512, 1024, fs);

% 计算频段能量比例
band_energy_orig = zeros(1, length(f_edges)-1);
band_energy_rec = zeros(1, length(f_edges)-1);
for k = 1:length(f_edges)-1
    band_mask = (f_bands >= f_edges(k)) & (f_bands < f_edges(k+1));
    band_energy_orig(k) = sum(Pxx_orig(band_mask));
    band_energy_rec(k) = sum(Pxx_rec(band_mask));
end
total_energy_orig = sum(band_energy_orig);
total_energy_rec = sum(band_energy_rec);
spectral_contrast_dist = sum(abs((band_energy_orig - band_energy_rec)./band_energy_orig));

%% 可视化对比
figure('Position', [100 100 1200 800])

% 时域信号对比
subplot(3,2,[1 2])
part_idx = 1:600;
plot(t(part_idx), signal(part_idx), 'b', t(part_idx), recover_sig(part_idx), 'r--')
title('时域信号对比'), xlabel('时间(s)'), legend('原始信号', '重构信号')

% 频谱对比
subplot(3,2,3)
plot(f, 20*log10(signal_f_3), 'b')
hold on

recover_sig_f = abs(fft(recover_sig)/L);
recover_sig_f = recover_sig_f(1:L/2+1);
recover_sig_f(2:end-1) = 2*recover_sig_f(2:end-1);
plot(f, 20*log10(recover_sig_f), 'r')
ylim([-150 5]) % 合理动态范围限制
title('幅度谱对比'), xlabel('频率(Hz)'), ylabel('幅度(dB)')

% 频段能量分布
subplot(3,2,4)
bar([band_energy_orig; band_energy_rec]')
% hold on 
% plot(band_energy_orig - band_energy_rec)
set(gca, 'XTickLabel', {'0-500Hz', '500-5kHz', '>5kHz'})
title('归一化频段能量分布'), legend('原始信号', '重构信号')

% 误差信号
subplot(3,2,5)
% plot(t, signal - recover_sig)
% title('时域误差信号'), xlabel('时间(s)')
spectrogram(signal, hamming(1024), 512, 1024, fs, 'yaxis')
title('重构信号时频谱')

% 时频谱对比
subplot(3,2,6)
spectrogram(recover_sig, hamming(1024), 512, 1024, fs, 'yaxis')
title('重构信号时频谱')

%% 显示评估结果
fprintf('===== 评估结果 =====\n');
fprintf('均方误差(MSE): %.4f\n', MSE);
fprintf('平均绝对误差(MAE): %.4f\n', MAE);
fprintf('动态时间规整(DTW): %.4f\n', DTW_score);
fprintf('谱对比失真度: %.4f\n', spectral_contrast_dist);