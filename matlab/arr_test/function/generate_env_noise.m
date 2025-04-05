function env_sig = generate_env_noise(fs, signal_length, v)
    % 输入参数:
    %   fs: 采样率 (需与主信号一致)
    %   signal_length: 目标信号长度 (样本数)
    %   v: 风速 (m/s)
    
    T = signal_length / fs; % 自动计算所需时长
    N = signal_length;
    ref_power = 1e-12;  % 保持参考功率不变

    % 生成白噪声
    white_noise = sqrt(ref_power * fs) * randn(1, N);
    white_noise = white_noise - mean(white_noise);

    % 全频段噪声谱建模
    f = linspace(0, fs/2, N/2+1);
    SL = 55 - 6*log10(f/400) + 0.08*v^0.6*log10(v/5.14);
    valid_band = (f >= 10) & (f <= 25000);
    SL(~valid_band) = interp1([5, 25000], [SL(find(f>=10,1)), SL(end)],...
                             f(~valid_band), 'linear', 'extrap');

    % 设计FIR滤波器
    order = 8192;
    f_norm = f/(fs/2);
    target_amp = 10.^(SL/20);
    b = fir2(order, f_norm, target_amp, chebwin(order+1, 50));

    % 能量校准
    [h, w] = freqz(b, 1, 2^16, fs);
    f_resolution = fs/(2^16);
    target_power = sum(10.^(SL/10)) * (fs/(2*(N/2)));
    filter_energy = sum(abs(h).^2) * f_resolution;
    scale_factor = sqrt(target_power / filter_energy);

    % 生成环境噪声
    env_sig = scale_factor * filter(b, 1, white_noise);
end