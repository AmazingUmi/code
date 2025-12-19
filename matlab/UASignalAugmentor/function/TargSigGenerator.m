function [TargSig, TargT] = TargSigGenerator(AnalyRecord, AnalyFreq, ...
    ArrRDSig, Amp_source, fs, Ndelay, TargSegNum)
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
%
% 输出:
%   TargSig     - 合成的接收信号 (实数向量)
%   TargT       - 对应的修剪后的时间序列向量

    % 计算片段长度
    NdelayLength = Ndelay(2) - Ndelay(1);
    AnalyrecordNum = length(AnalyRecord);  % 分段信号全部段数
    % 处理目标信号的分段的段数
    if nargin < 7 || isempty(TargSegNum)
        TargSegNum = AnalyrecordNum;
    elseif TargSegNum > AnalyrecordNum
        warning('TargSigGenerator:SegNumOverflow', ...
            '请求的段数 (%d) 大于可用段数 (%d)，将使用全部可用段数。', ...
            TargSegNum, AnalyrecordNum);
        TargSegNum = AnalyrecordNum;
    end

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
    SegIndex = StartSeg : (StartSeg + TargSegNum - 1);%段数小于总段数时目标信号的索引

    % 初始化目标信号
    TargSigLength = ceil((MAXdelay - MINdelay + TargSegNum + 0.01) * fs);  % 目标信号长度
    TargT   = (0:TargSigLength-1) / fs;  % 目标信号时间序列
    TargSig = zeros(size(TargT));

    % 合成信号
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
    
    % 取实部
    TargSig = real(TargSig);
    
    % 剔除尾部零信号
    lastIdx = find(TargSig ~= 0, 1, 'last');
    if ~isempty(lastIdx)
        TargSig = TargSig(1:lastIdx);
        TargT = TargT(1:lastIdx);
    end
end