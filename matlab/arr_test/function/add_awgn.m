function noisy_signal = add_awgn(signal, snr_db)
    % 计算信号功率（考虑复数情况）
    Ps = mean(abs(signal).^2);
    
    % 根据SNR计算噪声功率
    Pn = Ps / (10^(snr_db/10));
    
    % 生成高斯白噪声
    if isreal(signal)
        noise = sqrt(Pn) * randn(size(signal));
    else
        % 复数噪声：实部和虚部分别具有方差 Pn/2
        noise = sqrt(Pn/2) * (randn(size(signal)) + 1i*randn(size(signal)));
    end
    
    % 添加噪声到信号
    noisy_signal = signal + noise;
end