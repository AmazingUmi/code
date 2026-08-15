% CONVERT_MUNK_SSP Munk声速剖面数据转换（Eddy 辅助数据预处理）
% [统一入口说明]
% Purpose:      data/Eddy/MunkSSP.txt → data/Eddy/MunkSSP.mat（pchip 插值加密后保存）
% Inputs:       data/Eddy/MunkSSP.txt（相对当前工作目录解析）
% Outputs:      data/Eddy/MunkSSP.mat（变量 munkSSP: [Depth, Speed]）
% Dependencies: 无 function/ 依赖
% Pipeline:     Eddy 变体前置数据准备（供 EddyComparison / EXTRA_EddyAnalyzer 使用）
% 运行方式:     ⚠ 路径为 cwd 相对路径——需先将工作目录切到 UASignalAugmentor 根再运行
%
% Script to read MunkSSP.txt and convert to a two-column variable
clc;close all;clear;
% Define the relative path to the file
filename   = fullfile('data', 'Eddy', 'MunkSSP.txt');
outputname = fullfile('data', 'Eddy', 'MunkSSP.mat');
% Check if file exists
if ~isfile(filename)
    % Try absolute path or check current directory if running from elsewhere
    if isfile(fullfile(pwd, filename))
        filename = fullfile(pwd, filename);
    else
        error('File MunkSSP.txt not found in expected path: %s', filename);
    end
end

% Open the file
fid = fopen(filename, 'r');

if fid == -1
    error('Could not open file: %s', filename);
end

% Read the data
% The format in the file is: Depth Speed /
% We use %f %f to read the two numbers and %*s to skip the '/'
data = textscan(fid, '%f %f %*s');

% Close the file
fclose(fid);

% Combine into a two-column matrix [Depth, Speed]
munkSSP = [data{1}, data{2}];

% Display the first few rows to verify
disp('Converted MunkSSP data (First 5 rows):');
disp(munkSSP(1:5, :));

% Variable 'munkSSP' now holds the two-column data
% You can save it if needed:
save(outputname, 'munkSSP');

%% Interpolation and Plotting
% Define interpolation factor n
n = 4; % Increase depth resolution by n times

% Extract original depth and sound speed
depth_origin = munkSSP(:, 1);
speed_origin = munkSSP(:, 2);

% Create new depth vector with higher resolution
% We use linspace to generate n times the number of points within the same depth range
depth_interp = linspace(min(depth_origin), max(depth_origin), length(depth_origin) * n)';

% Perform interpolation
% 'pchip' is often good for SSPs to preserve shape and avoid overshoots
speed_interp = interp1(depth_origin, speed_origin, depth_interp, 'pchip'); 

% Plot the comparison
figure;
plot(speed_origin, depth_origin, 'o', 'MarkerSize', 6, 'LineWidth', 1.5, 'DisplayName', 'Original Data');
hold on;
plot(speed_interp, depth_interp, '-', 'LineWidth', 1.5, 'DisplayName', sprintf('Interpolated (x%d)', n));
hold off;

% Formatting the plot
set(gca, 'YDir', 'reverse'); % Depth increases downwards
grid on;
xlabel('Sound Speed (m/s)');
ylabel('Depth (m)');
title('Comparison of Original and Interpolated Sound Speed Profiles');
legend('Location', 'best');

munkSSP = [depth_interp, speed_interp];
save(outputname, 'munkSSP');