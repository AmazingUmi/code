function plotgeomap(lat, lon, ETOPO)
% 绘制数据集地形图
% lab

%% 输入兼容：允许不传ETOPO时从默认文件加载
if nargin < 3 || isempty(ETOPO)
    ETOPO = load('etopo1.mat');
end

%% 提取经纬度范围
Lon = ETOPO.Lon;
Lat = ETOPO.Lat;
Depth = ETOPO.Altitude;

idx_x = Lon>=lon(1) & Lon<=lon(end);    % 选择指定区域的经纬度索引
idx_y = Lat>=lat(1) & Lat<=lat(end);
d = Depth(idx_x, idx_y);        % 选出指定区域的海深数据


%% 颜色映射（海面/陆地与海底同时存在时使用分段colormap）
zmax = max(d(:));
zmin = min(d(:));
useSplitCmap = (zmax > 0) && (zmin < 0);
if useSplitCmap
    N1 = 1000;
    N2 = max(1, round(N1 * abs(zmax / zmin))); % 水上颜色分配网格数（避免0）
    cmapSea = [linspace(0,0.1,N1); linspace(0,0.6,N1); linspace(0.5046,0.8,N1)]; % 水下颜色分配
    cmap = cat(1, cmapSea', summer(N2));
else
    cmap = parula(256);
end

%% Plot
figure;
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
mesh(Lon(idx_x), Lat(idx_y), d');
xlabel('Longitude (°E)'); ylabel("Latitude (°N)");
colormap(gca, cmap); colorbar;
title('Bathymetry (3D)');

nexttile;
imagesc(Lon(idx_x), Lat(idx_y), d');
axis xy; axis equal;
xlabel('Longitude (°E)'); ylabel("Latitude (°N)");
colormap(gca, cmap); colorbar;
title('Bathymetry (2D)');
hold on;


% h1 = plot(lon_n, lat_n, 'r-x', 'LineWidth', 1.5);
% h2 = plot(lon_f, lat_f, 'm-o', 'LineWidth', 1.5);
% axis tight


% R = [];
% azi = [];
% coordS.lat = lat_n(1);
% coordS.lon = lon_n(1);
% coordE.lat = lat_n(2);
% coordE.lon = lon_n(2);
% bathm = plot_bathm(ETOPO, coordS, coordE, R, azi);

% coordS.lat = lat_f(1);
% coordS.lon = lon_f(1);
% coordE.lat = lat_f(2);
% coordE.lon = lon_f(2);
% bathm = plot_bathm(ETOPO, coordS, coordE, R, azi);

end

