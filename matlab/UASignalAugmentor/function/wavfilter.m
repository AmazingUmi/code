function [Analyrecord_filtered, Analy_freq_filtered] = wavfilter(Analyrecord, threshold)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% WAVFILTER 信号频率分量幅值筛选函数
%   对分析记录中的频率分量进行全局幅值排序和筛选，保留高幅值分量
%
% 输入参数:
%   Analyrecord - 分析记录结构体数组，包含每段信号的频率分析结果
%       .Amp - 频率分量的幅值
%       .freq - 频率分量的频率值（Hz）
%       .phase - 频率分量的相位
%   threshold - 幅值阈值比例（默认: 0.05）
%       保留幅值 >= threshold * 最大幅值 的频率分量
%
% 输出参数:
%   Analyrecord_filtered - 筛选后的分析记录结构体数组
%       结构与输入相同，但只保留满足阈值条件的频率分量
%   Analy_freq_filtered - 筛选后所有信号段的频率集合（去重后）
%
% 功能说明:
%   1. 将所有信号段的幅值组装成矩阵进行全局排序
%   2. 根据阈值筛选出高幅值频率分量的索引
%   3. 对每段信号按筛选索引更新 Amp、freq、phase
%   4. 不满足条件的信号段字段置为 0
%   5. 返回筛选后的记录和全局频率集合
%
% 示例:
%   [Analyrecord_filtered, Analy_freq_filtered] = wavfilter(Analyrecord);
%   [Analyrecord_filtered, Analy_freq_filtered] = wavfilter(Analyrecord, 0.1);
%
% 作者: [猫猫头]
% 日期: [2025-12-03]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 参数默认值设置
if nargin < 2 || isempty(threshold)
    threshold = 0.05;
end

% 初始化变量
Nrecord = length(Analyrecord);
max_freq_length = 0;

% 寻找频率个数最大值
for i = 1:Nrecord
    max_freq_length = max(max_freq_length, length(Analyrecord(i).Amp));
end

% 全局排序：组装所有的幅值
Amp_all = zeros(Nrecord, max_freq_length);
for i = 1:Nrecord
    Amp_all(i, 1:length(Analyrecord(i).Amp)) = Analyrecord(i).Amp;
end

[Amp_all_sorted, Amp_all_linear_indices] = sort(Amp_all(:), 'descend');
[indices_row, indices_col] = ind2sub(size(Amp_all), Amp_all_linear_indices); % 转二维索引
valid_idx = Amp_all_sorted >= threshold * Amp_all_sorted(1);
indices_row = indices_row(valid_idx);
indices_col = indices_col(valid_idx);

% 对每一段数据按照行数进行归类，准备筛选有效的幅值索引
indices_row_num = unique(indices_row); % 剩余的段数
sortedIndicesByRow = cell(length(indices_row_num), 1); % 记录各段需要计算的idx
num_row = [];
for i = 1:length(indices_row_num)
    indices_idx = indices_row == indices_row_num(i);
    num_row(i) = indices_row_num(i);
    sortedIndicesByRow{i,1} = indices_col(indices_idx);
end

% 处理 Analyrecord 中每一段数据，根据排序索引进行筛选，同时收集所有频率
Analy_freq_filtered = [];
Analyrecord_filtered = Analyrecord;

for i = 1:Nrecord
    row = num_row == i;
    if max(row) == 0
        % 当前段不满足条件，置为0
        Analyrecord_filtered(i).Amp = 0;
        Analyrecord_filtered(i).freq = 0;
        Analyrecord_filtered(i).phase = 0;
    else
        % 按照筛选索引更新
        Analyrecord_filtered(i).Amp = Analyrecord_filtered(i).Amp(sortedIndicesByRow{row,1});
        Analyrecord_filtered(i).freq = Analyrecord_filtered(i).freq(sortedIndicesByRow{row,1});
        Analyrecord_filtered(i).phase = Analyrecord_filtered(i).phase(sortedIndicesByRow{row,1});
        Analy_freq_filtered = unique([Analy_freq_filtered, Analyrecord_filtered(i).freq]); % 累计所有信号总的频率
    end
end

end
