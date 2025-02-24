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
signal = signal ./ max(abs(signal)); %归一化
signal = signal';
L = length(signal);
T = L/fs;
t = (0:L-1)/fs;

%% 切分信号
cut_Tlength = 1;%单位为秒（s）
N = floor(T/cut_Tlength); %分段段数
Nsignal = []; cut_length = cut_Tlength * fs;
%% 计算特性
tic
for i = 1:N
    % 频谱分析
    midsignal = signal((i-1)*cut_length+1:i*cut_length);
    signal_f = fft(midsignal);
    signal_f_2 = signal_f(1:cut_length/2+1);%此信号包含相位信息
    signal_f_3 = abs(signal_f_2/cut_length);
    signal_f_3(2:end-1) = 2*signal_f_3(2:end-1);%非直流分量乘2
    signal_f_3_phi = angle(signal_f_2);
    f = (0:cut_length/2)*fs/cut_length;

    % 频率成分提取
    threshold = 0.01; % 调整阈值观察不同效果
    [sig_peaks, sig_locs] = sort(signal_f_3,'descend');
    valid_idx = sig_peaks >= threshold*max(sig_peaks);
    sig_locs = sig_locs(valid_idx);
    sig_peaks = sig_peaks(valid_idx);
    sig_freq = f(sig_locs);
    sig_amplitude = sig_peaks;
    sig_phase = signal_f_3_phi(sig_locs);

    % 信号重构

    pt = (0:cut_length-1)/fs;
    recover_sig = zeros(size(pt));
    for k = 1:length(sig_freq)
        recover_sig = recover_sig + sig_amplitude(k)*cos(2*pi*sig_freq(k)*pt + sig_phase(k));
    end

    % 评估指标计算
    % 时域指标
    MSE(i) = mean((midsignal - recover_sig).^2);
    MAE(i) = mean(abs(midsignal - recover_sig));
    % 频域指标
    f_edges = [0 500 5000 fs/2];
    [Pxx_orig, f_bands] = pwelch(midsignal, hamming(1024), 512, 1024, fs);
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
    spectral_contrast_dist(i) = sum(abs((band_energy_orig - band_energy_rec)./band_energy_orig));

    %计算时频能量差异
    [s_orig, ~, ~] = spectrogram(midsignal, hamming(1024), 512, 1024, fs, 'yaxis');
    [s_rec, ~, ~] = spectrogram(recover_sig, hamming(1024), 512, 1024, fs, 'yaxis');
    d_timefreq = abs(s_orig - s_rec);
    Time_freq_contrast_dist(i) = mean(d_timefreq(:));

end
toc
Avr_MSE = mean(MSE);
Avr_MAE = mean(MAE);
Avr_spectral_contrast_dist = mean(spectral_contrast_dist);
Avr_Time_freq_contrast_dist = mean(Time_freq_contrast_dist);
%% 显示评估结果
fprintf('===== 评估结果 =====\n');
fprintf('时域均方误差(MSE): %.4f\n', Avr_MSE);
fprintf('时域平均绝对误差(MAE): %.4f\n', Avr_MAE);
fprintf('频谱对比失真度: %.4f\n', Avr_spectral_contrast_dist);
fprintf('时频对比失真度: %.4f\n', Avr_Time_freq_contrast_dist);

% %% 可视化对比
% figure('Position', [100 100 1200 800])
%
% % 时域信号对比
% subplot(3,2,[1 2])
% part_idx = 1:600;
% plot(t(part_idx), signal(part_idx), 'b', t(part_idx), recover_sig(part_idx), 'r--')
% title('时域信号对比'), xlabel('时间(s)'), legend('原始信号', '重构信号')
%
% % 频谱对比
% subplot(3,2,3)
% plot(f, 20*log10(signal_f_3), 'b')
% hold on
%
% recover_sig_f = abs(fft(recover_sig)/L);
% recover_sig_f = recover_sig_f(1:L/2+1);
% recover_sig_f(2:end-1) = 2*recover_sig_f(2:end-1);
% plot(f, 20*log10(recover_sig_f), 'r')
% ylim([-150 5]) % 合理动态范围限制
% title('幅度谱对比'), xlabel('频率(Hz)'), ylabel('幅度(dB)')
%
% % 频段能量分布
% subplot(3,2,4)
% bar([band_energy_orig; band_energy_rec]')
% % hold on
% % plot(band_energy_orig - band_energy_rec)
% set(gca, 'XTickLabel', {'0-500Hz', '500-5kHz', '>5kHz'})
% title('归一化频段能量分布'), legend('原始信号', '重构信号')
%
% % 误差信号
% subplot(3,2,5)
% % plot(t, signal - recover_sig)
% % title('时域误差信号'), xlabel('时间(s)')
% spectrogram(signal, hamming(1024), 512, 1024, fs, 'yaxis')
% title('重构信号时频谱')
%
% % 时频谱对比
% subplot(3,2,6)
% spectrogram(recover_sig, hamming(1024), 512, 1024, fs, 'yaxis')
% title('重构信号时频谱')
%

% === 替换原有subplot(3,2,5)和subplot(3,2,6) ===
% 
% % 原始信号时频谱
% tic
% subplot(1,2,1)
% [s_orig, f_orig, t_orig] = spectrogram(midsignal, hamming(1024), 512, 1024, fs, 'yaxis');
% imagesc(t_orig, f_orig, 10*log10(abs(s_orig))) % 转换为dB显示
% axis xy; colorbar; clim([-130 20]); % 统一色标范围
% title('原始信号时频谱'), xlabel('时间(s)'), ylabel('频率(Hz)')
% 
% % 重构信号时频谱
% subplot(1,2,2)
% [s_rec, f_rec, t_rec] = spectrogram(recover_sig, hamming(1024), 512, 1024, fs, 'yaxis');
% imagesc(t_rec, f_rec, 10*log10(abs(s_rec)))
% axis xy; colorbar; clim([-130 20]); % 保持与原始信号相同的色标
% title('重构信号时频谱'), xlabel('时间(s)'), ylabel('频率(Hz)')
