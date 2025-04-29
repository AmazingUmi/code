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
% 原始音频地址
wav_folder_path = 'G:\database\shipsEar\shipsEar_classified\origin_raw';
% 输出的图片地址
Pic_out_folder = 'G:\database\shipsEar\shipsEar_classified\group1\picture';
% 类别
subfolders = {'Class A','Class B','Class C','Class D','Class E'};
%% 特征图生成

for j = 1:length(subfolders)
    item_foldername = fullfile(wav_folder_path,subfolders{j});
    contents = dir(item_foldername);
    item_Sig_info = contents(~[contents.isdir]);
    clear contents;
    Pic_out_folder_class = fullfile(Pic_out_folder,subfolders{j});
    if ~exist(Pic_out_folder_class, 'dir')
        mkdir(Pic_out_folder_class); % 创建图片输出文件夹
    end

    for i = 1:length(item_Sig_info)
        Sig_name = fullfile(item_foldername,item_Sig_info(i).name);
        [signal, fs] = audioread(Sig_name);
        segments = processSignal(fs, signal, 'none', 'full');
        disp('meow');

        for seg = 1:length(segments(:,fs))
            s = segments(seg,:)';

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

            filename = sprintf('sig%d_class%d_pic%d.png', i, j, seg);
            pic_filename = fullfile(Pic_out_folder_class, filename);
            imwrite(three_channel_img, pic_filename, 'Compression', 'none');
        end
    end
end

