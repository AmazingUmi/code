function [Temp, Sal, Depth] = get_profile_filled(WOA18, lat, lon, timeIdx)
%% 提取给定坐标和时间的温盐深数据。
% 因1~12月份的剖面达到的深度为1500米，季度或全年平均的剖面深度为5500米。
% 在提取1~12月份的剖面时，1500米以上深度用全年的剖面数据填充。
% WOA18:  声速剖面数据集
% lat:  指定区域维度向量
% lon:  指定区域经度向量 Nlon=Nlat
% Temp: Ndepth*Nlon  温度剖面
% Sal:  Ndepth*Nlon  盐度剖面

% 数据集经纬度
Lat = WOA18.Lat;
Lon = WOA18.Lon;

if timeIdx <= 12     
    % WOA18.Data{17} 是全年平均数据
    TEMP = WOA18.Data{17}.Temp;
    SAL = WOA18.Data{17}.Sal;
    Depth = WOA18.Data{17}.Depth;
    Nd = length(WOA18.Data{timeIdx}.Depth);     % 第timeIdx月声速剖面数据的深度个数
    TEMP(:,:,1:Nd) = WOA18.Data{timeIdx}.Temp(:,:,:);
    SAL(:,:,1:Nd) = WOA18.Data{timeIdx}.Sal(:,:,:);
else
    TEMP = WOA18.Data{timeIdx}.Temp;
    SAL = WOA18.Data{timeIdx}.Sal;
    Depth = WOA18.Data{timeIdx}.Depth;
end

% 对每个深度，在经纬度二维平面内进行插值，以获取各经纬度的数据。
Nd = length(Depth);
% Sal = zeros(Nd, length(lon), length(lat));
% Temp = zeros(Nd, length(lon), length(lat));
Sal = zeros(Nd, length(lon));
Temp = zeros(Nd, length(lon));
[LON,LAT] = meshgrid(Lon,Lat);  % 数据集网格
% [lon, lat] = meshgrid(lon, lat);
% 插值得到指定经纬度站点上的温盐剖面
for id = 1:Nd
    Temp(id,:,:) = interp2(LON,LAT,TEMP(:,:,id)',lon,lat);   % Temp: (Ndepth*Nlon)
    Sal(id,:,:) = interp2(LON,LAT,SAL(:,:,id)',lon,lat);
end

