function depth = get_bathm(ETOPO, lat, lon)
%% 插值得到指定经纬度直线或网格上的海深数据
% Input:
%   ETOPO: ETOPO数据库
%   lat: 纬度向量   
%   lon: 经度向量
%   默认lat和lon大小和方向都相同，即插值得到一条直线上的数据
%   要想插值得到一个区域网格上的数据，建议用meshgrid生成lon和lat,或者lat,lon一个列向量和一个行向量
% Output：
%   depth: 各经纬度对应的海深
[LON, LAT] = meshgrid(ETOPO.Lon, ETOPO.Lat);
depth = - interp2(LON, LAT, ETOPO.Altitude',lon,lat);   % 插值得到指定经纬度点或网格上的海深

