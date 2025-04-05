%% 对输入的坐标、距离和方位信息进行相互转换和补充
% coordS: 起点坐标
% coordE: 终点坐标
% R: 起点到终点的距离
% azi: 起点到终点的方位角（正北为0°，顺时针增大）
function [coordE_lat, coordE_lon, azi] = coord_proc_new(coordS, R, azi)

for i = 1:length(R)
    azi = azi / 180 *pi;
    coordE_lon(i) = coordS.lon + R(i) * sin(azi) / (111 * cos(coordS.lat/180*pi));
    coordE_lat(i) = coordS.lat + R(i) * cos(azi) / 111;
end
