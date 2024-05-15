%%%%%
% reference:
% 1   https://blog.csdn.net/shuaibiXiangzai/article/details/132787946
% 2   https://blog.csdn.net/qq_43258963/article/details/115044378
%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
%% 读取2017年台风记录
year = 2017;
file_path = ['.\CMABSTdata\CH',num2str(year),'BST.txt'];
fid = fopen(file_path); % Open File
item = 0;
while 1

    newLine = fgetl(fid);
    if feof(fid)
        break;
    end
    if newLine(1:5) == '66666'
        item = item + 1;
        typhoonData(item).international_ID = strtrim(newLine(6:10));
        typhoonData(item).traceLine     = str2num(newLine(11:15));  %路径数据的行数
        typhoonData(item).tcNumber      = strtrim(newLine(16:20));  % tropical cyclone number 热带气旋编号
        typhoonData(item).typhoonID     = strtrim(newLine(21:25)); % 台风编号
        typhoonData(item).tcEndRecord   = str2num(newLine(27));   % 热带气旋终结记录
        % 0表示消散，1表示移出西太合风委员会的责任海区，2表示合并，3表示准静止
        typhoonData(item).sampleInterval= str2num(newLine(29));    % 每行路径间隔小时数
        typhoonData(item).typhoonName   = strtrim(newLine(31:50));
        % typhoonData(item).dataSetDate   = newLine(66:72);
    end
    for num = 1:1:typhoonData(item).traceLine
        dataLine = fgetl(fid);
        typhoonData(item).data(num).year  = dataLine(1:4);
        typhoonData(item).data(num).month = dataLine(5:6);
        typhoonData(item).data(num).day   = dataLine(7:8);
        typhoonData(item).data(num).hour  = dataLine(9:10);
        typhoonData(item).data(num).strength = dataLine(12);
        typhoonData(item).data(num).Lat   = str2double(dataLine(14:16))*0.1;
        typhoonData(item).data(num).Long  = str2double(dataLine(18:21))*0.1;
        typhoonData(item).data(num).pres  = str2num(dataLine(23:26));
        typhoonData(item).data(num).Wnd   = str2num(dataLine(31:34));
    end
end
out1=[num2str(year),'年台风次数:',num2str(item)];
disp(out1)
%绘图
figure
m_proj('mercator','lon',[100 150],'lat',[0 50]);
m_coast('patch',[0.92 .92 .92]);
m_grid('linestyle','-','gridcolor','w','backcolor',[.5294 .80784 0.92156]);
hold on
for i = 1:item
    Len = typhoonData(i).traceLine;
    for j = 1:Len
        lon(j) = typhoonData(i).data(j).Long;
        lat(j) = typhoonData(i).data(j).Lat;
    end
    m_plot(lon,lat);
    clear lon;clear lat;
end
picname = [num2str(year),' typhoon trajectory'];
title(picname)

%% 统计历年台风数据
year = 1949;
times = zeros(1,72);
minpress = zeros(1,72);
maxlevel = zeros(1,72);

for j = 1:72
    file_path = ['.\CMABSTdata\CH',num2str(year),'BST.txt'];
    fid = fopen(file_path); % Open File
    item = 0;
    ti = 0;
    while 1
        newLine = fgetl(fid);
        if feof(fid)
            break;
        end
        if newLine(1:5) == '66666'
            item = item + 1;
            typhoonData(item).traceLine     = str2num(newLine(11:15));  %路径数据的行数
        end
        for num = 1:1:typhoonData(item).traceLine
            dataLine = fgetl(fid);

            typhoonData(item).data(num).strength = str2num(dataLine(12));
            typhoonData(item).data(num).Lat   = str2double(dataLine(14:16))*0.1;
            typhoonData(item).data(num).Long  = str2double(dataLine(18:21))*0.1;
            typhoonData(item).data(num).pres  = str2num(dataLine(23:26));
            typhoonData(item).data(num).Wnd   = str2num(dataLine(31:34));
        end

    end
    for i = 1:item
        % 统计进入南海北部的次数
        Len = typhoonData(i).traceLine;
        for k = 1:Len
            lon(k) = typhoonData(i).data(k).Long;
            lat(k) = typhoonData(i).data(k).Lat;
            pres(k) = typhoonData(i).data(k).pres;
            level(k) = typhoonData(i).data(k).strength;
        end
        A = find(lon>110 & lon<118);
        B = find(lat>15 & lat<25);
        C = intersect(A, B);
        if ~isempty(C)
            ti = ti + 1;
            % 统计进入南海北部最低中心气压以及最强台风等级
            minp(i) = min(pres);
            maxl(i) = max(level);
        else
            minp(i) = 100000000000000000;
            maxl(i) = 0;
        end
        clear lon;clear lat;clear pres;clear level;
    end

    times(j) = ti;
    minpress(j) = min(minp);
    maxlevel(j) = max(maxl);

    year = year + 1;
end

t = 1949:1:2020;
figure
subplot(3,1,1)
plot(t,times)
xlabel('time/year');
ylabel('entrance times')
xlim([1949,2020]);

subplot(3,1,2)
plot(t,minpress)
xlabel('time/year');
ylabel('min center pressure')
xlim([1949,2020]);

subplot(3,1,3)
plot(t,maxlevel)
xlabel('time/year');
ylabel('max typhoon level')
xlim([1949,2020]);
