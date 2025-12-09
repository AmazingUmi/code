function [ssp_top, ssp_bot] = get_boundary_speed(BaseLines)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GET_BOUNDARY_SPEED 从Bellhop环境文件行数组中提取表面和海底声速
%   解析已读取的.env文件行数组，提取声速剖面的表面和海底声速值
%
% 输入参数:
%   BaseLines - 环境文件行数组（cell数组，通过strsplit获得）
%
% 输出参数:
%   ssp_top - 表面声速 (m/s)
%   ssp_bot - 海底声速 (m/s)
%
% 功能说明:
%   1. 查找包含 '! z c cs rho' 的所有行
%   2. 提取第一行（表面）和最后一行（海底）的声速值
%   3. 声速是每行的第二个数值
%
% 示例:
%   FileContents = fileread('ENV_1_Rr1Km.env');
%   BaseLines = strsplit(FileContents, '\n');
%   [ssp_top, ssp_bot] = get_surface_bottom_speed(BaseLines);
%
% 作者: [猫猫头]
% 日期: [2025-12-03]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 查找包含 '! z c cs rho' 的行
ssp_lines = [];
for i = 1:length(BaseLines)
    if contains(BaseLines{i}, '! z c cs rho')
        ssp_lines = [ssp_lines; i];
    end
end

% 检查是否找到声速剖面数据
if isempty(ssp_lines)
    error('未找到声速剖面数据 (! z c cs rho)');
end

% 提取表面声速（第一行）
line_top = BaseLines{ssp_lines(1)};
data_top = sscanf(line_top, '%f');
ssp_top = data_top(2);  % 第二个数字是声速 c

% 提取海底声速（最后一行）
line_bot = BaseLines{ssp_lines(end)};
data_bot = sscanf(line_bot, '%f');
ssp_bot = data_bot(2);  % 第二个数字是声速 c

end
