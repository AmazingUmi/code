%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr(1:end-9),'underwateracoustic\bellhop_fundation\function'));
clear pathstr tmp index;

%% 设置音频路径
wav_subfolders = {'Class A','Class B','Class C','Class D','Class E'};
wav_folder_total = 'D:\database\shipsEar\shipsEar_reclassified';
wav_folder{1} = 'train_raw_wav';%训练集
wav_folder{2} = 'val_raw_wav';%验证集
%环境噪声似乎不应该进行这样的扩展,'Class E'
NewSig_foldername = 'D:\database\shipsEar\NewSig_foldername_direct_0317';
% 检查目标文件夹是否存在，如果不存在则创建
if ~exist(NewSig_foldername, 'dir')
    mkdir(NewSig_foldername);
end

%% 记录不同的音频共同的频率
tic
for m = 1:2
    for j = 1:length(wav_subfolders)   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % 获取当前子文件夹路径
        subfolder_path = fullfile(wav_folder_total,wav_folder{m}, wav_subfolders{j});
        % 获取子文件夹中的所有音频文件
        audio_files = dir(fullfile(subfolder_path, '*.wav'));

        for k = 1:length(audio_files)
            filename = fullfile(subfolder_path,audio_files(k).name);
            [signal, fs] = audioread(filename);%读取实际信号、采样频率
            dt = 1/fs;
            L = length(signal); %信号长度
            T = L/fs;
            t = (0:L-1)*dt; % 信号时间

            num_path = 15;
            amp = rand(1,num_path);
            delay = 5*rand(1,num_path);


            tgsig_lth = ceil(max(delay)-min(delay) +T)*fs;
            tgt = (0:tgsig_lth-1)/fs; %目标信号时间序列
            tgsig = zeros(1,tgsig_lth);
            for i = 1:num_path
                midsig = zeros(1,tgsig_lth);
                startidx = floor((delay(i)-min(delay))*fs)+1;
                midsig(startidx:startidx+L-1) = amp(i)*signal;
                tgsig = tgsig + midsig;
            end
            tgsig = tgsig/max(abs(tgsig));
            %保存信号信息
            NewSig_class_name = string(fullfile(NewSig_foldername,wav_folder{m},wav_subfolders(j)));
            if ~exist(NewSig_class_name, 'dir')
                mkdir(NewSig_class_name);
            end
            NewSig_name = string(fullfile(NewSig_foldername,wav_folder{m},wav_subfolders(j),[audio_files(k).name(1:end-4),'_new1.wav']));
            audiowrite(NewSig_name,tgsig,fs)
           
        end
    end
end

toc