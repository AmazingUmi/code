function [y, envelope, out] = windNoiseWenz10k(opts)
% windNoiseWenz10k  Wind-generated underwater noise up to 10 kHz (Wenz shaping)
% 白噪声 → Wenz 风噪频谱成形 → 对数正态“慢包络”幅度调制（到 10 kHz）。
%
% [y, envelope, out] = windNoiseWenz10k(opts)
%
% opts (全可选):
%   Fs(48000), duration(120), w_ms(10), fmin(10), fmax(10000)
%   sigma_ln(0.6, 自然对数), env_lp_hz(2.0)
%   Nfir(2048), design_points(4096), seed(42)
%   saveWav(false), wavName('wind_noise_wenz_10k.wav')

% ---------- defaults ----------
if nargin<1, opts = struct(); end
Fs    = g(opts,'Fs',48000);
dur   = g(opts,'duration',120);
w_ms  = g(opts,'w_ms',10);
fmin  = g(opts,'fmin',10);
fmax  = g(opts,'fmax',10000);
sigma_ln = g(opts,'sigma_ln',0.6);       % 自然对数域 std
mu_ln    = -0.5*sigma_ln^2;              % 使 E[e]=1
env_lp_hz= g(opts,'env_lp_hz',2.0);
Nfir  = g(opts,'Nfir',2048);
design_points = g(opts,'design_points',4096);
seed  = g(opts,'seed',42);
saveWav = g(opts,'saveWav',false);
wavName = g(opts,'wavName','wind_noise_wenz_10k.wav');

N = round(Fs*dur);
rng(seed);

% ---------- 1) White noise ----------
white = randn(N,1);

% ---------- 2) Wenz wind-noise spectral target ----------
freqs = linspace(0, Fs/2, design_points);  % Hz
fk = max(freqs/1000, 1e-9);                % kHz
Nw_db = 50 + 7.5*sqrt(w_ms) + 20*log10(fk) - 40*log10(fk + 0.4);
Sw_lin = 10.^(Nw_db/10);

% normalize at 1 kHz
[~,ref_idx] = min(abs(fk - 1.0));
mag = sqrt(Sw_lin / Sw_lin(ref_idx));

% 带外余弦收尾
taper = ones(size(freqs));
if fmin > 0
    idx_below = freqs < fmin;
    if any(idx_below)
        x = freqs(idx_below)/fmin;
        taper(idx_below) = 0.5 - 0.5*cos(pi*x);
    end
end
idx_above = freqs > fmax;
if any(idx_above)
    x = (Fs/2 - freqs(idx_above)) / (Fs/2 - fmax);
    taper(idx_above) = max(0, 0.5 - 0.5*cos(pi*x));
end
mag_tapered = mag .* taper;
mag_tapered(1) = mag_tapered(2);   % 避免 DC 陷

% fir2 需要 [0,1] 归一化频率
F = freqs/(Fs/2);
b = fir2(Nfir, F, mag_tapered);

% ---------- 3) Shaping + stationary lognormal AM ----------
% 护边滤波，避免 FIR 瞬态污染统计
Lh = Nfir + 1;
guard = 4*(Lh-1);
white_ext = randn(N + 2*guard, 1);
shaped_full = filter(b, 1, white_ext);
shaped = shaped_full(guard + (1:N));
shaped = shaped / std(shaped);            % AM 前标准化

% “慢包络”（自然对数参数；均值=1）
[b_lp,a_lp] = butter(2, env_lp_hz/(Fs/2), 'low');
g_env = filtfilt(b_lp, a_lp, randn(N,1));
g_env = (g_env - mean(g_env)) / std(g_env);
envelope = exp(mu_ln + sigma_ln * g_env);
envelope = envelope / mean(envelope);     % 数值保证 E[e]≈1
envelope = max(envelope, realmin);        % >0 防止 log(0)

% 幅度调制
y = envelope .* shaped;

% 可选保存 wav（按峰值归一）
if saveWav
    y_audio = 0.9 * y / max(abs(y));
    audiowrite(wavName, y_audio, Fs);
end

% ---------- 4) Validation ----------
% Welch PSD
win = hamming(8192);
[PSD, f_psd] = pwelch(y, win, floor(0.5*length(win)), 8192, Fs, 'psd');
PSD_db = 10*log10(PSD + 1e-30);
fk_psd = max(f_psd/1000, 1e-9);
Nw_psd_db = 50 + 7.5*sqrt(w_ms) + 20*log10(fk_psd) - 40*log10(fk_psd + 0.4);
[~,ref_idx_psd] = min(abs(f_psd - 1000));
offset = PSD_db(ref_idx_psd) - Nw_psd_db(ref_idx_psd);
Nw_shift = Nw_psd_db + offset;

% slope check 100–10000 Hz
mask = (f_psd >= 100) & (f_psd <= 10000);
p = polyfit(log10(f_psd(mask)), PSD_db(mask), 1);

% lognormal 参数估计（自然对数）
mu_hat = mean(log(envelope));
sigma_hat = std(log(envelope));

% ---------- 输出 ----------
out = struct();
out.Fs = Fs; out.duration = dur; out.N = N;
out.white = white; out.shaped = shaped; out.filter_b = b;
out.freqs = freqs; out.mag_tapered = mag_tapered;
out.envelope = envelope; out.sigma_ln = sigma_ln; out.mu_ln = mu_ln;
out.psd_f = f_psd; out.psd_db = PSD_db; out.wenz_db_shift = Nw_shift;
out.slope_dB_per_dec = p(1);
out.mu_hat = mu_hat; out.sigma_hat = sigma_hat;

% 终端打印
fprintf('Spectral slope (100–10000 Hz): %.2f dB/decade\n', p(1));
fprintf('Envelope mean=%.4f (target=1), std=%.4f\n', mean(envelope), std(envelope));
fprintf('log(env): mu_hat=%.4f (theory=%.4f), sigma_hat=%.4f (theory=%.4f)\n', ...
        mu_hat, mu_ln, sigma_hat, sigma_ln);

end % ===== main =====

% ---------- helpers ----------
function v = g(S, f, d)
if isstruct(S) && isfield(S,f) && ~isempty(S.(f)), v = S.(f); else, v = d; end
end
