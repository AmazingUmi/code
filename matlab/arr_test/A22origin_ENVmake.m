%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);addpath([pathstr '\function']);
addpath(fullfile(pathstr(1:end-9),'underwateracoustic\bellhop_fundation\function'));
clear pathstr tmp index;
% 加载环境数据
EnviromentsDATA_PATH  = 'G:\database\EnviromentsDATA';
etop_dir = [EnviromentsDATA_PATH,'\targetETOPO.mat'];
woa23_dir = [EnviromentsDATA_PATH,'\target_WOA23_mat'];
[ETOPO, WOA23] = load_data_new(etop_dir, woa23_dir);
clear etop_dir woa23_dir EnviromentsDATA_PATH;
%% 设置环境路径
ENVpack_PATH = 'G:\database\Enhanced_shipsEar0418trans';
sign = 1; %shallow sea = 1, Transition zone = 2, Deepsea = 3
% 目标点位参数
if sign == 1
    % Shallow Sea
    ENVall_folder = fullfile(ENVpack_PATH,'Shallow');
    lat = [19.50 7.10 23.30 11.00 9.50 20.20];
    lon = [107.00 117.80 118.20 121.00 107.50 112.00];
    ReceiveRange = [1, 5, 10];    % 接收距离
    ReceiveDepth = [10, 20, 30];
elseif sign ==2
    % Transition zone
    ENVall_folder = fullfile(ENVpack_PATH,'Transition');
    lat = [18.80 8.20 20.40 15.10 14.10 17.00];
    lon = [114.30 118.50 117.60 123.00 110.10 112.40];
    ReceiveRange = [5, 30, 60];
    ReceiveDepth = [25, 50, 100, 300];
else
    % Deep Sea
    ENVall_folder = fullfile(ENVpack_PATH,'Deep');
    lat = [17.80 21.90 13.90 6.00 18.00 11.90];
    lon = [117.90 122.50 116.20 123.00 124.00 113.00];
    ReceiveRange = [5, 30, 60];
    ReceiveDepth = [25, 50, 100, 300];
end
if ~exist(ENVall_folder, 'dir')
    mkdir(ENVall_folder); % 创建文件夹
    fprintf('文件夹"%s"已创建。\n', ENVall_folder);
end
SourceRange = 0;        % 声源距离
SourceDepth = 10;       % 声源深度
azi  = 0;               % 测线方向
%% 生成
k = 1;
for i = 1:length(lat)
    coordS.lon = lon(i);
    coordS.lat = lat(i);
    ENVall_subfolder = fullfile(ENVall_folder,['ENV',num2str(i)]);


    % 参数文件输出
    % 文件命名

    for j  = 1:length(ReceiveRange)
        Rr = ReceiveRange(j);
        ENVall_subfolder_Rr = fullfile(ENVall_subfolder,['Rr',num2str(j)],'envfilefolder');
        if ~exist(ENVall_subfolder_Rr, 'dir')
            mkdir(ENVall_subfolder_Rr); % 创建文件夹
        end
        cd(ENVall_subfolder_Rr)
        coordE = [];%最远接受点经纬度
        [coordS, coordE, ~, ~] = coord_proc(coordS, coordE, max(ReceiveRange), azi);
        envfil = ['ENV_',num2str(i),'_Rr',num2str(Rr),'Km'];
        call_Bellhop_surface_new(ETOPO, WOA23, envfil, coordS, coordE, ...
            SourceDepth, ReceiveDepth, SourceRange, Rr);
    end
end