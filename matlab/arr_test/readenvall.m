%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('E:\Umicode\matlab\underwateracoustic\bellhop_fundation\function');
clear pathstr;clear tmp;clear index;
%% 设置env文件相关参数
ENVall_folder = 'E:\Database\Enhanced_shipsEar';%需要修正
contents = dir(ENVall_folder);
ENVall_subfolders = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
clear contents;
txtfilename = 'env_files_list.txt';
%% 读取arr结果、筛选并保存
for j = 1:length(ENVall_subfolders)
    newfilename = cellstr(readlines(fullfile(ENVall_folder,ENVall_subfolders(j).name,'envfilefolder',txtfilename)));
    newfilename(end) = [];
    ARR = [];
    for i = 1:length(newfilename)
        %中间变量初始化
        amp0 = [];
        idx = [];
        delay0 = [];
        phase0 = [];
        [ Arr, Pos ] = read_arrivals_asc([fullfile(ENVall_folder,ENVall_subfolders(j).name,'envfilefolder\'),newfilename{i},'.arr']);
        [delay0, idx] = sort(abs(Arr.delay));
        amp0 = abs(Arr.A(idx));
        phase0 = atan((imag(Arr.A(idx))./real(Arr.A(idx))));

        %需要设置门限，把过小幅值的声线过滤掉
        threshold = 0.1;
        delay0(amp0<=threshold*max(amp0)) = [];
        phase0(amp0<=threshold*max(amp0)) = [];
        amp0(amp0<=threshold*max(amp0)) = [];  %要保证在最后一行

        ARR(i).Amp= amp0;            %记录幅值
        ARR(i).Delay = delay0;       %记录时延
        ARR(i).phase = phase0;       %记录相位
        ARR(i).freq = Pos.freq;      %记录频率
    end
    save(fullfile(ENVall_folder,ENVall_subfolders(j).name,'ENV_ARR.mat'), 'ARR')
end
