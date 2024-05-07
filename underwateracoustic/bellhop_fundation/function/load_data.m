function [ETOPO, WOA18] = load_data(etop_dir, woa18_dir)
% 从数据集中加载地形数据和声速剖面数据
% ETOPO:    地形数据
% WOA18:    声速剖面数据
A = load([woa18_dir,'\woa18_17.mat'],'Lat');
WOA18.Lat = A.Lat;
A = load([woa18_dir,'\woa18_17.mat'],'Lon');
WOA18.Lon = A.Lon;
WOA18.Data = cell(1,17);
for it = 1:17
    WOA18.Data{it} = load(sprintf('%s\\woa18_%02d.mat', woa18_dir, it)...
        , 'Depth', 'Sal', 'Temp');
end

ETOPO = load(etop_dir);
