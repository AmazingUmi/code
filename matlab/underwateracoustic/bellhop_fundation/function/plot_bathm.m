%% 给定起点和终点坐标，画地形图
% Input:
%   ETOPO: ETOPO数据库
%   coordS: 起点坐标
%   corrdE: 终点坐标
% Output：
%   depth: 各经纬度对应的海深
function bathm = plot_bathm(ETOPO, coordS, coordE, R, azi)
[coordS, coordE, R, azi] = coord_proc(coordS, coordE, R, azi);
N = max(ceil(R), 2);
lat = linspace(coordS.lat, coordE.lat, N);
lon = linspace(coordS.lon, coordE.lon, N);
bathm.r = linspace(0,R,N);
[LON, LAT] = meshgrid(ETOPO.Lon, ETOPO.Lat);
bathm.d = - interp2(LON, LAT, ETOPO.Altitude',lon,lat);
figure;
plot(bathm.r, bathm.d, 'k', 'LineWidth',1.5);
set(gca,'YDir','reverse');
xlim([bathm.r(1),bathm.r(end)]);
ylim([0,max(bathm.d)]);
xlabel('距离 (km)')
ylabel('深度 (m)')