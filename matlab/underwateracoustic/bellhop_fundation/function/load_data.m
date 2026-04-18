function [ETOPO, WOA18] = load_data(etop_dir, woa18_dir)
% 从数据集中加载地形数据和声速剖面数据
% ETOPO:    地形数据
% WOA18:    声速剖面数据
if exist(etop_dir, 'file') ~= 2
    error('load_data:MissingETOPO', 'ETOPO文件不存在: %s', etop_dir);
end
if exist(woa18_dir, 'dir') ~= 7
    error('load_data:MissingWOA18Dir', 'WOA18目录不存在: %s', woa18_dir);
end

latlonFile = fullfile(woa18_dir, 'woa18_17.mat');
A = load(latlonFile, 'Lat', 'Lon');
WOA18.Lat = A.Lat;
WOA18.Lon = A.Lon;
WOA18.Data = cell(1,17);
for it = 1:17
    f = fullfile(woa18_dir, sprintf('woa18_%02d.mat', it));
    WOA18.Data{it} = load(f, 'Depth', 'Sal', 'Temp');
end

ETOPO = load(etop_dir);
