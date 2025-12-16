function [y_time, M] = SigGenerateTD(freq, T, fs, amp0, phase0, delay, amp, phase)
% SigGenerateTD  通过时域叠加生成多径衰落信号
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
%   y_time  - 叠加后的多径信号 (复数行向量)，长度 M
%   M       - 输出信号采样点数
%
    % 1. 构造源信号
    N = round(T * fs);              % 原信号点数
    t = (0:N-1) / fs;               % 时间轴

    % 生成复值基带信号 (合并源幅度与相位)
    s = (amp0 * exp(1j * phase0)) * exp(1j * 2 * pi * freq * t);

    % 2. 路径参数预处理
    % 确保列向量以进行向量化计算
    delay = delay(:);
    amp   = amp(:);
    phase = phase(:);

    if isempty(delay)
        % 异常处理：无路径时返回全零
        M = ceil((T + 0.01) * fs);
        y_time = complex(zeros(1, M));
        return;
    end

    % 时延归零与量化
    delay_shift = delay - min(delay);
    offsets = floor(delay_shift * fs) + 1;
    
    % 计算各径复系数
    path_gains = amp .* exp(1j * phase);
    
    % 3. 计算输出长度并初始化
    % 原逻辑：原长 + 最大时延 + 10ms 余量
    M = ceil((T + max(delay_shift) + 0.01) * fs);
    y_time = complex(zeros(1, M));
    
    % 4. 叠加信号
    for i = 1 : length(offsets)
        start_idx = offsets(i);
        
        % 利用 MATLAB 空数组特性，无需 if len > 0 判断
        idx = start_idx : start_idx + N - 1;
        y_time(idx) = y_time(idx) + path_gains(i) * s(1:N);
    end
end
