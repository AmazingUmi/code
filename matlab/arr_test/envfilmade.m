%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('E:\Umicode\matlab\underwateracoustic\bellhop_fundation\function');
clear pathstr;clear tmp;clear index;

%% 设置环境路径
ENVall_folder = 'E:\Database\Enhanced_shipsEar';
Signal_folder = 'E:\Database\shipsEar\Shipsear_signal_folder';
load([Signal_folder,'\Analy_freq_all.mat']);

% 获取文件夹中的所有内容，筛选出所有子文件夹
contents = dir(ENVall_folder);
ENVall_subfolders = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
clear contents;

%创建文件夹
for j = 1:length(ENVall_subfolders)
    ENV_foldername = fullfile(ENVall_folder,ENVall_subfolders(j).name,'envfilefolder');
    if ~exist(ENV_foldername, 'dir')
        mkdir(ENV_foldername); % 创建文件夹
        fprintf('文件夹"%s"已创建。\n', ENV_foldername);
    else
        fprintf('文件夹"%s"已存在。\n', ENV_foldername);
    end
    cd(ENV_foldername)
end

%生成新的环境文件
for j = 1%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    ENV_foldername = fullfile(ENVall_folder,ENVall_subfolders(j).name,'envfilefolder');
    cd(ENV_foldername)

    newfilename = {};
    envfilename = 'test.env';
    for i = 1:length(Analy_freq_all)
        newfilename{i} = sprintf('test_%d', i);
        %修改循环中，环境文件里的频率
        fileContents = fileread(envfilename);
        lines = strsplit(fileContents, '\n');
        newline = sprintf('  %d  	 	 	 ! Frequency (Hz) ',Analy_freq_all(i));
        lines{2} = newline;
        newContents = strjoin(lines, '\n');
        fid = fopen([newfilename{i},'.env'], 'w');
        fprintf(fid, '%s', newContents);
        fclose(fid);
        copyfile([envfilename(1:end-4),'.trc'], [newfilename{i},'.trc']);
        copyfile([envfilename(1:end-4),'.bty'], [newfilename{i},'.bty']);
        copyfile([envfilename(1:end-4),'.brc'], [newfilename{i},'.brc']);
    end

    fileID = fopen('env_files_list.txt', 'w');
    for i = 1:length(Analy_freq_all)
        fprintf(fileID, '%s\n', newfilename{i});
    end
    fclose(fileID);

end
%%
% 使用 tar + gzip 压缩
cd(ENVall_folder);
cd ..
zipname = 'files';
systemline = sprintf('tar -czf %s.tar.gz %s',zipname,'Enhanced_shipsEar');
system(systemline);


% [ Arr, Pos ] = read_arrivals_asc([newfilename{i},'.arr']);