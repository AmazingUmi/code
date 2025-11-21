function [y, meta] = shipNoiseGenerate_bellhopchannel(cfg)
% shipNoiseGenerate  ���ɽ������������������� + ���ף�������ѡ���Ŀ����������ˮ���ŵ�
% [y, meta] = shipNoiseGenerate(cfg)
%
% ���� cfg(�ṹ�壬ȫ����ѡ) ���� �����ֶΣ�
%   ������fs(Hz, Ĭ��40000), T(s, Ĭ��10), seed(Ĭ��1)
%   �ƽ���prop_rpm(Ĭ��180), prop_blades(Ĭ��4)
%   Wenz��SA(���˻�Ծ��, Ĭ��0.6), w_ms(����, Ĭ��8), fmin(10), fmax(10000)
%   ������ѭ��ƽ�ȣ�sigma_ln(0.6), env_fc_Hz(2), bp_lo_factor(0.5), bp_hi_factor(4), cont_gain(0.30)
%   ����SNR������Delta_shaft0(12), decay_shaft(1.0), Delta_blade0(15), decay_blade(1.5),
%                Delta_side0(8), sideband_order(2), AM_index(0.30),
%                shaft_harm_max(8), blade_harm_max(12), Nline_pow(19) �� df=fs/2^N
%   �궨��cal_mode = 'global' | 'cont-only' | 'none'��Ĭ�� 'global'��
%         Lbb_target_dB(Ĭ��120)
%   �ŵ�����ѡ����channel.apply(false)
%
% �����
%   y    : �ϳɣ�����ŵ��󣩵�ʱ�����У���������
%   meta : �ṹ�壬�� fs, t, cont, tone, y_raw, y (���ܹ��ŵ�), Wenz PSD, RMSE, Lbb ��

%% -------- ������Ĭ�� --------
fs   = g(cfg,'fs', 40000);
T    = g(cfg,'T',  10);
N    = round(fs*T);
t    = (0:N-1).'/fs;
seed = g(cfg,'seed', 1);

prop_rpm    = g(cfg,'prop_rpm',180);
prop_blades = g(cfg,'prop_blades',4);
f_shaft     = prop_rpm/60;
f_bpf       = prop_blades*f_shaft;

SA   = g(cfg,'SA', 0.6);
w_ms = g(cfg,'w_ms',8);
fmin = g(cfg,'fmin',10);
fmax = g(cfg,'fmax',10000);

sigma_ln     = g(cfg,'sigma_ln',0.6);
env_fc_Hz    = g(cfg,'env_fc_Hz',2);
bp_lo_factor = g(cfg,'bp_lo_factor',0.5);
bp_hi_factor = g(cfg,'bp_hi_factor',4.0);
cont_gain    = g(cfg,'cont_gain',0.30);

Delta_shaft0 = g(cfg,'Delta_shaft0',12);
decay_shaft  = g(cfg,'decay_shaft',1.0);
Delta_blade0 = g(cfg,'Delta_blade0',15);
decay_blade  = g(cfg,'decay_blade',1.5);
Delta_side0  = g(cfg,'Delta_side0',8);
sideband_order = g(cfg,'sideband_order',2);
AM_index     = g(cfg,'AM_index',0.30);
shaft_harm_max = g(cfg,'shaft_harm_max',8);
blade_harm_max = g(cfg,'blade_harm_max',12);
Nline_pow    = g(cfg,'Nline_pow',19);  % 2^19 by default

cal_mode       = g(cfg,'cal_mode','global'); % 'global'|'cont-only'|'none'
Lbb_target_dB  = g(cfg,'Lbb_target_dB',120);

P_ref = 1e-6;

%% -------- 1) �����ף�Wenz ����PSD���� + ѭ��ƽ�Ƚ���BPF���� --------
rng(seed);
[cont, S_wenz_dB, fgrid] = make_continuous_Wenz(fs, N, SA, w_ms, fmin, fmax);

% ѭ��ƽ�Ȱ���
[b_lp,a_lp] = butter(2, env_fc_Hz/(fs/2), 'low');
g_env = filtfilt(b_lp,a_lp, randn(N,1)); g_env = (g_env-mean(g_env))/std(g_env);
env = exp(-0.5*sigma_ln^2 + sigma_ln*g_env); env = env / mean(env);

bp_lo = max(20,   bp_lo_factor*f_bpf);
bp_hi = min(10000,bp_hi_factor*f_bpf);
cont = apply_bp_envelope(cont, env, fs, bp_lo, bp_hi);

% �������ǿ��
cont = cont_gain * cont;

% �� Wenz �ġ����� PSD ��������10�C10kHz �γ������룩
[delta_dB, g_psd] = lock_continuous_psd(cont, fs, fgrid, S_wenz_dB, P_ref);
cont = g_psd * cont;

%% -------- 2) ���ף�SNR ��������Եذ壩+ ENBW + դ����� --------
% periodogram ���볤��
Nline = 2^min(Nline_pow, floor(log2(N)));
df_line = fs/Nline;

% �����׵ذ� PSD��Welch��
nfft_floor = 131072;
[Pcf, ff] = pwelch(cont, hamming(nfft_floor), 0.5*nfft_floor, nfft_floor, fs, 'psd');
interp_floor = @(f0) max(1e-30, interp1(ff, Pcf, min(max(f0,ff(2)), fs/2), 'linear', 'extrap'));

% ��������
tone = zeros(N,1);
rng(seed+1); phi = 2*pi*rand(4096,1); ip=1;
qbin = @(f) round(f/df_line)*df_line;

% ��Ƶг��
for h = 1:shaft_harm_max
    f0 = h*f_shaft; if f0 >= fs/2, break; end
    f0 = qbin(f0);
    Sfloor = interp_floor(f0);
    Delta  = max(3, Delta_shaft0 - decay_shaft*(h-1));
    A = sqrt( 2 * Sfloor * df_line * 10^(Delta/10) );
    tone = tone + A * sin(2*pi*f0*t + phi(ip)); ip=ip+1;
end
% ҶƵ + �ߴ�
for m = 1:blade_harm_max
    fb = m*f_bpf; if fb >= fs/2, break; end
    fb = qbin(fb);
    Sfloor = interp_floor(fb);
    Delta  = max(4, Delta_blade0 - decay_blade*(m-1));
    Acore  = sqrt( 2 * Sfloor * df_line * 10^(Delta/10) );
    tone   = tone + Acore * sin(2*pi*fb*t + phi(ip)); ip=ip+1;
    for sb = 1:sideband_order
        f1 = qbin(fb + sb*f_shaft);
        f2 = qbin(fb - sb*f_shaft);
        if f1 < fs/2
            Sfloor1 = interp_floor(f1);
            Asb1 = sqrt( 2 * Sfloor1 * df_line * 10^((Delta_side0)/10) ) * (AM_index/sb);
            tone = tone + Asb1 * sin(2*pi*f1*t + phi(ip)); ip=ip+1;
        end
        if f2 > 0
            Sfloor2 = interp_floor(f2);
            Asb2 = sqrt( 2 * Sfloor2 * df_line * 10^((Delta_side0)/10) ) * (AM_index/sb);
            tone = tone + Asb2 * sin(2*pi*f2*t + phi(ip)); ip=ip+1;
        end
    end
end

%% -------- 3) �ϳ� + �������궨 --------
y_raw = cont + tone;

switch lower(cal_mode)
    case 'global'
        % ����ȱȵ�Ŀ�꣨���� SNR/��Ը߶ȣ�
        P_target = (P_ref^2) * 10^(Lbb_target_dB/10);
        g_total  = sqrt( P_target / max(var(y_raw), eps) );
        y        = g_total * y_raw; cont = g_total*cont; tone = g_total*tone;
        cal_note = sprintf('[global] g_total=%.3f', g_total);

    case 'cont-only'
        P_target = (P_ref^2) * 10^(Lbb_target_dB/10);
        Pc = var(cont); Pt = var(tone);
        if P_target <= Pt
            warning('Ŀ����������ͣ����׷����ѳ���Ŀ�ꡣ������� Lbb �򽵵�����SNR��');
            y = y_raw; cal_note = '[cont-only] infeasible, skip';
        else
            g_bb = sqrt( (P_target - Pt) / max(Pc, eps) );
            cont = g_bb * cont; y = cont + tone;
            cal_note = sprintf('[cont-only] g_bb=%.3f', g_bb);
        end

    otherwise
        y = y_raw; cal_note = '[none] no calibration';
end

%% -------- 4) ��ѡ��ˮ���ŵ��������� --------
ch = g(cfg,'channel', struct('apply',false));
if g(ch,'apply',false)
    ch.fs = fs;
    [y, ch_meta] = apply_channel_ir(y, ch);  % ʱ��IR��������Thorp
else
    ch_meta = [];
end

%% -------- 5) ͳ������ָ֤�� --------
Lbb = 10*log10( (rms(y)^2)/P_ref^2 );

% Welch PSD vs Wenz ����״ RMSE��10�C10kHz�����������룩
nfftW = 65536;
[Pxx,fW] = pwelch(y, hamming(nfftW), 0.5*nfftW, nfftW, fs, 'psd');
PSD_W_dB = 10*log10(Pxx/P_ref^2);
fkW = max(fW/1000,1e-9);
[~,Wenz_dB] = wenz_psd(fkW, SA, w_ms);  % dB/Hz
mask = (fW>=10 & fW<=10000);
offset = mean(PSD_W_dB(mask) - Wenz_dB(mask));
rmse_dB = sqrt(mean( (PSD_W_dB(mask) - (Wenz_dB(mask)+offset)).^2 ));

%% -------- 6) ��� meta --------
meta = struct();
meta.fs = fs; meta.t = t; meta.P_ref = P_ref;
meta.y = y; meta.y_raw = y_raw; meta.cont = cont; meta.tone = tone;
meta.fgrid = fgrid; meta.S_wenz_dB = S_wenz_dB;
meta.delta_dB_cont_lock = delta_dB; meta.g_psd = g_psd;
meta.df_line = df_line; meta.Nline = Nline;
meta.cal_mode = cal_mode; meta.Lbb_target_dB = Lbb_target_dB;
meta.Lbb = Lbb; meta.rmse_Wenz_dB = rmse_dB; meta.offset_Wenz_dB = offset;
meta.info = struct('f_shaft',f_shaft,'f_bpf',f_bpf,'cont_gain',cont_gain, ...
    'Delta_shaft0',Delta_shaft0,'Delta_blade0',Delta_blade0,'Delta_side0',Delta_side0, ...
    'decay_shaft',decay_shaft,'decay_blade',decay_blade,'sideband_order',sideband_order, ...
    'AM_index',AM_index,'bp_lo',bp_lo,'bp_hi',bp_hi,'cal_note',cal_note);
meta.channel = ch_meta;

end % ===== end main =====


%% ================= ���ߺ����� =================
function val = g(s, field, default)
    if isstruct(s) && isfield(s,field) && ~isempty(s.(field)), val = s.(field);
    else, val = default; end
end

function [cont, S_wenz_dB, fgrid] = make_continuous_Wenz(fs, N, SA, w_ms, fmin, fmax)
    % ���ɰ� Wenz ����(����+��+��)���ε������ף���״����������������PSD����
    P_ref = 1e-6;
    design_points = 4096;
    fgrid = linspace(0, fs/2, design_points).';
    fk    = max(fgrid/1000, 1e-9);    % kHz
    [S_wenz_lin, S_wenz_dB] = wenz_psd(fk, SA, w_ms); %#ok<ASGLU>

    mag = sqrt(S_wenz_lin / max(S_wenz_lin));
    % ����������β
    taper = ones(size(fgrid));
    ib = fgrid < fmin; ia = fgrid > fmax;
    if any(ib), x=fgrid(ib)/fmin; taper(ib)=0.5-0.5*cos(pi*x); end
    if any(ia), x=(fs/2 - fgrid(ia))/(fs/2 - fmax); taper(ia)=max(0,0.5-0.5*cos(pi*x)); end
    mag = mag .* taper; mag(1) = mag(2);

    b_wenz = fir2(2048, fgrid/(fs/2), mag);
    cont = filter(b_wenz, 1, randn(N,1));
end

function cont2 = apply_bp_envelope(cont, env, fs, f1, f2)
    if exist('designfilt','file')
        bp = designfilt('bandpassiir','FilterOrder',6, ...
            'HalfPowerFrequency1', f1, 'HalfPowerFrequency2', f2, 'SampleRate', fs);
        cont_bp = filtfilt(bp, cont);
    else
        [bb,aa] = butter(4, [f1,f2]/(fs/2), 'bandpass');
        cont_bp = filtfilt(bb, aa, cont);
    end
    cont2 = (cont - cont_bp) + env .* cont_bp;
end

function [delta_dB, g_psd] = lock_continuous_psd(cont, fs, fgrid, S_wenz_dB, P_ref)
    nfft = 131072;
    [Pcc, fc] = pwelch(cont, hamming(nfft), 0.5*nfft, nfft, fs, 'psd');
    S_wenz_lin_fc = interp1(fgrid, 10.^(S_wenz_dB/10)*P_ref^2, fc, 'linear','extrap');
    mask = (fc>=10 & fc<=10000);
    delta_dB = mean( 10*log10(Pcc(mask)/P_ref^2) - 10*log10(S_wenz_lin_fc(mask)/P_ref^2) );
    g_psd = 10^(-delta_dB/20);
end

function [S_lin, S_dB] = wenz_psd(fk_kHz, SA, w_ms)
    % ���� fk_kHz: Ƶ��(kHz)
    P_ref = 1e-6;
    Ns = 40 + 20*(SA - 0.5) + 26*log10(fk_kHz) - 60*log10(fk_kHz + 0.03);
    Nw = 50 + 7.5*sqrt(w_ms)  + 20*log10(fk_kHz) - 40*log10(fk_kHz + 0.4);
    Nt = -15 + 20*log10(fk_kHz);
    S_dB = 10*log10(10.^(Ns/10) + 10.^(Nw/10) + 10.^(Nt/10)); % dB re 1?Pa^2/Hz
    S_lin = 10.^(S_dB/10) * (P_ref^2);                         % Pa^2/Hz
end

function [y_out, info] = apply_channel_ir(y, ch)
    % �򻯰棺���񷨶ྶ + Thorp ���գ�Ƶ�򹹽�H(f)��IFFT��h�������Ծ���
    fs = ch.fs; y = y(:); N = numel(y);
    geo.R = g(ch,'R',1500); geo.zs = g(ch,'zs',20); geo.zr = g(ch,'zr',40);
    geo.H = g(ch,'H',200);  geo.c  = g(ch,'c',1500);
    opt.include_direct = g(ch,'include_direct',true);
    opt.include_surface= g(ch,'include_surface',true);
    opt.include_bottom = g(ch,'include_bottom',true);
    opt.include_SB     = g(ch,'include_SB',false);
    opt.spread_exp     = g(ch,'spread_exp',1.0);
    opt.Gamma_surf     = g(ch,'Gamma_surf',-1.0);
    opt.Gamma_bot_mag  = g(ch,'Gamma_bot_mag',0.6);
    opt.Gamma_bot_phase= g(ch,'Gamma_bot_phase_deg',0);
    opt.absorption_on  = g(ch,'absorption_on',true);
    padm               = g(ch,'pad_margin_s',0.5);

    % ·��
    paths = [];
    if opt.include_direct,  paths=[paths; mk('direct',geo.R, geo.zr-geo.zs, 0,0,geo)]; end
    if opt.include_surface, paths=[paths; mk('surface',geo.R, geo.zr+geo.zs, 1,0,geo)]; end
    if opt.include_bottom,  paths=[paths; mk('bottom',geo.R, 2*geo.H-geo.zs-geo.zr, 0,1,geo)]; end
    if opt.include_SB,      paths=[paths; mk('S+B',geo.R, 2*geo.H+geo.zs+geo.zr, 1,1,geo)]; end

    for k=1:numel(paths)
        L = paths(k).L; A_spread = 1/(L^opt.spread_exp + eps);
        Gamma_s = opt.Gamma_surf^paths(k).Ns;
        Gamma_b = (opt.Gamma_bot_mag*exp(1j*deg2rad(opt.Gamma_bot_phase)))^paths(k).Nb;
        paths(k).A_geo = A_spread * Gamma_s * Gamma_b;
    end

    max_tau = max([paths.tau]);
    padL = ceil((max_tau + padm)*fs); padR = padL;
    Npad = N + padL + padR; Nfft = 2^nextpow2(Npad);
    f = (0:Nfft-1).'*(fs/Nfft); fkHz = f/1000;

    alpha_dbkm = zeros(size(f));
    if opt.absorption_on
        alpha_dbkm = thorp_dbkm(fkHz);
    end

    H = zeros(Nfft,1);
    for k=1:numel(paths)
        Lkm = paths(k).L/1000;
        A_abs = 10.^(-(alpha_dbkm.*Lkm)/20);
        H = H + paths(k).A_geo .* A_abs .* exp(-1j*2*pi*f*paths(k).tau);
    end

    y_pad = [zeros(padL,1); y; zeros(padR,1)];
    Y = fft(y_pad, Nfft) .* H;
    y_full = real(ifft(Y, Nfft));
    y_out  = y_full(padL+(1:N));

    info = struct('paths',paths,'H',H,'f',f);
end

function a = thorp_dbkm(fkHz)
    f2 = fkHz.^2 + eps;
    a = 0.11.*(f2./(1+f2)) + 44.*(f2./(4100+f2)) + 2.75e-4.*f2 + 0.003;
end

function p = mk(tag, R, Dz, Ns, Nb, geo)
    L = hypot(R, Dz);
    p = struct('tag',tag,'L',L,'tau',L/geo.c,'Ns',Ns,'Nb',Nb,'A_geo',[]);
end
