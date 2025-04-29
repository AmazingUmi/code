%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath([pathstr,'\function']);
addpath(fullfile(pathstr(1:end-9),'underwateracoustic\bellhop_fundation\function'));
clear pathstr tmp index;

%% 1. 基本配置
ENVall_folder = 'G:\database\Enhanced_combined0425';
ENV_classes   = {'Deep'};%{'Shallow','Transition','Deep'};
subdirs       = {'A','B','C','D','E'};

% 目标根目录
dstRoot = 'G:\database\MergedDataset_single_env\Deep';

% 清空或创建目标子集+类别目录
subsets = {'train','val','test'};
for t = 1:numel(subsets)
    for s = 1:numel(subdirs)
        dirpath = fullfile(dstRoot, subsets{t}, subdirs{s});
        if exist(dirpath,'dir'), rmdir(dirpath,'s'); end
        mkdir(dirpath);
    end
end

%% 2. 收集每个子集的 ENV 组根文件夹
trainFolders = {};
valFolders   = {};
testFolders  = {};

for i = 1:numel(ENV_classes)
    classPath = fullfile(ENVall_folder, ENV_classes{i});
    
    % 找到该类下所有 ENV_xxx 文件夹（按名字自然排序，1~6 组）
    D = dir(classPath);
    D = D([D.isdir] & ~ismember({D.name},{'.','..'}));
    [~,idx] = sort({D.name});  % 保证顺序
    D = D(idx);
    
    % 前4 组 -> train，第5组 -> val，第6组 -> test
    for j = 1:4
        trainFolders{end+1} = fullfile(classPath, D(j).name);
    end
    valFolders{end+1}  = fullfile(classPath, D(5).name);
    testFolders{end+1} = fullfile(classPath, D(6).name);
end

%% 3. 执行拷贝
copyByCategory(trainFolders, 'train', subdirs, dstRoot);
copyByCategory(valFolders,   'val',   subdirs, dstRoot);
copyByCategory(testFolders,  'test',  subdirs, dstRoot);


