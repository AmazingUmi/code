function [coordS, coordE, R, azi] = coord_proc(coordS, coordE, R, azi)
% 对输入的坐标、距离和方位信息进行相互转换和补充
% coordS: 起点坐标
% coordE: 终点坐标
% R: 起点到终点的距离
% azi: 起点到终点的方位角（正北为0°，顺时针增大）

% 输入起点和终点坐标，计算距离和方位
if ~isempty(coordE)
    x = (coordE.lon - coordS.lon) * (111 * cos(coordS.lat/180*pi));
    y = (coordE.lat - coordS.lat) * 111;
    R = sqrt(x*x + y*y);
    if y > 0
        azi = atan(x / y);
    elseif y == 0
        azi = sign(x) * pi / 2;
    else
        azi = atan(x / y) + pi;
    end

% 输入起点、距离和方位，计算终点
elseif ~isempty(R) && ~isempty(azi)
    R = max(R);
    azi = azi / 180 *pi;
    coordE.lon = coordS.lon + R * sin(azi) / (111 * cos(coordS.lat/180*pi));
    coordE.lat = coordS.lat + R * cos(azi) / 111;
end
