function deleteOnePoint(figureNumbers,axesNumbers,~)
% % 删除某个点（来自plot函数绘制）
%
%
% figureNumbers = 1;
% axesNumbers = 1;

% 找到目标坐标轴
figureNum = figureNumbers(1);
axesList = findobj(figureNum,'Type','axes');
if isempty(axesNumbers)
    axesNumbers = 1;
end
axesH = axesList(axesNumbers(1));
axes(axesH);

minx = axesH.XLim(1);
maxx = axesH.XLim(2);
miny = axesH.YLim(1);
maxy = axesH.YLim(2);

% 获取鼠标点击的点
cp = ginput(1);
tempcp = cp;
cp(1) = (cp(1)-minx)/(maxx-minx);
cp(2) = (cp(2)-miny)/(maxy-miny);
% 判断与点击点最近的点

lines = findobj(axesH,'Type','line');
xy_flag_order_dist = []; % N X 4 matrix
for i = 1:length(lines)
    x = (lines(i).XData'-minx)/(maxx-minx);
    y = (lines(i).YData'-miny)/(maxy-miny);
    flag = zeros(length(x),1)+i;
    order = [1:length(x)]';
    dist = (x-cp(1)).^2 + (y-cp(2)).^2;
    xy_flag_order_dist = [xy_flag_order_dist; x y flag order dist];
end

[d,index] = min(xy_flag_order_dist(:,5));
target_flag = xy_flag_order_dist(index,3);
target_order = xy_flag_order_dist(index,4);

% 去除捕捉到的点
lines(target_flag).XData = [lines(target_flag).XData(1:target_order-1) lines(target_flag).XData(target_order+1:end)];
lines(target_flag).YData = [lines(target_flag).YData(1:target_order-1) lines(target_flag).YData(target_order+1:end)];

        
