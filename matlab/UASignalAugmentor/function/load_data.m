function [ETOPO, WOA23] = load_data(OceanDataPath, ETOPOName, WOAName)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% LOAD_DATA 加载海洋环境数据（地形和声速剖面）
%   加载ETOPO地形数据和WOA23温盐深数据集，用于海洋声学环境建模
%
% 输入参数:
%   OceanDataPath - 海洋数据文件夹路径（字符串）
%   ETOPOName - ETOPO地形数据文件名（字符串）
%   WOAName - WOA23数据文件名格式（包含 %d 占位符，如 'woa23_%02d.mat'）
%
% 输出参数:
%   ETOPO - ETOPO地形数据结构体
%       包含海底地形的经纬度和深度信息
%   WOA23 - WOA23声速剖面数据结构体
%       .Lat - 纬度数据
%       .Lon - 经度数据
%       .Data - 元胞数组(1x17)，包含温盐深数据
%           索引1-12: 各月数据
%           索引13-16: 季平均数据（冬-春-夏-秋）
%           索引17: 全年平均数据
%           每个元胞包含: .Depth（深度）, .Sal（盐度）, .Temp（温度）
%
% 功能说明:
%   1. 读取WOA23全年数据文件获取经纬度信息
%   2. 按照索引映射读取17个WOA23数据文件：
%      - 文件名01-12对应月数据，索引1-12
%      - 文件名13-16对应季数据，索引13-16
%      - 文件名00对应年数据，索引17
%   3. 加载ETOPO地形数据文件
%   4. 返回完整的海洋环境数据结构
%
% 数据索引说明:
%   提取前文件名: 01-12(月), 13-16(季), 00(年)
%   提取后索引: 1-12(月), 13-16(季), 17(年)
%
% 示例:
%   [ETOPO, WOA23] = load_data('G:\database\OceanData', 'etopo_2022.mat', 'woa23_%02d.mat');
%
% 作者: [猫猫头]
% 日期: [2025-12-03]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 读取经纬度信息（全年数据）
WOA23.Lat = load(fullfile(OceanDataPath, sprintf(WOAName, 0)), 'Lat');
WOA23.Lon = load(fullfile(OceanDataPath, sprintf(WOAName, 0)), 'Lon');

% 定义文件名索引映射
file_ids = [1:12, 13:16, 0];  % MATLAB索引1-17对应文件名01-12,13-16,00
% 读取温盐深信息（全年数据）
WOA23.Data = cell(1,17);
for it = 1:17
    filename = sprintf('woa23_%02d.mat', file_ids(it));
    WOA23.Data{it} = load(fullfile(OceanDataPath, filename), 'Depth', 'Sal', 'Temp');
end

% 加载地形数据
ETOPO = load(fullfile(OceanDataPath, ETOPOName));
end
