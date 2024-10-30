function call_Bellhop_surface_more(ETOPO,WOA18,envfil, freq, SD, RD, timeIdx, coordS, coordE, SourceRange, ReceiveRange, rmax, ri, zi, run_type, top_option,bottom_option, beam_option, alpha1,alpha2)
%% 将输入参数写入环境文件中
% ETOPO:    地形数据集
% WOA18:    声速剖面数据集
% envfil:   输入参数文件名(不包括后缀)
% freq:     声源信号频率
% SD:       声源深度
% timeIdx:  月份
% latitude: 区间两端点纬度
% longitude:区间两端点经度
% R:
% azi:
% sourceRange:  声源在区间开始端的距离
% rmax:         最大计算距离
% run_type:     Bellhop计算类型
% option_type:  Bellhop计算选项
% alpha1:       bellhop开角限制下限
% alpha2:       bellhop开角限制上限


model = 'BELLHOP';
titleEnv = ['Acoustic Calculation ',envfil];

% [coordS, coordE, R, azi] = coord_proc(coordS, coordE, R, azi);  % R:区间长度   azi：终点相对于起点的方位

if SourceRange < 0 || SourceRange > rmax
    error("The range of source is beyond the range of coordinate.");
end

% Get bathymetry for *.bty and ssp_raw for *.env
N = max(rmax+1, 2);    % N:默认以1km的间隔将区间划分网格需要的网格点数，至少两个点

% 将两端点连线等间距划分成N个网格点，lat,lon为网格点的经纬度坐标，用于后续插值
lat = linspace(coordS.lat, coordE.lat, N);  
lon = linspace(coordS.lon, coordE.lon, N);

bathm.r = linspace(0,rmax,N) - SourceRange;    % .bty地形文件的距离参数
[bathm.d, ssp_raw, SSProf] = get_env(ETOPO,WOA18,lat,lon,timeIdx);

Zmax = ceil(max(bathm.d));  % 区间上实际的最大海深
% Zmax = 4000;    % 限制最大海深为Zmax，深度大于Zmax的声速部分将被移除
ssp_raw = ssp_raw(ssp_raw(:,1)<=Zmax, :);
MeanDep = mean(bathm.d);  % 区间平均海深
if MeanDep>Zmax
    % 如果Zmax小于实际海深的平均深度，则将实际海底地形平均深度减小到Zmax（如果海底地形变化非常大，如海底山，这里的处理不在适合）
    bathm.d = bathm.d-(MeanDep-Zmax);   
end

SSP.NMedia = 1;                                 % 媒质层数
SSP.N = 0;                                    % 深度网格数
SSP.sigma = 0;                                %   
SSP.depth = [0, ssp_raw(end,1)];                % 海水层最大深度
SSP.raw(1).z = ssp_raw(:,1)';                   % 深度
SSP.raw(1).alphaR = ssp_raw(:,2)';              % 纵波声速
SSP.raw(1).betaR = zeros(1,length(ssp_raw));    % 横波声速
SSP.raw(1).rho = ones(1,length(ssp_raw));       % 密度
SSP.raw(1).alphaI = zeros(1,length(ssp_raw));   % 纵波衰减
SSP.raw(1).betaI = zeros(1,length(ssp_raw));    % 横波衰减

Bdry.Top.Opt = top_option;         % bellhop上端选项

Bdry.Bot.Opt = bottom_option;  



Bdry.Bot.HS.alphaR = 1500;          % 海底纵波声速
Bdry.Bot.HS.betaR = 0;              % 海底横波声速
Bdry.Bot.HS.rho = 1;                % 海底密度
Bdry.Bot.HS.alphaI = 0;             % 海底纵波衰减
Bdry.Bot.HS.betaI = 0;              % 海底横波衰减

Pos.s.z = SD;  % 声源深度

 % 接收深度/m
if zi == 0;
    Pos.r.z = RD;
else
    Pos.r.z = 0:zi:Zmax;               
end




if ReceiveRange == 0
    Pos.r.range = bathm.r(1):ri:rmax;  % 接收距离/km
else
    Pos.r.range = ReceiveRange;
end
% Rmax = max(abs(bathm.r));

Beam.RunType = run_type;
Beam.Nbeams = 0;
if SourceRange == 0 
    % 声源位于区间起点时
    if exist('alpha1','var') && exist('alpha2','var')
        Beam.alpha = [alpha1,alpha2];       % 设置为指定声源发射开角
    else
        Beam.alpha = [-90,90];          % 默认设置为180度发射开角
    end
elseif SourceRange == rmax
    Beam.alpha = [90,270];
else
    Beam.alpha = [-90,270];
end

Beam.deltas = 0;
Beam.Box.z = Zmax+500;      % 计算最大深度，要大于设置的最大接收深度
Beam.Box.r = rmax+1;        % 计算最大距离，要大于设置的最大接收距离
        Beam.epmult = beam_option.epmult;
        Beam.rLoop = beam_option.rLoop;
        Beam.Nimage = beam_option.Nimage;
        Beam.Ibwin = beam_option.Ibwin;
        Beam.Type = beam_option.Type;
write_env(envfil, model, titleEnv, freq, SSP, Bdry, Pos, Beam, [], rmax);   % 将参数写入env文件
write_bty(envfil, "'LS'" ,bathm);       % 设置海底地形.bty文件
write_ssp(envfil, bathm.r, SSProf.c);   % 设置不同距离上的声速剖面集合.ssp文件

% bellhop(envfil);

% [ PlotTitle, PlotType, freqVec, freq0, atten, Pos_, pressure ] = read_shd( [envfil, '.shd'] );
% plotshd('envB.shd');
% hold on;
% fill(1000*[bathm.r(1),bathm.r,bathm.r(end)],[max(bathm.d), bathm.d, max(bathm.d)],'k');
%     
