function call_Bellhop_surface2(ETOPO,WOA18,envfil, freq, SD, timeIdx, latitude, longitude, R, azi, sourceRange, rmax, run_type, option_type,alpha,angel)
model = 'BELLHOP';
titleEnv = 'Acoustic Calculation';
coordS.lat = latitude(1);
coordS.lon = longitude(1);
coordE.lat = latitude(2);
coordE.lon = longitude(2);
[coordS, coordE, R, azi] = coord_proc(coordS, coordE, R, azi);

% if sourceRange < 0 || sourceRange > R
%     error("The range of source is beyond the range of coordinate.");
% end

% Get bathymetry for *.bty and ssp_raw for *.env
N = max(ceil(R), 2);
lat = linspace(coordS.lat, coordE.lat, N);
lon = linspace(coordS.lon, coordE.lon, N);
bathm.r = linspace(0,R,N) - sourceRange;
[bathm.d, ssp_raw, SSProf] = get_env(ETOPO,WOA18,lat,lon,timeIdx);
ssp_raw = load('ssp2.mat').ssp_2;
Zmax = ceil(max(bathm.d));
Zmax = 6000;
ssp_raw = ssp_raw(ssp_raw(:,1)<=Zmax, :);

SSP.NMedia = 1;
SSP.N = [0];
SSP.sigma = [0];
SSP.depth = [0, ssp_raw(end,1)];
SSP.raw(1).z = ssp_raw(:,1)';
SSP.raw(1).alphaR = ssp_raw(:,2)';
SSP.raw(1).betaR = zeros(1,length(ssp_raw));
SSP.raw(1).rho = ones(1,length(ssp_raw));
SSP.raw(1).alphaI = zeros(1,length(ssp_raw));
SSP.raw(1).betaI = zeros(1,length(ssp_raw));


Bdry.Top.Opt = option_type;
Bdry.Bot.Opt = 'F';
Bdry.Bot.HS.alphaR = 1500;
Bdry.Bot.HS.betaR = 0;
Bdry.Bot.HS.rho = 1;
Bdry.Bot.HS.alphaI = 0;
Bdry.Bot.HS.betaI = 0;


Pos.s.z = SD;
Pos.r.z = 0:10:Zmax;
Pos.r.range = bathm.r(1):0.1:rmax;

% Rmax = max(abs(bathm.r));

% Beam.RunType = 'IB~';
Beam.RunType = run_type;
Beam.Nbeams = 10000;
if sourceRange == 0
    Beam.alpha = [alpha,angel];
elseif sourceRange == rmax
    Beam.alpha = [90,270];
else
    Beam.alpha = [-90,270];
end
Beam.deltas = 0;
Beam.Box.z = Zmax+1000;
Beam.Box.r = rmax+1;

write_env(envfil, model,titleEnv, freq, SSP, Bdry, Pos, Beam, [], rmax);
write_bty(envfil, "'LS'" ,bathm);
write_ssp(envfil,bathm.r, SSProf.c);
% bellhop(envfil);

% [ PlotTitle, PlotType, freqVec, freq0, atten, Pos_, pressure ] = read_shd( [envfil, '.shd'] );
% plotshd('envB.shd');
% hold on;
% fill(1000*[bathm.r(1),bathm.r,bathm.r(end)],[max(bathm.d), bathm.d, max(bathm.d)],'k');
%     
