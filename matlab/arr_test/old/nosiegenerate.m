%% 海洋环境噪声仿真（10Hz-25kHz扩展版）
% 作者：MATLAB科研助手
% 日期：2025-02-25
% 功能：生成10Hz-25kHz海洋环境噪声，匹配理论功率谱

%% 基础参数设置
clear; clc;
fs = 50000;         % 采样率需满足Nyquist准则（fs > 2 * 25kHz）
T = 10;             % 信号时长(s)
N = fs * T;         % 采样点数
v = 8;              % 风速(m/s)
ref_power = 1e-12;  % 参考功率(1μPa²/Hz)

%% 1. 高斯白噪声生成（功率预校准）
white_noise = sqrt(ref_power * fs) * randn(1, N);
white_noise = white_noise - mean(white_noise); % 精确去直流

%% 2. 全频段噪声谱建模（Knudsen模型）
f = linspace(0, fs/2, N/2+1); % 频率轴：0~25kHz
SL = 55 - 6*log10(f/400) + 0.08*v^0.6*log10(v/5.14); % 原模型公式

% 频带限制（扩展到10Hz-25kHz）
valid_band = (f >= 10) & (f <= 25000);
SL(~valid_band) = interp1([5, 25000], [SL(find(f>=10,1)), SL(find(f<=25000,1,'last'))],...
                         f(~valid_band), 'linear', 'extrap');

%% 3. 高精度FIR滤波器设计
order = 8192;       % 增加阶数保证宽频带精度
f_norm = f/(fs/2);
target_amp = 10.^(SL/20);

% 设计滤波器（使用切比雪夫窗抑制纹波）
b = fir2(order, f_norm, target_amp, chebwin(order+1, 50)); 

% 能量补偿计算
[h, w] = freqz(b, 1, 2^16, fs);
f_resolution = fs/(2^16); 
target_power = sum(10.^(SL/10)) * (fs/(2*(N/2))); 
filter_energy = sum(abs(h).^2) * f_resolution;
scale_factor = sqrt(target_power / filter_energy);

%% 4. 生成环境噪声
env_noise = scale_factor * filter(b, 1, white_noise);

%% 5. 功率谱验证
nfft = 4096;        % 增加FFT点数提高频率分辨率
[Pxx, f_psd] = pwelch(env_noise, hamming(nfft), nfft/2, nfft, fs, 'psd');
Pxx_dB = 10*log10(Pxx / ref_power); 
SL_interp = interp1(f, SL, f_psd, 'pchip'); % 理论值插值

%% 6. 全频段可视化
figure('Color','w','Position',[100,100,1200,600])
semilogx(f_psd, Pxx_dB, 'b', 'LineWidth',1.5)
hold on
semilogx(f_psd, SL_interp, 'r--', 'LineWidth',1.5)

% 坐标轴设置
set(gca, 'XScale','log','FontSize',12,'XGrid','on','YGrid','on')
xlim([10 25000])
xticks([10 100 1000 10000 25000])
xticklabels({'10','100','1k','10k','25k'})
ylim([-40 60])
xlabel('Frequency (Hz)','FontSize',14)
ylabel('Power Spectrum Density (dB re 1μPa²/Hz)','FontSize',14)
title('10Hz-25kHz海洋噪声功率谱验证','FontSize',16,'FontWeight','bold')
legend('仿真结果','理论模型','Location','southwest','FontSize',12)
grid on

%% 7. 音频输出（可选）
% env_audio = resample(env_noise, 48000, fs); % 降采样至可听范围
% audiowrite('Ocean_Noise_10Hz-25kHz.wav', env_audio/max(abs(env_audio))*0.8, 48000);