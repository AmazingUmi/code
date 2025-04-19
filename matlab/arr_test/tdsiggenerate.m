function [y_time, M] = tdsiggenerate(freq, T, fs, amp0, phase0, delay, amp, phase)
% tdsiggenerate  通过时域叠加生成多径衰落信号（先用复信号，最终输出其实部）
%
% 输入参数：
%   freq    - 原信号频率 (Hz)
%   T       - 原信号持续时间 (秒)
%   fs      - 采样率 (Hz)
%   amp0    - 原信号幅度标量
%   phase0  - 原信号初相位 (弧度)
%   delay   - 各径时延向量 (秒)，长度 P
%   amp     - 各径幅值向量，长度 P
%   phase   - 各径附加相位向量 (弧度)，长度 P
%
% 输出参数：
%   y_time  - 叠加后取实部的多径信号 (行向量)，长度 M
%   M       - 输出信号采样点数
%
    % 1. 构造时间向量
    N = round(T * fs);              % 原信号点数
    t = (0:N-1) / fs;               % 时间轴

    % 2. 生成复值基带信号
    s = amp0 * exp(1j*(2*pi*freq*t + phase0));  

    % 3. 时延归零
    delay_shift = delay - min(delay);

    % 4. 计算输出长度：原长 + 最大时延 + 10ms 余量
    M = ceil((T + max(delay_shift) + 0.01) * fs);

    % 5. 叠加各径（复数累加）
    y_complex = complex(zeros(1, M));
    offsets = floor(delay_shift * fs) + 1;  % 各径起始索引
    
    for i = 1 : length(amp)
        % 每条径的复信号 = 基带 * 路径衰减 * 路径附加相位
        sp = amp(i) * s * exp(1j * phase(i));
        idx = offsets(i) : (offsets(i) + N - 1);
        y_complex(idx) = y_complex(idx) + sp;
    end

    % 6. 最终输出其实部
    % y_time = real(y_complex);
    y_time = y_complex;
end
