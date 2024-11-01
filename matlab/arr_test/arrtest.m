%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr); addpath([pathstr '\function']);
%% 读取到达结构文件，过滤掉幅值较小的波形
% 打开文件
filename = 'test.env';
d = 1; %频率间隔
freq = [200,500];
% freq = 200:1/d:500;
H = zeros(1, length(freq));
for i = 1:length(freq)
    %中间变量初始化
    amp0 = [];
    idx = [];
    delay0 = [];
    %修改循环中，环境文件里的频率
    fileContents = fileread(filename);
    lines = strsplit(fileContents, '\n');
    newline = sprintf('  %d  	 	 	 ! Frequency (Hz) ',freq(i));
    lines{2} = newline;
    newContents = strjoin(lines, '\n');
    fid = fopen(filename, 'w');
    fprintf(fid, '%s', newContents);
    fclose(fid);
    %运行bellhop，计算得到到达结构文件
    bellhop('test');
    [ Arr, Pos ] = read_arrivals_asc('test.arr');
    %需要设置门限，把过小幅值的声线过滤掉
    [delay0, idx] = sort(abs(Arr.delay));
    amp0 = abs(Arr.A(idx));
    delay0(amp0<=0.01*max(amp0)) = [];
    amp0(amp0<=0.01*max(amp0)) = [];
    ARR(i).Amp= amp0;
    ARR(i).Delay = delay0;
end
%% 测试，生成原始信号
fs = 10000; %采样频率
dt = 1/fs;
L = fs * 10; %信号截取长度
t = (0:L-1)*dt; % 时间向量，长度为 10 秒
signal = t*0;;
% 生成正弦波信号(随机生成，测试)
for i = 1:length(freq)
    dsignal = rand*sin(2*pi*freq(i)*t);
    signal = signal + dsignal;
    maxdelay(i) = max(ARR(i).Delay);
end


tgsig_lth = max(maxdelay)*fs + length(t); %目标信号长度
tgt = (0:tgsig_lth-1)*dt; %目标信号时间序列
tgsig = 0*tgt; %目标信号初始化
for k = 1:length(freq)
    
    for j = 1:length(ARR(k).Amp)
        dsig = tgt*0;  %临时中间变量
        be = floor(delay0(j)*fs); %确定信号初始位置
        en = be+length(t)-1; %确定信号结束位置
        dsig(be:en) = signal;
        tgsig = tgsig+dsig*ARR(k).Amp(j);
    end
end