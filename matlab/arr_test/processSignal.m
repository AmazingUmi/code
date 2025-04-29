function segments = processSignal(fs, tgsig, snr_db, duration)
% processSignal 对输入信号做预处理、加噪声、预加重、中心化、归一化并分帧
% 如果未指定 duration 参数，则截取前 10 秒；如果指定为 'full'，则使用全部信号
% 当 snr_db 设置为 'none' 或 Inf 时不添加噪声
%
% segments = processSignal(fs, tgsig)
% segments = processSignal(fs, tgsig, snr_db)
% segments = processSignal(fs, tgsig, snr_db, duration)
%
% 输入：
% fs — 采样率 (Hz)
% tgsig — 原始信号向量
% snr_db — （可选）添加白噪声的 SNR（dB），如果未提供，则随机产生 3 到 5 之间的实数
%          如果设置为 'none' 或 Inf，则不添加噪声
% duration — （可选）信号处理的时长（秒），可以是数值或字符串 'full'。默认为 10 秒
%
% 输出：
% segments — 大小为 [numSegments × fs] 的矩阵，每行是一个长度为 fs 的信号片段

% 处理可选参数
if nargin < 3 || isempty(snr_db)
    snr_db = 3 + (5 - 3) * rand(); % 产生 3 到 5 之间的随机实数
end

if nargin < 4 || isempty(duration)
    duration = 10; % 默认处理 10 秒
end

% 根据 duration 参数截取信号
if ischar(duration) || isstring(duration)
    if strcmpi(duration, 'full')
        % 使用全部信号，不截取
    else
        error('duration 参数必须是数值或字符串 ''full''');
    end
else
    % duration 是数值，截取指定长度
    maxSamples = duration * fs;
    if length(tgsig) > maxSamples
        tgsig = tgsig(1:maxSamples);
    end
end

% 1. 归一化到 [-1,1]
x = tgsig ./ max(abs(tgsig));

% 2. 添加高斯白噪声（根据 snr_db 参数决定）
add_noise = true;
if ischar(snr_db) || isstring(snr_db)
    if strcmpi(snr_db, 'none')
        add_noise = false;
    else
        error('snr_db 字符串参数只能是 ''none''');
    end
elseif isinf(snr_db)
    add_noise = false;
end

if add_noise
    x = add_awgn(x, snr_db);
end

% 3. 预加重
preEmphasisCoeff = 0.95;
x = filter([1, -preEmphasisCoeff], 1, x);

% 4. 中心化
x = x - mean(x);

% 5. 再次归一化
x = x ./ max(abs(x));

% 6. 分帧：1 秒长度，50% 重叠
frameLen = fs; % 每帧长度 (样本数)
hopLen = round(frameLen/2); % 50% 重叠
numSamples = length(x);
numFrames = floor((numSamples - frameLen) / hopLen) + 1;
segments = zeros(numFrames, frameLen);
idx = 1;

for i = 1:numFrames
    segments(i, :) = x(idx : idx + frameLen - 1);
    idx = idx + hopLen;
end

% 处理尾部不足 1 秒的残余信号
remSamples = numSamples - (idx - hopLen);
lastStart = idx - hopLen; % 上一个帧的起始索引
residualStart = numSamples - frameLen + 1; % 倒数第一个完整帧的起始索引

if remSamples > 0 && remSamples < frameLen && residualStart > lastStart
    % 只有当 residualStart 严格大于上一次帧起始才追加，避免重复
    segments(end+1, :) = x(residualStart : residualStart + frameLen - 1);
end

end