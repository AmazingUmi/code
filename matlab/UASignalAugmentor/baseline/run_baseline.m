function run_baseline(label)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RUN_BASELINE UASA 行为基线（characterization）脚本
%   目的：冻结当前 UASignalAugmentor 各阶段的行为快照，用于后续
%   behavior-preserving 重构的前后比对。本脚本不验证"科学正确性"。
%
% 重要约定：
%   - 只调用 function/ 下的生产函数，绝不修改任何生产代码
%   - 所有生成文件写入系统临时目录（仓库外），仓库只保留报告
%   - A1 参数取自 A1WavTransformer.m 当前默认值（FreqRange=[10,200],
%     cut_Tlength=1, threshold=0.05）——CURRENT BEHAVIOR
%   - A4 参数取自 A4ArrProcessor.m（MAX_FREQ_LIMIT=5000,
%     AMP_THRESHOLD_RATIO=0.05）——CURRENT BEHAVIOR
%   - A5 参数取自 A5RecSigSynthesizer.m（Amp_source=1e5, fs=52734
%     硬编码）——CURRENT BEHAVIOR，原样记录，不修正
%   - 随机性：TargSigGenerator 内部 randi 无种子。生产默认行为 =
%     不设 rng（记录两次调用是否一致）；test-controlled seed =
%     在本脚本外部 rng(42)（与生产行为明确区分）
%   - CallBell 二进制依赖 DYLD_LIBRARY_PATH 注入（homebrew libomp/
%     libgfortran），属环境依赖，见报告 S4 节
%
% 用法（在 baseline/ 目录下）：
%   matlab -batch "run_baseline('run1')"   % 首次运行建立 reference
%   matlab -batch "run_baseline('run2')"   % 第二次运行做确定性比对
%
% 输出：
%   baseline/output/baseline_report_<label>.md
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1, label = 'run1'; end

addpath(fullfile(fileparts(mfilename('fullpath')), 'function'));  % <root>/function
root = uasa_project_root();   % 等价于原 fileparts(fileparts(...)) 推导

workroot = fullfile(tempdir, 'opencode', 'uasa_baseline');
work = fullfile(workroot, label);
if exist(work, 'dir'), rmdir(work, 's'); end
mkdir(work);

outdir = fullfile(root, 'baseline', 'output');
if ~exist(outdir, 'dir'), mkdir(outdir); end

L = {};

    function pr(s)
        fprintf('%s\n', s);
        L{end+1} = s; %#ok<AGROW>
    end

pr(sprintf('# UASA 行为基线报告 — %s', label));
pr(sprintf('- 运行时间: %s', datestr(now, 'yyyy-mm-dd HH:MM:SS')));
pr(sprintf('- 本脚本目录: %s', fullfile(root, 'baseline')));
pr(sprintf('- 临时工作目录(仓库外): %s', work));

%% ================= S0 环境记录 =================
pr('');
pr('## S0 运行环境');
pr(sprintf('- MATLAB version: %s', version));
pr(sprintf('- computer: %s, ismac=%d', computer, ismac));
try
    gcount = gpuDeviceCount;
catch
    gcount = 0;
end
pr(sprintf('- gpuDeviceCount: %d  (Apple Silicon 上 MATLAB GPU 通常为 0 → TargSigGenerator 生产默认走 CPU 路径)', gcount));
rs = rng;
if isfield(rs, 'Substream')
    pr(sprintf('- rng 生产默认(未显式设置): Type=%s, Seed=%d, Substream=%d', rs.Type, rs.Seed, rs.Substream));
else
    pr(sprintf('- rng 生产默认(未显式设置): Type=%s, Seed=%d', rs.Type, rs.Seed));
end

%% ================= S1 A1 频率提取 =================
pr('');
pr('## S1 A1 — wavfreq + wavfilter（生产参数，CURRENT BEHAVIOR）');

wavfile = fullfile(root, 'data', 'raw', 'Class A', '46__23_07_13_H3_bateero1.wav');
pr('- 测试样本: data/raw/Class A/46__23_07_13_H3_bateero1.wav (仓库已跟踪的最小 wav)');

FreqRange = [10, 200]; cut_Tlength = 1; threshold = 0.05;
pr(sprintf('- 参数(照抄 A1WavTransformer.m): FreqRange=[%g %g], cut_Tlength=%g, threshold=%g', ...
    FreqRange, cut_Tlength, threshold));

[fs, Ndelay, Analyrecord, Analy_freq_raw] = wavfreq(wavfile, FreqRange, cut_Tlength);
info = audioinfo(wavfile);
pr(sprintf('- audioinfo: fs=%g Hz, TotalSamples=%d, Duration=%.3f s, BitsPerSample=%d, NumChannels=%d', ...
    info.SampleRate, info.TotalSamples, info.Duration, info.BitsPerSample, info.NumChannels));
pr(sprintf('- wavfreq 输出: fs=%g, 分段数 N=%d, Ndelay=[%g ... %g] 步长=%g', ...
    fs, numel(Ndelay), Ndelay(1), Ndelay(end), Ndelay(2)-Ndelay(1)));

nseg = numel(Analyrecord);
cnts = zeros(nseg,1);
for i = 1:nseg, cnts(i) = numel(Analyrecord(i).Amp); end
pr(sprintf('- 滤波前 Analyrecord: 段数=%d, 每段频率数 min/max/mean=%.0f/%.0f/%.1f', ...
    nseg, min(cnts), max(cnts), mean(cnts)));
pr(sprintf('- 滤波前 Analy_freq_raw: numel=%d, min=%.1f, max=%.1f', ...
    numel(Analy_freq_raw), min(Analy_freq_raw), max(Analy_freq_raw)));

[ArF, AfF] = wavfilter(Analyrecord, threshold);
cntf = zeros(nseg,1);
for i = 1:nseg, cntf(i) = numel(zero2empty(ArF(i).Amp)); end
pr(sprintf('- 滤波后 Analyrecord: 每段频率数 min/max/mean=%.0f/%.0f/%.1f', ...
    min(cntf), max(cntf), mean(cntf)));
pr(sprintf('- 滤波后 Analy_freq_filtered: numel=%d, min=%.4g, max=%.4g, mean=%.6g, std=%.6g', ...
    numel(AfF), min(AfF), max(AfF), mean(AfF), std(AfF)));

allAmp = []; allPha = [];
for i = 1:nseg
    a = zero2empty(ArF(i).Amp); p = zero2empty(ArF(i).phase);
    if ~isempty(a), allAmp = [allAmp; a(:)]; allPha = [allPha; p(:)]; end %#ok<AGROW>
end
pr(sprintf('- 滤波后全局幅值: n=%d, NaN=%d, Inf=%d, min=%.6g, max=%.6g, mean=%.6g, std=%.6g', ...
    numel(allAmp), sum(isnan(allAmp)), sum(isinf(allAmp)), min(allAmp), max(allAmp), mean(allAmp), std(allAmp)));
pr(sprintf('- 滤波后全局相位(rad): min=%.6g, max=%.6g, mean=%.6g, std=%.6g', ...
    min(allPha), max(allPha), mean(allPha), std(allPha)));

% 与仓库已提交的历史 A1 产物对比（信息性，非判定——历史产物可能由不同参数生成）
commSig = fullfile(root, 'data', 'processed', 'Class A_46__23_07_13_H3_bateero1.mat');
S = load(commSig);
pr(sprintf('- 已提交产物 Class A_*.mat: fs=%g, Ndelay numel=%d, Analy_freq numel=%d, min=%.4g, max=%.4g', ...
    S.fs, numel(S.Ndelay), numel(S.Analy_freq), min(S.Analy_freq), max(S.Analy_freq)));
A = load(fullfile(root, 'data', 'processed', 'Analy_freq_all.mat'));
afa = A.Analy_freq_all(:);
pr(sprintf('- 已提交产物 Analy_freq_all.mat: numel=%d, min=%.4g, max=%.4g, mean=%.6g, std=%.6g', ...
    numel(afa), min(afa), max(afa), mean(afa), std(afa)));
pr(sprintf('- 信息性对比: 本次 fs 与已提交 fs 一致: %s；本次 AfF 与已提交 Analy_freq 交集数=%d', ...
    num2str(isequal(fs, S.fs)), numel(intersect(AfF, S.Analy_freq))));

S1ref = struct('fs', fs, 'N', nseg, 'nAfF', numel(AfF), 'AfFsum', sum(AfF), 'maxAmp', max(allAmp));

%% ================= S2 A2 环境文件生成（最小单点） =================
pr('');
pr('## S2 A2 — ConfigDeep + load_data + FileMaker（单站点单距离，CURRENT BEHAVIOR）');

C = load(fullfile(root, 'data', 'OriginEnvPack', 'ConfigDeep.mat'));
pr(sprintf('- ConfigDeep.mat 字段: %s', strjoin(fieldnames(C), ', ')));
pr(sprintf('  Site_loc.zone=%s, 站点数=%d, ReceiveRange=%s, ReceiveDepth=%s', ...
    C.Site_loc.zone, numel(C.Site_loc.lat), mat2str(C.Site_loc.ReceiveRange), mat2str(C.Site_loc.ReceiveDepth)));
pr(sprintf('  Source: SourceRange=%g, SourceDepth=%g, azi=%g, freq=%g, freqvec=%g, timeIdx=%d', ...
    C.Source.SourceRange, C.Source.SourceDepth, C.Source.azi, C.Source.freq, C.Source.freqvec, C.Source.timeIdx));
pr(sprintf('  Cal: top_sea_state_level=%g, mesoscale.type=%s, bottom_base_type=%s, bottom_alpha_b=%g, Beam.RunType=%s, Beam.Type=%s', ...
    C.Cal.top_sea_state_level, C.Cal.mesoscale.type, C.Cal.bottom_base_type, C.Cal.bottom_alpha_b, C.Cal.Beam.RunType, C.Cal.Beam.Type));

[ETOPO, WOA] = load_data(fullfile(root, 'data', 'OceanData'), 'ETOPO2022.mat', 'woa23_%02d.mat');
pr(sprintf('- load_data: ETOPO.Lon n=%d, ETOPO.Lat n=%d, WOA.Data cells=%d (索引1-12月,13-16季,17年)', ...
    numel(ETOPO.Lon), numel(ETOPO.Lat), numel(WOA.Data)));

% 完全照抄 A2ENVmaker.m 的 Config_out 组装方式（含其当前行为：每个模板都带完整 ReceiveRange）
Config_out.Cal = C.Cal; Config_out.Source = C.Source;
Config_out.Receiver = []; Config_out.Loc = [];
Config_out.Receiver.ReceiveDepth = C.Site_loc.ReceiveDepth;
Config_out.Receiver.ReceiveRange = C.Site_loc.ReceiveRange;
coordS.lon = C.Site_loc.lon(1); coordS.lat = C.Site_loc.lat(1);
Config_out.Loc.coordS = coordS;
[~, coordE, ~, ~] = coord_proc(coordS, [], C.Site_loc.ReceiveRange, C.Source.azi);
Config_out.Loc.coordE = coordE;
pr(sprintf('- 站点1: coordS=(%.3f,%.3f) → coordE 末端=(%.4f,%.4f)', ...
    coordS.lon, coordS.lat, coordE.lon(end), coordE.lat(end)));

envDir = fullfile(work, 'Deep', 'ENV1', 'Rr1', 'EnvTemplate');
mkdir(envDir);
EnvFileName = 'ENV_1_Rr5Km';
prevcwd = cd(envDir);
FileMaker(ETOPO, WOA, EnvFileName, Config_out);
cd(prevcwd);

d = dir(envDir);
pr('- FileMaker 生成文件（名称, 字节）:');
for k = 1:numel(d)
    if ~strcmp(d(k).name, '.') && ~strcmp(d(k).name, '..')
        pr(sprintf('    %s, %d', d(k).name, d(k).bytes));
    end
end
show_file(@pr, fullfile(envDir, [EnvFileName, '.env']), 30);
show_file(@pr, fullfile(envDir, [EnvFileName, '.bty']), 4);
show_file(@pr, fullfile(envDir, [EnvFileName, '.ssp']), 4);
show_file(@pr, fullfile(envDir, [EnvFileName, '.trc']), 3);
show_file(@pr, fullfile(envDir, [EnvFileName, '.brc']), 3);

%% ================= S3 A3 频率扩展（缩减集，TEST-CONTROLLED） =================
pr('');
pr('## S3 A3 — FreqDuplicator（TEST-CONTROLLED 缩减频率集）');

% 生产行为 = 对整个 Analy_freq_all 复制；此处为控制 bellhop 成本取前5个
% 与信号频率有交集的频率（保证 S6 频率耦合），已在文档标注为缩减集。
inter = intersect(afa, S.Analy_freq);
nsub = min(5, numel(inter));
FreqSubset = inter(1:nsub);
pr(sprintf('- 完整 Analy_freq_all 长度=%d；本基线缩减集长度=%d: [%s]', ...
    numel(afa), nsub, strjoin(string(FreqSubset), ', ')));

FreqDuplicator(envDir, [], envDir, FreqSubset, ...
    C.Cal.top_sea_state_level, C.Cal.bottom_base_type, C.Cal.bottom_alpha_b);

d3 = dir(fullfile(envDir, 'test_*'));
pr(sprintf('- FreqDuplicator 生成 test_* 文件数=%d（每频率5件套 env/bty/ssp/trc/brc）', numel(d3)));
listfile = fullfile(envDir, 'env_files_list.txt');
lf = fileread(listfile);
pr('- env_files_list.txt 内容（CallBell 协议输入）:');
pr(sprintf('    %s', strjoin(regexp(lf, '\r?\n', 'split'), ' | ')));
envtxt = fileread(fullfile(envDir, 'test_1.env'));
tpltxt = fileread(fullfile(envDir, [EnvFileName, '.env']));
pr(sprintf('- test_1.env 与模板 .env 文本完全一致: %s（一致说明本旧版实现未逐频率改写env体, 差异定位见下）', ...
    num2str(isequal(envtxt, tpltxt))));
[tf, ldiff] = differs_at(envtxt, tpltxt);
if ldiff > 0
    pr(sprintf('  → 首个差异出现在字符偏移 %d 附近（预期为频率行）', ldiff));
end

%% ================= S4 CallBell 运行 BELLHOP =================
pr('');
pr('## S4 CallBell — BellParallelMac 协议运行（真实 bellhop 计算）');

bellmac = fullfile(root, 'CallBell', 'mac');
libomp = '/opt/homebrew/Cellar/libomp/20.1.5/lib';
libgfortran = '/opt/homebrew/Cellar/gcc/14.2.0_1/lib/gcc/current';
% 注意：MATLAB 为签名进程，setenv 的 DYLD_* 不会传入 system() 子进程，
% 必须在子 shell 命令内联 export（环境依赖，见 BEHAVIOR_BASELINE.md）。
pr(sprintf('- DYLD_LIBRARY_PATH 注入(子shell内联): %s ; %s', libomp, libgfortran));
pr('  (二进制 rpath 指向的 ~/miniconda3/lib/{libomp,libgfortran.5}.dylib 在本机不存在 → 环境漂移，属环境依赖非仓库缺陷)');

cmd = sprintf('export DYLD_LIBRARY_PATH="%s:%s"; cd "%s" && ./BellParallelMac "%s"', ...
    libomp, libgfortran, bellmac, envDir);
[st, outmsg] = system(cmd);
pr(sprintf('- BellParallelMac 退出码=%d', st));
outlines = regexp(strtrim(outmsg), '\r?\n', 'split');
for k = 1:min(numel(outlines), 6), pr(sprintf('    %s', outlines{k})); end
arrfiles = dir(fullfile(envDir, '*.arr'));
pr(sprintf('- 生成 .arr 文件数=%d', numel(arrfiles)));

if numel(arrfiles) == 0
    % 回退（功能等价，如实记录）：BellParallelMac 内部 system() 再经 /bin/sh 时
    % DYLD_* 被平台二进制剥离，bellhop.exe 无法继承 → 直接逐个调用 bellhop.exe，
    % 调用约定与 BellParallelMac 相同（cwd=目标目录，参数=env 文件名）。
    pr('- 回退: 直接调用 bellhop.exe（等价调用约定）');
    % 注意：env_files_list.txt 末行可能无换行符（本次实测），`while read` 会漏掉
    % 最后一项 → 改用 for 循环。文件名无空格，此处安全。
    loopcmd = sprintf(['export DYLD_LIBRARY_PATH="%s:%s"; cd "%s" && ', ...
        'for f in $(cat env_files_list.txt); do "%s/bellhop.exe" "$f" < /dev/null; done'], ...
        libomp, libgfortran, envDir, bellmac);
    [st2, outmsg2] = system(loopcmd);
    pr(sprintf('- bellhop.exe 循环退出码=%d', st2));
    outlines2 = regexp(strtrim(outmsg2), '\r?\n', 'split');
    for k = 1:min(numel(outlines2), 4), pr(sprintf('    %s', outlines2{k})); end
    arrfiles = dir(fullfile(envDir, '*.arr'));
    pr(sprintf('- 生成 .arr 文件数=%d（回退后）', numel(arrfiles)));
end

if numel(arrfiles) >= 1
    show_file(@pr, fullfile(envDir, 'test_1.arr'), 14);
else
    pr('- 阻断: bellhop 未产出 .arr，S5/S6 将无法动态执行');
end

%% ================= S5 A4 到达结构解析 =================
pr('');
pr('## S5 A4 — read_arrivals_asc + ArrReader（生产参数）');
if numel(arrfiles) >= 1
    [Arr1, Pos1] = read_arrivals_asc(fullfile(envDir, 'test_1.arr'));
    pr(sprintf('- test_1.arr: Pos.freq=%g, 接收深度 Pos.r.z=%s, 接收距离=%s', ...
        Pos1.freq, mat2str(Pos1.r.z), mat2str(Pos1.r.r)));
    % 本仓库 read_arrivals_asc 返回 Arr(irr,irz,isd)，字段 .Narr/.A/.delay
    numarr = [Arr1.Narr];
    pr(sprintf('- 每接收点声线数 Narr: min=%d, max=%d, 总和=%d', min(numarr), max(numarr), sum(numarr)));

    ArrReader(cellstr(readlines(listfile)), envDir, 5000, 0.05);
    E = load(fullfile(work, 'Deep', 'ENV1', 'Rr1', 'ENV_ARR_less.mat'));
    ARR = E.ARR;
    [nf, nd] = size(ARR);
    pr(sprintf('- ENV_ARR_less.mat: ARR 尺寸=%dx%d (频率×深度), 字段=%s', ...
        nf, nd, strjoin(fieldnames(ARR), ',')));
    allD = []; allA2 = []; allP = [];
    for m2 = 1:nf
        for n2 = 1:nd
            allD = [allD; ARR(m2,n2).Delay(:)]; %#ok<AGROW>
            allA2 = [allA2; ARR(m2,n2).Amp(:)]; %#ok<AGROW>
            allP = [allP; ARR(m2,n2).phase(:)]; %#ok<AGROW>
        end
    end
    pr(sprintf('- ARR.Delay(s): n=%d, NaN=%d, min=%.6g, max=%.6g, mean=%.6g, std=%.6g', ...
        numel(allD), sum(isnan(allD)), min(allD), max(allD), mean(allD), std(allD)));
    pr(sprintf('- ARR.Amp: n=%d, NaN=%d, min=%.6g, max=%.6g, mean=%.6g, std=%.6g', ...
        numel(allA2), sum(isnan(allA2)), min(allA2), max(allA2), mean(allA2), std(allA2)));
    pr(sprintf('- ARR.phase(rad): n=%d, min=%.6g, max=%.6g', numel(allP), min(allP), max(allP)));
    pr(sprintf('- ARR(1,1): freq=%g, rd=%g, 声线数=%d; ARR(end,end): freq=%g, rd=%g, 声线数=%d', ...
        ARR(1,1).freq, ARR(1,1).rd, numel(ARR(1,1).Amp), ...
        ARR(end,end).freq, ARR(end,end).rd, numel(ARR(end,end).Amp)));
else
    pr('- 跳过（S4 未产出 .arr）');
end

%% ================= S6 A5 信号合成（随机性对照） =================
pr('');
pr('## S6 A5 — TargSigGenerator（Amp_source=1e5, fs=52734 硬编码，CURRENT BEHAVIOR）');
if numel(arrfiles) >= 1
    % 模拟 SignalPatchGenerator 的取行与频率耦合方式（第1个接收深度）。
    % 生产契约: ArrRDSig = ARRSingleRD(idx,:) —— 每个信号频率一行（生产中
    % 信号频率 ⊆ Analy_freq_all, idx 无 0）。本缩减基线中缩减频率集只有5个，
    % 信号147个频率中的未命中者用空模板行占位（生产代码 isempty(delay0)→continue
    % 的跳过语义与"未命中"一致），保持 TargSigGenerator 的输入契约不变。
    ARRSingleRD = ARR(:, 1);
    [~, idx] = ismember(S.Analy_freq, FreqSubset);
    pr(sprintf('- 信号频率与缩减集耦合: 信号频率数=%d, 命中=%d', numel(S.Analy_freq), sum(idx > 0)));
    tmplrow = struct('Amp', [], 'Delay', [], 'phase', [], 'freq', [], 'rd', []);
    ArrRDSig = repmat(tmplrow, numel(S.Analy_freq), 1);
    hit = idx > 0;
    ArrRDSig(hit) = ARRSingleRD(idx(hit));

    args = {S.Analyrecord, S.Analy_freq, ArrRDSig, 1e5, 52734, S.Ndelay};

    % (a) 生产默认行为：不设 rng，连续两次。
    %     生产传 TargSegNum=[]（全段）→ StartMax=AnalyrecordNum-N+1=1 →
    %     randi(1) 恒为 1 → 尽管无种子，生产路径输出仍然确定（实测）。
    [sigA1, tA1] = TargSigGenerator(args{:});
    [sigA2, tA2] = TargSigGenerator(args{:});
    pr(sprintf('- 生产默认(无rng,全段) 两次调用输出完全一致: %s', num2str(isequal(sigA1, sigA2))));
    pr('  → randi 无种子但 StartMax=1 → randi(1)≡1（CURRENT BEHAVIOR：A5 生产路径确定；随机性仅在 TargSegNum<N 时暴露，见 PROBE）');
    pr(sprintf('  第1次: len=%d, min=%.6g, max=%.6g, mean=%.6g, std=%.6g, NaN=%d, Inf=%d', ...
        numel(sigA1), min(sigA1), max(sigA1), mean(sigA1), std(sigA1), sum(isnan(sigA1)), sum(isinf(sigA1))));
    pr(sprintf('  第2次: len=%d, min=%.6g, max=%.6g, mean=%.6g, std=%.6g', ...
        numel(sigA2), min(sigA2), max(sigA2), mean(sigA2), std(sigA2)));
    pr(sprintf('  TargT 末值: %.6g s', tA1(end)));
    pr(sprintf('  两次长度一致: %s (StartSeg 随机 → 若一致属巧合)', num2str(isequal(numel(sigA1), numel(sigA2)))));

    % (b) test-controlled seed：外部 rng(42) 两次
    rng(42, 'twister'); [sigB1, ~] = TargSigGenerator(args{:});
    rng(42, 'twister'); [sigB2, ~] = TargSigGenerator(args{:});
    pr(sprintf('- test-controlled rng(42) 两次调用输出完全一致: %s', num2str(isequal(sigB1, sigB2))));
    pr(sprintf('  seeded: len=%d, min=%.6g, max=%.6g, mean=%.6g, std=%.6g, NaN=%d, Inf=%d', ...
        numel(sigB1), min(sigB1), max(sigB1), mean(sigB1), std(sigB1), sum(isnan(sigB1)), sum(isinf(sigB1))));
    p5 = sprintf(' %.17g', sigB1(1:min(5, end)));
    pr(sprintf('  seeded 前5样本(高精度参考值):%s', p5));

    % (c) PROBE（非生产路径）: 生产 SignalPatchGenerator 传 TargSegNum=[]（全段）
    %     → StartMax=1 → randi(1) 恒为 1 → 生产路径实际确定。此探针显式传
    %     TargSegNum=10 (<11) 以暴露 randi 的潜伏随机性。
    rng('default'); [sigC1, ~] = TargSigGenerator(args{:}, 10);
    rng('default'); [sigC2, ~] = TargSigGenerator(args{:}, 10);
    rng('default'); [sigC3, ~] = TargSigGenerator(args{:}, 10);
    pr(sprintf('- PROBE TargSegNum=10: 三次调用(len=%d/%d/%d) 两两一致: %s/%s/%s', ...
        numel(sigC1), numel(sigC2), numel(sigC3), ...
        num2str(isequal(sigC1, sigC2)), num2str(isequal(sigC1, sigC3)), num2str(isequal(sigC2, sigC3))));
    rng(42, 'twister'); [sigC4, ~] = TargSigGenerator(args{:}, 10);
    rng(42, 'twister'); [sigC5, ~] = TargSigGenerator(args{:}, 10);
    pr(sprintf('  PROBE rng(42)+TargSegNum=10 两次一致: %s, len=%d', ...
        num2str(isequal(sigC4, sigC5)), numel(sigC4)));
    pr(sprintf('  PROBE sigC4 统计: min=%.6g, max=%.6g, mean=%.6g, std=%.6g', ...
        min(sigC4), max(sigC4), mean(sigC4), std(sigC4)));
    % PROBE2: 同一会话内不重置连续两次（流推进）→ 演示真正的无种子随机性
    rng('default'); [sigD1, ~] = TargSigGenerator(args{:}, 10);
    [sigD2, ~] = TargSigGenerator(args{:}, 10);   % 不重置，randi 取流中下一个值
    pr(sprintf('  PROBE2 会话内不重置连续两次(TargSegNum=10) 一致: %s（len=%d/%d）', ...
        num2str(isequal(sigD1, sigD2)), numel(sigD1), numel(sigD2)));
else
    pr('- 跳过（S4 未产出 .arr）');
end

%% ================= S7 跨运行比对 =================
pr('');
pr('## S7 跨运行确定性比对');
refdir = fullfile(workroot, 'reference');
if strcmp(label, 'run1')
    % 保存 reference：S1 数值 + S2 模板文本 + S5 ARR + S6 seeded 信号
    if exist(refdir, 'dir'), rmdir(refdir, 's'); end
    mkdir(refdir);
    S1ref.AfF = AfF;
    save(fullfile(refdir, 'ref.mat'), 'S1ref');
    for k = 1:numel(d)
        if ~strcmp(d(k).name, '.') && ~strcmp(d(k).name, '..')
            copyfile(fullfile(envDir, d(k).name), fullfile(refdir, ['tpl_', d(k).name]));
        end
    end
    if exist(fullfile(work, 'Deep', 'ENV1', 'Rr1', 'ENV_ARR_less.mat'), 'file')
        copyfile(fullfile(work, 'Deep', 'ENV1', 'Rr1', 'ENV_ARR_less.mat'), fullfile(refdir, 'ENV_ARR_less.mat'));
    end
    if exist('sigB1', 'var'), save(fullfile(refdir, 'sigB1.mat'), 'sigB1'); end
    pr('- 本次为 run1，已建立 reference（临时目录，仓库外）');
else
    R = load(fullfile(refdir, 'ref.mat'));
    pr(sprintf('- S1 一致性: fs=%s, N=%s, AfF numel=%s, AfF 向量一致=%s, maxAmp=%s', ...
        num2str(S1ref.fs == R.S1ref.fs), num2str(S1ref.N == R.S1ref.N), ...
        num2str(S1ref.nAfF == R.S1ref.nAfF), num2str(isequal(AfF, R.S1ref.AfF)), ...
        num2str(S1ref.maxAmp == R.S1ref.maxAmp)));
    sameFiles = true;
    for k = 1:numel(d)
        nm = d(k).name;
        if ~strcmp(nm, '.') && ~strcmp(nm, '..')
            refnm = fullfile(refdir, ['tpl_', nm]);
            if exist(refnm, 'file')
                f1 = fileread(fullfile(envDir, nm));
                f2 = fileread(refnm);
                if ~isequal(f1, f2), sameFiles = false; pr(sprintf('  差异: %s', nm)); end
            end
        end
    end
    pr(sprintf('- S2: FileMaker 模板文件跨运行字节级一致=%s', num2str(sameFiles)));
    if exist(fullfile(work, 'Deep', 'ENV1', 'Rr1', 'ENV_ARR_less.mat'), 'file')
        E2 = load(fullfile(work, 'Deep', 'ENV1', 'Rr1', 'ENV_ARR_less.mat'));
        E1 = load(fullfile(refdir, 'ENV_ARR_less.mat'));
        pr(sprintf('- S5: ARR 跨运行 isequal=%s', num2str(isequal(E1.ARR, E2.ARR))));
    end
    if exist('sigB1', 'var') && exist(fullfile(refdir, 'sigB1.mat'), 'file')
        R6 = load(fullfile(refdir, 'sigB1.mat'));
        pr(sprintf('- S6: seeded TargSig 跨运行 isequal=%s', num2str(isequal(R6.sigB1, sigB1))));
    end
end

pr('');
pr('--- 报告结束 ---');

fid = fopen(fullfile(outdir, ['baseline_report_', label, '.md']), 'w');
fprintf(fid, '%s\n', L{:});
fclose(fid);
fprintf('报告已写入: %s\n', fullfile(outdir, ['baseline_report_', label, '.md']));
end

function show_file(prh, fpath, nmax)
    txt = regexp(fileread(fpath), '\r?\n', 'split');
    prh(sprintf('--- %s (前%d行, 共%d行) ---', fpath, min(nmax, numel(txt)), numel(txt)));
    for k = 1:min(nmax, numel(txt))
        prh(sprintf('%4d| %s', k, txt{k}));
    end
end

function x = zero2empty(x)
    if isnumeric(x) && isscalar(x) && x == 0, x = []; end
end

function [tf, loc] = differs_at(a, b)
    tf = isequal(a, b);
    loc = 0;
    if ~tf
        n = min(numel(a), numel(b));
        for k = 1:n
            if a(k) ~= b(k), loc = k; break; end
        end
        if loc == 0, loc = n + 1; end
    end
end
