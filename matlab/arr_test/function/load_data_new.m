function [ETOPO, WOA23] = load_data_new(etop_dir, woa23_dir)
% 加载地形数据与WOA23数据集声速剖面数据
% ETOPO: 地形数据
% WOA23: 声速剖面数据
% 提取前数据索引说明: 1-12每月, 13-16季平均, 00全年
% 提取后数据索引说明: 1-12每月, 13-16季平均（冬-春-夏-秋）, 17全年

% 读取经纬度信息（全年数据）
A = load(fullfile(woa23_dir, 'woa23_00.mat'), 'Lat', 'Lon');
WOA23.Lat = A.Lat;
WOA23.Lon = A.Lon;

% 定义文件名索引映射
file_ids = [1:12, 13:16, 0];  % MATLAB索引1-17对应文件名01-12,13-16,00

WOA23.Data = cell(1,17);
for it = 1:17
    filename = sprintf('woa23_%02d.mat', file_ids(it));
    WOA23.Data{it} = load(fullfile(woa23_dir, filename), 'Depth', 'Sal', 'Temp');
end

% 加载地形数据
ETOPO = load(etop_dir);
