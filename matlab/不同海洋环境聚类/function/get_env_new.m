function [seaDepth, SSP] = get_env_new(ETOPO, WOA18, lat, lon, timeIdx)
%% 从数据集中获得lon,lat向量指定直线区间上多个位置的海深和声速剖面
%% Input
% ETOPO:    海深数据集
% WOA18:    声速剖面数据集
% lat:      指定区间的维度向量
% lon:      指定区间的经度向量
% timeIdx:  声速剖面月份选择
%% Output
% seaDepth: 指定直线区间上的最大海深
% ssp_raw:  区间平均声速剖面（0至最大海深）
% SSP:      区间多个点上的声速剖面集合

seaDepth = get_bathm(ETOPO, lat, lon);  % 获取海深数据
[Temp, Sal, TSDepth] = get_profile_filled(WOA18, lat, lon, timeIdx);  % 获取温盐剖面数据 Temp: Ndepth*Nlon 

Nd = length(TSDepth);
TempMean = nan(Nd,1);    % Mean temperature at each depth 
SalMean = nan(Nd,1);     % Mean salinity at each depth
for iz = 1:Nd
    TempMean(iz) = mean(Temp(iz,~isnan(Temp(iz,:) ) ) ); % 每个深度上非空值的平均
    SalMean(iz) = mean( Sal(iz, ~isnan( Sal(iz,:) ) ) );
end

% Find the depth idx of the profile.
idxD = find(isnan(TempMean) | isnan(SalMean)); % 有效数据的最大深度索引
if isempty(idxD)   % No NaN is found.查找是否存在某个深度的数据全是NAN
    idxD = length(TSDepth);
else
    idxD = idxD(1) - 1;     % 这里默认如果存在某个深度数据全是nan，则这个深度以下肯定也全是nan
end
%% ssp_raw: the ssp written to the *.env
% Extend profile to sea depth 扩展温盐剖面至最大海深
seaDepth_max = ceil(max(seaDepth,[],'all')); % 指定区域最大海深
if idxD == 0  % No profile data
    error('Profile data missing.');
elseif TSDepth(idxD) < seaDepth_max
    % 如果有效数据最大深度小于地形最大海深，
    % 则将有效数据最大海深处的数据等值地补充至地形最大海深处
    TempMean = [TempMean(1:idxD); TempMean(idxD)];
    SalMean = [SalMean(1:idxD); SalMean(idxD)];
    ssp_z = [TSDepth(1:idxD); seaDepth_max];      % 深度
    ssp_c = sound_speed(TempMean, SalMean, ssp_z); % 计算声速
    ssp_raw = [ssp_z, ssp_c];  % 声速剖面
elseif TSDepth(idxD) == seaDepth_max
    % % 如果有效数据最大深度刚好等于地形最大海深，则直接使用idxD即可
    TempMean = TempMean(1:idxD);
    SalMean = SalMean(1:idxD);
    ssp_z = TSDepth(1:idxD);
    ssp_c = sound_speed(TempMean, SalMean, ssp_z);
    ssp_raw = [ssp_z, ssp_c];
else
    % 选择最大海深以上的深度数据和温盐数据
    ssp_z = TSDepth( TSDepth < seaDepth_max ); 
    ssp_z = [ssp_z; seaDepth_max];
    TempMean = interp1(TSDepth(1:idxD), TempMean(1:idxD), ssp_z);  
    SalMean = interp1(TSDepth(1:idxD), SalMean(1:idxD), ssp_z);
    ssp_c = sound_speed(TempMean, SalMean, ssp_z);
    ssp_raw = [ssp_z, ssp_c];
end
%% SSP: the ssp written to the *.ssp
% Replace NaN data with corresponding mean value.

Nz = length(ssp_z);
c = zeros(Nz,length(lat));

C_all = sound_speed(Temp, Sal, TSDepth);  % Temp、Sal: NDepth*Nlon 
for iz = 1:Nz-1
    c(iz,:) = C_all(iz,:);
    c(iz,isnan(c(iz,:))) = ssp_c(iz);   % 用该深度上的均值代替空值
end

if seaDepth_max > TSDepth(end)  
    % 最大海深大于温盐最大测量深度
    c(Nz,:) = ssp_c(Nz);  
elseif seaDepth_max == TSDepth(end)
    % 最大海深等于温盐最大测量深度,则使用温盐计算的声速
    c(Nz,:) = C_all(Nz,:);
    c(Nz,isnan(c(Nz,:))) = ssp_c(Nz);  % 用均值代替空值
else
    % 最大海深小于温盐最大测量深度
    c(Nz,:) = ssp_c(Nz);
end
SSP.z = ssp_z;
SSP.c = c;