%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('D:\code\matlab\underwateracoustic\bellhop_fundation\function');
clear pathstr;clear tmp;clear index;
%% 读取原始时域信号
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
    [sig_peaks, sig_locs] = sort(signal_f_3, 'descend');  % 找到峰值
    %过滤掉较小的幅值
    sig_locs(sig_peaks<=0.01*sig_peaks(1)) = [];
    sig_peaks(sig_peaks<=0.01*sig_peaks(1)) = [];
    sig_freq = f(sig_locs);    % 主要频率 (取前两个为例)
    sig_amplitude = sig_peaks; % 对应的幅值
    sig_phase = signal_f_3_phi(sig_locs);
    Analyrecord(i).Amp = sig_amplitude; %每段信号各自的幅值
    Analyrecord(i).freq = sig_freq;
    Analyrecord(i).phase = sig_phase;
    Analy_freq = unique([Analy_freq,sig_freq]);%记录所有信号总的频率数
end
%% 对所需频率计算.arr文件,此部分为所
% 有分段的信号共用的频率,因此涉及到调度问题
% 读取到达结构文件，过滤掉幅值较小的波形
enviromentname = 'sig1\env1'
envfilename = 'test.env';
tempfolder = ['D:\temp\paper\',enviromentname];
% 检查文件夹是否存在
if ~exist(tempfolder, 'dir')
    mkdir(tempfolder); % 创建文件夹
    fprintf('文件夹"%s"已创建。\n', tempfolder);
else
    fprintf('文件夹"%s"已存在。\n', tempfolder);
end
cd(tempfolder);
save('Signal_info.mat', 'fs', 't','L','T','dt','Ndelay','Analyrecord', 'Analy_freq')
%% 
newfilename = {};
for i = 1:length(Analy_freq)
    newfilename{i} = sprintf('test_%d', i);
    %修改循环中，环境文件里的频率
    fileContents = fileread(envfilename);
    lines = strsplit(fileContents, '\n');
    newline = sprintf('  %d  	 	 	 ! Frequency (Hz) ',Analy_freq(i));
    lines{2} = newline;
    newContents = strjoin(lines, '\n');
    fid = fopen([newfilename{i},'.env'], 'w');
    fprintf(fid, '%s', newContents);
    fclose(fid);
    copyfile([envfilename(1:end-4),'.trc'], [newfilename{i},'.trc']);
    copyfile([envfilename(1:end-4),'.bty'], [newfilename{i},'.bty']);
    copyfile([envfilename(1:end-4),'.brc'], [newfilename{i},'.brc']);
end

fileID = fopen('env_files_list.txt', 'w');
for i = 1:length(Analy_freq)
    fprintf(fileID, '%s\n', newfilename{i});
end
fclose(fileID);
%% 
% 使用 tar + gzip 压缩
cd ..
zipname = 'files'
systemline = sprintf('tar -czf %s.tar.gz %s',zipname,tempfolder(end-3:end))
system(systemline);


% [ Arr, Pos ] = read_arrivals_asc([newfilename{i},'.arr']);