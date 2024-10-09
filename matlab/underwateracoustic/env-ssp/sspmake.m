%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%注意：要配合envmake一起使用，因为plotssp需要配合env文件
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
etop_dir = 'etopo1.mat';   woa18_dir = 'WOA18_mat';
% 从数据集中加载地形数据和声速剖面数据
[ETOPO, WOA18] = load_data(etop_dir, woa18_dir);
%clear
clear etop_dir; clear woa18_dir; clear index; clear pathstr; clear tmp;
%% 设定位置
timeIdx = 13;
%声源点位
coordS.lon = 115;
coordS.lat = 13;
%测线方向及长度
azi  = 0;
rmax = 200;
dr = 1;
n = rmax/dr+1;
%计算最远距离接收点经纬度
coordE = [];
[coordS, coordE, rmax, ] = coord_proc(coordS, coordE, rmax, azi);

lon = linspace(coordS.lon, coordE.lon, n);
lat = linspace(coordS.lat, coordE.lat, n);

% 读取声速剖面及地形
[seaDepth, ssp_raw, SSP] = get_env(ETOPO, WOA18, lat, lon, timeIdx);
% clear azi;clear lat;clear lon; clear ssp_raw;clear ETOPO;clear WOA18;
clear coordE;clear coordS;
%% 添加中尺度现象

r = linspace(0,rmax,n);
z = SSP.z;
m = length(z);
zm = max(z);

% 添加高斯涡
rc = 100; %涡心水平位置
zc = 600; %涡心竖直位置
DR = 70;  %涡水平尺度
DZ = 400; %涡竖直尺度
DC = -40; %涡的强度
dc = zeros(size(SSP.c));


for i=1:n
    for j=1:m
        dc(j,i)=DC*exp(  -((r(i)-rc)/DR)^2  -((z(j)-zc)/DZ)^2   );
    end
end
ssp = dc + SSP.c;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% %添加内波
% z0 = 1000; %内波基准深度
% L = 40;   %特征长度
% rc = 100; %波峰中心所在距离
% DC = 500;  %内波强度
% h = z0 + DC * (sech( (r-rc)/L )).^2;
% % plot(r,h)
% 
% k1=20;
% k2=50;
% k3=k1+k2-1;
% 
% zn = zeros(1, k3);
% sspn = zeros(1,k3);  %转换后的临时声速
% ssp = zeros(m,n); %转换后的声速
% for i = 1:n
% zd0 = linspace(z0, zm, k2);
% zd = linspace(h(i), zm, k2);
% sspd = interp1(z, SSP.c(:,i), zd0);
% 
% zu0 = linspace(0, z0, k1);
% zu = linspace(0, h(i), k1);
% sspu = interp1(z, SSP.c(:,i), zu0);
% 
% zn(1:k1) = zu;
% zn(k1+1:k3) = zd(2:k2);
% 
% sspn(1:k1) = sspu;
% sspn(k1+1:k3) = sspd(2:k2);
% 
% ssp(:,i) = interp1(zn,sspn,z);
% end



%% output
%绘图
figure
pcolor(r ,z ,ssp);
shading interp; colormap( jet );
colorbar( 'YDir', 'Reverse' )
set( gca, 'YDir', 'Reverse' )   % because view messes up the zoom feature
xlabel( 'range(km)' );
ylabel( 'Depth (m)' );
% caxis([1490,1540]);
% 
% %输出.ssp文件
% sspfile = 'test';
% write_ssp(sspfile,r,ssp)