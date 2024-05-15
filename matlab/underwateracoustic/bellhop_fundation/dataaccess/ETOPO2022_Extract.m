% clear;
LAT = [5, 15];
LON = [130, 150];

dirname = '.\DATA\';

LAT_N = (15*(floor(LAT(1)/15)+1)):15:(15*ceil(LAT(2)/15));
LON_N = (15*floor(LON(1)/15)):15:(15*(ceil(LON(2)/15)-1));

Lat1 = zeros(length(LAT_N)*3600, 1);
Lon1 = zeros(length(LON_N)*3600, 1);
Z = zeros(length(LON_N)*3600, length(LAT_N)*3600);
for i_lat = 1:length(LAT_N)
    for i_lon = 1:length(LON_N)
        if LAT_N(i_lat) >= 0
            lat_str = sprintf('N%02d', LAT_N(i_lat));
        else
            lat_str = sprintf('S%02d', abs(LAT_N(i_lat)));
        end
        if LON_N(i_lon) >= 0
            lon_str = sprintf('E%03d', LON_N(i_lon));
        else
            lon_str = sprintf('W%03d', abs(LON_N(i_lon)));
        end
        
        filename = sprintf('ETOPO_2022_v1_15s_%s%s_surface.nc', lat_str, lon_str);
        lat = ncread([dirname, filename], 'lat');
        lon = ncread([dirname, filename], 'lon');
        z = ncread([dirname, filename], 'z');
        
        if i_lat == 1
            Lon1((i_lon-1)*3600+1:i_lon*3600) = lon;
        end
        Z((i_lon-1)*3600+1:i_lon*3600, (i_lat-1)*3600+1:i_lat*3600) = z;
    end
    Lat1((i_lat-1)*3600+1:i_lat*3600) = lat;
end

idx_x = Lon1>=LON(1) & Lon1<=LON(end);
idx_y = Lat1>=LAT(1) & Lat1<=LAT(end);
Lon = Lon1(idx_x);
Lat = Lat1(idx_y);
Altitude = Z(idx_x, idx_y);
Dimension = "Lon × Lat";
save('etopo2022_A.mat', 'Lon', 'Lat', 'Altitude', 'Dimension');

%plotmap;

%% ETOPO 2022: Ice surface elevation, 60 Arc-Second Resolution
LAT = [70, 85];
LON = [-180, -90];

Lat1 = ncread('ETOPO_2022_v1_60s_N90W180_surface.nc','lat');
Lon1 = ncread('ETOPO_2022_v1_60s_N90W180_surface.nc','lon');
Lon2 = [Lon1(length(Lon1)/2+1:end); Lon1(1:length(Lon1)/2)+360 ];
Z1 = ncread('ETOPO_2022_v1_60s_N90W180_surface.nc','z');
Z2 = [Z1(length(Lon1)/2+1:end,:); Z1(1:length(Lon1)/2,:)];
idx_x = Lon1>=LON(1) & Lon1<=LON(end);
idx_y = Lat1>=LAT(1) & Lat1<=LAT(end);
Lon = Lon1(idx_x);
Lat = Lat1(idx_y);
Altitude = Z1(idx_x, idx_y);
Dimension = "Lon × Lat";
save('etopo2022_BJ.mat', 'Lon', 'Lat', 'Altitude', 'Dimension');
