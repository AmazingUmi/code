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
%未切分音频地址
val_folder_path = 'D:\database\shipsEar\shipsEar_reclassified\val_raw_wav';
train_folder_path = 'D:\database\shipsEar\shipsEar_reclassified\train_raw_wav';
%输出的图片地址
val_Pic_out_folder = 'D:\database\shipsEar\shipsEar_reclassified\val_origin_pic';
train_Pic_out_folder = 'D:\database\shipsEar\shipsEar_reclassified\train_origin_pic';

contents = dir(val_folder_path);
subfolders = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
clear contents;

%% 纯mel谱图！！！！！！！！！！！！！！！！！！！！！！！！！！！！
tic
for j = 1:length(subfolders)
    item_foldername = fullfile(val_folder_path,subfolders(j).name);
    contents = dir(item_foldername);
    item_Sig_info = contents(~[contents.isdir]);
    clear contents;
    Pic_out_folder = fullfile(val_Pic_out_folder,subfolders(j).name);
    if ~exist(Pic_out_folder, 'dir')
        mkdir(Pic_out_folder); % 创建图片输出文件夹
    end

    % :length(NewSig_info)
    num_pic = 0;
    for i = 1:length(item_Sig_info)
        Sig_name = fullfile(item_foldername,item_Sig_info(i).name);
        [signal, fs] = audioread(Sig_name);
        signal = signal';
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
            num_pic = num_pic + 1;
            s = segments(k,:)';
            h=figure;
            melSpectrogram(s, fs,"NumBands",98);       % 绘制梅尔频谱图。
            axis off;    colorbar off;   colormap gray;
            set(gcf,'Position',[500 1000 98 98]);      set(gca,'Position',[0 0 1 1]);
            I = getimage(gcf);          %Convert plot to image (true color RGB matrix).
            I1=flipud(mat2gray(I));
            J = imresize(I1, [98, 98]); %Resize image to resolution
            filename1=fullfile(Pic_out_folder,sprintf('%s.png',num2str(num_pic)));
            imwrite(J, filename1, 'Compression','none');         %Save image to file
            close(h);
        end
    end
end
toc
%% 多特征谱图！！！！！！！！！！！！！！！！！！！！！！！！！！！！
