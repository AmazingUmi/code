function FileMaker(ETOPO, WOA, FileName, Config)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FILEMAKER 生成Bellhop声场计算所需的环境文件
%   根据ETOPO地形、WOA声速剖面和配置参数，生成Bellhop计算所需的各类文件
%
% 输入参数:
%   ETOPO - ETOPO地形数据结构体
%       .Lon, .Lat, .Altitude - 经纬度和高程数据
%   WOA - WOA23声速剖面数据结构体
%       .Lat, .Lon, .Data - 温盐深数据
%   FileName - 输出文件名前缀（字符串）
%   Config - 配置参数结构体
%       .Loc - 位置配置（起点coordS，终点coordE）
%       .Source - 声源配置（位置、频率、时间索引）
%       .Receiver - 接收配置（距离、深度）
%       .Cal - 计算配置（边界条件、波束参数等）
%
% 输出文件:
%   *.env - Bellhop环境文件
%   *.bty - 海底地形文件
%   *.ssp - 声速剖面文件
%   *.trc - 海面反射系数文件
%   *.brc - 海底反射系数文件
%
% 功能说明:
%   1. 根据起止坐标和接收距离生成网格点
%   2. 提取海深和声速剖面数据
%   3. 构建声速剖面结构（SSP）
%   4. 设置声源和接收器位置
%   5. 生成各类Bellhop输入文件
%
% 作者: [猫猫头]
% 日期: [2025-12-03]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 基本参数设置
model = 'BELLHOP';
rmax = max(Config.Receiver.ReceiveRange);  % 最大接收距离
titleEnv = ['Acoustic Calculation ', FileName];

% 验证声源距离是否在合理范围内
if Config.Source.SourceRange < 0 || Config.Source.SourceRange > rmax
    error('声源距离超出坐标范围: SourceRange=%.2f, 有效范围=[0, %.2f]', ...
        Config.Source.SourceRange, rmax);
end
%% 生成计算网格并提取环境数据
% 默认以1km间隔划分网格，至少需要两个点
N = max(rmax + 1, 2);
lat = linspace(Config.Loc.coordS.lat, Config.Loc.coordE.lat, N);
lon = linspace(Config.Loc.coordS.lon, Config.Loc.coordE.lon, N);

% 提取海底地形和声速剖面
bathm.r = linspace(0, rmax, N) - Config.Source.SourceRange;  % 地形文件距离参数
[bathm.d, ssp_raw, SSProf] = get_env(ETOPO, WOA, lon, lat, Config.Source.timeIdx);
if ~strcmp(Config.Cal.mesoscale.type, 'none')
    SSProf = add_mesoscale(SSProf, rmax, Config.Cal.mesoscale.type, Config.Cal.mesoscale.params);
end
%% 处理声速剖面数据
% 计算最大海深并裁剪声速剖面
Zmax = ceil(max(bathm.d));  % 区间实际最大海深
ssp_raw = ssp_raw(ssp_raw(:, 1) <= Zmax, :);
ssp_top = ssp_raw(1, 2);    % 海面声速
ssp_bot = ssp_raw(end, 2);  % 海底声速

% 地形平滑处理
MeanDep = mean(bathm.d);    % 区间平均海深
if MeanDep > Zmax
    % 如果Zmax小于实际海深的平均深度，则调整地形
    % 注: 海底地形变化剧烈（如海底山）时需要特殊处理
    bathm.d = bathm.d - (MeanDep - Zmax);
end

%% 构建声速剖面结构 (SSP)
SSP.NMedia = 1;                              % 媒质层数
SSP.N = 0;                                   % 深度网格数（0=使用原始数据）
SSP.sigma = 0;                               % 粗糙度参数
SSP.depth = [0, ssp_raw(end, 1)];            % 海水层深度范围 [表层, 底层]

% 声速剖面原始数据
SSP.raw(1).z      = ssp_raw(:, 1)';          % 深度 (m)
SSP.raw(1).alphaR = ssp_raw(:, 2)';          % 纵波声速 (m/s)
SSP.raw(1).betaR  = zeros(1, length(ssp_raw));  % 横波声速 (m/s)
SSP.raw(1).rho    = ones(1, length(ssp_raw));   % 密度 (g/cm³)
SSP.raw(1).alphaI = zeros(1, length(ssp_raw));  % 纵波衰减 (dB/λ)
SSP.raw(1).betaI  = zeros(1, length(ssp_raw));  % 横波衰减 (dB/λ)



%% 设置声源和接收器位置
Pos.s.z     = Config.Source.SourceDepth;     % 声源深度 (m)
Pos.r.z     = Config.Receiver.ReceiveDepth;  % 接收深度数组 (m)
Pos.r.range = Config.Receiver.ReceiveRange;  % 接收距离数组 (km)

%% 设置边界条件和波束参数
Bdry = Config.Cal.Bdry;  % 边界条件配置

Beam = Config.Cal.Beam;  % 波束配置
Beam.Box.z = Zmax + 500;  % 计算最大深度（需大于最大接收深度）
Beam.Box.r = rmax + 1;    % 计算最大距离（需大于最大接收距离）



%% 生成Bellhop输入文件
% 生成海面反射系数文件 (*.trc)
if length(Config.Cal.Bdry.Top.Opt) >= 2 && Config.Cal.Bdry.Top.Opt(2) == 'F'
    ReCoeTop(Config.Source.freqvec, ssp_top, Config.Cal.top_sea_state_level, ...
        sprintf('%s', FileName));
end

% 生成海底反射系数文件 (*.brc)
if Config.Cal.Bdry.Bot.Opt(1) == 'F'
    RefCoeBw(Config.Cal.bottom_base_type, sprintf('%s', FileName), ...
        Config.Source.freqvec, ssp_bot, Config.Cal.bottom_alpha_b);
end

% 生成环境文件 (*.env)
write_env(FileName, model, titleEnv, Config.Source.freq, SSP, Bdry, Pos, ...
    Beam, [], rmax);

% 生成海底地形文件 (*.bty)
write_bty(FileName, "'LS'", bathm);

% 生成声速剖面文件 (*.ssp)
write_ssp(FileName, bathm.r, SSProf.c);

end
