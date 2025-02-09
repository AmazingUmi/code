function tfEntropy = computeTimeFrequencyEntropy(spectrogramMatrix, windowSize)
    % 计算时频熵的优化实现
    % spectrogramMatrix: 输入的时频谱图矩阵（频率 × 时间）
    % windowSize: 计算熵的时频窗口大小（例如，5 表示 5x5 的窗口）

    % 定义卷积核
    kernel = ones(windowSize, windowSize);

    % 计算窗口内的总能量
    windowSum = conv2(spectrogramMatrix, kernel, 'same');

    % 避免除以零
    windowSum(windowSum == 0) = eps;

    % 归一化为概率分布
    p = spectrogramMatrix ./ windowSum;

    % 计算 p * log2(p)
    p(p == 0) = eps; % 避免 log2(0)
    entropyMatrix = -p .* log2(p);

    % 计算局部熵（窗口内的平均熵）
    tfEntropy = conv2(entropyMatrix, kernel, 'same') ./ (windowSize^2);
end
