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
ENVall_folder = 'G:\database\Enhanced_shipsEar';%临时调试所用
contents = dir(ENVall_folder);
ENVall_subfolders = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
clear contents;
%创建图片输出文件夹
for j = 1:length(ENVall_subfolders)
    NewSig_foldername = fullfile(ENVall_folder,ENVall_subfolders(j).name,'pic_out');
    if ~exist(NewSig_foldername, 'dir')
        mkdir(NewSig_foldername); % 创建文件夹
        fprintf('文件夹"%s"已创建。\n', NewSig_foldername);
    else
        fprintf('文件夹"%s"已存在。\n', NewSig_foldername);
    end
end
%% 绘制谱图
for j = 2:5% : length(ENVall_subfolders)
    NewSig_foldername = fullfile(ENVall_folder,ENVall_subfolders(j).name,'Newsig');
    Pic_out_folder = fullfile(ENVall_folder,ENVall_subfolders(j).name,'pic_out');
    contents = dir(NewSig_foldername);
    NewSig_info = contents(~[contents.isdir]);
    clear contents;

    for i = 1 : length(NewSig_info)
        NewSig_name = fullfile(NewSig_foldername,NewSig_info(i).name);
        if NewSig_info(i).name(1:3) == 'tra'
            Pic_out_folder_class = fullfile(Pic_out_folder,sprintf('Class %s',NewSig_info(i).name(21)));%需要争取获取输出路径
        else
            Pic_out_folder_class = fullfile(Pic_out_folder,sprintf('Class %s',NewSig_info(i).name(19)));%NewSig_info(i).name(1:3),
        end
        if ~exist(Pic_out_folder_class, 'dir')
            mkdir(Pic_out_folder_class); % 创建文件夹
        end
        load(NewSig_name)  %读取fs,tgt,tgsig
        tgsig = tgsig./max(abs(tgsig));
        %添加噪声
        snr_db = 5;
        % 添加高斯白噪声
        tgsig = add_awgn(tgsig, snr_db);
        signal = tgsig;
        clear tgsig;
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
            filename1 = fullfile(Pic_out_folder_class, [NewSig_info(i).name(1:end-4), sprintf('_pic%s.png', num2str(k))]);
            imwrite(three_channel_img, filename1, 'Compression', 'none');
        end
    end
end
