function plotSSP(SSP, r, z, title_str)
% PLOTSSP 绘制二维声速剖面
%
% 用法:
%   plotSSP(SSP, r, z, title_str)
%
% 输入:
%   SSP       - 包含声速矩阵 .c 的结构体 (Size: Depth x Range)
%   r         - 距离向量 (km)
%   z         - 深度向量 (m)
%   title_str - (可选) 图形标题
%
% 示例:
%   plotSSP(SSP_no_eddy, 0:1:200, ssp_raw(:,1), 'Sound Speed Profile');

    if nargin < 4
        title_str = 'Sound Speed Profile';
    end

    % 检查输入维度
    [nz, nr] = size(SSP.c);
    if length(z) ~= nz || length(r) ~= nr
        % 尝试转置
        if length(z) == nr && length(r) == nz
            SSP.c = SSP.c';
        else
            warning('维度不匹配: SSP.c (%dx%d), z (%d), r (%d)', nz, nr, length(z), length(r));
        end
    end

    % 创建图形
    figure('Name', title_str, 'NumberTitle', 'off');
    
    % 绘制伪彩色图
    % 使用 imagesc 自动缩放颜色范围
    imagesc(r, z, SSP.c);
    
    % 设置颜色条
    c = colorbar;
    c.Label.String = 'Sound Speed (m/s)';
    c.Label.FontSize = 12;
    colormap(jet); % 使用经典 jet 色图，或者 parula
    
    % 设置坐标轴
    axis ij; % 深度轴反向（0在顶部）
    xlabel('Range (km)', 'FontSize', 12);
    ylabel('Depth (m)', 'FontSize', 12);
    title(title_str, 'FontSize', 14, 'FontWeight', 'bold');
    
    % 美化
    set(gca, 'FontSize', 10, 'LineWidth', 1);
    box on;
    shading interp
    
    % 添加等声速线 (可选)
    hold on;
    [C, h] = contour(r, z, SSP.c, 'k', 'ShowText', 'on');
    clabel(C, h, 'Color', 'k', 'FontSize', 8);
    hold off;
end
