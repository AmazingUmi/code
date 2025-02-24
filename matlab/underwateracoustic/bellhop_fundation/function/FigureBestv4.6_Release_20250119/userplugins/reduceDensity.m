function reduceDensity(figureNumbers,axesNumbers,co)
% % ½µµÍMarkerµÄÃÜ¶È

interval = 2;

for i = 1:length(figureNumbers)
    figureNum = figureNumbers(i);
    figure(figureNum)
    
    axesList = findobj(figureNum,'Type','axes');
    
    for j = 1:length(axesList)
        axesH = axesList(j);
        lines = findobj(axesH,'Type','line');
        
        for k = 1:length(lines)
            line = lines(k);
            line.XData = line.XData(1:interval:end);
            line.YData = line.YData(1:interval:end);
        end
        
    end
    
end