%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EDDYCOMPARISON 涡旋影响对比工具
%   生成含涡和不含涡的环境文件，运行Bellhop，对比传播损失差异
%
% 功能:
%   1. 加载Munk声速剖面
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

%% 加载计算参数
fprintf('===== 加载计算参数 =====\n');
ConfigFileDir = fullfile(project_root, 'data', 'Eddy', 'EddyFileConfig.mat');
SigFreqDir    = fullfile(project_root, 'data', 'processed', 'Analy_freq_all.mat');
% 开始加载
Config = load(ConfigFileDir);
fprintf('已加载参数文件: %s\n', ConfigFileDir);
load(SigFreqDir, 'Analy_freq_all');
fprintf('已加载频率文件: %s\n', SigFreqDir);
% bellhop程序路径设置
bellhop_path = fullfile(project_root, 'CallBell','mac', 'bellhop.exe');
% 检查 bellhop.exe 是否存在
if ~exist(bellhop_path, 'file')
    error('Bellhop 可执行文件不存在: %s', bellhop_path);
end
%% 加载海洋环境数据
fprintf('===== 开始加载海洋环境数据 =====\n');
% 加载Munk声速剖面
MunkSSPDir = fullfile(project_root, 'data', 'Eddy', 'MunkSSP.mat');
load(MunkSSPDir, 'munkSSP');
fprintf('已加载Munk声速剖面: %s\n', MunkSSPDir);
% 计算地形数据
rmax = ceil(1.5 * max(Config.Receiver.ReceiveRange));
N = max(rmax + 1, 2);
BTY.r = linspace(0, rmax, N);            % 地形文件距离参数
BTY.d = max(munkSSP(:,1)) * ones(1, N);  % 理想环境下海底为恒定深度
% 计算声速数据
SSP.ssp_raw   = munkSSP;
SSProf0.z   = munkSSP(:,1);
SSProf0.c   = repmat(munkSSP(:,2), 1, N);
SSP.SSProf  = SSProf0;
fprintf('【声速剖面提取】以及【地形计算】完成\n\n');
% 暂存涡旋参数
EddyParams = Config.Cal.mesoscale.params;
Config.Receiver.ReceiveRange = 0:0.5:rmax;       % 接收距离 (km)
Config.Receiver.ReceiveDepth = 0:5:max(BTY.d); % 接收深度 (m)
% 输出路径设置
Outputdir = '/Users/luyiyang/Database/testBin/EddyAnalyzer_output';

NumOfrc = length(EddyParams.rcVector);
NumOfDC = length(EddyParams.DCVector);

for nrc = 1:NumOfrc
    EddyParams.rc = EddyParams.rcVector(nrc);
    for nDC = 1:NumOfDC
        EddyParams.DC = EddyParams.DCVector(nDC);
        % 创建输出目录
        ouputname  = sprintf('rc%s_DC%s',num2str(EddyParams.rc),num2str(EddyParams.DC));
        output_dir = fullfile(Outputdir, 'Comparison', ouputname);
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end
        % 图片保存路径
        pic_dir = fullfile(output_dir, 'pic');
        if ~exist(pic_dir, 'dir')
            mkdir(pic_dir);
        end

        %%%%%%%%%%%%%%%%%% 绘制声速剖面 %%%%%%%%%%%%%%%%%
        fprintf('===== 绘制声速剖面 =====\n');
        SSP_with_eddy = add_mesoscale(SSProf0, rmax, 'eddy', EddyParams);

        r_vec = 0:1:rmax;
        z_vec = munkSSP(:,1);

        % 绘制 SSP
        plotSSP(SSP_with_eddy, r_vec, z_vec, 'With Eddy Sound Speed Profile');
        saveas(gcf, fullfile(pic_dir, sprintf('SSP_%s.png', ouputname)));
        fprintf('声速剖面图已生成并保存至: %s\n', pic_dir);
        %%%%%%%%%%%%%%%%%% 开始计算参数 %%%%%%%%%%%%%%%%%
        run_types = {'RB','CB'};
        % 循环处理每种运行模式
        for i = 1:length(run_types)
            run_type = run_types{i};
            fprintf('\n>>> 开始处理模式: %s <<<\n', run_type);
            Config.Cal.Beam.RunType = run_type;
            % 定义文件名后缀
            suffix = ['_' run_type];

            % 切换到输出目录，因为 FileMaker 在当前目录生成文件
            cd(output_dir);

            try
                fprintf('生成环境文件 (%s)...\n', run_type);
                Config.Cal.mesoscale.type = 'eddy';
                Config.Cal.mesoscale.params = EddyParams;
                SSP.SSProf = SSP_with_eddy;
                FileMakerIdeal(BTY, SSP, ['WithEddy' suffix], Config);
            catch ME
                cd(pathstr);
                rethrow(ME);
            end
            cd(pathstr);

            fprintf('环境文件生成完成\n');

            %%%%%%%%%%%%%%%%%% 运行Bellhop %%%%%%%%%%%%%%%%%
            fprintf('===== 运行Bellhop (%s) =====\n', run_type);
            % 切换到输出目录执行 Bellhop
            cd(output_dir);

            try
                run_bellhop_case(bellhop_path, ['WithEddy' suffix]);
                fprintf('Bellhop 计算完成\n');
            catch ME
                cd(pathstr);  % 恢复目录
                rethrow(ME);
            end

            cd(pathstr);  % 恢复目录

            %%%%%%%%%%%%%%%%%% 读取并对比结果 %%%%%%%%%%%%%%%%%
            fprintf('===== 读取计算结果 (%s) =====\n', run_type);

            if strcmp(run_type, 'CB')
                % 检查输出文件是否存在 (.shd)
                shd_file = fullfile(output_dir, ['WithEddy' suffix '.shd']);
                if ~exist(shd_file, 'file')
                    error('含涡场景输出文件不存在: %s', shd_file);
                end
            elseif strcmp(run_type, 'RB')
                % 检查输出文件是否存在 (.ray)
                ray_file = fullfile(output_dir, ['WithEddy' suffix '.ray']);
                if ~exist(ray_file, 'file')
                    error('含涡场景声线文件不存在: %s', ray_file);
                end
            end
            fprintf('结果读取完成\n');

            %%%%%%%%%%%%%%%%%% 可视化 %%%%%%%%%%%%%%%%%
            fprintf('===== 绘制对比图 (%s) =====\n', run_type);
            if strcmp(run_type, 'CB')
                % 绘制传播损失 (TL)
                % 创建图形窗口
                figure('Name', '含涡传播损失', 'Position', [100, 600, 1200, 500]);
                plotshd(shd_file);
                shading("interp");
                title('含涡传播损失');
                saveas(gcf, fullfile(pic_dir, sprintf('TL_%s.png', ouputname)));

            elseif strcmp(run_type, 'RB')
                % 绘制声线轨迹 (Ray Trace)
                % 创建图形窗口
                figure('Name', '含涡声线轨迹', 'Position', [100, 600, 1200, 500]);
                plotray(ray_file);
                title('含涡声线轨迹');
                saveas(gcf, fullfile(pic_dir, sprintf('Ray_%s.png', ouputname)));
            end
            fprintf('对比图已保存至: %s\n', pic_dir);
        end
        close all
    end
end
fprintf('===== 分析完成 =====\n');
fprintf('输出目录: %s\n', output_dir);

%% 辅助函数

function run_bellhop_case(exedir, case_name)
fprintf('计算场景: %s ... ', case_name);
cmd = sprintf('"%s" "%s"', exedir, case_name);
[status, cmdout] = system(cmd);
if status ~= 0
    fprintf('失败\n');
    fprintf('输出:\n%s\n', cmdout);
    error('Bellhop 运行失败');
else
    fprintf('成功\n');
end
end
