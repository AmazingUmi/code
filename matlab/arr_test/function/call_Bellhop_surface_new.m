function call_Bellhop_surface_new(ETOPO, WOA23, envfil, coordS, coordE, ...
    SourceDepth, ReceiveDepth, SourceRange, ReceiveRange)
%% 默认参数部分
run_type = 'AB';   % 5 character
top_option = 'CFFT';% 5 character
sea_state_level = 0;   % n级海况
freq = 500;   % 计算中心频率
freqvec = 500;   % 反射系数计算宽带频率
timeIdx = 1;          % 声速剖面采样月份
% 海底板块
bottom_option = 'F*'; % 2 character
base_type = 'IMG';  % 底质类型
alpha_b = 0.05;

% 波束板块
beam_option.Type = 'CS';% 2 character
beam_option.epmult = 0.3;
beam_option.rLoop  = 1;
beam_option.Nimage = 1;
beam_option.Ibwin  = 1;



%% 原函数部分
model = 'BELLHOP';
rmax = max(ReceiveRange);
titleEnv = ['Acoustic Calculation ',envfil];
if SourceRange < 0 || SourceRange > rmax
    error("The range of source is beyond the range of coordinate.");
end
% Get bathymetry for *.bty and ssp_raw for *.env
N = max(rmax+1, 2);    % N:默认以1km的间隔将区间划分网格需要的网格点数，至少两个点
lat = linspace(coordS.lat, coordE.lat, N);
lon = linspace(coordS.lon, coordE.lon, N);

bathm.r = linspace(0,rmax,N) - SourceRange;    % .bty地形文件的距离参数
[bathm.d, ssp_raw, SSProf] = get_env(ETOPO,WOA23,lat,lon,timeIdx);

Zmax = ceil(max(bathm.d));  % 区间上实际的最大海深
ssp_raw = ssp_raw(ssp_raw(:,1)<=Zmax, :);
ssp_top = ssp_raw(1,2); % top speed
ssp_bot = ssp_raw(end,2); % bottom speed
MeanDep = mean(bathm.d);  % 区间平均海深
if MeanDep>Zmax
    % 如果Zmax小于实际海深的平均深度，则将实际海底地形平均深度减小到Zmax（如果海底地形变化非常大，如海底山，这里的处理不在适合）
    bathm.d = bathm.d-(MeanDep-Zmax);
end

SSP.NMedia = 1;                                 % 媒质层数
SSP.N = 0;                                      % 深度网格数
SSP.sigma = 0;                                  %
SSP.depth = [0, ssp_raw(end,1)];                % 海水层最大深度
SSP.raw(1).z = ssp_raw(:,1)';                   % 深度
SSP.raw(1).alphaR = ssp_raw(:,2)';              % 纵波声速
SSP.raw(1).betaR = zeros(1,length(ssp_raw));    % 横波声速
SSP.raw(1).rho = ones(1,length(ssp_raw));       % 密度
SSP.raw(1).alphaI = zeros(1,length(ssp_raw));   % 纵波衰减
SSP.raw(1).betaI = zeros(1,length(ssp_raw));    % 横波衰减

Bdry.Top.Opt = top_option;          % bellhop上端选项
Bdry.Bot.Opt = bottom_option;       % bellhop下端选项
Bdry.Bot.HS.alphaR = 1500;          % 海底纵波声速
Bdry.Bot.HS.betaR = 0;              % 海底横波声速
Bdry.Bot.HS.rho = 1;                % 海底密度
Bdry.Bot.HS.alphaI = 0;             % 海底纵波衰减
Bdry.Bot.HS.betaI = 0;              % 海底横波衰减

Pos.s.z = SourceDepth;
Pos.r.z = ReceiveDepth;
Pos.r.range = ReceiveRange;



Beam.RunType = run_type;
Beam.Nbeams = 0;
Beam.alpha = [-90,90];
Beam.deltas = 0;
Beam.Box.z = Zmax+500;      % 计算最大深度，要大于设置的最大接收深度
Beam.Box.r = rmax+1;        % 计算最大距离，要大于设置的最大接收距离
Beam.epmult = beam_option.epmult;
Beam.rLoop = beam_option.rLoop;
Beam.Nimage = beam_option.Nimage;
Beam.Ibwin = beam_option.Ibwin;
Beam.Type = beam_option.Type;
%% 文件生成部分
TopReCoe(freqvec, ssp_top, sea_state_level, sprintf('%s', envfil));
RefCoeBw(base_type, sprintf('%s', envfil), freqvec, ssp_bot, alpha_b);
write_env(envfil, model, titleEnv, freq, SSP, Bdry, Pos, Beam, [], rmax);   % 将参数写入env文件
write_bty(envfil, "'LS'" ,bathm);       % 设置海底地形.bty文件
write_ssp(envfil, bathm.r, SSProf.c);   % 设置不同距离上的声速剖面集合.ssp文件


