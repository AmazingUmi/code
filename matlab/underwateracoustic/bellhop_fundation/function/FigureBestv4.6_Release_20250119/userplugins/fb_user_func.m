function fb_user_func(figureNumbers,axesNumbers,co)
% 函数功能：创建线条动画（demo）
% close all
% x = linspace(0,4*pi,30000);
% plot(x,cos(x),'k')
% hold on 
% plot(x,sin(x),'k')
figure(figureNumbers)
tars = findobj(figureNumbers,'Type','line');
hold on

for i = 1:length(tars)
    tar = tars(i);
    tar.Color = [1 1 1]*0.8;
    tar_x = tar.XData;
    tar_y = tar.YData;
    s = scatter(tar_x(1),tar_y(1),'SizeData',100,'MarkerFaceColor','y','MarkerEdgeColor','b');
    % delete(tar)
    h = animatedline('LineWidth',2,'Color','b');        
    for k = 1:length(tar_x)
        addpoints(h,tar_x(k),tar_y(k));
        s.XData = tar_x(k);
        s.YData = tar_y(k);
        drawnow
        pause(0.01)
    end
end

hold off