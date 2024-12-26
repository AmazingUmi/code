%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('D:\code\matlab\underwateracoustic\bellhop_fundation\function');
clear pathstr;clear tmp;clear index;
%% 
tempfolder = 'D:\temp\paper\env1';
txtfilename = 'env_files_list.txt';
cd(tempfolder);

load('Signal_info.mat')
newfilename = cellstr(readlines(txtfilename));

%% 
parfor i = 1:length(Analy_freq)
    %中间变量初始化
    amp0 = [];
    idx = [];
    delay0 = [];
    [ Arr, Pos ] = read_arrivals_asc([newfilename{i},'.arr']);
    %需要设置门限，把过小幅值的声线过滤掉
    [delay0, idx] = sort(abs(Arr.delay));
    amp0 = abs(Arr.A(idx));
    delay0(amp0<=0.01*max(amp0)) = [];
    amp0(amp0<=0.01*max(amp0)) = [];
    ARR(i).Amp= amp0;            %记录幅值
    ARR(i).Delay = delay0;       %记录时延
    ARR(i).freq = Analy_freq(i); %记录频率
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
N = length(Analyrecord);
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