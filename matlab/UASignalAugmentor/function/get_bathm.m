function depth = get_bathm(ETOPO, lon, lat)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GET_BATHM 从ETOPO数据库插值获取海深数据
%   根据指定经纬度坐标，通过二维插值获取对应位置的海深值
%
% 输入参数:
%   ETOPO - ETOPO地形数据结构体
%       .Lon - 经度向量
%       .Lat - 纬度向量
%       .Altitude - 高程矩阵 (Lon × Lat)
%   lon - 目标经度（标量、向量或矩阵）
%   lat - 目标纬度（标量、向量或矩阵）
%       注: lon和lat维度需保持一致
%
% 输出参数:
%   depth - 对应经纬度的海深值（米），正值表示水深
%
% 使用说明:
%   - 直线插值: lon和lat为相同长度的向量
%   - 网格插值: 使用meshgrid生成lon和lat矩阵
%
% 示例:
%   % 单点查询
%   depth = get_bathm(ETOPO, 115.5, 20.3);
%   % 直线查询
%   depth = get_bathm(ETOPO, [115, 116, 117], [20, 20.5, 21]);
%   % 网格查询
%   [lon_grid, lat_grid] = meshgrid(115:0.1:117, 20:0.1:22);
%   depth = get_bathm(ETOPO, lon_grid, lat_grid);
%
% 作者: [猫猫头]
% 日期: [2025-12-03]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 生成插值网格 (Lat × Lon)
[LON, LAT] = meshgrid(ETOPO.Lon, ETOPO.Lat);

% 二维插值 (ETOPO.Altitude转置以匹配meshgrid维度: Lon×Lat → Lat×Lon)
% 负号将高程转换为海深 (负高程 = 正海深)
depth = - interp2(LON, LAT, ETOPO.Altitude', lon, lat);

