%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr(1:end-9),'underwateracoustic\bellhop_fundation\function'));
clear pathstr tmp index;

%% 设置输入输出路径
%未切分音频地址
val_folder_path = 'G:\database\shipsEar\shipsEar_reclassified\val_raw_wav';
train_folder_path = 'G:\database\shipsEar\shipsEar_reclassified\train_raw_wav';
%输出的图片地址
val_Pic_out_folder = 'G:\database\shipsEar\shipsEar_reclassified\val_origin_pic';
train_Pic_out_folder = 'G:\database\shipsEar\shipsEar_reclassified\train_origin_pic';

contents = dir(train_folder_path);
subfolders = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
clear contents;

%% 纯mel谱图
tic
for j = 1:length(subfolders)
    item_foldername = fullfile(train_folder_path,subfolders(j).name);
    contents = dir(item_foldername);
    item_Sig_info = contents(~[contents.isdir]);
    clear contents;
    Pic_out_folder = fullfile(train_Pic_out_folder,subfolders(j).name);
    if ~exist(Pic_out_folder, 'dir')
        mkdir(Pic_out_folder); % 创建图片输出文件夹
    end

    % :length(NewSig_info)
    % num_pic = 0;
    for i = 1:length(item_Sig_info)
        Sig_name = fullfile(item_foldername,item_Sig_info(i).name);
        [signal, fs] = audioread(Sig_name);
        signal = signal';
        %预加重操作
        a = 0.95;  % 预加重系数
        signal = filter([1 -a], 1, signal);
        % 中心化操作
        signal = signal - mean(signal);
        % 归一化操作
        signal = signal/max(abs(signal));
        

        T = length(signal)/fs;
        %初始化
        segments = [];
        segment_length = 1 * fs;
        overlap_length = 0.5 * segment_length;
        start_idx = 1;
        % 分割信号
        while start_idx + segment_length - 1 <= length(signal)
            segment = signal(start_idx:start_idx + segment_length - 1);
            segments = [segments; segment];
            start_idx = start_idx + overlap_length;
        end
        % 处理剩余不足 1 秒的部分
        if start_idx < length(signal)
            remaining_part = signal(start_idx:end);
            if length(remaining_part) < segment_length
                start_idx = start_idx - (segment_length - length(remaining_part));  % 向前滑动，保证剩余部分补充至 1 秒
                segment = signal(start_idx:start_idx + segment_length - 1);  % 重新获取 1 秒长的片段
                segments = [segments; segment];  % 将补充后的片段作为最后一个片段
            end
        end
        disp('meow');

        for k = 1:length(segments(:,fs))
            s = segments(k,:)';
            % 计算 mel 频谱图
            [mel_spec,~,~] = melSpectrogram(s, fs, "NumBands", 98);
            % 对频谱图进行归一化并调整至 98×98 大小（单通道灰度图）
            mel_spec_dB = 10*log10(mel_spec + eps);
            % 2. 对转换后的数据进行归一化前先翻转（模拟 getimage 后 flipud(mat2gray(·)）的效果）
            mel_img = imresize(mat2gray(flipud(mel_spec_dB)), [98, 98]);
            % 构建保存图像的文件名，并保存图像（不进行压缩）
            filename1 = fullfile(Pic_out_folder, [item_Sig_info(i).name(1:end-4), sprintf('_pic%s.png', num2str(k))]);
            imwrite(mel_img, filename1, 'Compression','none');
        end
    end
end
toc
%% 多特征谱图！！！！！！！！！！！！！！！！！！！！！！！！！！！！
