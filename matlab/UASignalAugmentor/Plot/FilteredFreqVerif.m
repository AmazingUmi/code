%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FILTEREDFREQVERIF 频率滤波效果验证工具（批量模式）
%   验证滤除部分频率对信号特征的影响，评估频率筛选策略的合理性
%
% 功能说明:
%   1. 批量读取 data/raw 下所有类别的音频文件
%   2. 利用 wavfreq 函数进行频率分析（按时间分段）
%   3. 利用 wavfilter 函数进行阈值筛选
%   4. 重构信号并计算多种评估指标
%   5. 对比原始信号与重构信号的时域和频域特性
%   6. 生成综合报告，汇总所有文件和参数组合的结果
%
% 代码优化:
%   - 复用 wavfreq.m 进行频率分析，避免重复 FFT 代码
%   - 复用 wavfilter.m 进行阈值筛选，保持与 A1 一致性
%   - 减少代码重复，提高可维护性
%
% 评估指标:
%   时域指标:
%     - MSE (均方误差)
%     - MAE (平均绝对误差)
%   频域指标:
%     - 频谱对比失真度
%     - 时频对比曼哈顿距离
%     - 时频对比对数失真度 (LSD)
%     - 时频对比 KL 散度
%
% 输出文件:
%   - 综合评估报告_YYYYMMDD_HHMMSS.txt: 汇总报告
%   - 评估结果数据_YYYYMMDD_HHMMSS.mat: MATLAB 数据文件
%
% 使用说明:
%   1. 确保音频文件在 data/raw/Class X/ 下
%   2. 设置分段时间长度和滤波阈值参数（第 78-80 行）
%   3. 运行脚本查看评估结果
%   4. 可选开启可视化部分查看对比图
%
% 作者: [猫猫头]
% 日期: [2025-12-12]
% 版本: v2.0 (简化版，复用 wavfreq/wavfilter 函数)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 初始化
clear; close all; clc;

% 获取脚本路径
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\');
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);

% 添加项目函数路径
project_root = fileparts(pathstr);  % UASignalAugmentor 根目录
addpath(fullfile(project_root, 'function'));

clear pathstr tmp index;

%% 配置参数
% 音频文件根目录
raw_data_path = fullfile(project_root, 'data', 'raw');
% 处理参数
cut_Tlength_vec = [1, 2];           % 信号分段时间长度（秒）
threshold_vec = [0.01, 0.05];       % 幅值滤波阈值（保留幅值 >= threshold × 最大幅值）
freq_range = [10, 5000];            % 有效频率范围（Hz）

% 输出文件夹
output_folder = fullfile(project_root, 'Plot', 'results');
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
    fprintf('创建输出文件夹: %s\n', output_folder);
end
%% 参数检视
fprintf('===== 频率滤波效果验证工具（批量模式） =====\n\n');
% 如果路径不存在，使用备用路径
if ~exist(raw_data_path, 'dir')
    error('无法找到音频数据文件夹，请检查路径设置');
end
fprintf('音频数据根目录: %s\n', raw_data_path);

% 获取所有类别文件夹
class_folders = dir(raw_data_path);
class_folders = class_folders([class_folders.isdir] & ~ismember({class_folders.name}, {'.', '..'}));
if isempty(class_folders)
    error('未找到任何类别文件夹');
end

% 收集所有音频文件
audio_files = [];
for i = 1:length(class_folders)
    class_path = fullfile(raw_data_path, class_folders(i).name);
    wav_files = dir(fullfile(class_path, '*.wav'));
    for j = 1:length(wav_files)
        audio_files(end+1).path = fullfile(class_path, wav_files(j).name);
        audio_files(end).class = class_folders(i).name;
        audio_files(end).filename = wav_files(j).name;
    end
end
if isempty(audio_files)
    error('未找到任何 .wav 文件');
end
fprintf('找到 %d 个音频文件，分布在 %d 个类别中\n', length(audio_files), length(class_folders));
fprintf('分段时间长度: %s 秒\n', mat2str(cut_Tlength_vec));
fprintf('滤波阈值: %s\n', mat2str(threshold_vec));
fprintf('频率范围: %d - %d Hz\n\n', freq_range(1), freq_range(2));

% 初始化综合结果存储
all_results = struct();
result_idx = 0;

%% 批量处理所有音频文件
fprintf('\n===== 开始批量处理 %d 个音频文件 =====\n\n', length(audio_files));

for file_idx = 1:length(audio_files)
    audio_file_path = audio_files(file_idx).path;
    audio_class = audio_files(file_idx).class;
    audio_filename = audio_files(file_idx).filename;

    fprintf('\n[%d/%d] 处理文件: %s/%s\n', file_idx, length(audio_files), audio_class, audio_filename);

    try
        % 读取音频信号
        [signal, fs] = audioread(audio_file_path);
        signal = signal ./ max(abs(signal));  % 归一化
        signal = signal';  % 转为行向量
        L = length(signal);
        T = L / fs;
        t = (0:L-1) / fs;

        fprintf('  采样率: %d Hz, 时长: %.2f 秒\n', fs, T);
    catch ME
        warning(ME.identifier, '  读取文件失败: %s，跳过该文件', ME.message);
        continue;
    end

    %% 主处理循环
    for a = 1:length(threshold_vec)
        threshold = threshold_vec(a);

        for b = 1:length(cut_Tlength_vec)
            cut_Tlength = cut_Tlength_vec(b);
            fprintf('    配置: 阈值=%.2f, 分段长度=%.1fs\n', threshold, cut_Tlength);
            tic;

            %% 使用 wavfreq 进行频率分析（直接传入内存信号）
            [~, Ndelay, Analyrecord, ~] = wavfreq(signal, freq_range, cut_Tlength, fs);

            % 使用 wavfilter 进行阈值筛选
            [Analyrecord_filtered, ~] = wavfilter(Analyrecord, threshold);

            % 分段参数
            N = length(Analyrecord_filtered);
            cut_length = ceil(cut_Tlength * fs);
            Nsignal = zeros(N, cut_length);

            % 评估指标初始化
            MSE = zeros(1, N);
            MAE = zeros(1, N);
            spectral_contrast_dist = zeros(1, N);
            Time_freq_contrast_dist_Manhattan = zeros(1, N);
            Time_freq_contrast_dist_LSD = zeros(1, N);
            Time_freq_contrast_dist_KL = zeros(1, N);

            %% 分段信号重构与评估
            for i = 1:N
                % 提取当前段信号
                mid_signal = signal((i-1)*cut_length+1 : i*cut_length);

                % 从 wavfilter 结果中获取频率成分
                sig_freq = Analyrecord_filtered(i).freq;
                sig_amplitude = Analyrecord_filtered(i).Amp;
                sig_phase = Analyrecord_filtered(i).phase;

                % 跳过被置零的段（不满足阈值条件）
                if sig_freq == 0
                    recover_sig = zeros(1, cut_length);
                else
                    % 信号重构（基于筛选后的频率成分）
                    pt = (0:cut_length-1) / fs;
                    recover_sig = zeros(size(pt));
                    for k = 1:length(sig_freq)
                        recover_sig = recover_sig + sig_amplitude(k) * cos(2*pi*sig_freq(k)*pt + sig_phase(k));
                    end
                end
                Nsignal(i, :) = recover_sig;

                % 时域评估指标
                MSE(i) = mean((mid_signal - recover_sig).^2);
                MAE(i) = mean(abs(mid_signal - recover_sig));

                % 频域评估指标
                f_edges = [10, 500, 5000, fs/2];
                [Pxx_orig, f_bands] = pwelch(mid_signal, hamming(1024), 512, 1024, fs);
                [Pxx_rec, ~] = pwelch(recover_sig, hamming(1024), 512, 1024, fs);

                % 计算频段能量比例
                band_energy_orig = zeros(1, length(f_edges)-1);
                band_energy_rec = zeros(1, length(f_edges)-1);
                for k = 1:length(f_edges)-1
                    band_mask = (f_bands >= f_edges(k)) & (f_bands < f_edges(k+1));
                    band_energy_orig(k) = sum(Pxx_orig(band_mask));
                    band_energy_rec(k) = sum(Pxx_rec(band_mask));
                end
                spectral_contrast_dist(i) = sum(abs((band_energy_orig - band_energy_rec) ./ (band_energy_orig + eps)));

                % 时频域评估指标
                [s_orig, ~, ~] = spectrogram(mid_signal, hamming(1024), 512, 1024, fs, 'yaxis');
                [s_rec, ~, ~] = spectrogram(recover_sig, hamming(1024), 512, 1024, fs, 'yaxis');

                % 曼哈顿距离
                d_timefreq = abs(s_orig - s_rec);
                Time_freq_contrast_dist_Manhattan(i) = mean(d_timefreq(:));

                % 对数谱距离 (LSD)
                log_error_sq = (log10(abs(s_orig) + eps) - log10(abs(s_rec) + eps)).^2;
                Time_freq_contrast_dist_LSD(i) = sqrt(mean(log_error_sq(:)));

                % KL 散度
                power_orig = abs(s_orig).^2;
                power_rec  = abs(s_rec).^2;
                P = power_orig ./ (sum(power_orig, 1) + eps);
                Q = power_rec  ./ (sum(power_rec, 1) + eps);
                KL_divergence = sum(P .* log((P + eps) ./ (Q + eps)), 1);
                Time_freq_contrast_dist_KL(i) = mean(KL_divergence);
            end

            elapsed_time = toc;
            % fprintf('      分段处理完成，耗时: %.2f 秒\n', elapsed_time);

            %% 整体信号评估
            % fprintf('      计算整体评估指标...\n');

            % 拼接重构信号
            recover_sig_complete = zeros(1, N*cut_length);
            for i = 1:N
                recover_sig_complete((i-1)*cut_length+1 : i*cut_length) = Nsignal(i, :);
            end

            % 截取原始信号（与重构信号长度一致）
            signal_truncated = signal(1:N*cut_length);

            % 整体频域评估
            f_edges = [10, 500, 5000, fs/2];
            [Pxx_orig, f_bands] = pwelch(signal_truncated, hamming(1024), 512, 1024, fs);
            [Pxx_rec, ~] = pwelch(recover_sig_complete, hamming(1024), 512, 1024, fs);

            band_energy_orig = zeros(1, length(f_edges)-1);
            band_energy_rec = zeros(1, length(f_edges)-1);
            for k = 1:length(f_edges)-1
                band_mask = (f_bands >= f_edges(k)) & (f_bands < f_edges(k+1));
                band_energy_orig(k) = sum(Pxx_orig(band_mask));
                band_energy_rec(k) = sum(Pxx_rec(band_mask));
            end
            spectral_contrast_dist_complete = sum(abs((band_energy_orig - band_energy_rec) ./ (band_energy_orig + eps)));

            % 整体时频域评估
            [s_orig, ~, ~] = spectrogram(signal_truncated, hamming(1024), 512, 1024, fs, 'yaxis');
            [s_rec, ~, ~] = spectrogram(recover_sig_complete, hamming(1024), 512, 1024, fs, 'yaxis');

            d_timefreq = abs(s_orig - s_rec);
            Time_freq_contrast_dist_Manhattan_complete = mean(d_timefreq(:));

            log_error_sq = (log10(abs(s_orig) + eps) - log10(abs(s_rec) + eps)).^2;
            Time_freq_contrast_dist_LSD_complete = sqrt(mean(log_error_sq(:)));

            power_orig = abs(s_orig).^2;
            power_rec  = abs(s_rec).^2;
            P = power_orig ./ (sum(power_orig, 1) + eps);
            Q = power_rec  ./ (sum(power_rec, 1) + eps);
            KL_divergence = sum(P .* log((P + eps) ./ (Q + eps)), 1);
            Time_freq_contrast_dist_KL_complete = mean(KL_divergence);

            %% 计算分段平均指标
            Avr_MSE = mean(MSE);
            Avr_MAE = mean(MAE);
            Avr_spectral_contrast_dist = mean(spectral_contrast_dist);
            Avr_Time_freq_contrast_dist_Manhattan = mean(Time_freq_contrast_dist_Manhattan);
            Avr_Time_freq_contrast_dist_LSD = mean(Time_freq_contrast_dist_LSD);
            Avr_Time_freq_contrast_dist_KL = mean(Time_freq_contrast_dist_KL);

            %% 保存结果到结构体
            result_idx = result_idx + 1;
            all_results(result_idx).audio_file = audio_filename;
            all_results(result_idx).audio_class = audio_class;
            all_results(result_idx).threshold = threshold;
            all_results(result_idx).cut_Tlength = cut_Tlength;
            all_results(result_idx).fs = fs;
            all_results(result_idx).duration = T;
            all_results(result_idx).num_segments = N;
            all_results(result_idx).Avr_MSE = Avr_MSE;
            all_results(result_idx).Avr_MAE = Avr_MAE;
            all_results(result_idx).Avr_spectral_contrast_dist = Avr_spectral_contrast_dist;
            all_results(result_idx).Avr_Time_freq_contrast_dist_Manhattan = Avr_Time_freq_contrast_dist_Manhattan;
            all_results(result_idx).Avr_Time_freq_contrast_dist_LSD = Avr_Time_freq_contrast_dist_LSD;
            all_results(result_idx).Avr_Time_freq_contrast_dist_KL = Avr_Time_freq_contrast_dist_KL;
            all_results(result_idx).spectral_contrast_dist_complete = spectral_contrast_dist_complete;
            all_results(result_idx).Time_freq_contrast_dist_Manhattan_complete = Time_freq_contrast_dist_Manhattan_complete;
            all_results(result_idx).Time_freq_contrast_dist_LSD_complete = Time_freq_contrast_dist_LSD_complete;
            all_results(result_idx).Time_freq_contrast_dist_KL_complete = Time_freq_contrast_dist_KL_complete;
        end
    end

    fprintf('  文件处理完成\n');
end

%% 生成综合报告
fprintf('\n===== 生成综合报告 =====\n');

if isempty(all_results)
    warning('没有成功处理的文件，无法生成报告');
    return;
end

% 生成综合报告文件
report_filename = fullfile(output_folder, sprintf('综合评估报告_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
fileID = fopen(report_filename, 'w');

fprintf(fileID, '=========================================\n');
fprintf(fileID, '    频率滤波效果验证综合报告\n');
fprintf(fileID, '=========================================\n\n');
fprintf(fileID, '生成时间: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fileID, '处理文件总数: %d\n', length(audio_files));
fprintf(fileID, '成功处理: %d\n', length(all_results));
fprintf(fileID, '频率范围: %d - %d Hz\n\n', freq_range(1), freq_range(2));

% 按参数组合分组统计
fprintf(fileID, '=========================================\n');
fprintf(fileID, '一、按参数组合统计\n');
fprintf(fileID, '=========================================\n\n');

for a = 1:length(threshold_vec)
    threshold = threshold_vec(a);
    for b = 1:length(cut_Tlength_vec)
        cut_Tlength = cut_Tlength_vec(b);

        % 筛选当前参数组合的结果
        idx = ([all_results.threshold] == threshold) & ([all_results.cut_Tlength] == cut_Tlength);
        group_results = all_results(idx);

        if isempty(group_results)
            continue;
        end

        fprintf(fileID, '-----------------------------------------\n');
        fprintf(fileID, '参数组合: 阈值=%.2f, 分段长度=%.1fs\n', threshold, cut_Tlength);
        fprintf(fileID, '-----------------------------------------\n');
        fprintf(fileID, '处理文件数: %d\n\n', length(group_results));

        % 计算统计量
        fprintf(fileID, '分段评估结果统计（平均值）:\n');
        fprintf(fileID, '  MSE:           均值=%.6f, 标准差=%.6f\n', ...
            mean([group_results.Avr_MSE]), std([group_results.Avr_MSE]));
        fprintf(fileID, '  MAE:           均值=%.6f, 标准差=%.6f\n', ...
            mean([group_results.Avr_MAE]), std([group_results.Avr_MAE]));
        fprintf(fileID, '  频谱失真度:     均值=%.6f, 标准差=%.6f\n', ...
            mean([group_results.Avr_spectral_contrast_dist]), std([group_results.Avr_spectral_contrast_dist]));
        fprintf(fileID, '  时频曼哈顿距离: 均值=%.6f, 标准差=%.6f\n', ...
            mean([group_results.Avr_Time_freq_contrast_dist_Manhattan]), std([group_results.Avr_Time_freq_contrast_dist_Manhattan]));
        fprintf(fileID, '  时频LSD:       均值=%.6f, 标准差=%.6f\n', ...
            mean([group_results.Avr_Time_freq_contrast_dist_LSD]), std([group_results.Avr_Time_freq_contrast_dist_LSD]));
        fprintf(fileID, '  时频KL散度:    均值=%.6f, 标准差=%.6f\n\n', ...
            mean([group_results.Avr_Time_freq_contrast_dist_KL]), std([group_results.Avr_Time_freq_contrast_dist_KL]));

        fprintf(fileID, '整体评估结果统计:\n');
        fprintf(fileID, '  频谱失真度:     均值=%.6f, 标准差=%.6f\n', ...
            mean([group_results.spectral_contrast_dist_complete]), std([group_results.spectral_contrast_dist_complete]));
        fprintf(fileID, '  时频曼哈顿距离: 均值=%.6f, 标准差=%.6f\n', ...
            mean([group_results.Time_freq_contrast_dist_Manhattan_complete]), std([group_results.Time_freq_contrast_dist_Manhattan_complete]));
        fprintf(fileID, '  时频LSD:       均值=%.6f, 标准差=%.6f\n', ...
            mean([group_results.Time_freq_contrast_dist_LSD_complete]), std([group_results.Time_freq_contrast_dist_LSD_complete]));
        fprintf(fileID, '  时频KL散度:    均值=%.6f, 标准差=%.6f\n\n', ...
            mean([group_results.Time_freq_contrast_dist_KL_complete]), std([group_results.Time_freq_contrast_dist_KL_complete]));
    end
end

% 按类别统计
fprintf(fileID, '\n=========================================\n');
fprintf(fileID, '二、按音频类别统计\n');
fprintf(fileID, '=========================================\n\n');

class_names = unique({all_results.audio_class});
for c = 1:length(class_names)
    class_name = class_names{c};
    idx = strcmp({all_results.audio_class}, class_name);
    class_results = all_results(idx);

    fprintf(fileID, '-----------------------------------------\n');
    fprintf(fileID, '类别: %s\n', class_name);
    fprintf(fileID, '-----------------------------------------\n');
    fprintf(fileID, '文件数: %d\n', length(class_results) / (length(threshold_vec) * length(cut_Tlength_vec)));
    fprintf(fileID, '测试配置数: %d\n\n', length(class_results));

    fprintf(fileID, '整体评估结果统计（所有参数配置平均）:\n');
    fprintf(fileID, '  频谱失真度:     %.6f ± %.6f\n', ...
        mean([class_results.spectral_contrast_dist_complete]), std([class_results.spectral_contrast_dist_complete]));
    fprintf(fileID, '  时频曼哈顿距离: %.6f ± %.6f\n', ...
        mean([class_results.Time_freq_contrast_dist_Manhattan_complete]), std([class_results.Time_freq_contrast_dist_Manhattan_complete]));
    fprintf(fileID, '  时频LSD:       %.6f ± %.6f\n', ...
        mean([class_results.Time_freq_contrast_dist_LSD_complete]), std([class_results.Time_freq_contrast_dist_LSD_complete]));
    fprintf(fileID, '  时频KL散度:    %.6f ± %.6f\n\n', ...
        mean([class_results.Time_freq_contrast_dist_KL_complete]), std([class_results.Time_freq_contrast_dist_KL_complete]));
end

% 详细结果列表
fprintf(fileID, '\n=========================================\n');
fprintf(fileID, '三、详细结果列表\n');
fprintf(fileID, '=========================================\n\n');

fprintf(fileID, '%-40s %-15s %-8s %-8s %-12s %-12s %-12s\n', ...
    '文件名', '类别', '阈值', '分段(s)', 'MSE', 'MAE', '频谱失真');
fprintf(fileID, '%s\n', repmat('-', 1, 120));

for i = 1:length(all_results)
    fprintf(fileID, '%-40s %-15s %-8.2f %-8.1f %-12.6f %-12.6f %-12.6f\n', ...
        all_results(i).audio_file, all_results(i).audio_class, ...
        all_results(i).threshold, all_results(i).cut_Tlength, ...
        all_results(i).Avr_MSE, all_results(i).Avr_MAE, ...
        all_results(i).spectral_contrast_dist_complete);
end

fclose(fileID);

fprintf('\n===== 评估完成 =====\n');
fprintf('综合报告已保存: %s\n', report_filename);
fprintf('结果文件夹: %s\n', output_folder);

% 保存 MATLAB 数据文件
mat_filename = fullfile(output_folder, sprintf('评估结果数据_%s.mat', datestr(now, 'yyyymmdd_HHMMSS')));
save(mat_filename, 'all_results', 'threshold_vec', 'cut_Tlength_vec', 'freq_range');
fprintf('MATLAB 数据文件已保存: %s\n', mat_filename);

%% 可视化对比（可选）
% 取消下面代码的注释以查看可视化结果

% % 使用最后一组参数的结果进行可视化
% figure('Position', [100 100 1400 900])
%
% % 时域信号对比（局部）
% subplot(3, 2, [1 2])
% part_idx = 1:min(600, length(signal_truncated));
% plot(t(part_idx), signal_truncated(part_idx), 'b', 'LineWidth', 1.5)
% hold on
% plot(t(part_idx), recover_sig_complete(part_idx), 'r--', 'LineWidth', 1.5)
% title('时域信号对比（局部）', 'FontSize', 12)
% xlabel('时间 (s)'), ylabel('幅值')
% legend('原始信号', '重构信号')
% grid on
%
% % 原始信号频谱
% subplot(3, 2, 3)
% signal_f_full = abs(fft(signal_truncated)) / length(signal_truncated);
% signal_f_full = signal_f_full(1:floor(length(signal_f_full)/2)+1);
% signal_f_full(2:end-1) = 2 * signal_f_full(2:end-1);
% f_full = (0:length(signal_f_full)-1) * fs / length(signal_truncated);
% plot(f_full, 20*log10(signal_f_full + eps), 'b', 'LineWidth', 1.5)
% xlim([0, freq_range(2)])
% ylim([-120, 5])
% title('原始信号频谱', 'FontSize', 12)
% xlabel('频率 (Hz)'), ylabel('幅度 (dB)')
% grid on
%
% % 重构信号频谱
% subplot(3, 2, 4)
% recover_f_full = abs(fft(recover_sig_complete)) / length(recover_sig_complete);
% recover_f_full = recover_f_full(1:floor(length(recover_f_full)/2)+1);
% recover_f_full(2:end-1) = 2 * recover_f_full(2:end-1);
% plot(f_full, 20*log10(recover_f_full + eps), 'r', 'LineWidth', 1.5)
% xlim([0, freq_range(2)])
% ylim([-120, 5])
% title('重构信号频谱', 'FontSize', 12)
% xlabel('频率 (Hz)'), ylabel('幅度 (dB)')
% grid on
%
% % 原始信号时频谱
% subplot(3, 2, 5)
% [s_orig_plot, f_orig, t_orig] = spectrogram(signal_truncated(1:min(end, fs*5)), ...
%     hamming(1024), 512, 1024, fs, 'yaxis');
% imagesc(t_orig, f_orig, 10*log10(abs(s_orig_plot) + eps))
% axis xy; colorbar; clim([-100, 20]);
% ylim([0, freq_range(2)])
% title('原始信号时频谱', 'FontSize', 12)
% xlabel('时间 (s)'), ylabel('频率 (Hz)')
%
% % 重构信号时频谱
% subplot(3, 2, 6)
% [s_rec_plot, f_rec, t_rec] = spectrogram(recover_sig_complete(1:min(end, fs*5)), ...
%     hamming(1024), 512, 1024, fs, 'yaxis');
% imagesc(t_rec, f_rec, 10*log10(abs(s_rec_plot) + eps))
% axis xy; colorbar; clim([-100, 20]);
% ylim([0, freq_range(2)])
% title('重构信号时频谱', 'FontSize', 12)
% xlabel('时间 (s)'), ylabel('频率 (Hz)')
%
% % 调整布局
% sgtitle(sprintf('频率滤波效果对比 (阈值=%.2f, 分段=%.1fs)', threshold, cut_Tlength), ...
%     'FontSize', 14, 'FontWeight', 'bold')
