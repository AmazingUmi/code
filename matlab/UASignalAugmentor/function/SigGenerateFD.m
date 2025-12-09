function [y_freq, M] = SigGenerateFD(signal, fs, delay, amp, phase)
% multipathExpansion 模拟多径传播，将原始信号扩展为经过多径衰落后的信号
%
% 输入参数：
%   signal - 原始输入信号（行向量或列向量）
%   fs     - 采样率（Hz）
%   delay  - 各路径时延（单位秒），例如 [0.001, 0.003, ...]
%   amp    - 各路径幅值，数组长度应与 delay 相同
%   phase  - 各路径相位（单位：弧度），数组长度应与 delay 相同
%
% 输出参数：
%   y_freq   - 采用频域处理得到的扩展信号
%   M        - 扩展信号对应的信号点数
    % 原信号采样点数和持续时间
    N = length(signal);      % 原始信号采样点数
    T = N / fs;              % 原始信号持续时间（秒）
    % 为了时域对齐，将所有路径的延迟归零（即减去最小延迟）
    delay_shift = delay - min(delay);
    % 目标时域输出长度：原始信号长度 + 最大延迟（归零后） + 0.1秒余量
    M = ceil((T + max(delay_shift) + 0.01) * fs);
    % 构造对称频率向量 f_vec
    if mod(M, 2) == 0
        f_vec = (-M/2:(M/2-1)) * (fs / M);
    else
        f_vec = (-(M-1)/2:(M-1)/2) * (fs / M);
    end
    % 构造多径信道的频率响应 H_tmp
    H_tmp = zeros(1, M);
    for i = 1:length(delay)
        % 各路径贡献：幅值 * exp(1j*相位) * exp(-1j*2*pi*f*延迟)
        H_tmp = H_tmp + amp(i) * exp(1j*phase(i)) * exp(-1j * 2 * pi * f_vec * delay_shift(i));
    end
    % 将中心化频谱转换为 MATLAB 标准顺序
    H_complete = ifftshift(H_tmp);
    % 对原信号零填充到长度 M 后进行 FFT
    x_padded = [signal, zeros(1, M - N)];
    X = fft(x_padded, M);
    % 频域乘法后进行 IFFT 得到时域输出
    Y = X .* H_complete;
    y_freq = real(ifft(Y, M));
end
