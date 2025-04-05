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
ENVall_folder = 'G:\database\Enhanced_shipsEar0405';
ENV_classes = {'Shallow', 'Transition', 'Deep'};
Signal_folder_path = 'G:\database\shipsEar\Shipsear_signal_folder';
load([Signal_folder_path,'\Analy_freq_all.mat']);

%创建文件夹
for i = 1:length(ENV_classes)
    ENV_class_path = fullfile(ENVall_folder,ENV_classes{i});
    contents = dir(ENV_class_path);
    ENV_single_foldernames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
    for j = 1:length(ENV_single_foldernames)
        ENV_single_folder = fullfile(ENV_class_path,ENV_single_foldernames(j).name);
        contents = dir(ENV_single_folder);
        ENV_Rr_foldernames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
        clear contents;
        for k = 1:length(ENV_Rr_foldernames)
            ENV_Rr_folder = fullfile(ENV_single_folder,ENV_Rr_foldernames(k).name,'envfilefolder');
            if ~exist(ENV_Rr_folder, 'dir')
                mkdir(ENV_Rr_folder); % 创建文件夹
                fprintf('文件夹"%s"已创建。\n', ENV_Rr_folder);
            else
                fprintf('文件夹"%s"已存在。\n', ENV_Rr_folder);
            end
            cd(ENV_Rr_folder)
            fileList = dir('ENV*');
            envfilename = [fileList(1).name(1:end-4),'.env'];
            newfilename = {};

            %改成parfor
            parfor m = 1:length(Analy_freq_all)
                newfilename{m} = sprintf('test_%d', m);
                %修改循环中，环境文件里的频率
                fileContents = fileread(envfilename);
                lines = strsplit(fileContents, '\n');
                newline = sprintf('  %d  	 	 	 ! Frequency (Hz) ',Analy_freq_all(m));
                lines{2} = newline;
                newContents = strjoin(lines, '\n');
                fid = fopen([newfilename{m},'.env'], 'w');
                fprintf(fid, '%s', newContents);
                fclose(fid);
                copyfile([envfilename(1:end-4),'.trc'], [newfilename{m},'.trc']);
                copyfile([envfilename(1:end-4),'.bty'], [newfilename{m},'.bty']);
                copyfile([envfilename(1:end-4),'.brc'], [newfilename{m},'.brc']);
            end

            fileID = fopen('env_files_list.txt', 'w');
            for m = 1:length(Analy_freq_all)
                fprintf(fileID, '%s\n', newfilename{m});
            end
            fclose(fileID);
        end
    end
end
%% 文件打包，方便传输
% 使用 tar + gzip 压缩
cd(ENVall_folder);
cd ..
tic
zipname = ['ENVall_files_', datestr(now, 'yyyymmdd')];
systemline = sprintf('tar -czf %s.tar.gz %s',zipname,'Enhanced_shipsEar0405');
system(systemline);
toc

%/public/home/amazingumi/temp/code/bellhop_parallel /public/home/amazingumi/temp/ENV1/envfilefolder
% [ Arr, Pos ] = read_arrivals_asc([newfilename{i},'.arr']);