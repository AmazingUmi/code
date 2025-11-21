function shipNoiseValidatePlot(meta)
% 验证/绘图（健壮版）
% 图：时域、Welch PSD vs Wenz（形状对齐+RMSE）、矩形窗periodogram（窄线谱）、低频Welch

% ---- 基本量（有就取，没有用默认） ----
P_ref = getf(meta,'P_ref',1e-6);
fs    = getf(meta,'fs',   40000);
y     = getf(meta,'y',    []);
if isempty(y), error('meta.y 为空，无法绘图。请先调用 shipNoiseGenerate 得到 meta。'); end
t     = getf(meta,'t',    (0:numel(y)-1).'/fs);

% ---- 子图1：时域 ----
figure('Position',[80 80 1350 920]);
subplot(2,2,1);
L = min(round(fs*10), numel(y));
plot(t(1:L), y(1:L)); grid on;
xlabel('t [s]'); ylabel('p [Pa]'); title('时域（前10s）');

% ---- 子图2：Welch PSD vs Wenz（形状对齐 + RMSE）----
subplot(2,2,2);
nfftW = 65536;
[Pxx,fW] = pwelch(y, hamming(nfftW), 0.5*nfftW, nfftW, fs, 'psd');
PSD_W_dB = 10*log10(Pxx/P_ref^2);

% 有就用 meta 的 Wenz 曲线，否则现场算一条
if isfield(meta,'S_wenz_dB') && isfield(meta,'fgrid') && ~isempty(meta.S_wenz_dB)
    fgrid    = meta.fgrid(:);
    Wenz_dB  = interp1(fgrid, meta.S_wenz_dB(:), fW, 'linear','extrap');
else
    info = getf(meta,'info', struct());
    SA   = getf(meta,'SA',  getf(info,'SA',  0.6));
    w_ms = getf(meta,'w_ms',getf(info,'w_ms',8  ));
    fk   = max(fW/1000,1e-9);
    Ns = 40 + 20*(SA - 0.5) + 26*log10(fk) - 60*log10(fk + 0.03);
    Nw = 50 + 7.5*sqrt(w_ms)  + 20*log10(fk) - 40*log10(fk + 0.4);
    Nt = -15 + 20*log10(fk);
    Wenz_dB = 10*log10(10.^(Ns/10) + 10.^(Nw/10) + 10.^(Nt/10));
end

mask   = (fW>=10 & fW<=10000);
offset = mean(PSD_W_dB(mask) - Wenz_dB(mask));
rmse_dB = sqrt(mean( (PSD_W_dB(mask) - (Wenz_dB(mask)+offset)).^2 ));

semilogx(fW, PSD_W_dB,'LineWidth',1.2); hold on;
semilogx(fW, Wenz_dB+offset,'--','LineWidth',1.0); grid on;
xlim([10 20000]); xlabel('f [Hz]'); ylabel('PSD [dB re 1\muPa^2/Hz]');
title(sprintf('Welch PSD vs Wenz（RMSE=%.2f dB, 形状对齐）', rmse_dB));
legend('Simulated','Wenz+const');

% ---- 子图3：矩形窗 periodogram（看窄线谱）----
subplot(2,2,3);
Nline = getf(meta,'Nline', 2^19);
Nline = min(Nline, 2^floor(log2(numel(y))));
seg0  = max(1, floor((numel(y)-Nline)/2)+1);
seg1  = seg0 + Nline - 1;
y_seg = y(seg0:seg1);
[PSD_P,fP] = periodogram(y_seg, rectwin(Nline), Nline, fs, 'psd');
PSD_P_dB   = 10*log10(PSD_P/P_ref^2);
plot(fP, PSD_P_dB,'k'); grid on; xlim([0 1000]);
xlabel('f [Hz]'); ylabel('PSD [dB re 1\muPa^2/Hz]');
title(sprintf('Line-resolved Periodogram (Rect)  df=%.4f Hz', fs/Nline));

% 标出轴/叶/边带（缺了就回退默认）
info           = getf(meta,'info', struct());
f_shaft        = getf(info,'f_shaft', getf(info,'prop_rpm',180)/60);
prop_blades    = getf(info,'prop_blades', 4);
f_bpf          = getf(info,'f_bpf', prop_blades*f_shaft);
shaft_harm_max = getf(info,'shaft_harm_max', 8);
blade_harm_max = getf(info,'blade_harm_max',12);
sideband_order = getf(info,'sideband_order', 2);
df_line        = getf(meta,'df_line', fs/2^19);

tones = [];
for h=1:shaft_harm_max
    f0=h*f_shaft; if f0<fs/2, tones(end+1)=round(f0/df_line)*df_line; end %#ok<AGROW>
end
for m=1:blade_harm_max
    fb=m*f_bpf; if fb>=fs/2, break; end
    tones(end+1)=round(fb/df_line)*df_line; %#ok<AGROW>
    for sb=1:sideband_order
        f1=fb+sb*f_shaft; f2=fb-sb*f_shaft;
        if f1<fs/2, tones(end+1)=round(f1/df_line)*df_line; end %#ok<AGROW>
        if f2>0,    tones(end+1)=round(f2/df_line)*df_line; end %#ok<AGROW>
    end
end
tones = unique(tones);
hold on; yl = ylim;
for f0=tones
    if f0<=1000
        line([f0 f0], yl, 'Color',[.7 .1 .1],'LineStyle',':','LineWidth',0.6);
    end
end
hold off;

% ---- 子图4：低频 Welch 高分辨率 ----
subplot(2,2,4);
NFFT = 131072;
[Pxx_h,f_h] = pwelch(y, hamming(NFFT), NFFT/2, NFFT, fs, 'psd');
plot(f_h, 10*log10(Pxx_h/P_ref^2)); grid on; xlim([0 400]);
xlabel('f [Hz]'); ylabel('PSD [dB re 1\muPa^2/Hz]');
title('Welch 高分辨率（0–400 Hz）');

sgtitle('Ship Noise — Validate');

end

% ---- 小工具：安全取字段（无则给默认）----
function val = getf(S, field, default)
if isstruct(S) && isfield(S, field) && ~isempty(S.(field))
    val = S.(field);
else
    val = default;
end
end
