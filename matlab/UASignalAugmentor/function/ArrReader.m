function ArrReader(ArrFileName, EnvSiteRrDir, MAX_FREQ_LIMIT, AMP_THRESHOLD_RATIO)
% ARRREADER 读取Bellhop计算的到达结构文件(.arr)，提取并保存声线信息
%
% 输入:
%   ArrFileName: .arr文件名列表 (cell array)
%   EnvSiteRrDir: .arr文件所在目录，也是.mat文件保存目录
%   MAX_FREQ_LIMIT: 最大处理频率
%   AMP_THRESHOLD_RATIO: 幅值门限比例

    num_files = length(ArrFileName);
    
    % 1. 预读取第一个存在的文件以获取接收深度数量，用于预分配
    %    这是parfor性能优化的关键，避免在循环中动态调整结构体大小
    num_depths = 0;
    for k = 1:num_files
        test_file = fullfile(EnvSiteRrDir, [ArrFileName{k}, '.arr']);
        if exist(test_file, 'file')
            try
                [~, Pos] = read_arrivals_asc(test_file);
                num_depths = length(Pos.r.z);
                break;
            catch
                continue;
            end
        end
    end
    
    if num_depths == 0
        warning('ArrReader:NoFiles', '目录下没有找到有效的.arr文件或读取失败: %s', EnvSiteRrDir);
        return;
    end

    % 2. 预分配结构体数组
    %    定义标准结构体模板，确保所有元素字段一致
    template_struct = struct('Amp', [], 'Delay', [], 'phase', [], 'freq', [], 'rd', []);
    ARR = repmat(template_struct, num_files, num_depths);
    
    % 3. 并行处理
    for m = 1:num_files
        % 构建文件路径
        arr_file = fullfile(EnvSiteRrDir, [ArrFileName{m}, '.arr']);
        
        % 检查文件是否存在
        if ~exist(arr_file, 'file')
            % warning('未找到文件: %s', arr_file); % 并行时减少打印以免刷屏
            continue;
        end
        
        % 读取到达结构 (耗时操作，增加try-catch防止单个文件损坏中断整个流程)
        try
            [Arr, Pos] = read_arrivals_asc(arr_file);
        catch
            fprintf('读取失败: %s\n', arr_file);
            continue;
        end
        
        % 提取频率
        freq = Pos.freq;
        ReceiveDepth = Pos.r.z;
        % 频率过滤
        if freq > MAX_FREQ_LIMIT
            continue;
        end
        
        % 创建临时行变量，用于parfor切片赋值
        row_structs = repmat(template_struct, 1, num_depths);

        % 遍历每个接收深度
        for n = 1:num_depths
            % 提取原始数据
            raw_amp = abs(Arr(n).A);
            raw_delay = abs(Arr(n).delay);
            raw_phase = angle(Arr(n).A);
            
            % 按时延排序
            [delay_sorted, sort_idx] = sort(raw_delay);
            amp_sorted = raw_amp(sort_idx);
            phase_sorted = raw_phase(sort_idx);
            
            % 应用幅值门限过滤弱声线
            if ~isempty(amp_sorted)
                max_amp = max(amp_sorted);
                mask = amp_sorted >= (AMP_THRESHOLD_RATIO * max_amp);
                
                % 赋值
                row_structs(n).Amp   = amp_sorted(mask);
                row_structs(n).Delay = delay_sorted(mask);
                row_structs(n).phase = phase_sorted(mask);
                row_structs(n).freq  = freq;
                row_structs(n).rd    = ReceiveDepth(n);
            else
                 row_structs(n).freq = freq;
            end
        end
        
        % 将一行结果赋值回主数组 (Parfor Slicing)
        ARR(m, :) = row_structs;
    end
    % 保存到上一级目录
    OutputDir = fileparts(EnvSiteRrDir);
    % 保存为.mat格式
    OutputMatName = fullfile(OutputDir, 'ENV_ARR_less.mat');
    save(OutputMatName, 'ARR');
    fprintf('    保存MAT文件: ENV_ARR_less.mat\n');
end
