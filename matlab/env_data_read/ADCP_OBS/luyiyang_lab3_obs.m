%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
clear index;clear pathstr;clear tmp;
%% 导入并另存obs数据
file_path = ['.\OBS-20130727.log'];
fid = fopen(file_path); % Open File
item = 0;
r = 1;
while 1
    newLine = fgetl(fid);
    if feof(fid)
        break;
    end
    if  r < 9
        r = r + 1;
        continue
    end
    if newLine(18:21) == '2013'
        item = item + 1;
        Data(item).hour     = str2double(newLine(1:2));
        Data(item).minute     = str2double(newLine(4:5));
        Data(item).second     = str2double(newLine(7:10));
        Data(item).month  = str2double(newLine(12:13));
        Data(item).day = str2double(newLine(15:16));
        Data(item).year  = str2double(newLine(18:21));

        Data(item).depth   = str2double(newLine(26:30));
        Data(item).ntu   = str2double(newLine(32:39));
        Data(item).tem   = str2double(newLine(41:49));
        Data(item).con   = str2double(newLine(51:57));
        Data(item).sal   = str2double(newLine(59:69));
    end
end
clear newLine;clear item;clear num;clear year;clear fid;clear file_path;
clear dataLine;
save('OBSdata.mat');
%% 重载obs数据并提取部分
clc;close all;clear all;
load OBSdata.mat

for i = 1:length(Data)
    Tem(i) = Data(i).tem;
    Con(i) = Data(i).con;
    Sal(i) = Data(i).sal;
    d(i) = Data(i).depth;
    time(i) = Data(i).day * 86400 + Data(i).hour * 3600 + Data(i).minute * 60 + Data(i).second-2375312;
end
%% 绘图
feature('DefaultCharacterSet','UTF-8');
%随时间过程线图
figure
subplot(3,1,1);
plot(time,Tem);
xlim([0,max(time)]);
xlabel('time');
ylabel('Temperature (deg C)');
title('温度过程');

subplot(3,1,2);
plot(time,Sal);
xlim([0,max(time)]);
% ylim([0,180]);
xlabel('time');
ylabel('Sallinity (PSU)');
title('盐度过程');

subplot(3,1,3);
plot(time,Con);
xlim([0,max(time)]);
% ylim([0,180]);
xlabel('time');
ylabel('Conductivity (mS/cm)');
title('浊度过程');

%随深度变化示意图
figure
subplot(3,1,1);
plot(d(47847:47996),Tem(47847:47996));
title('温度垂直过程');

subplot(3,1,2);
plot(d(47847:47996),Sal(47847:47996));
title('盐度垂直过程');

subplot(3,1,3);
plot(d(47847:47996),Con(47847:47996));
title('浊度垂直过程');