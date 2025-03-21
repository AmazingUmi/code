%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr(1:end-9),'underwateracoustic\bellhop_fundation\function'));
clear pathstr tmp index;

%% 设置环境路径
ENVall_folder = 'D:\database\Enhanced_shipsEar';
Signal_folder_path = 'D:\database\shipsEar\Shipsear_signal_folder';
load([Signal_folder_path,'\Analy_freq_all.mat']);

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
%% 生成新的环境文件
tic
for j = 1%:length(ENVall_subfolders)
    ENV_foldername = fullfile(ENVall_folder,ENVall_subfolders(j).name,'envfilefolder');
    cd(ENV_foldername)
    fileList = dir('TEST_s*');
    envfilename = [fileList(1).name(1:end-4),'.env'];
    newfilename = {};
    
    %改成parfor
    parfor i = 1:length(Analy_freq_all)
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
toc
%% 文件打包，方便传输
% 使用 tar + gzip 压缩
cd(ENVall_folder);
% cd ..
tic
zipname = ['ENVall_files_', datestr(now, 'yyyymmdd')];
systemline = sprintf('tar -czf %s.tar.gz %s',zipname,'ENV1');
system(systemline);
toc

%/public/home/amazingumi/temp/code/bellhop_parallel /public/home/amazingumi/temp/ENV1/envfilefolder
% [ Arr, Pos ] = read_arrivals_asc([newfilename{i},'.arr']);