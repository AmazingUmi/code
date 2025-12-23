function NewFileNames = FreqDuplicator(SourceDir, EnvName, OutputDir, FreqVector, SeaState, BotType, BotAlpha)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FREQDUPLICATOR 环境文件频率扩展函数
%   读取指定的基础环境文件(.env)，为每个频率生成副本并修改频率参数。
%   同时处理关联文件：
%   - 自动复制 .bty, .ssp, .sbp 文件
%   - 根据需要重新计算 .trc (海面反射系数) 和 .brc (海底反射系数)
%
% 输入参数:
%   SourceDir    - 源文件所在文件夹路径
%   EnvName      - 环境文件名 (不含扩展名)
%   OutputDir    - 输出文件夹路径
%   FreqVector   - 需要生成的频率向量 (Hz)
%   SeaState     - (可选) 海况等级 (默认: 0, 用于 .trc 计算)
%   BotType      - (可选) 海底类型 (默认: 'S', 用于 .brc 计算)
%   BotAlpha     - (可选) 海底吸收系数 (默认: 0.5, 用于 .brc 计算)
%
% 输出参数:
%   NewFileNames - 生成的新文件名前缀列表 (Cell Array)
%
% 作者: [猫猫头]
% 日期: [2025-12-14]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 参数处理以及验证
if nargin < 5
    SeaState = [];
end

if nargin < 7
    BotType = [];
    BotAlpha = [];
end

% 若 EnvName 为空，自动探测源目录下的 .env 文件
if isempty(EnvName)
    EnvFiles = dir(fullfile(SourceDir, '*.env'));
    if isempty(EnvFiles)
        error('在源目录 %s 中未找到 .env 文件', SourceDir);
    end
    [~, EnvName, ~] = fileparts(EnvFiles(1).name);
    if length(EnvFiles) > 1
        warning('找到多个 .env 文件，默认使用: %s', EnvName);
    end
end

EnvFilePath = fullfile(SourceDir, [EnvName, '.env']);

% 确保输出文件夹存在
if ~exist(OutputDir, 'dir')
    mkdir(OutputDir);
end

% 查找所有以 EnvName 开头的源文件
SourceFiles = dir(fullfile(SourceDir, [EnvName, '.*']));
if isempty(SourceFiles)
    error('未找到任何以 %s 开头的文件', EnvName);
end

FileSuffix = cell(1, length(SourceFiles));
for k = 1:length(SourceFiles)
    [~, ~, ext] = fileparts(SourceFiles(k).name);
    FileSuffix{k} = ext;
    clear ext;
end

Need_trc = any(strcmp(FileSuffix, '.trc'));
Need_brc = any(strcmp(FileSuffix, '.brc'));
Need_ssp = any(strcmp(FileSuffix, '.ssp'));
Need_bty = any(strcmp(FileSuffix, '.bty'));
Need_sbp = any(strcmp(FileSuffix, '.sbp'));

%% 读取并解析.env文件以确定需求
FileContents = fileread(EnvFilePath);
% 使用正则分割以兼容不同操作系统的换行符
BaseLines = regexp(FileContents, '\r?\n', 'split');


if Need_trc || Need_brc
    % 提取边界声速 (用于计算反射系数)
    [ssp_top, ssp_bot] = get_boundary_speed(BaseLines);
end
%% 批量生成文件
NewFileNames = cell(1, length(FreqVector));

fprintf('正在处理: %s -> %s\n', EnvName, OutputDir);

for m = 1:length(FreqVector)
    % 1. 生成新文件名
    NewFileNames{m} = sprintf('test_%d', m);
    NewEnvPath = fullfile(OutputDir, [NewFileNames{m}, '.env']);
    
    % 2. 修改频率行 (通常是第2行)
    % 注意: 这里我们操作原始 BaseLines 以保持格式
    Lines = BaseLines;
    % 找到频率行 (第2个非空行)
    FreqLineIdx = find(~cellfun('isempty', Lines), 2);
    if length(FreqLineIdx) >= 2
        FreqLineIdx = FreqLineIdx(2);
        NewLine = sprintf('  %.2f  \t \t \t ! Frequency (Hz) ', FreqVector(m));
        Lines{FreqLineIdx} = NewLine;
    else
        warning('无法定位频率行，跳过文件生成: %s', NewEnvPath);
        continue;
    end
    % 找到底部参数行
    FreqLineIdx2 = find(~cellfun(@isempty, regexp(Lines, 'Bottom Option')));
    
    % 如果包含 'A'，则进行修改
    if ~isempty(FreqLineIdx2) && contains(Lines{FreqLineIdx2(1)}, 'A')
        TargetLineIdx = FreqLineIdx2(1) + 1;
        if TargetLineIdx <= length(Lines)
            % 获取该行数据以计算 alpha
            LineVals = sscanf(Lines{TargetLineIdx}, '%f');
            if length(LineVals) >= 2
                % 根据公式计算 alpha
                val2 = LineVals(2); % 该行第二个数
                lamda = val2 / FreqVector(m);
                amp_val = (FreqVector(m)/1000)^1.71;
                alpha = 0.39 * amp_val * lamda;
                
                % 将该行的第五个数修改为计算出的 alpha
                Lines{TargetLineIdx} = regexprep(Lines{TargetLineIdx}, ...
                    '^(\s*(?:\S+\s+){4})(\S+)', sprintf('$1%.6f', alpha));
            end
        end
    end

    NewContents = strjoin(Lines, '\n'); % 使用 \n 连接，MATLAB 会自动处理写文件时的换行
    
    % 3. 写入新的环境文件
    fid = fopen(NewEnvPath, 'w');
    if fid == -1
        error('无法写入文件: %s', NewEnvPath);
    end
    fprintf(fid, '%s', NewContents);
    fclose(fid);
    
    % 4. 复制辅助文件 (.bty, .ssp)
    if Need_bty
        SrcBty = fullfile(SourceDir, [EnvName, '.bty']);
        DstBty = fullfile(OutputDir, [NewFileNames{m}, '.bty']);
        copyfile(SrcBty, DstBty);
    end

    if Need_ssp
        SrcSsp = fullfile(SourceDir, [EnvName, '.ssp']);
        DstSsp = fullfile(OutputDir, [NewFileNames{m}, '.ssp']);
        copyfile(SrcSsp, DstSsp);
    end

    if Need_sbp
        SrcSbp = fullfile(SourceDir, [EnvName, '.sbp']);
        DstSbp = fullfile(OutputDir, [NewFileNames{m}, '.sbp']);
        copyfile(SrcSbp, DstSbp);
    end

    % 5. 重新计算反射系数 (.trc, .brc)
    OldDir = pwd;
    cd(OutputDir);
    try
        % 如果需要 .trc，则生成
        if Need_trc
            ReCoeTop(FreqVector(m), ssp_top, SeaState, NewFileNames{m});
        end

        % 如果需要 .brc，则生成
        if Need_brc
            RefCoeBw(BotType, NewFileNames{m}, FreqVector(m), ssp_bot, BotAlpha);
        end
    catch ME
        cd(OldDir);
        rethrow(ME);
    end
    cd(OldDir);
end

%% 生成文件列表
ListFileDir = fullfile(OutputDir, 'env_files_list.txt');
fid = fopen(ListFileDir, 'w');
for m = 1:length(NewFileNames)
    if m == length(NewFileNames)
        fprintf(fid, '%s', NewFileNames{m});
    else
        fprintf(fid, '%s\n', NewFileNames{m});
    end
end
fclose(fid);

fprintf('完成: 已生成 %d 组环境文件于 %s\n', length(FreqVector), OutputDir);

end
