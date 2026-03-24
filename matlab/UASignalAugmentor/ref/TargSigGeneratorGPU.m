function [TargSig, TargT] = TargSigGeneratorGPU(AnalyRecord, AnalyFreq, ...
    ArrRDSig, Amp_source, fs, Ndelay, TargSegNum, useGPU, BatchSize)
% TargSigGenerator 合成目标接收信号
%
% 输入:
%   AnalyRecord - 信号分段记录结构体数组
%   AnalyFreq   - 信号频率数组 (Hz)
%   ArrRDSig    - 到达结构数据 (包含 Delay, Amp, phase)
%   Amp_source  - 源强度标量
%   fs          - 采样率 (Hz)
%   Ndelay      - 分段时间索引向量 (秒)
%   TargSegNum  - (可选) 需要生成的连续段数。如果不输入，默认生成所有段。
%   useGPU      - (可选) 是否使用 GPU 加速 (true/false)。如果不输入，自动检测。
%   BatchSize   - (可选) GPU 计算时的批处理大小。默认为 1 (不启用批处理)。
%                 设置较大的值 (如 100) 可以显著提高 GPU 利用率，但会消耗更多显存。
%
% 输出:
%   TargSig     - 合成的接收信号 (实数向量)
%   TargT       - 对应的修剪后的时间序列向量

% 计算片段长度
NdelayLength = Ndelay(2) - Ndelay(1);
AnalyrecordNum = length(AnalyRecord);  % 分段信号全部段数
% 处理目标信号的分段的段数
if nargin < 7 || isempty(TargSegNum) || TargSegNum == 0
    TargSegNum = AnalyrecordNum;
elseif TargSegNum > AnalyrecordNum
    warning('TargSigGenerator:SegNumOverflow', ...
        '请求的段数 (%d) 大于可用段数 (%d)，将使用全部可用段数。', ...
        TargSegNum, AnalyrecordNum);
    TargSegNum = AnalyrecordNum;
end

% 检查 GPU 可用性
if nargin < 8 || isempty(useGPU)
    try
        useGPU = (gpuDeviceCount > 0);
    catch
        useGPU = false;
    end
else
    % 如果用户强制开启，检查是否有设备
    if useGPU
        try
            if gpuDeviceCount == 0
                warning('TargSigGenerator:NoGPU', '请求使用 GPU 但未检测到设备，将回退到 CPU。');
                useGPU = false;
            end
        catch
            useGPU = false;
        end
    end
end

if nargin < 9 || isempty(BatchSize)
    BatchSize = 1;
end

%%%%%%%%%%%%%%%%%%%%%%%%%开始计算%%%%%%%%%%%%%%%%%%%%%%%
% 预计算每个频率的最小时延，避免在循环中重复调用 min()
numFreqs = length(ArrRDSig);
min_delay_lookup = zeros(numFreqs, 1);
all_delays_cell = {ArrRDSig.Delay}; % 使用 cell array 避免结构体数组访问开销

% 向量化获取所有 delay 用于计算全局极值
% 注意：这里假设 ArrRDSig 中的 Delay 都是列向量或行向量
allDelays = [all_delays_cell{:}];

if isempty(allDelays)
    MAXdelay = 0;
    MINdelay = 0;
else
    MAXdelay = max(allDelays);
    MINdelay = min(allDelays);
end

% 填充 min_delay_lookup
for k = 1:numFreqs
    if ~isempty(all_delays_cell{k})
        min_delay_lookup(k) = min(all_delays_cell{k});
    end
end

StartMax = AnalyrecordNum - TargSegNum + 1;
StartSeg = randi(StartMax);
% 段数小于总段数时所需的对于原始信号AnalyRecord的索引
SegIndex = StartSeg : (StartSeg + TargSegNum - 1);

% 初始化目标信号
TargSigLength = double(ceil((MAXdelay - MINdelay + TargSegNum + 0.01) * fs));  % 目标信号长度
TargT   = (0:TargSigLength-1) / fs;  % 目标信号时间序列



if useGPU
    TargSig = gpuArray.zeros(size(TargT));
else
    TargSig = zeros(size(TargT));
end

if useGPU && BatchSize > 1
    % =================================================================
    % GPU 频率聚合模式 (Frequency Aggregation Mode)
    % =================================================================

    % 1. 收集所有段的频率信息，构建频率到段的映射
    % ---------------------------------------------------------
    % 我们需要知道：对于每个唯一频率，它在哪些段出现，对应的 Amp, Phase, TimeOffset 是多少
    
    % 预估总点数以分配内存
    total_points = 0;
    for ii = 1:TargSegNum
        total_points = total_points + length(AnalyRecord(SegIndex(ii)).freq);
    end
    
    % 临时存储所有段数中的频率（不同段可重复的）及其属性
    All_Freqs = zeros(total_points, 1);
    All_Amps  = zeros(total_points, 1);
    All_Phas  = zeros(total_points, 1);
    All_TimeOffsets = zeros(total_points, 1);
    
    cursor = 1;
    for ii = 1:TargSegNum
        SegIdx = SegIndex(ii);
        % 原始信号分段成分提取
        seg_freqs = round(AnalyRecord(SegIdx).freq, 4)';
        seg_amps  = AnalyRecord(SegIdx).Amp;
        seg_phas  = AnalyRecord(SegIdx).phase;
        
        num_f = length(seg_freqs);
        range = cursor : cursor + num_f - 1;
        
        All_Freqs(range) = seg_freqs;
        All_Amps(range)  = seg_amps;
        All_Phas(range)  = seg_phas;
        All_TimeOffsets(range) = (Ndelay(ii) - MINdelay);
        
        cursor = cursor + num_f;
    end
    
    % 截断
    valid_len = cursor - 1;
    All_Freqs = All_Freqs(1:valid_len);
    All_Amps  = All_Amps(1:valid_len);
    All_Phas  = All_Phas(1:valid_len);
    All_TimeOffsets = All_TimeOffsets(1:valid_len);
    
    % 2. 找出唯一频率 (Unique Frequencies)
    % ---------------------------------------------------------
    [UniqueFreqs, ~, ic] = unique(All_Freqs);
    numUnique = length(UniqueFreqs);
    
    % 查找这些唯一频率在 ArrRDSig 中的位置
    [~, UniqueLocs] = ismember(UniqueFreqs, AnalyFreq);
    
    % 过滤掉无效频率 (不在 AnalyFreq 中) 或 没有多径数据的频率
    valid_u_mask = (UniqueLocs ~= 0);
    % 进一步检查 Delay 是否为空
    for k = 1:numUnique
        if valid_u_mask(k)
            if isempty(ArrRDSig(UniqueLocs(k)).Delay)
                valid_u_mask(k) = false;
            end
        end
    end
    
    % 仅保留有效的唯一频率
    ValidUniqueFreqs = UniqueFreqs(valid_u_mask);
    ValidUniqueLocs  = UniqueLocs(valid_u_mask);
    
    % 重新映射 ic (Inverse Indices) 以匹配过滤后的列表
    % 这是一个难点：我们需要把原始的 All_Freqs 映射到 ValidUniqueFreqs 的索引上
    % 如果某个原始频率被过滤掉了，它的索引应该是 0
    
    % 构建一个从 原始Unique索引 -> 新Valid索引 的映射表
    old_to_new_map = zeros(numUnique, 1);
    old_to_new_map(valid_u_mask) = 1:length(ValidUniqueFreqs);
    
    % 更新 ic: 现在 ic 中的值对应 ValidUniqueFreqs 的下标，0 表示无效
    NewIC = old_to_new_map(ic);
    
    % 3. 按批次处理唯一频率 (Batch Process Unique Frequencies)
    % ---------------------------------------------------------
    % 我们遍历 ValidUniqueFreqs，每次处理 BatchSize 个频率
    % 对于这一批频率，我们计算它们的波形，然后找到所有引用了这些频率的段进行叠加
    
    numValidUnique = length(ValidUniqueFreqs);
    
    for b_start = 1:BatchSize:numValidUnique
        b_end = min(b_start + BatchSize - 1, numValidUnique);
        curr_batch_size = b_end - b_start + 1;
        
        % 当前批次的频率和位置
        batch_freqs = ValidUniqueFreqs(b_start:b_end);
        batch_locs  = ValidUniqueLocs(b_start:b_end);
        
        % --- 准备多径参数 (与之前相同) ---
        max_P = 0;
        for k = 1:curr_batch_size
            max_P = max(max_P, length(ArrRDSig(batch_locs(k)).Delay));
        end
        
        batch_delays = zeros(curr_batch_size, max_P);
        batch_amps   = zeros(curr_batch_size, max_P);
        batch_phases = zeros(curr_batch_size, max_P);
        batch_min_delays = zeros(curr_batch_size, 1);
        
        for k = 1:curr_batch_size
            loc = batch_locs(k);
            d = ArrRDSig(loc).Delay;
            a = ArrRDSig(loc).Amp';
            p = ArrRDSig(loc).phase;
            len = length(d);
            
            batch_delays(k, 1:len) = d;
            batch_amps(k, 1:len)   = a;
            batch_phases(k, 1:len) = p;
            batch_min_delays(k)    = min_delay_lookup(loc);
            
            if len < max_P
                batch_delays(k, len+1:end) = min(d);
                batch_amps(k, len+1:end)   = 0;
            end
        end
        
        % --- GPU 计算标准波形 (Standard Waveforms) ---
        % 这里我们计算单位幅度 (Amp=1, Phase=0) 的波形
        % 实际的 Amp 和 Phase 将在叠加时应用
        
        g_freqs  = gpuArray(batch_freqs);
        g_delays = gpuArray(batch_delays);
        g_amps   = gpuArray(batch_amps);
        g_phases = gpuArray(batch_phases);
        
        N = round(NdelayLength * fs);
        t_vec = gpuArray.colon(0, N-1) ./ fs;
        
        % 源信号 (单位幅度)
        S = exp(1j * 2 * pi * g_freqs .* t_vec); 
        
        row_mins = min(g_delays, [], 2);
        delay_shift = g_delays - row_mins;
        offsets = floor(delay_shift * fs) + 1;
        path_gains = g_amps .* exp(1j * g_phases);
        
        M_batch = double(gather(ceil((NdelayLength + max(delay_shift(:)) + 0.01) * fs)));
        Y_batch = complex(gpuArray.zeros(curr_batch_size, M_batch));
        
        [B_sz, ~] = size(S); % B_sz 是行数 (当前 Batch 的大小)
        col_step = gpuArray((0:N-1) * B_sz); % 生成列偏移步长
        
        for p = 1:max_P
            off_col = offsets(:, p);
            gain_col = path_gains(:, p);
            if all(abs(gain_col) == 0), continue; end
            
            start_indices = (1:B_sz)' + (off_col - 1) * B_sz;
            IND = start_indices + col_step;
            Y_batch(IND) = Y_batch(IND) + gain_col .* S;
        end
        
        % --- 散射叠加 (Scatter Accumulation) ---
        % 现在的 Y_batch 包含了当前批次频率的标准波形
        % 我们需要找到所有引用了这些频率的原始任务，并进行加权叠加
        
        % 找到所有属于当前 Batch 的原始任务索引
        % NewIC 中的值范围是 1..numValidUnique
        % 当前 Batch 覆盖的范围是 b_start..b_end
        
        % 这是一个逻辑掩码，找出所有引用了当前批次频率的任务
        task_mask = (NewIC >= b_start) & (NewIC <= b_end);
        task_indices = find(task_mask);
        
        if isempty(task_indices)
            continue;
        end
        
        % 提取这些任务的属性
        t_amps   = All_Amps(task_indices);
        t_phas   = All_Phas(task_indices);
        t_offset = All_TimeOffsets(task_indices);
        
        % 对应的频率在 Batch 中的索引 (1..BatchSize)
        t_batch_idx = NewIC(task_indices) - b_start + 1;
        
        % 对应的最小延迟 (用于计算起始位置)
        t_min_delays = batch_min_delays(t_batch_idx);
        
        % 传输到 GPU
        g_t_amps   = gpuArray(t_amps);
        g_t_phas   = gpuArray(t_phas);
        % g_t_offset = gpuArray(t_offset); % 下面计算用 CPU 即可，索引需要是整数
        
        % 计算复数权重
        complex_weights = (Amp_source * g_t_amps) .* exp(1j * g_t_phas);
        
        % 这里的循环无法避免，因为每个任务的 TimeOffset 不同
        % 但我们是在 GPU 上操作，且只是简单的向量加法，速度很快
        % 为了进一步加速，可以将相同 TimeOffset 的任务合并（可选优化）
        
        p_starts = double(floor((t_min_delays + t_offset) * fs) + 1);
        p_starts = max(1, p_starts);
        
        for k = 1:length(task_indices)
            b_idx = t_batch_idx(k);
            ps    = p_starts(k);
            
            % 检查 ps 是否有效 (防止 NaN 或 Inf 导致索引错误)
            if isnan(ps) || isinf(ps)
                % warning('TargSigGeneratorGPU:InvalidIndex', 'Calculated start index is NaN or Inf. Skipping task.');
                continue;
            end
            
            weight = complex_weights(k);
            
            y_row = Y_batch(b_idx, :);
            
            len = min(M_batch, TargSigLength - ps + 1);
            if len > 0
                idx_rng = ps : ps + len - 1;
                TargSig(idx_rng) = TargSig(idx_rng) + y_row(1:len) * weight;
            end
        end
    end

else
    % =================================================================
    % 传统逐段处理模式 (CPU 或 GPU BatchSize=1)
    % =================================================================
    for ii = 1:TargSegNum
        SegIdx  = SegIndex(ii);
        OrgFreq = round(AnalyRecord(SegIdx).freq, 4)';
        OrgAmp  = AnalyRecord(SegIdx).Amp;
        OrgPha  = AnalyRecord(SegIdx).phase;

        [~, tar_f_loc] = ismember(OrgFreq, AnalyFreq);

        % 预计算当前段的时间偏移基准
        time_offset_base = (Ndelay(ii) - MINdelay) * fs;

        if any(tar_f_loc) % 只要有匹配的频率就处理
            % 仅处理匹配成功的频率
            valid_idx = find(tar_f_loc ~= 0);
            for k = 1:length(valid_idx)
                rn = valid_idx(k);
                loc = tar_f_loc(rn);

                freq0  = OrgFreq(rn);
                delay0 = ArrRDSig(loc).Delay;

                % 如果该频率没有对应的时延数据（即没有声线到达），则跳过
                if isempty(delay0)
                    continue;
                end

                amp0   = ArrRDSig(loc).Amp';
                phase0 = ArrRDSig(loc).phase;
                originAmp = Amp_source * OrgAmp(rn);

                if useGPU
                    delay0 = gpuArray(delay0);
                    amp0   = gpuArray(amp0);
                    phase0 = gpuArray(phase0);
                end

                % 生成时域信号
                [y_time, M_length] = SigGenerateTD(freq0, NdelayLength, fs, ...
                    originAmp, OrgPha(rn), delay0, amp0, phase0);

                % 确定信号初始位置
                PointStart = floor(min_delay_lookup(loc) * fs + time_offset_base) + 1;
                PointStart = max(1, PointStart); % 修正可能的浮点误差导致的 0 索引

                % 边界保护与叠加信号
                len = min(M_length, TargSigLength - PointStart + 1);

                % 直接叠加到 TargSig，省去中间变量
                idx = PointStart : PointStart + len - 1;
                TargSig(idx) = TargSig(idx) + y_time(1:len);
            end
        end
    end
end

% 取实部
TargSig = real(TargSig);

if useGPU
    TargSig = gather(TargSig);
end

% 剔除尾部零信号
lastIdx = find(TargSig ~= 0, 1, 'last');
if ~isempty(lastIdx)
    TargSig = TargSig(1:lastIdx);
    TargT = TargT(1:lastIdx);
end
end
