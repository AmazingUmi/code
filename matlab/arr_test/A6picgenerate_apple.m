%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '/') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath([pathstr,'/function']);
addpath(fullfile(pathstr(1:end-9),'underwateracoustic/bellhop_fundation/function'));
clear pathstr tmp index;
%% 设置环境路径
ENVall_folder = '/Volumes/192.168.7.8/database/Enhanced_combined0425';
ENV_classes = {'Shallow', 'Transition', 'Deep'};
fs = 52734;
%%
for i = 1:length(ENV_classes)
    ENV_class_path = fullfile(ENVall_folder,ENV_classes{i});
    contents = dir(ENV_class_path);
    ENV_single_foldernames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
    clear contents;
    for j = 1:length(ENV_single_foldernames)
        ENV_single_folder = fullfile(ENV_class_path,ENV_single_foldernames(j).name);
        contents = dir(ENV_single_folder);
        ENV_Rr_foldernames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
        clear contents;
        for k = 1:length(ENV_Rr_foldernames)
            ENV_Rr_folder = fullfile(ENV_single_folder,ENV_Rr_foldernames(k).name);
            NewSig_folder = fullfile(ENV_Rr_folder,'NewSig');
            Pic_out_folder = fullfile(ENV_Rr_folder,'Pic_out');
            NewSig_mat_files = dir(fullfile(NewSig_folder, '*.mat'));

            if ~exist(Pic_out_folder, 'dir')
                mkdir(Pic_out_folder); % 创建文件夹
            end
            % 定义要创建的子文件夹名称
            subdirs = {'A','B','C','D','E'};
            % 循环创建每个子文件夹
            for sub = 1:numel(subdirs)
                subdirPath = fullfile(Pic_out_folder, subdirs{sub});
                if ~exist(subdirPath, 'dir')
                    mkdir(subdirPath);
                end
            end
            for sig = 1:length(NewSig_mat_files)
                sig_mat = load(fullfile(NewSig_folder,NewSig_mat_files(sig).name));
                if any(sig_mat.tgsig(:))
                    % 将原始信号分段，并进行预处理
                    segments = processSignal(fs, sig_mat.tgsig);
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
                        filename = sprintf('EC%d_ENV%d_Rr%d_sig%d_pic%d.png', i, j, k, sig, seg);
                        pic_filename = fullfile(Pic_out_folder, NewSig_mat_files(sig).name(7), filename);
                        imwrite(three_channel_img, pic_filename, 'Compression', 'none');
                    end
                    % obr =1;
                end
            end
        end
    end
end