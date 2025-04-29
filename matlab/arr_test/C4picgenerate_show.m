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
all_folder_path = 'G:\database\shipsEar\shipsEar_classified\origin_raw';
val_folder_path = 'G:\database\shipsEar\shipsEar_reclassified\val_raw_wav';
train_folder_path = 'G:\database\shipsEar\shipsEar_reclassified\train_raw_wav';
%输出的图片地址
all_Pic_out_folder = 'G:\database\shipsEar\shipsEar_classified\origin_pic_rgb';
val_Pic_out_folder = 'G:\database\shipsEar\shipsEar_reclassified\val_origin_pic_rgb';
train_Pic_out_folder = 'G:\database\shipsEar\shipsEar_reclassified\train_origin_pic_rgb';

contents = dir(all_folder_path);
subfolders = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
clear contents;

%% 绘图
tic
for j = 1:length(subfolders)
    item_foldername = fullfile(all_folder_path,subfolders(j).name);
    contents = dir(item_foldername);
    item_Sig_info = contents(~[contents.isdir]);
    Pic_out_folder = fullfile(all_Pic_out_folder,subfolders(j).name);
    if ~exist(Pic_out_folder, 'dir')
        mkdir(Pic_out_folder); % 创建图片输出文件夹
    end

    % :length(NewSig_info)
    num_pic = 0;
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

        parfor k = 1:length(segments(:,fs))
            s = segments(k,:)';
            
            % 1. 处理 mel 谱图
            [mel_spec,~,~] = melSpectrogram(s, fs, "NumBands", 98);
            % 转换为 dB（避免 log(0) 用 eps）
            mel_spec_dB = 10 * log10(mel_spec + eps);
            % 上下翻转、归一化，并调整到 98×98
            mel_img = imresize(mat2gray(flipud(mel_spec_dB)), [98, 98]);

            % 2. 处理 CQT 谱图
            fmin = 10;
            fmax = fs / 2;
            numOctaves = log2(fmax / fmin);
            binsPerOctave = round(98 / numOctaves);
            cqtObj = cqt(s, 'SamplingFrequency', fs, 'BinsPerOctave', binsPerOctave, 'FrequencyLimits', [fmin, fmax]);
            cfs_full = abs(cqtObj.c);
            % 保留单边谱（上半部分）
            cfs_oneSided = cfs_full(1:ceil(size(cfs_full,1)/2), :);
            % 转换为 dB，并进行翻转、归一化及尺寸调整
            cqt_spec_dB = 10 * log10(cfs_oneSided + eps);
            cqt_img = imresize(mat2gray(flipud(cqt_spec_dB)), [98, 98]);

            % 3. 处理 Bark 谱图
            window = hamming(256);
            noverlap = round(0.5 * length(window));
            nfft = 512;
            [S, F, T] = spectrogram(s, window, noverlap, nfft, fs);
            % 将频率映射到 Bark 标度
            barkF = 13 * atan(0.00076 * F) + 3.5 * atan((F / 7500).^2);
            numBands = 98;
            edges = linspace(min(barkF), max(barkF), numBands+1);
            barkSpec = zeros(numBands, length(T));
            for m = 1:numBands
                idx = barkF >= edges(m) & barkF < edges(m+1);
                if any(idx)
                    % 这里对能量求和（也可以改为求均值）
                    barkSpec(m, :) = sum(abs(S(idx, :)), 1);
                end
            end
            % 转换为 dB，翻转、归一化及尺寸调整
            bark_spec_dB = 10 * log10(barkSpec + eps);
            bark_img = imresize(mat2gray(flipud(bark_spec_dB)), [98, 98]);

            % 4. 拼接三个通道生成 RGB 图像
            three_channel_img = cat(3, mel_img, cqt_img, bark_img);
            filename1 = fullfile(Pic_out_folder, [item_Sig_info(i).name(1:end-4), sprintf('_pic%s.png', num2str(k))]);
            imwrite(three_channel_img, filename1, 'Compression', 'none');
        end
    end
end
toc
%% 绘图展示
% figure;
% imagesc(cfs_final);
% axis xy;         % 保持坐标轴方向一致
% axis on;         % 显示坐标轴
% xlabel('Time frames');   % 时间轴标签
% ylabel('Frequency bins');% 频率轴标签
% colormap gray;   % 使用灰度图展示
% colorbar;        % 显示色条
% title('98x98 CQT 特征图');
% 
% 
% %% 5. 临时绘图展示各个通道以及组合后的图像
% figure;
% subplot(2,2,1);
% imagesc(mel_img);
% axis xy;
% xlabel('Time frames');
% ylabel('Mel bins');
% title('Mel Spectrogram');
% colorbar;
% 
% subplot(2,2,2);
% imagesc(cqt_img);
% axis xy;
% xlabel('Time frames');
% ylabel('Frequency bins');
% title('CQT (Single-sided)');
% colorbar;
% 
% subplot(2,2,3);
% imagesc(bark_img);
% axis xy;
% xlabel('Time frames');
% ylabel('Frequency bins');
% title('bark_img Spectrogram');
% colorbar;
% 
% subplot(2,2,4);
% imagesc(three_channel_img);
% axis xy;
% xlabel('Time frames');
% ylabel('Frequency bins');
% title('Combined 3-channel Image');
% colorbar;