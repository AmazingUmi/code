%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('D:\code\matlab\underwateracoustic\bellhop_fundation\function');
clear pathstr;clear tmp;clear index;
%% 读取原始时域信号（此处暂时用生成的信号替代）
filename = 'D:\database\shipsEar\shipsEar_classified_renamed_reclasified\A_Workvessels\1.wav';
[signal, fs] = audioread(filename);%读取实际信号、采样频率
dt = 1/fs;
L = length(signal); %信号长度
T = L/fs;
t = (0:L-1)*dt; % 信号时间
%% 切分信号
N = 10; %分段段数
for i = 1:N
    % Nt(i,:) = (i-1)/N*T:dt:i/N*T-dt;
    Nsignal(i,:) = signal((i-1)/N*L+1:i/N*L);
    Ndelay(i) = (i-1)/N*T;
end

%分别对分段信号进行分解，获取其主要频率分量
Analy_freq = [];
for i = 1:N
    mid_signal = Nsignal(i,:);
    signal_f = fft(mid_signal);  %此信号包含相位信息
    signal_f_2 = signal_f(1:L/2/N+1);
    signal_f_3 = 2*1/L*N*abs(signal_f_2); %信号幅值
    signal_f_3_phi = atan(imag(signal_f_2)./real(signal_f_2));
    % signal_f(end+1) = signal_f(1);  %补充至频谱左右对称
    % signal_f_2 = 2*1/L*N*fftshift(abs(signal_f));
    % signal_f_3 = signal_f_2(L/2/N:end);
    f = (0:T*fs/2/N);
    % figure
    % plot(f,signal_f_3);%绘制频谱图
    [sig_peaks, sig_locs] = findpeaks(signal_f_3, 'SortStr', 'descend');  % 找到峰值
    %过滤掉较小的幅值
    sig_locs(sig_peaks<=0.5*sig_peaks(1)) = [];
    sig_peaks(sig_peaks<=0.5*sig_peaks(1)) = [];
    sig_freq = f(sig_locs);    % 主要频率 (取前两个为例)
    sig_amplitude = sig_peaks; % 对应的幅值
    sig_phase = signal_f_3_phi(sig_locs);
    Analyrecord(i).Amp = sig_amplitude; %每段信号各自的幅值
    Analyrecord(i).freq = sig_freq;
    Analyrecord(i).phase = sig_phase;
    Analy_freq = unique([Analy_freq,sig_freq]);%记录所有信号总的频率数
end

% imf = emd(signal);

%% 对所需频率计算.arr文件,此部分为所有分段的信号共用的频率,因此涉及到调度问题
% 读取到达结构文件，过滤掉幅值较小的波形

envfilename = 'test.env';
H = zeros(1, length(Analy_freq));
parfor i = 1:length(Analy_freq)
    %中间变量初始化
    amp0 = [];
    idx = [];
    delay0 = [];
    newfilename = sprintf('test_%d', i);
    %修改循环中，环境文件里的频率
    fileContents = fileread(envfilename);
    lines = strsplit(fileContents, '\n');
    newline = sprintf('  %d  	 	 	 ! Frequency (Hz) ',Analy_freq(i));
    lines{2} = newline;
    newContents = strjoin(lines, '\n');
    fid = fopen([newfilename,'.env'], 'w');
    fprintf(fid, '%s', newContents);
    fclose(fid);

    copyfile([envfilename(1:end-4),'.trc'], [newfilename,'.trc']);
    copyfile([envfilename(1:end-4),'.bty'], [newfilename,'.bty']);
    copyfile([envfilename(1:end-4),'.brc'], [newfilename,'.brc']);

    %运行bellhop，计算得到到达结构文件
    bellhop(newfilename);
    [ Arr, Pos ] = read_arrivals_asc([newfilename,'.arr']);
    %需要设置门限，把过小幅值的声线过滤掉
    [delay0, idx] = sort(abs(Arr.delay));
    amp0 = abs(Arr.A(idx));
    delay0(amp0<=0.01*max(amp0)) = [];
    amp0(amp0<=0.01*max(amp0)) = [];
    ARR(i).Amp= amp0;            %记录幅值
    ARR(i).Delay = delay0;       %记录时延
    ARR(i).freq = Analy_freq(i); %记录频率
    delete([newfilename, '.*']);
end
%%
for i = 1:length(Analy_freq)
    maxdelay(i) = max(ARR(i).Delay);     %记录最大时延
    mindelay(i) = min(ARR(i).Delay);     %记录最小时延
end
%问题在于信号时间过长，应该切割掉部分空白值
tgsig_lth = (max(maxdelay)-min(mindelay))*fs + length(t) + 1; %目标信号长度,最长时延-最短时延+原始信号长度+空白
tgt = (0:tgsig_lth-1)*dt; %目标信号时间序列
tgsig = 0*tgt; %目标信号初始化

for i = 1:N
    tar_freq = Analyrecord(i).freq;
    tar_amp = Analyrecord(i).Amp;
    tar_pha = Analyrecord(i).phase;
    [~, tar_f_loc] = ismember(tar_freq, Analy_freq);
    mid_t = (0:L/N-1)*dt;  %中间信号时间序列

    for k = 1:length(tar_freq)
        %生成中间信号
        mid_signal = tar_amp(k)*sin(2*pi*tar_freq(k)*mid_t+tar_pha(k));
        %对中间信号进行时延幅值拓展
        for j = 1:length(ARR(tar_f_loc(k)).Amp)
            delay0 = ARR(tar_f_loc(k)).Delay;
            amp0 = ARR(tar_f_loc(k)).Amp;
            dsig = tgt*0;  %临时中间变量
            be = floor((delay0(j)-min(mindelay)+Ndelay(i))*fs)+1; %确定信号初始位置
            en = be+length(t)/N-1; %确定信号结束位置
            dsig(be:en) = mid_signal;
            tgsig = tgsig+dsig*amp0(j);
        end
    end
end
plot(tgt,tgsig)