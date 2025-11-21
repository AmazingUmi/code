function [ETOPO, WOA23] = load_data(etop_dir, woa23_dir)
% 从数据集中加载地形数据和声速剖面数据
% ETOPO:    地形数据
% WOA18:    声速剖面数据
A = load([woa23_dir,'\woa23_00.mat'],'Lat');
WOA23.Lat = A.Lat;
A = load([woa23_dir,'\woa23_00.mat'],'Lon');
WOA23.Lon = A.Lon;
WOA23.Data = cell(1,17);
for it = 1:17
    WOA23.Data{it} = load(sprintf('%s\\woa23_%02d.mat', woa23_dir, it-1)...
        , 'Depth', 'Sal', 'Temp');
end

ETOPO = load(etop_dir);
