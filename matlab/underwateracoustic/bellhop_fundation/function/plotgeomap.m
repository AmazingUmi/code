function plotgeomap(lat, lon)
% 绘制数据集地形图
% lab

%% Load ETOP Data
ETOPO = load('etopo1.mat');  % 加载数据集经纬度范围和对应地形数据     
Lon = ETOPO.Lon;      
Lat = ETOPO.Lat;
Depth = ETOPO.Altitude;     
[yy, xx] = meshgrid(Lat,Lon);

idx_x = Lon>=lon(1) & Lon<=lon(end);    % 选择指定区域的经纬度索引
idx_y = Lat>=lat(1) & Lat<=lat(end);
d = Depth(idx_x, idx_y);        % 选出指定区域的海深数据


%% Plot
figure;
mesh(Lon(idx_x), Lat(idx_y), d');
xlabel('Longitude (°E)'); ylabel("Latitude (°N)");
zmax = max(d(:));
zmin = min(d(:));
if zmax > 0 && zmin < 0
    N1 = 1000;      
    N2 = round(N1*abs(zmax/zmin));  % 水上颜色分配网格数
    cmap = [linspace(0,0.1,N1);linspace(0,0.6,N1);linspace(0.5046,0.8,N1)]; % 水下颜色分配
    colormap(cat(1,(cmap'), (summer(N2))));     % 统一深度网格间距分配水上和水下颜色
    %c = colorbar;
    %c.Label.String = "Sea Depth (m)"
end
colorbar;
%% Plot
figure;
imagesc(Lon(idx_x), Lat(idx_y), d');
axis xy; axis equal;
xlabel('Longitude (°E)'); ylabel("Latitude (°N)");

zmax = max(d(:));
zmin = min(d(:));
if zmax > 0 && zmin < 0
    N1 = 1000;      
    N2 = round(N1*abs(zmax/zmin));  % 水上颜色分配网格数
    cmap = [linspace(0,0.1,N1);linspace(0,0.6,N1);linspace(0.5046,0.8,N1)]; % 水下颜色分配
    colormap(cat(1,(cmap'), (summer(N2))));     % 统一深度网格间距分配水上和水下颜色
    %c = colorbar;
    %c.Label.String = "Sea Depth (m)"
end
colorbar;
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

