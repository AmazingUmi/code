%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('E:\Umicode\matlab\underwateracoustic\bellhop_fundation\function');
clear pathstr;clear tmp;clear index;
%%
ENVall_folder = 'E:\Database\Enhanced_shipsEar';%需要修正

contents = dir(ENVall_folder);
ENVall_subfolders = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
clear contents;

% :length(ENVall_subfolders)
sig_part = 1;

for j = 1
    NewSig_foldername = fullfile(ENVall_folder,ENVall_subfolders(j).name,'Newsig');
    contents = dir(NewSig_foldername);
    NewSig_info = contents(~[contents.isdir]);
    clear contents;
    % :length(NewSig_info)
    for i = 1
        NewSig_name = fullfile(NewSig_foldername,NewSig_info(i).name);
        load(NewSig_name)  %读取fs,tgt,tgsig
        T = length(tgt)/fs;
        %初始化
        segments = [];
        segment_length = 1 * fs;
        overlap_length = 0.5 * segment_length;
        start_idx = 1;
        % 分割信号
        while start_idx + segment_length - 1 <= length(tgsig)
            segment = tgsig(start_idx:start_idx + segment_length - 1);
            segments = [segments; segment];
            start_idx = start_idx + overlap_length;
        end
        % 处理剩余不足 1 秒的部分
        if start_idx < length(tgsig)
            remaining_part = tgsig(start_idx:end);
            if length(remaining_part) < segment_length
                start_idx = start_idx - (segment_length - length(remaining_part));  % 向前滑动，保证剩余部分补充至 1 秒
                segment = tgsig(start_idx:start_idx + segment_length - 1);  % 重新获取 1 秒长的片段
                segments = [segments; segment];  % 将补充后的片段作为最后一个片段
            end
        end
        disp('meow');
        for k = 1:length(segments(:,fs))
            s = segments(k,:)';
            h=figure;
            melSpectrogram(s, fs);       % 绘制梅尔频谱图。
            axis off;    colorbar off;   colormap gray;
            set(gcf,'Position',[500 1000 32 98]);      set(gca,'Position',[0 0 1 1]);
            I = getimage(gcf);          %Convert plot to image (true color RGB matrix).
            I1=mat2gray(I);
            J = imresize(I1, [32, 98]); %Resize image to resolution
            n=num2str(j);
            filename1=fullfile('E:\Umicode\matlab\arr_test\out',sprintf('%s.png',num2str(k)));
            imwrite(J, filename1, 'Compression','none');         %Save image to file
            close(h);
        end
    end
end

