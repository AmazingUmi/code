%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EDDYCOMPARISON 涡旋影响对比工具
%   生成含涡和不含涡的环境文件，运行Bellhop，对比传播损失差异
%
% 功能:
%   1. 加载海洋数据（ETOPO + WOA23）
%   2. 设置计算参数
%   3. 生成含涡和不含涡的两组环境文件
%   4. 调用Bellhop计算
%   5. 读取并对比传播损失结果
%
% 作者: [猫猫头]
% 日期: [2025-12-12]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
pathstr = fileparts(tmp.Filename);
cd(pathstr);

clear tmp index;
% 添加项目函数路径
project_root = fileparts(pathstr);  % UASignalAugmentor 根目录
addpath(fullfile(project_root, 'function'));

%% 创建输出目录
output_dir = fullfile(pathstr, 'eddy');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% 加载海洋环境数据
fprintf('===== 开始加载海洋环境数据 =====\n');

% 数据路径配置
OceanDataPath = fullfile(project_root, 'data', 'OceanData');
ETOPOName     = 'ETOPO2022.mat';
WOAName       = 'woa23_%02d.mat';

% 加载ETOPO和WOA23数据
fprintf('加载 ETOPO 和 WOA23 数据...\n');
[ETOPO, WOA] = load_data(OceanDataPath, ETOPOName, WOAName);
fprintf('数据加载完成\n\n');

%% 加载计算参数
fprintf('===== 加载计算参数 =====\n');
param_file = fullfile(pathstr, 'EddyComparison_Params.mat');

load(param_file);
fprintf('已加载参数文件: %s\n', param_file);

% 从 Config 提取参数
timeIdx = Config.Source.timeIdx;
coordS = Config.Loc.coordS;
azi = Config.Source.azi;
freq = Config.Source.freq;
src_depth = Config.Source.SourceDepth;
rmax = max(Config.Receiver.ReceiveRange);
if length(Config.Receiver.ReceiveRange) > 1
    dr = Config.Receiver.ReceiveRange(2) - Config.Receiver.ReceiveRange(1);
else
    dr = 1;
end
eddy_params = Config.EddyParams;
run_types = Config.RunTypes;

fprintf('声源: (%.1f°E, %.1f°N), 深度=%d m\n', coordS.lon, coordS.lat, src_depth);
fprintf('方位角=%d°, 距离=%.1f km, 频率=%.1f Hz\n', azi, rmax, freq);
fprintf('涡旋: 位置=(%.0f km, %.0f m), 尺度=(%.0f×%.0f km×m), 强度=%.1f m/s\n\n', ...
    eddy_params.rc, eddy_params.zc, eddy_params.DR, eddy_params.DZ, eddy_params.DC);

%% 计算终点坐标
coordE = [];
[coordS, coordE, ~, ~] = coord_proc(coordS, coordE, rmax, azi);

%% 提取声速剖面
fprintf('===== 提取声速剖面 =====\n');
n = rmax/dr + 1;
lon = linspace(coordS.lon, coordE.lon, n);
lat = linspace(coordS.lat, coordE.lat, n);
[Depth, ssp_raw, SSP] = get_env(ETOPO, WOA, lon, lat, timeIdx);
Config.Receiver.ReceiveDepth = 0:5:max(Depth); % 接收深度 (m)
fprintf('声速剖面提取完成\n\n');

%% 生成两组环境文件
fprintf('===== 生成环境文件 =====\n');

% 检查 run_types 是否存在，如果不存在则检查 run_type，否则默认为 {'CB'}
if ~exist('run_types', 'var')
    if exist('run_type', 'var')
        run_types = {run_type};
    else
        run_types = {'CB'};
    end
end
fprintf('Bellhop 运行模式: %s\n', strjoin(run_types, ', '));

%% 绘制声速剖面
fprintf('===== 绘制声速剖面 =====\n');
SSP_no_eddy = add_mesoscale(SSP, rmax, 'none');
SSP_with_eddy = add_mesoscale(SSP, rmax, 'eddy', eddy_params);

r_vec = 0:dr:rmax;
z_vec = ssp_raw(:,1);

% 图片保存路径
pic_dir = fullfile(pathstr, 'pic');
if ~exist(pic_dir, 'dir')
    mkdir(pic_dir);
end

% 绘制无涡 SSP
plotSSP(SSP_no_eddy, r_vec, z_vec, 'No Eddy Sound Speed Profile');
hold on 
plotbty()
saveas(gcf, fullfile(pic_dir, 'SSP_NoEddy.png'));

% 绘制含涡 SSP
plotSSP(SSP_with_eddy, r_vec, z_vec, 'With Eddy Sound Speed Profile');
saveas(gcf, fullfile(pic_dir, 'SSP_WithEddy.png'));
fprintf('声速剖面图已生成并保存至: %s\n', pic_dir);

% 循环处理每种运行模式
for i = 1:length(run_types)
    run_type = run_types{i};
    fprintf('\n>>> 开始处理模式: %s <<<\n', run_type);
    Config.Cal.Beam.RunType = run_type;
    % 定义文件名后缀
    suffix = ['_' run_type];

    % 切换到输出目录，因为 FileMaker 在当前目录生成文件
    current_dir = pwd;
    cd(output_dir);

    try
        % 1. 生成无涡环境文件
        fprintf('生成无涡环境文件 (%s)...\n', run_type);
        Config.Cal.mesoscale.type = 'none';
        Config.Cal.mesoscale.params = [];
        FileMaker(ETOPO, WOA, ['NoEddy' suffix], Config);

        % 2. 生成含涡环境文件
        fprintf('生成含涡环境文件 (%s)...\n', run_type);
        Config.Cal.mesoscale.type = 'eddy';
        Config.Cal.mesoscale.params = eddy_params;
        FileMaker(ETOPO, WOA, ['WithEddy' suffix], Config);
    catch ME
        cd(current_dir);
        rethrow(ME);
    end
    cd(current_dir);

    fprintf('环境文件生成完成\n');

    %% 运行Bellhop
    fprintf('===== 运行Bellhop (%s) =====\n', run_type);
    bellhop_path = fullfile(project_root, 'CallBell', 'bellhop.exe');

    % 检查 bellhop.exe 是否存在
    if ~exist(bellhop_path, 'file')
        error('Bellhop 可执行文件不存在: %s', bellhop_path);
    end
    
    % 保存当前目录
    current_dir = pwd;

    % 切换到输出目录执行 Bellhop
    cd(output_dir);

    try
        % 运行无涡场景
        run_bellhop_case(bellhop_path, ['NoEddy' suffix]);
        
        % 运行含涡场景
        run_bellhop_case(bellhop_path, ['WithEddy' suffix]);
        
        fprintf('Bellhop 计算完成\n');
    catch ME
        cd(current_dir);  % 恢复目录
        rethrow(ME);
    end

    cd(current_dir);  % 恢复目录

    %% 读取并对比结果
    fprintf('===== 读取计算结果 (%s) =====\n', run_type);

    if strcmp(run_type, 'CB')
        % 检查输出文件是否存在 (.shd)
        shd_file1 = fullfile(output_dir, ['NoEddy' suffix '.shd']);
        shd_file2 = fullfile(output_dir, ['WithEddy' suffix '.shd']);

        if ~exist(shd_file1, 'file')
            error('无涡场景输出文件不存在: %s', shd_file1);
        end
        if ~exist(shd_file2, 'file')
            error('含涡场景输出文件不存在: %s', shd_file2);
        end
    elseif strcmp(run_type, 'RB')
        % 检查输出文件是否存在 (.ray)
        ray_file1 = fullfile(output_dir, ['NoEddy' suffix '.ray']);
        ray_file2 = fullfile(output_dir, ['WithEddy' suffix '.ray']);
        
        if ~exist(ray_file1, 'file')
            error('无涡场景声线文件不存在: %s', ray_file1);
        end
        if ~exist(ray_file2, 'file')
            error('含涡场景声线文件不存在: %s', ray_file2);
        end
    end

    fprintf('结果读取完成\n');

    %% 可视化
    fprintf('===== 绘制对比图 (%s) =====\n', run_type);


    % 图片保存路径
    pic_dir = fullfile(pathstr, 'pic');
    if ~exist(pic_dir, 'dir')
        mkdir(pic_dir);
    end

    if strcmp(run_type, 'CB')
        % 绘制传播损失 (TL)
        
        % 创建图形窗口
        figure('Name', '无涡传播损失', 'Position', [100, 100, 1200, 500]);
        plotshd(shd_file1);
        shading("interp");
        title('无涡传播损失');
        saveas(gcf, fullfile(pic_dir, 'TL_NoEddy.png'));

        % 创建图形窗口
        figure('Name', '含涡传播损失', 'Position', [100, 600, 1200, 500]);
        plotshd(shd_file2);
        shading("interp");
        title('含涡传播损失');
        saveas(gcf, fullfile(pic_dir, 'TL_WithEddy.png'));
        
    elseif strcmp(run_type, 'RB')
        % 绘制声线轨迹 (Ray Trace)
        
        % 创建图形窗口
        figure('Name', '无涡声线轨迹', 'Position', [100, 100, 1200, 500]);
        plotray(ray_file1);
        title('无涡声线轨迹');
        saveas(gcf, fullfile(pic_dir, 'Ray_NoEddy.png'));
        
        % 创建图形窗口
        figure('Name', '含涡声线轨迹', 'Position', [100, 600, 1200, 500]);
        plotray(ray_file2);
        title('含涡声线轨迹');
        saveas(gcf, fullfile(pic_dir, 'Ray_WithEddy.png'));
    end

    fprintf('对比图已保存至: %s\n', pic_dir);
end

fprintf('===== 分析完成 =====\n');
fprintf('输出目录: %s\n', output_dir);

%% 辅助函数

function run_bellhop_case(exe_path, case_name)
    fprintf('计算场景: %s ... ', case_name);
    cmd = sprintf('"%s" "%s"', exe_path, case_name);
    [status, cmdout] = system(cmd);
    if status ~= 0
        fprintf('失败\n');
        fprintf('输出:\n%s\n', cmdout);
        error('Bellhop 运行失败');
    else
        fprintf('成功\n');
    end
end
