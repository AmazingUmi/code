% 改进后的海洋环境噪声仿真示例
% 包含波浪噪声、船舶噪声、生物噪声和气象噪声，并考虑频率依赖的传播损耗

% 清理环境
clear; close all; clc;

% 仿真参数
Fs = 48000;            % 采样频率 (Hz)
T = 10;                % 仿真时长 (秒)
N = Fs * T;            % 采样点数
f = (0:N-1)*(Fs/N);    % 频率向量

% 传播参数
distance = 1000;       % 传播距离 (米)
c = 1500;              % 声速 (m/s)

% 使用 Thorp 模型计算频率依赖的吸收系数
f_kHz = f / 1000; % 频率转换为 kHz
alpha_thorp = 0.076 * f_kHz.^2 ./ (1 + (f_kHz/0.88).^2) + ...
              0.0055 * f_kHz.^2 ./ (1 + (f_kHz/3.3).^2);
% 单位：dB/km
% 计算传播损耗 (线性尺度)
prop_loss_freq = 10.^(-alpha_thorp * (distance / 1000) / 10); % distance 转换为 km

% 波浪噪声参数（JONSWAP谱）
gamma = 3.3;           % 峰值因子
H_s = 2;               % 有效波高 (米)
T_p = 8;               % 峰值周期 (秒)
g = 9.81;              % 重力加速度 (m/s^2)

% 初始化波浪噪声功率谱密度
S_wave = zeros(size(f));

% 计算非零频率的S_wave
nonzero = f > 0;
f_nz = f(nonzero);

% JONSWAP谱计算（仅对非零频率）
sigma = ones(size(f_nz));
sigma(f_nz < 5) = 0.07;
sigma(f_nz >= 5) = 0.09;

S_wave(nonzero) = (5/16) * H_s^2 * g^2 ./ ((2*pi).^4 .* f_nz.^5) ...
    .* exp(-1.25*(f_nz*T_p).^(-4)) .* gamma.^exp(-(f_nz-T_p).^2 ./ (2*0.56*T_p.^2)) ...
    .* sigma;

% 将f=0的波浪噪声功率谱密度设置为0
S_wave(1) = 0;

% 船舶噪声参数（带有频率峰值的谱）
% 假设船舶噪声在特定频率有峰值，例如200 Hz
S_ship = 1e-12 * (1 + 10*exp(-((f-200)/50).^2));  % 添加一个高于背景的峰值

% 生物噪声参数（例如鲸鱼噪声，集中在几十到几百Hz）
S_bio = 1e-13 * exp(-((f-100)/30).^2);

% 气象噪声参数（风暴引起的低频噪声）
% 减少低频段的能量
S_weather = 1e-14 * (1 + 0.05*f.^2 .* exp(-f/1000));

% 调整波浪噪声的整体能量，避免低频过高
% 应用高通滤波器削减低于 cutoff_freq 的频率
cutoff_freq = 10; % 截止频率 (Hz)
high_pass = double(f >= cutoff_freq);
S_wave = S_wave .* high_pass;

% 总噪声功率谱密度（考虑传播损耗）
S_total = (S_wave + S_ship + S_bio + S_weather) .* prop_loss_freq;

% 检查S_total是否包含NaN或Inf
if any(isnan(S_total)) || any(isinf(S_total))
    warning('S_total 包含 NaN 或 Inf。请检查各个噪声源的功率谱密度。');
    % 可以选择将NaN或Inf替换为0或其他适当的值
    S_total(isnan(S_total) | isinf(S_total)) = 0;
end

% 确保S_total不为负
S_total(S_total < 0) = 0;

% 生成随机相位
phi = 2 * pi * rand(size(f));

% 生成频域噪声
A = sqrt(S_total * Fs / 2);
% 处理可能的负值或NaN（虽然已经处理过）
A(~isfinite(A)) = 0;

X = A .* exp(1i * phi);

% 保持实数信号的对称性
X(1) = sqrt(S_total(1) * Fs) * exp(1i * phi(1)); % DC分量
if mod(N, 2) == 0
    % 如果N为偶数，Nyquist分量只有一个
    X(N/2+1) = sqrt(S_total(N/2+1) * Fs) * exp(1i * phi(N/2+1)); % Nyquist分量
end
for k = 2:(floor(N/2))
    X(N - k + 1) = conj(X(k));
end

% 转换为时域信号
noise = real(ifft(X, 'symmetric'));

% 确保时域信号没有NaN或Inf
if any(~isfinite(noise))
    warning('时域信号 noise 包含非有限值。');
    noise(~isfinite(noise)) = 0;
end

% 时间向量
t = (0:N-1)/Fs;

% 绘制功率谱密度
figure;
semilogy(f(1:floor(N/2)), S_total(1:floor(N/2)));
xlabel('频率 (Hz)');
ylabel('功率谱密度 (W/Hz)');
title('总环境噪声功率谱密度');
grid on;

% 绘制时域信号
figure;
plot(t(1:Fs), noise(1:Fs)); % 显示前1秒
xlabel('时间 (秒)');
ylabel('振幅');
title('海洋环境噪声时域信号 (前1秒)');
grid on;

% 绘制各噪声源的功率谱密度
figure;
semilogy(f(1:floor(N/2)), S_wave(1:floor(N/2)), 'b', ...
         f(1:floor(N/2)), S_ship(1:floor(N/2)), 'r', ...
         f(1:floor(N/2)), S_bio(1:floor(N/2)), 'g', ...
         f(1:floor(N/2)), S_weather(1:floor(N/2)), 'm');
xlabel('频率 (Hz)');
ylabel('功率谱密度 (W/Hz)');
title('各噪声源功率谱密度');
legend('波浪噪声', '船舶噪声', '生物噪声', '气象噪声');
grid on;

% 保存音频文件（可选）
% audiowrite('improved_ocean_noise.wav', noise, Fs);
