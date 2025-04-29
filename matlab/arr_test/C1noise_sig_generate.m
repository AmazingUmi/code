%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath([pathstr,'\function']);
addpath(fullfile(pathstr(1:end-9),'underwateracoustic\bellhop_fundation\function'));
clear pathstr tmp index;

%% 设置输入输出路径
% 原始音频地址
wav_folder_path = 'G:\database\shipsEar\shipsEar_classified\origin_raw';
% 输出的含噪声音频地址
Noisy_out_folder = 'G:\database\shipsEar\shipsEar_classified\group1\noisy_audio';
% 类别
subfolders = {'Class A','Class B','Class C','Class D','Class E'};
% 信噪比
SNR_dB = [15, 10, 5, 0, -5];

% 按信噪比创建子文件夹
for k = 1:length(SNR_dB)
    snr_folder = fullfile(Noisy_out_folder, sprintf('SNR_%d', SNR_dB(k)));
    if ~exist(snr_folder, 'dir')
        mkdir(snr_folder);
    end
end

%% 含噪声信号生成
for j = 1:length(subfolders)
    item_foldername = fullfile(wav_folder_path, subfolders{j});
    contents = dir(item_foldername);
    item_Sig_info = contents(~[contents.isdir]);
    clear contents;
    
    % 在每个SNR文件夹中创建类别子文件夹
    for k = 1:length(SNR_dB)
        snr_folder = fullfile(Noisy_out_folder, sprintf('SNR_%d', SNR_dB(k)));
        class_folder = fullfile(snr_folder, subfolders{j});
        if ~exist(class_folder, 'dir')
            mkdir(class_folder);
        end
    end
    
    for i = 1:length(item_Sig_info)
        % 读取原始信号
        Sig_name = fullfile(item_foldername, item_Sig_info(i).name);
        [~, filename0, ~] = fileparts(item_Sig_info(i).name);
        [signal, fs] = audioread(Sig_name);
        % 为每个信噪比生成含噪声信号
        for k = 1:length(SNR_dB)         
            % 使用 add_awgn 函数添加噪声
            noisy_signal = add_awgn(signal, SNR_dB(k));
            % 保存含噪声音频文件
            snr_folder = fullfile(Noisy_out_folder, sprintf('SNR_%d', SNR_dB(k)));
            class_folder = fullfile(snr_folder, subfolders{j});
            noisy_filepath = fullfile(class_folder, [filename0, '_SNR_', num2str(SNR_dB(k)), '.wav']);
            audiowrite(noisy_filepath, noisy_signal, fs);
        end
    end
end

fprintf('所有文件处理完成！\n');

