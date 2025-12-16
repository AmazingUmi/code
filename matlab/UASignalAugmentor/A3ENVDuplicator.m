%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A3ENVDUPLICATOR 环境文件频率扩展工具
%   读取信号提取的频率成分，为每个频率复制并修改Bellhop环境文件
%
% 工作流程说明:
%   本脚本是信号增强处理链的第3步，配合A1和A2脚本使用：
%   A1_WavTransformer  -> 提取音频信号的频率成分
%   A2_ENVmaker        -> 生成基础环境文件（各站点、各距离）
%   A3_ENVDuplicator   -> 为每个频率扩展环境文件（本脚本）
%
% 功能说明:
%   1. 加载A1生成的所有频率成分 (Analy_freq_all.mat)
%   2. 加载配置参数 (Config.mat) 获取边界条件和底质参数
%   3. 遍历A2生成的所有环境文件夹（Shallow/Transition/Deep）
%   4. 提取基础环境文件的表面和海底声速
%   5. 为每个频率生成环境文件副本并修改频率参数
%   6. 根据频率重新计算海面反射系数（.trc）和海底反射系数（.brc）
%   7. 复制地形文件（.bty）和声速剖面文件（.ssp）
%   8. 生成环境文件列表 (env_files_list.txt)
%   9. 打包所有环境文件为压缩包便于传输
%
% 输入文件:
%   - Analy_freq_all.mat: A1生成的所有信号频率成分数组
%   - Config.mat: 配置参数（海况等级、底质类型等）
%   - 基础环境文件: A2生成的 ENV_*.env, *.bty, *.ssp
%
% 输出文件:
%   - test_{i}.env: 各频率对应的环境文件（i为频率索引）
%   - test_{i}.bty: 海底地形文件
%   - test_{i}.ssp: 声速剖面文件
%   - test_{i}.trc: 海面反射系数文件（根据频率重新计算）
%   - test_{i}.brc: 海底反射系数文件（根据频率重新计算）
%   - env_files_list.txt: 环境文件名列表
%   - ENVall_files_YYYYMMDD.tar.gz: 打包的压缩文件
%
% 关键改进:
%   - 自动提取表面和海底声速，无需手动配置
%   - 为每个频率重新计算反射系数，确保物理准确性
%   - 使用配置文件统一管理海况等级和底质参数
%
% 作者: [猫猫头]
% 日期: [2025-12-03]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
pathstr = fileparts(tmp.Filename);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr, 'function'));
clear tmp index;

%% 加载配置和频率数据
fprintf('===== 开始环境文件频率扩展 =====\n\n');

% 路径配置
OriginEnvPackPath    = fullfile(pathstr, 'data', 'OriginEnvPack');  % 环境文件总文件夹
Signal_path          = fullfile(pathstr, 'data', 'processed');

% 加载配置文件
ConfigName = 'ConfigDeep.mat';  % 'ConfigShallow.mat'/'ConfigTransition.mat'/'ConfigDeep.mat'
Config = load(fullfile(OriginEnvPackPath, ConfigName));
fprintf('加载配置文件: %s\n', ConfigName);
fprintf('海域类型: %s\n', Config.Site_loc.zone);

% 加载信号频率数据
fprintf('加载信号频率数据...\n');
load(fullfile(Signal_path, 'Analy_freq_all.mat'), 'Analy_freq_all');
fprintf('频率数量: %d\n', length(Analy_freq_all));
fprintf('频率范围: %.1f - %.1f Hz\n\n', min(Analy_freq_all), max(Analy_freq_all));

%% 批量处理环境文件
fprintf('===== 开始批量处理环境文件 =====\n\n');

TotalFoldersNum = 0;  % 统计处理的文件夹总数

% 根据Config中的zone确定处理的海域类型
ZoneName = Config.Site_loc.zone;
fprintf('--- 处理海域类型: %s ---\n', ZoneName);

% 获取海域类型文件夹路径
EnvClassPath = fullfile(OriginEnvPackPath, ZoneName);
if ~exist(EnvClassPath, 'dir')
    error('错误: 海域类型文件夹不存在: %s', EnvClassPath);
end

% 获取所有站点文件夹 (ENV1, ENV2, ...)
contents = dir(EnvClassPath);
EnvFolderNames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
clear contents;
fprintf('  站点数量: %d\n', length(EnvFolderNames));

% 遍历每个站点
for j = 1:length(EnvFolderNames)
    EnvFolderPath = fullfile(EnvClassPath, EnvFolderNames(j).name);
    fprintf('  处理站点: %s\n', EnvFolderNames(j).name);

    % 获取所有距离文件夹 (Rr1, Rr2, ...)
    contents = dir(EnvFolderPath);
    EnvRrNames = contents([contents.isdir] & ~ismember({contents.name}, {'.', '..'}));
    clear contents;

    % 遍历每个距离配置
    for k = 1:length(EnvRrNames)
        EnvRrFolder = fullfile(EnvFolderPath, EnvRrNames(k).name, 'EnvTemplate');

        % 确保环境文件夹存在
        if ~exist(EnvRrFolder, 'dir')
            mkdir(EnvRrFolder);
            fprintf('    需要创建文件夹: %s\n', EnvRrFolder);
        end

        EnvName = [];
        FreqDuplicator(EnvRrFolder, EnvName, EnvRrFolder, Analy_freq_all, ...
            Config.Cal.top_sea_state_level, Config.Cal.bottom_base_type, Config.Cal.bottom_alpha_b)
        fprintf('    完成: 生成 %d 组文件\n', length(Analy_freq_all));
        TotalFoldersNum = TotalFoldersNum + 1;
    end
end
fprintf('\n===== 环境文件处理完成 =====\n');
fprintf('海域类型: %s\n', ZoneName);
fprintf('总计处理: %d 个环境文件夹\n', TotalFoldersNum);
fprintf('每个文件夹生成: %d 个频率副本\n', length(Analy_freq_all));
fprintf('总文件数: %d 组\n\n', TotalFoldersNum * length(Analy_freq_all));
%% 打包压缩文件
fprintf('===== 开始打包环境文件 =====\n');

% 获取打包目标路径信息
[ParentDir, PackFolderName] = fileparts(OriginEnvPackPath);
ZipName = ['ENVall_files_', datestr(now, 'yyyymmdd')];
ZipFileName = [ZipName, '.tar.gz'];

% 切换到父目录进行打包，避免包含绝对路径
cd(ParentDir);

fprintf('目标文件夹: %s\n', PackFolderName);
fprintf('压缩包名称: %s\n', ZipFileName);
fprintf('正在压缩文件（可能需要较长时间）...\n');

tic;
% 使用系统 tar 命令 (macOS/Linux)
Cmd = sprintf('tar -czf "%s" "%s"', ZipFileName, PackFolderName);
[Status, CmdOut] = system(Cmd);
ElapsedTime = toc;

if Status == 0
    fprintf('压缩完成! 耗时: %.2f 秒\n', ElapsedTime);
    fprintf('压缩文件路径: %s\n', fullfile(ParentDir, ZipFileName));
else
    warning('压缩失败: %s', CmdOut);
end

cd(pathstr);
fprintf('\n===== 全部处理完成 =====\n');

% 注释说明
% 用于远程服务器运行的示例命令:
% /public/home/amazingumi/temp/code/bellhop_parallel /public/home/amazingumi/temp/ENV1/envfilefolder
%
% 读取到达结构示例:
% [Arr, Pos] = read_arrivals_asc([newfilename{i}, '.arr']);