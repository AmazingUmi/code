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
ENVall_folder = 'D:\database\shipsEar\test2.26';%临时调试所用

Signal_folder = 'D:\database\shipsEar\Shipsear_signal_folder';
Pic_out_folder = 'D:\database\Enhanced_shipsEar\out';

contents = dir(ENVall_folder);
ENVall_subfolders = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
clear contents;

%% 绘制谱图
for j = 1% : length(ENVall_subfolders)
    NewSig_foldername = fullfile(ENVall_folder,ENVall_subfolders(j).name,'Newsig');
    contents = dir(NewSig_foldername);
    NewSig_info = contents(~[contents.isdir]);
    clear contents;
    
    for i = 1% : length(NewSig_info)
        NewSig_name = fullfile(NewSig_foldername,NewSig_info(i).name);
        Pic_out_folder_class = fullfile(Pic_out_folder,NewSig_info(i).name(21));%需要争取获取输出路径
        load(NewSig_name)  %读取fs,tgt,tgsig
        tgsig = tgsig./max(abs(tgsig));
        T = length(tgt)/fs;
        %初始化
        segments = [];
        segment_length = 1 * fs;
        overlap_length = 0.5 * segment_length;
        start_idx = 1;
        % 分割信号
        while start_idx + segment_length < length(tgsig)
            segment = tgsig(start_idx:start_idx + segment_length - 1);
            segments = [segments; segment];
            start_idx = start_idx + overlap_length;
        end
        
        disp('meow');
        for k = 1:length(segments(:,fs))
            s = segments(k,:)';
            h=figure;
            melSpectrogram(s, fs,"NumBands",98);       % 绘制梅尔频谱图。
            axis off;    colorbar off;   colormap gray;
            set(gcf,'Position',[500 1000 98 98]);      set(gca,'Position',[0 0 1 1]);
            I = getimage(gcf);          %Convert plot to image (true color RGB matrix).
            I1=flipud(mat2gray(I));
            J = imresize(I1, [98, 98]); %Resize image to resolution
            filename1=fullfile(Pic_out_folder_class,sprintf('%s.png',num2str(k)));
            imwrite(J, filename1, 'Compression','none');         %Save image to file
            close(h);
        end
    end
end
%% 
% % 假设以下变量已定义
% % segments: [num_segments, signal_length] 的矩阵
% % fs: 采样率
% % Pic_out_folder: 图像保存文件夹路径
% 
% % 定义 TF Entropy 的窗口大小
% windowSize = 5; % 可以根据需要调整
% 
% for k = 1:size(segments, 1)
%     % 获取第 k 个音频段，并确保其为 double 类型
%     s = double(segments(k, :)');
% 
%     % 检查 s 的类型
%     if ~isa(s, 'double')
%         disp(['k = ' num2str(k) ': 信号类型为 ' class(s)]);
%         s = cast(s, 'double');
%     end
% 
%     % 检查信号是否包含 NaN 或 Inf
%     if any(isnan(s)) || any(isinf(s))
%         disp(['k = ' num2str(k) ': 信号包含 NaN 或 Inf 值，跳过该段']);
%         continue; % 跳过当前循环，继续下一个
%     end
% 
%     h = figure('Visible','off');
% 
%     % 计算梅尔频谱图
%     melSpec = melSpectrogram(s, fs, "NumBands", 64);
%     melSpecImage = mat2gray(melSpec); % 归一化到 [0,1]
%     melSpecResized = imresize(melSpecImage, [64, 98]); % 调整大小
% 
%     % 计算 MFCC
%     coeffs = mfcc(s, fs, 'NumCoeffs', 32, 'LogEnergy', 'Ignore'); % 获取64个MFCC系数
%     mfccImage = mat2gray(coeffs'); % 转置后归一化
%     mfccResized = imresize(mfccImage, [64, 98]);
% 
%     % 计算 Time-Frequency Entropy 特征
%     try
%         tfEntropySpec = computeTimeFrequencyEntropy(melSpec, windowSize);
%     catch ME
%         disp(['TF Entropy 计算错误，k = ' num2str(k) ': ' ME.message]);
%         close(h);
%         continue; % 跳过当前循环，继续下一个
%     end
%     tfEntropyImage = mat2gray(tfEntropySpec);
%     tfEntropyResized = imresize(tfEntropyImage, [64, 98]);
% 
%     % 合并三个特征为 RGB 三通道
%     combinedImage = cat(3, melSpecResized, mfccResized, tfEntropyResized);
% 
%     % 显示并保存图像
%     imshow(combinedImage);
%     axis off; colorbar off; 
%     set(gcf, 'Position', [500 1000 64 98]); 
%     set(gca, 'Position', [0 0 1 1]);
% 
%     % 保存为 PNG 文件
%     filename = fullfile(Pic_out_folder, sprintf('%s.png', num2str(k)));
%     imwrite(combinedImage, filename, 'Compression', 'none');
% 
%     close(h);
% end
