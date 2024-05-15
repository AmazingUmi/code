%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
clear index;clear pathstr;clear tmp;
%% 导入并另存ADCP数据
year = 2013;
file_path = ['.\ADP_',num2str(year),'0727.pra'];
fid = fopen(file_path); % Open File
item = 0;
while 1
    newLine = fgetl(fid);
    if feof(fid)
        break;
    end
    if newLine(1:2) == '07'
        item = item + 1;
        Data(item).month = str2double(newLine(1:2));
        Data(item).day  = str2double(newLine(3:5));  %
        Data(item).year  = str2double(newLine(6:10));  %
        Data(item).hour     = str2double(newLine(11:13)); %
        Data(item).minute     = str2double(newLine(14:16)); %
        Data(item).second     = str2double(newLine(17:19)); %
        Data(item).traceLine   = str2double(newLine(end-3:end));   %
    end
    for num = 1:1:Data(item).traceLine
        dataLine = fgetl(fid);
        Data(item).data(num).depth   = str2double(dataLine(1:3))*0.5;
        Data(item).data(num).u  = str2double(dataLine(4:12));
        Data(item).data(num).v  = str2double(dataLine(13:22));
        Data(item).data(num).w  = str2double(dataLine(23:31));
        Data(item).data(num).p1  = str2double(dataLine(32:35));
        Data(item).data(num).p2  = str2double(dataLine(36:39));
        Data(item).data(num).p3  = str2double(dataLine(40:end));
    end
end
clear newLine;clear item;clear num;clear year;clear fid;clear file_path;
clear dataLine;
save('ADCPdata.mat');
%% 重载数据，并提取所需数据
clc;clear all;
load ADCPdata.mat
b = [1, 0, 0];
for i = 1:length(Data)
    Data(i).data(21:end) = [];
    velocity(i) = sqrt((Data(i).data(4).u)^2 + (Data(i).data(4).v)^2 + (Data(i).data(4).w)^2);
    time(i) = Data(i).day * 86400 + Data(i).hour * 3600 + Data(i).minute * 60 + Data(i).second - 2374903;
    a = [Data(i).data(4).u, Data(i).data(4).v, Data(i).data(4).w];
    angle(i) = atan2d(norm(cross(a,b)),dot(a,b));
    for j = 1:20
        Velocity(i,j) = sqrt((Data(i).data(j).u)^2 + (Data(i).data(j).v)^2 + (Data(i).data(j).w)^2);
        A = [Data(i).data(j).u, Data(i).data(j).v, Data(i).data(j).w];
        Angle(i,j) = atan2d(norm(cross(A,b)),dot(A,b));
    end
end
clear a;clear b;clear i;
%% 绘图
feature('DefaultCharacterSet','UTF-8');
figure
subplot(2,1,1);
plot(time,velocity);
xlim([0,max(time)]);
xlabel('time');
ylabel('Speed amplitude');
title('水下第4层流速过程线图');

subplot(2,1,2);
plot(time,angle);
xlim([0,max(time)]);
ylim([0,180]);
xlabel('time');
ylabel('Speed angle');
title('水下第4层流向过程线图');

depth = 0.5:0.5:10;

figure
subplot(2,1,1);
pcolor(time,depth,Velocity');
xlim([0,time(100)]);
ylim([0.5,10]);
xlabel('time');
ylabel('depth');
title('前1000秒垂向流速剖面图');
shading interp
colorbar
colormap('jet')

subplot(2,1,2);
pcolor(time,depth,Angle');
xlim([0,time(100)]);
ylim([0.5,10]);
xlabel('time');
ylabel('depth');
title('前1000秒垂向流向剖面图');
shading interp
colorbar
colormap('jet')