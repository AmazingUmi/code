function [Depth, ssp_raw, SSP] = get_env(ETOPO, WOA, lon, lat, timeIdx)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GET_ENV 获取指定区域的海深和声速剖面数据
%   从ETOPO和WOA数据集中提取指定经纬度区间的海深和声速剖面信息
%
% 输入参数:
%   ETOPO - ETOPO地形数据结构体
%       .Lon, .Lat, .Altitude - 经纬度和高程数据
%   WOA - WOA23声速剖面数据结构体
%       .Lat, .Lon, .Data - 温盐深数据
%   lon - 目标经度向量
%   lat - 目标纬度向量
%   timeIdx - 时间索引 (1-12:月份, 13-16:季节, 17:年平均)
%
% 输出参数:
%   Depth - 指定区间上的海深向量 (m)
%   ssp_raw - 区间平均声速剖面 [深度, 声速] (用于*.env文件)
%   SSP - 区间多点声速剖面集合结构体 (用于*.ssp文件)
%       .z - 深度向量 (m)
%       .c - 声速矩阵 (Nz × Nr)
%
% 功能说明:
%   1. 提取指定区间的海深数据
%   2. 提取温盐剖面并计算平均值
%   3. 扩展声速剖面至最大海深
%   4. 生成*.env和*.ssp文件所需的声速剖面数据
%   5. 用平均值填充NaN数据
%
% 作者: [猫猫头]
% 日期: [2025-12-03]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 提取海深和温盐剖面数据
Depth = get_bathm(ETOPO, lon, lat);  % 获取ETOPO海深数据
[Temp, Sal, WOADepth] = get_envInfo(WOA, lon, lat, timeIdx);  % 获取温盐剖面 (Ndepth × Nlon)

%% 计算每个深度上的平均温盐值
Nd = length(WOADepth);
TempMean = nan(Nd, 1);  % 各深度平均温度
SalMean  = nan(Nd, 1);  % 各深度平均盐度

for iz = 1:Nd
    % 计算每个深度上非NaN值的平均
    TempMean(iz) = mean(Temp(iz, ~isnan(Temp(iz, :))), 'omitnan');
    SalMean(iz)  = mean(Sal(iz, ~isnan(Sal(iz, :))), 'omitnan');
end

%% 确定有效数据的最大深度索引
% 查找是否存在某个深度的数据全是NaN
idxD = find(isnan(TempMean) | isnan(SalMean));

if isempty(idxD)  % 未发现NaN，所有深度数据都有效
    idxD = length(WOADepth);
else
    % 假设如果某个深度全是NaN，则该深度以下也全是NaN
    idxD = idxD(1) - 1;
end
%% 生成*.env文件所需的平均声速剖面 (ssp_raw)
% 扩展温盐剖面至最大海深
seaDepth_max = ceil(max(Depth, [], 'all'));  % 指定区域最大海深

if idxD == 0
    % 无有效剖面数据
    error('温盐剖面数据缺失');
    
elseif WOADepth(idxD) < seaDepth_max
    % 情况1: 有效数据最大深度 < 地形最大海深
    % 将最大深度处的数据等值补充至地形最大海深处
    TempMean = [TempMean(1:idxD); TempMean(idxD)];
    SalMean  = [SalMean(1:idxD); SalMean(idxD)];
    ssp_z    = [WOADepth(1:idxD); seaDepth_max];
    ssp_c    = sound_speed(TempMean, SalMean, ssp_z);
    ssp_raw  = [ssp_z, ssp_c];
    
elseif WOADepth(idxD) == seaDepth_max
    % 情况2: 有效数据最大深度 = 地形最大海深
    % 直接使用有效数据
    TempMean = TempMean(1:idxD);
    SalMean  = SalMean(1:idxD);
    ssp_z    = WOADepth(1:idxD);
    ssp_c    = sound_speed(TempMean, SalMean, ssp_z);
    ssp_raw  = [ssp_z, ssp_c];
    
else
    % 情况3: 有效数据最大深度 > 地形最大海深
    % 选择最大海深以上的数据并插值
    ssp_z    = WOADepth(WOADepth < seaDepth_max);
    ssp_z    = [ssp_z; seaDepth_max];
    TempMean = interp1(WOADepth(1:idxD), TempMean(1:idxD), ssp_z);
    SalMean  = interp1(WOADepth(1:idxD), SalMean(1:idxD), ssp_z);
    ssp_c    = sound_speed(TempMean, SalMean, ssp_z);
    ssp_raw  = [ssp_z, ssp_c];
end
%% 生成*.ssp文件所需的多点声速剖面 (SSP)
% 用平均值替换NaN数据
Nz = length(ssp_z);
c = zeros(Nz, length(lat));

% 计算所有位置的声速 (Temp、Sal: NDepth × Nr)
C_all = sound_speed(Temp, Sal, WOADepth);

% 对每个深度层进行处理
for iz = 1:Nz-1
    c(iz, :) = C_all(iz, :);
    c(iz, isnan(c(iz, :))) = ssp_c(iz);  % 用该深度的平均值替换NaN
end

% 处理最底层数据
if seaDepth_max > WOADepth(end)
    % 最大海深 > 温盐最大测量深度
    c(Nz, :) = ssp_c(Nz);
    
elseif seaDepth_max == WOADepth(end)
    % 最大海深 = 温盐最大测量深度
    c(Nz, :) = C_all(Nz, :);
    c(Nz, isnan(c(Nz, :))) = ssp_c(Nz);  % 用平均值替换NaN
    
else
    % 最大海深 < 温盐最大测量深度
    c(Nz, :) = ssp_c(Nz);
end

% 构建输出结构体
SSP.z = ssp_z;  % 深度向量 (m)
SSP.c = c;      % 声速矩阵 (Nz × Nr, m/s)

end