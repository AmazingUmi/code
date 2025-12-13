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
index = strfind(tmp.Filename, '\');
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(fullfile(pathstr, '..', 'function'));

% 添加 Bellhop 读取函数路径
bellhop_func_path = fullfile(pathstr, '..', '..', 'underwateracoustic', 'bellhop_fundation', 'function');
if exist(bellhop_func_path, 'dir')
    addpath(bellhop_func_path);
end

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
OceanDataPath = fullfile(project_root, 'data\OceanData');
ETOPOName     = 'ETOPO2022.mat';
WOAName       = 'woa23_%02d.mat';

% 加载ETOPO和WOA23数据
fprintf('加载 ETOPO 和 WOA23 数据...\n');
[ETOPO, WOA] = load_data(OceanDataPath, ETOPOName, WOAName);
fprintf('数据加载完成\n\n');

%% 设置计算参数
fprintf('===== 设置计算参数 =====\n');

% 时间索引
timeIdx = 13;  % 13-16: 季节, 17: 年平均

% 声源位置
coordS.lon = 115;
coordS.lat = 13;

% 计算范围
azi = 0;        % 方位角 (°)
rmax = 200;     % 最大距离 (km)
dr = 1;         % 距离间隔 (km)

% 频率
freq = 100;     % Hz

% 声源/接收器深度
src_depth = 50;     % 声源深度 (m)
rcv_depth = 0:10:3000;  % 接收器深度 (m)

% 涡旋参数
eddy_params.rc = 100;   % 涡心位置 (km)
eddy_params.zc = 600;   % 涡心深度 (m)
eddy_params.DR = 70;    % 水平尺度 (km)
eddy_params.DZ = 500;   % 竖直尺度 (m)
eddy_params.DC = -200;  % 强度 (m/s, 负=冷涡)

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
% rcv_depth = 0:10:max(Depth);  % 接收器深度 (m)
fprintf('声速剖面提取完成\n\n');

%% 生成两组环境文件
fprintf('===== 生成环境文件 =====\n');

% 1. 不含涡
fprintf('生成无涡环境文件...\n');
SSP_no_eddy = add_mesoscale(SSP, rmax, 'none');
env_name_no_eddy = fullfile(output_dir, 'NoEddy');
create_bellhop_env(env_name_no_eddy, freq, src_depth, rcv_depth, rmax, dr, ...
    Depth, ssp_raw, SSP_no_eddy);

% 2. 含涡
fprintf('生成含涡环境文件...\n');
SSP_with_eddy = add_mesoscale(SSP, rmax, 'eddy', eddy_params);
env_name_with_eddy = fullfile(output_dir, 'WithEddy');
create_bellhop_env(env_name_with_eddy, freq, src_depth, rcv_depth, rmax, dr, ...
    Depth, ssp_raw, SSP_with_eddy);

fprintf('环境文件生成完成\n\n');

%% 运行Bellhop
fprintf('===== 运行Bellhop =====\n');
bellhop_path = fullfile(project_root, 'CallBell', 'bellhop.exe');

% 检查 bellhop.exe 是否存在
if ~exist(bellhop_path, 'file')
    error('Bellhop 可执行文件不存在: %s', bellhop_path);
end
fprintf('Bellhop 路径: %s\n', bellhop_path);

% 保存当前目录
current_dir = pwd;

% 切换到输出目录执行 Bellhop
cd(output_dir);

try
    fprintf('计算无涡场景...\n');
    [status1, cmdout1] = system(sprintf('"%s" NoEddy', bellhop_path));
    if status1 ~= 0
        fprintf('警告：无涡场景计算可能出错\n输出:\n%s\n', cmdout1);
    else
        fprintf('无涡场景计算成功\n');
    end
    
    fprintf('计算含涡场景...\n');
    [status2, cmdout2] = system(sprintf('"%s" WithEddy', bellhop_path));
    if status2 ~= 0
        fprintf('警告：含涡场景计算可能出错\n输出:\n%s\n', cmdout2);
    else
        fprintf('含涡场景计算成功\n');
    end
    
    fprintf('Bellhop 计算完成\n\n');
catch ME
    cd(current_dir);  % 恢复目录
    rethrow(ME);
end

cd(current_dir);  % 恢复目录

%% 读取并对比结果
fprintf('===== 读取计算结果 =====\n');

% 检查输出文件是否存在
shd_file1 = fullfile(output_dir, 'NoEddy.shd');
shd_file2 = fullfile(output_dir, 'WithEddy.shd');

if ~exist(shd_file1, 'file')
    error('无涡场景输出文件不存在: %s', shd_file1);
end
if ~exist(shd_file2, 'file')
    error('含涡场景输出文件不存在: %s', shd_file2);
end

fprintf('结果读取完成\n\n');

%% 可视化
fprintf('===== 绘制对比图 =====\n');

% 设置全局变量（plotshd需要）
global units jkpsflag
units = 'km';  % 使用公里作为单位
jkpsflag = 0;  % 不使用固定尺寸

% 创建图形窗口
figure('Position', [100, 100, 1600, 900]);

% 图1: 无涡场景 - 使用plotshd
plotshd(shd_file1);
title('无涡传播损失');

% 图2: 含涡场景 - 使用plotshd
figure
plotshd(shd_file2);
title('含涡传播损失');

fprintf('对比图已保存\n\n');

fprintf('===== 分析完成 =====\n');
fprintf('输出目录: %s\n', output_dir);

%% 本地函数：创建Bellhop环境文件
function create_bellhop_env(env_name, freq, src_depth, rcv_depth, rmax, dr, ...
    Depth, ssp_raw, SSP)
    
    % Bellhop基本参数
    model = 'BELLHOP';
    title_env = 'Eddy Comparison';
    
    % SSP结构
    SSP_env.NMedia = 1;
    SSP_env.N = 0;
    SSP_env.sigma = 0;
    SSP_env.depth = [0, ssp_raw(end, 1)];
    SSP_env.raw(1).z = ssp_raw(:,1);
    SSP_env.raw(1).alphaR = ssp_raw(:,2);
    SSP_env.raw(1).betaR = zeros(size(ssp_raw(:,1)));
    SSP_env.raw(1).rho = 1.0 * ones(size(ssp_raw(:,1)));
    SSP_env.raw(1).alphaI = zeros(size(ssp_raw(:,1)));
    SSP_env.raw(1).betaI = zeros(size(ssp_raw(:,1)));
    
    % 边界条件
    Bdry.Top.Opt = 'QVW';
    Bdry.Bot.Opt = 'A*';
    Bdry.Bot.HS.alphaR = 1600;
    Bdry.Bot.HS.betaR = 0;
    Bdry.Bot.HS.rho = 1.5;
    Bdry.Bot.HS.alphaI = 0.5;
    Bdry.Bot.HS.betaI = 0;
    
    % 位置
    Pos.s.z = src_depth;
    Pos.r.z = rcv_depth;
    Pos.r.range = 0:2*dr:rmax;
    
    % 波束参数
    Beam.RunType = 'CB';
    Beam.Nbeams = 0;
    Beam.alpha = [-90, 90];
    Beam.deltas = 0;
    Beam.Box.z = ceil(max(Depth))+500;
    Beam.Box.r = rmax;
    
    cInt.Low = 1400;
    cInt.High = 1600;
    
    % 写入.env文件
    write_env([env_name '.env'], model, title_env, freq, SSP_env, Bdry, ...
        Pos, Beam, cInt, rmax);
    
    % 写入.bty文件
    bathm.r = (0:dr:rmax)';
    bathm.d = Depth(:);
    write_bty(env_name, 'L', bathm);
    
    % 写入.ssp文件
    rkm = 0:dr:rmax;
    write_ssp(env_name, rkm, SSP.c);
end
