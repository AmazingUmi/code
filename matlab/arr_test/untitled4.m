%—— 基本路径 ——%
srcBase = 'G:\database\Enhanced_shipsEar0418';
dstBase = 'G:\database\Enhanced_shipsEar0405';

%—— 递归查找所有 ENV_ARR_less.mat ——%
% 需要 R2016b 及以上支持通配符“**”
files = dir(fullfile(srcBase, '**', 'ENV_ARR_less.mat'));

%—— 批量移动 ——%
for k = 1:numel(files)
    % 源文件全路径
    srcFile = fullfile(files(k).folder, files(k).name);
    
    % 计算相对路径（去掉 srcBase 前缀）
    relPath = strrep(files(k).folder, srcBase, '');
    
    % 目标文件夹
    dstFolder = fullfile(dstBase, relPath);
    
    % 不存在就创建（包括所有中间目录）
    if ~exist(dstFolder, 'dir')
        mkdir(dstFolder);
        fprintf('创建文件夹: %s\n', dstFolder);
    end
    
    % 执行移动
    try
        copyfile(srcFile, dstFolder);
        fprintf('已移动: %s → %s\n', srcFile, dstFolder);
    catch ME
        warning('移动失败: %s\n原因: %s\n', srcFile, ME.message);
    end
end
