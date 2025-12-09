function [f,H] = ffft(signal)
fs = 48000;
len = length(signal);
signal_f = fft(signal);  %此信号包含相位信息
signal_f_2 = signal_f(1:len/2+1);
signal_f_3 = abs(signal_f_2)/len; %信号幅值
signal_f_3(2:end-1) = 2*signal_f_3(2:end-1);
H = signal_f_3;
f = (0:len/2)/len*fs;
end