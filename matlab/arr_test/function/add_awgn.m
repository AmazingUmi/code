function noisy_signal = add_awgn(signal, snr_db, varargin)
    % ADD_AWGN 为信号添加加性高斯白噪声(AWGN)
    %
    % 用法：
    %   noisy_signal = add_awgn(signal, snr_db)
    %   noisy_signal = add_awgn(signal, snr_db, 'seed', seed_value)
    %
    % 输入参数：
    %   signal - 输入信号(实数或复数)
    %   snr_db - 所需的信噪比(dB)
    %   可选参数:
    %     'seed' - 随机数生成器种子，用于可重现结果
    %
    % 输出参数：
    %   noisy_signal - 添加噪声后的信号
    
    % 解析可选参数
    p = inputParser;
    addParameter(p, 'seed', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
    parse(p, varargin{:});
    
    seed_value = p.Results.seed;
    
    % 设置随机数生成器种子(如果提供)
    if ~isempty(seed_value)
        rng(seed_value);
    end
    
    % 处理边界情况
    if isinf(snr_db) && snr_db > 0
        noisy_signal = signal;  % 无限SNR，直接返回原始信号
        return;
    end
    
    % 计算信号功率(考虑复数情况)
    Ps = mean(abs(signal).^2);
    
    % 处理零功率信号
    if Ps == 0
        warning('信号功率为零，添加基于给定SNR的噪声可能无意义');
        Ps = eps;  % 使用很小的数代替零
    end
    
    % 根据SNR计算噪声功率
    Pn = Ps / (10^(snr_db/10));
    
    % 预分配噪声数组
    noise = zeros(size(signal), 'like', signal);
    
    % 生成高斯白噪声
    if isreal(signal)
        % 实数信号情况
        noise = sqrt(Pn) * randn(size(signal));
    else
        % 复数信号情况 - 一次性生成复数噪声
        noise = sqrt(Pn/2) * complex(randn(size(signal)), randn(size(signal)));
    end
    
    % 添加噪声到信号
    noisy_signal = signal + noise;
    
    % 对于非常低的SNR值进行警告
    if snr_db < -50
        warning('指定的SNR非常低(%g dB)，结果可能主要是噪声', snr_db);
    end
end