%非并行版本，计算速度慢，但方便调试
%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('E:\Umicode\matlab\underwateracoustic\bellhop_fundation\function');
addpath('E:\干活\715\10月开发\WOA18_mat');
%% 目标区域及经纬度输入
% WOA和EOTOP数据集经纬度范围或指定海域经纬度范围
Lat = [14, 23];  Lon = [108,118];
% 中心站点经纬度
Center = [115.417, 20.395];
plotgeomap(Lat, Lon);
plot(Center(1), Center(2), 'r*', 'LineWidth', 1.5);
%读取数据库 地形、声速剖面
etop_dir = 'etopo1.mat';
woa18_dir = 'WOA18_mat';
% 从数据集中加载地形数据和声速剖面数据
[ETOPO, WOA18] = load_data(etop_dir, woa18_dir);
cd('./out')
%% 环境参数设置
runtype = 'IB';   % 5 character
envfil = 'test';
MouthIdx = 1;          % 声速剖面采样月份
% 海面板块
top_option = 'CFFT';% 5 character
sea_state_level = 0;   % n级海况
freq = 100;   % 计算中心频率
freqvec = 100;   % 反射系数计算宽带频率
%海面高程
lambda = 100;
height = 5;

% 海底板块
bottom_option = 'F*'; % 2 character
base_type = 'D40';  % 底质类型
alpha_b = 0.05;

% 阵列板块
BeamWidth =0;     % BeamWidth为新的波束宽度
BeamWidth(end+1) = 360; % 360度表示无指向性
SourceRange = 0;
ReceiveRange = 0;
SourthDepth = 80;  %声源深度
ReceiveDepth = 80; %接收深度
alpha = 90;
theta=-90:270;
DI=ones(1,length(theta));

% 波束板块
beam_option.Type = 'CS';% 2 character
beam_option.epmult = 0.3;
beam_option.rLoop  = 1;
beam_option.Nimage = 1;
beam_option.Ibwin  = 1;

%计算精度
ri = 0.5;  % 接收距离间隔/km
zi = 0;  % 接收深度间隔/m
%% 点位经纬度选择
Centerp.lon=Center(1);Centerp.lat=Center(2);
targetp.lon=0;targetp.lat=0;
for j=1
    if j<6
        centerpp.lon=Centerp.lon-0.5+0.25*(j-1);
        centerpp.lat=Centerp.lat-0.5;
    elseif j>5 && j<11
        centerpp.lon=Centerp.lon-0.5+0.25*(j-6);
        centerpp.lat=Centerp.lat-0.25;
    elseif j>10 && j<16
        centerpp.lon=Centerp.lon-0.5+0.25*(j-11);
        centerpp.lat=Centerp.lat;
    elseif j>15 && j<21
        centerpp.lon=Centerp.lon-0.5+0.25*(j-16);
        centerpp.lat=Centerp.lat+0.25;
    else j>20
        centerpp.lon=Centerp.lon-0.5+0.25*(j-21);
        centerpp.lat=Centerp.lat+0.5;
    end
    %文件编号
    n=num2str(j);
    envfil= ['pos',n];
    % 声速板块
    [~, ssp_raw, ~] = get_env(ETOPO,WOA18,centerpp.lat,centerpp.lon, MouthIdx); % 获取平均声速剖面
    ssp_top = ssp_raw(1,2); % top speed
    ssp_bot = ssp_raw(end,2); % bottom speed

    % 海面建模ati
    if contains(top_option,'*')==1
        write_altimetry(lambda,height,rmax,ri,envfil)
    end
    % 声源指向性sbp
    if contains(runtype,'*')==1
        SourceBeam(BeamWidth,theta,DI,envfil)
    end
    % 海面反射trc
    a=strfind(top_option,'F');
    if ismember(2,a)==1
        TopReCoe(freqvec, ssp_top, sea_state_level, sprintf('%s', envfil));
    end
    % 海底反射brc
    if contains(bottom_option,'*')==1
        RefCoeBw(base_type, sprintf('%s', envfil), freqvec, ssp_bot, alpha_b);
    end

    %每个点位计算的方向数
    Ndir = 16;

    for i=1:Ndir
        azi=360/Ndir*(i-1);
        rmax=50;
        targetp = [];
        [centerpp, targetp, rmax, azi] = coord_proc(centerpp, targetp,rmax, azi);
        %绘图参数设置
        R = linspace(0,rmax,rmax/ri+1);
        tht = 360/Ndir*(0:Ndir-1);

    

    % 环境 env、bty、ssp
    call_Bellhop_surface_more(ETOPO,WOA18,envfil, freq, SourthDepth,ReceiveDepth, MouthIdx, centerpp, targetp, ...
        SourceRange,ReceiveRange,rmax, ri, zi, runtype, top_option,bottom_option,beam_option,-alpha,alpha);
    bellhop(envfil)

    %读取一维传播损失
    [~, ~, ~, ~, ~, ~, pressure] = read_shd([envfil,'.shd']);
    pressure = squeeze(pressure);
    tlt = abs( pressure );	            % this is really the negative of TL
    tlt( tlt == 0 ) = max( max( tlt ) ) / 1e10;      % replaces zero by a small number
    tlt = -20.0 * log10( tlt );          % so there's no error when we take the log
    TLT(i,:) = tlt;
    end

    %绘制三维传播损失
    h=figure;
    tht(Ndir+1)=tht(Ndir)+360/Ndir;
    TLT(Ndir+1,:) = TLT(1,:);
    polarPcolor(R,tht,TLT,'Nspokes',9)
    clim([40 130])
    shading interp
    tej = flipud( jet( 256 ) );
    colormap( tej )
    jpgname=[envfil, '.png'];
    %codes to generate figure;
    set(h,'PaperPositionMode','manual');
    set(h,'PaperUnits','points');
    set(h,'PaperPosition',[0,0,600,450]);%恰当选择尺寸
    n1=num2str(centerpp.lon) ;
    n2=num2str(centerpp.lat);
    n3=num2str(SourthDepth);
    n4=num2str(ReceiveDepth);
    titlename=[n1,'°E,',n2,'°N',newline,'sd=', n3, 'm,rd=', n4, 'm'];
    t=title(titlename,'FontSize',10,'FontName','Times New Roman','Position',[-0.75,0.9,0]);
    print(h, jpgname,'-r600','-djpeg');%-r600可改为300dpi分辨率
    % close(h)
    dispname=[n,'/25'];
    disp(dispname)
end