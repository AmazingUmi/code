function [fs, Ndelay, Analyrecord, Analy_freq] = wavfreq(audioname, FreqRange, cut_Tlength)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% WAVFREQ 音频信号频率分析函数
%   对音频信号进行分段处理，提取每段的频率成分、幅值和相位信息
%
% 输入参数:
%   audioname - 音频文件路径（字符串）
%   cut_Tlength - 信号分段时间长度（秒）
%
% 输出参数:
%   fs - 音频采样频率（Hz）
%   Ndelay - 各段信号的时间延迟数组（秒）
%   Analyrecord - 结构体数组，包含每段信号的频率分析结果
%       .Amp - 频率分量的幅值
%       .freq - 频率分量的频率值（Hz）
%       .phase - 频率分量的相位
%   Analy_freq - 所有信号段的频率集合（去重后）
%
% 功能说明:
%   1. 读取音频文件并获取采样频率
%   2. 根据指定时间长度将信号分段
%   3. 对每段信号进行FFT变换，提取频率成分
%   4. 滤除10Hz以下和5000Hz以上的频率分量
%   5. 按幅值降序排列频率分量
%   6. 返回每段信号的分析结果和全局频率集合
%
% 示例:
%   [fs, Ndelay, Analyrecord, Analy_freq] = wavfreq('ship_signal.wav', 1.0);
%
% 作者: [猫猫头]
% 日期: [2025-12-03]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 参数默认值设置
if nargin < 2 || isempty(cut_Tlength) || isempty(FreqRange)
    cut_Tlength = 1;
    FreqRange   = [10, 5000];

end

[signal, fs] = audioread(audioname);%读取实际信号、采样频率
L = length(signal); %信号长度
T = L/fs;

%切分信号,依据信号长度进行修正
N = floor(T/cut_Tlength);
Ndelay = [];
cut_length = cut_Tlength * fs;

%计算信号段延迟
for ii = 1:N
    Ndelay(ii) = (ii-1)*cut_Tlength;
end

%分别对分段信号进行分解，获取其主要频率分量
Analy_freq = [];
Analyrecord = [];
for i = 1:N
    mid_signal =  signal((i-1)*cut_length+1:i*cut_length);
    signal_f = fft(mid_signal);  %此信号包含相位信息
    signal_f_2 = signal_f(1:cut_length/2+1);
    signal_f_3 = abs(signal_f_2)/cut_length; %信号幅值
    signal_f_3(2:end-1) = 2*signal_f_3(2:end-1);
    signal_f_3_phi = angle(signal_f_2);
    f = (0:cut_length/2)/cut_length*fs;
    % figure
    % plot(f,signal_f_3);%绘制频谱图

    % 频率成分提取
    [sig_peaks, sig_locs] = sort(signal_f_3,'descend');
    sig_freq = f(sig_locs);
    sig_amplitude = sig_peaks;
    sig_phase = signal_f_3_phi(sig_locs);

    %滤除10Hz以下频率，以及fs/2以上的频率
    freq_idx = (sig_freq >= FreqRange(1)) & (sig_freq <= FreqRange(2));
    sig_amplitude = sig_amplitude(freq_idx);
    sig_freq = sig_freq(freq_idx);
    sig_phase = sig_phase(freq_idx);
    sig_freq = round(sig_freq,1);%防止出现重复频率

    Analyrecord(i).Amp = sig_amplitude; %每段信号各自的幅值
    Analyrecord(i).freq = sig_freq;
    Analyrecord(i).phase = sig_phase;
    Analy_freq = unique([Analy_freq,sig_freq]);%记录所有信号总的频率数
end
end