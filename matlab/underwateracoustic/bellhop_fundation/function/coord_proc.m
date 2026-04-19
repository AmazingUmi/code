%% 对输入的坐标、距离和方位信息进行相互转换和补充
% coordS: 起点坐标
% coordE: 终点坐标
% R: 起点到终点的距离
% azi: 起点到终点的方位角（正北为0°，顺时针增大）
function [coordS, coordE, R, azi] = coord_proc(coordS, coordE, R, azi)

% 输入起点和终点坐标，计算距离和方位
if ~isempty(coordE)
    x = (coordE.lon - coordS.lon) * (111 * cosd(coordS.lat));
    y = (coordE.lat - coordS.lat) * 111;
    R = hypot(x, y);
    azi = mod(atan2d(x, y), 360);

% 输入起点、距离和方位，计算终点
elseif ~isempty(R) && ~isempty(azi)
    coordE.lon = coordS.lon + R * sind(azi) / (111 * cosd(coordS.lat));
    coordE.lat = coordS.lat + R * cosd(azi) / 111;
end
