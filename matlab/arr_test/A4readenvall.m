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
contents = dir(ENVall_folder);
ENVall_subfolders = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
clear contents;
envfilename = 'envfilefolder';
txtfilename = 'env_files_list.txt';
ENVall_name = 'ENV_ARR.mat';
%%
for i = 1:length(ENV_classes)
    ENV_class_path = fullfile(ENVall_folder,ENV_classes{i});
    contents = dir(ENV_class_path);
    ENV_single_foldernames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
    if i == 1
        RDN = 3;
    else
        RDN = 4;
    end
    for j = 1:length(ENV_single_foldernames)
        ENV_single_folder = fullfile(ENV_class_path,ENV_single_foldernames(j).name);
        contents = dir(ENV_single_folder);
        ENV_Rr_foldernames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
        clear contents;
        for k = 1:length(ENV_Rr_foldernames)
            ENV_Rr_folder = fullfile(ENV_single_folder,ENV_Rr_foldernames(k).name);
            newfilename = cellstr(readlines(fullfile(ENV_Rr_folder,envfilename,txtfilename)));
            newfilename(end) = [];
            ARR = [];
            parfor m = 1:length(newfilename)
                %中间变量初始化
                amp0 = [];
                idx = [];
                delay0 = [];
                phase0 = [];
                [ Arr, Pos ] = read_arrivals_asc(fullfile(ENV_Rr_folder,envfilename,[newfilename{m},'.arr']));
                % ReceiveDepth = Pos.r.z;
                % RDN = length(ReceiveDepth);
                ReceiveRange = Pos.r.r/1000;
                freq = Pos.freq;
                if freq <= 5000
                    for n = 1:RDN
                        [delay0, idx] = sort(abs(Arr(n).delay));
                        amp0 = abs(Arr(n).A(idx));
                        phase0 = angle(Arr(n).A(idx));
                        %需要设置门限，把过小幅值的声线过滤掉
                        threshold = 0.05;
                        idx = amp0>=threshold*max(amp0);
                        delay0 = delay0(idx);
                        phase0 = phase0(idx);
                        amp0 = amp0(idx);

                        ARR(m,n).Amp= amp0;            %记录幅值
                        ARR(m,n).Delay = delay0;       %记录时延
                        ARR(m,n).phase = phase0;       %记录相位
                        ARR(m,n).freq = freq;      %记录频率
                    end
                end
            end
            save(fullfile(ENV_Rr_folder,'ENV_ARR_less.mat'), 'ARR');
            jsonStr = jsonencode(ARR);
            fid = fopen(fullfile(ENV_Rr_folder,'ENV_ARR_less.json'), 'w');
            if fid == -1
                error('无法打开文件进行写入！');
            end
            fwrite(fid, jsonStr, 'char');
            fclose(fid);
            disp('meow');
        end
    end
end