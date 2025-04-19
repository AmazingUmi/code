%% 参数设置
clc; clear; close all;

fs = 52734;         % 采样率 (Hz)
T = 1;             % 信号持续时间 (秒)
N = fs * T;        % 原始信号采样点数

% 信道参数：对于单频率（例如 50Hz），给出两条路径的参数（其他频率可以类似）
% 这里假设仅对 50Hz 下的信道参数有效
K = 10;
delay = rand(1,K);  % 单位秒
amp   = rand(1,K);
phase = zeros(1,K);

% 为了时域对齐，将延迟归零，即减去所有延迟的最小值
delay_shift = delay - min(delay);

% 目标时域输出长度：信号长度 + 最大延迟（归零后） + 余量
tgtlength = ceil((T + max(delay_shift) + 0.1)*fs);

%% 原始信号生成
% 仅使用 50 Hz 正弦信号
t = (0:N-1)/fs;
signal = 1*cos(2*pi*5000*t);

%% 【频域方法】构造完整信道频率响应（方式一：对称频率向量）
% 设 M 为零填充后的长度
M = tgtlength;

% 构造对称频率向量 f_vec
if mod(M,2) == 0
    f_vec = (-M/2:M/2-1)*(fs/M);
else
    f_vec = (-(M-1)/2:(M-1)/2)*(fs/M);
end

% 构造 H_tmp（中心化频谱），只针对 50 Hz 分量赋值
H_tmp = zeros(1,M);
for i = 1:length(delay)
    % 这里构造的频率响应覆盖全频带，但其实非目标频率处贡献为相位旋转
    H_tmp = H_tmp + amp(i)*exp(1j*phase(i)) .* exp(-1j*2*pi * f_vec * delay_shift(i));
end

% 将中心化频谱转换为 MATLAB 标准顺序
H_complete = ifftshift(H_tmp);

% 验证共轭对称（可选打印部分对比）
% 对于 k = 2...M/2, 理论要求 H_complete(M - k + 2) = conj(H_complete(k))
fprintf('验证共轭对称性（数值）：\n');
for k = 2:ceil(M/2)
    diff_val = norm( H_complete(M - k + 2) - conj(H_complete(k)) );
    fprintf('k = %d, 差值 = %e\n', k, diff_val);
end

%% 频域处理
% 将原始信号零填充到长度 M 后 FFT
x_padded = [signal, zeros(1, M-N)];
X = fft(x_padded, M);

% 频域乘法
Y = X .* H_complete;

% IFFT 得到时域输出
y_freq = ifft(Y, M);
t_freq = (0:M-1)/fs;

%% 【直接时域方法】分路径延时叠加
% 对于 50Hz 分量，直接将信号按各路径延时和幅值叠加
tgtsig = zeros(1, M);
for i = 1:length(delay)
    offset = ceil(delay_shift(i)*fs);  % 延迟转换为样本数
    idx_start = offset + 1;
    idx_end = offset + N;
    if idx_end > M
        valid_len = M - offset;
        tgtsig(idx_start:M) = tgtsig(idx_start:M) + amp(i)* signal(1:valid_len);
    else
        tgtsig(idx_start:idx_end) = tgtsig(idx_start:idx_end) + amp(i)* signal;
    end
end
y_direct = tgtsig;
t_direct = (0:M-1)/fs;

%% 绘图对比
figure;
subplot(3,1,1);
plot(t, signal, 'b','LineWidth',1.5);
xlabel('时间 (s)'); ylabel('幅值');
title('原始信号 (50 Hz)');

subplot(3,1,2);
plot(t_freq, real(y_freq), 'r','LineWidth',1.5);
xlabel('时间 (s)'); ylabel('幅值');
title('频域方法输出（利用对称频率向量构造 H\_complete）');

subplot(3,1,3);
plot(t_direct, y_direct, 'k','LineWidth',1.5);
xlabel('时间 (s)'); ylabel('幅值');
title('直接时域方法输出（延时叠加）');

%% 误差分析（比较一段区间内两种方法的输出）
compare_length = ceil((T + max(delay_shift))*fs);
err = norm(y_direct(1:compare_length) - real(y_freq(1:compare_length))) / norm(y_direct(1:compare_length));
fprintf('频域方法与直接时域方法输出的相对误差：%e\n', err);
