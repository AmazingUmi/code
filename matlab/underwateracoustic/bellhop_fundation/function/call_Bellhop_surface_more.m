function call_Bellhop_surface_more(ETOPO, WOA18, envfil, varargin)
%% Write BELLHOP environment, bathymetry, and 2D SSP files.
% Preferred usage:
%   call_Bellhop_surface_more(ETOPO, WOA18, envfil, cfg)
%
% Backward-compatible usage:
%   call_Bellhop_surface_more(ETOPO, WOA18, envfil, freq, SD, RD, ...
%       timeIdx, coordS, coordE, SourceRange, rmax, ri, zi, run_type, ...
%       top_option, bottom_option, beam_option, alpha1, alpha2)

cfg = parseBellhopSurfaceConfig(varargin{:});

model = 'BELLHOP';
titleEnv = ['Acoustic Calculation ', envfil];

freq = cfg.freq;
sourceDepth = cfg.sourceDepth;
receiveDepth = cfg.receiveDepth;
timeIdx = cfg.monthIdx;
coordS = cfg.coordS;
coordE = cfg.coordE;
sourceRange = cfg.sourceRange;
rmax = cfg.receiveRange;
ri = cfg.receiveRangeStep;
zi = cfg.receiveDepthStep;
runType = cfg.runType;
topOption = cfg.topOption;
bottomOption = cfg.bottomOption;
beamOption = cfg.beamOption;

if sourceRange < 0 || sourceRange > rmax
    error('call_Bellhop_surface_more:InvalidSourceRange', ...
        'The source range is outside the coordinate range.');
end
if isempty(ri)
    ri = 0;
end
if isempty(zi)
    zi = 0;
end

% Get bathymetry for *.bty and ssp_raw for *.env.
N = max(ceil(rmax) + 1, 2);
lat = linspace(coordS.lat, coordE.lat, N);
lon = linspace(coordS.lon, coordE.lon, N);

bathm.r = linspace(0, rmax, N) - sourceRange;
[bathm.d, ssp_raw, SSProf] = get_env(ETOPO, WOA18, lat, lon, timeIdx);

Zmax = ceil(max(bathm.d));
validateDepths(sourceDepth, receiveDepth, bathm.d, ri);

ssp_raw = ssp_raw(ssp_raw(:, 1) <= Zmax, :);
meanDepth = mean(bathm.d);
if meanDepth > Zmax
    bathm.d = bathm.d - (meanDepth - Zmax);
end

SSP = buildWaterColumnSSP(ssp_raw);
Bdry = buildBoundary(topOption, bottomOption);
Pos = buildPosition(sourceDepth, receiveDepth, bathm.r, rmax, ri, zi, Zmax);
Beam = buildBeam(runType, beamOption, sourceRange, rmax, Zmax, cfg);

write_env(envfil, model, titleEnv, freq, SSP, Bdry, Pos, Beam, [], rmax);
write_bty(envfil, "'LS'", bathm);
write_ssp(envfil, bathm.r, SSProf.c);

% bellhop(envfil);
end

function cfg = parseBellhopSurfaceConfig(varargin)
if numel(varargin) == 1 && isstruct(varargin{1})
    cfg = normalizeConfig(varargin{1});
    return;
end

if numel(varargin) ~= 14 && numel(varargin) ~= 16
    error('call_Bellhop_surface_more:InvalidInput', ...
        'Use either a cfg struct or the legacy argument list.');
end

cfg.freq = varargin{1};
cfg.sourceDepth = varargin{2};
cfg.receiveDepth = varargin{3};
cfg.monthIdx = varargin{4};
cfg.coordS = varargin{5};
cfg.coordE = varargin{6};
cfg.sourceRange = varargin{7};
cfg.receiveRange = varargin{8};
cfg.receiveRangeStep = varargin{9};
cfg.receiveDepthStep = varargin{10};
cfg.runType = varargin{11};
cfg.topOption = varargin{12};
cfg.bottomOption = varargin{13};
cfg.beamOption = varargin{14};
if numel(varargin) == 16
    cfg.alphaLimits = [varargin{15}, varargin{16}];
end
cfg = normalizeConfig(cfg);
end

function cfg = normalizeConfig(cfg)
requiredFields = {'freq', 'sourceDepth', 'receiveDepth', 'monthIdx', ...
    'coordS', 'coordE', 'sourceRange', 'runType', 'topOption', ...
    'bottomOption', 'beamOption'};
for ii = 1:numel(requiredFields)
    if ~isfield(cfg, requiredFields{ii})
        error('call_Bellhop_surface_more:MissingConfigField', ...
            'Missing cfg.%s.', requiredFields{ii});
    end
end

if ~isfield(cfg, 'receiveRange')
    if isfield(cfg, 'rmax')
        cfg.receiveRange = cfg.rmax;
    else
        error('call_Bellhop_surface_more:MissingConfigField', ...
            'Missing cfg.receiveRange.');
    end
end
if ~isfield(cfg, 'receiveRangeStep')
    cfg.receiveRangeStep = 0;
end
if ~isfield(cfg, 'receiveDepthStep')
    cfg.receiveDepthStep = 0;
end
end

function validateDepths(sourceDepth, receiveDepth, bathymetryDepth, ri)
if sourceDepth >= bathymetryDepth(1)
    error('call_Bellhop_surface_more:InvalidSourceDepth', ...
        'The source depth must be shallower than the seabed at the source location.');
end

if ri == 0
    receiveSeabedDepth = bathymetryDepth(end);
else
    receiveSeabedDepth = min(bathymetryDepth);
end
if receiveDepth >= receiveSeabedDepth
    error('call_Bellhop_surface_more:InvalidReceiverDepth', ...
        'The receiver depth must be shallower than the seabed.');
end
end

function SSP = buildWaterColumnSSP(ssp_raw)
SSP.NMedia = 1;
SSP.N = 0;
SSP.sigma = 0;
SSP.depth = [0, ssp_raw(end, 1)];
SSP.raw(1).z = ssp_raw(:, 1)';
SSP.raw(1).alphaR = ssp_raw(:, 2)';
SSP.raw(1).betaR = zeros(1, size(ssp_raw, 1));
SSP.raw(1).rho = ones(1, size(ssp_raw, 1));
SSP.raw(1).alphaI = zeros(1, size(ssp_raw, 1));
SSP.raw(1).betaI = zeros(1, size(ssp_raw, 1));
end

function Bdry = buildBoundary(topOption, bottomOption)
Bdry.Top.Opt = topOption;
Bdry.Bot.Opt = bottomOption;
Bdry.Bot.HS.alphaR = 1500;
Bdry.Bot.HS.betaR = 0;
Bdry.Bot.HS.rho = 1;
Bdry.Bot.HS.alphaI = 0;
Bdry.Bot.HS.betaI = 0;
end

function Pos = buildPosition(sourceDepth, receiveDepth, bathmRange, rmax, ri, zi, Zmax)
Pos.s.z = sourceDepth;

if zi == 0
    Pos.r.z = receiveDepth;
else
    Pos.r.z = 0:zi:Zmax;
end

if ri == 0
    Pos.r.range = rmax;
else
    Pos.r.range = bathmRange(1):ri:rmax;
end
end

function Beam = buildBeam(runType, beamOption, sourceRange, rmax, Zmax, cfg)
Beam.RunType = runType;
Beam.Nbeams = 0;

if sourceRange == 0
    if isfield(cfg, 'alphaLimits') && numel(cfg.alphaLimits) == 2
        Beam.alpha = cfg.alphaLimits;
    else
        Beam.alpha = [-90, 90];
    end
elseif sourceRange == rmax
    Beam.alpha = [90, 270];
else
    Beam.alpha = [-90, 270];
end

Beam.deltas = 0;
Beam.Box.z = Zmax + 500;
Beam.Box.r = rmax + 1;
Beam.epmult = beamOption.epmult;
Beam.rLoop = beamOption.rLoop;
Beam.Nimage = beamOption.Nimage;
Beam.Ibwin = beamOption.Ibwin;
Beam.Type = beamOption.Type;
end
