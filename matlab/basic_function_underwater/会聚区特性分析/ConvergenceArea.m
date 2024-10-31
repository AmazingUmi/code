%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);
addpath('E:\Umicode\matlab\underwateracoustic\bellhop_fundation\function');
addpath('E:\干活\715\10月开发\WOA18_mat');

etop_dir = 'etopo1.mat';   woa18_dir = 'WOA18_mat';
[ETOPO, WOA18] = load_data(etop_dir, woa18_dir);
clear etop_dir; clear woa18_dir; clear index; clear pathstr; clear tmp;
%% 
%声源点位
coordS.lon = 115; 
coordS.lat = 13;
%测线方向及长度
azi  = 0;
rmax = 100;
%计算最远距离接收点经纬度
coordE = [];
[coordS, coordE, rmax, azi] = coord_proc(coordS, coordE, rmax, azi);

runtype = 'IB';   % 5 character
envfil = 'test';

% 海面板块
top_option = 'CFFT';% 5 character
sea_state_level = 0;   % n级海况
freq = 50;   % 计算中心频率
freqvec = 500;   % 反射系数计算宽带频率
%海面高程
lambda = 100;
height = 5;

% 声速板块
MouthIdx = 1;          % 声速剖面采样月份
[~, ssp_raw, ~] = get_env(ETOPO,WOA18,coordS.lat,coordS.lon, MouthIdx); % 获取平均声速剖面
ssp_top = ssp_raw(1,2); % top speed
ssp_bot = ssp_raw(end,2); % bottom speed

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


ri = 0.5;  % 接收距离间隔/km
zi = 20;  % 接收深度间隔/m


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
% 环境 env、bty、ssp
call_Bellhop_surface_more(ETOPO,WOA18,envfil, freq, SourthDepth,ReceiveDepth, MouthIdx, coordS, coordE, ...
    SourceRange,ReceiveRange,rmax, ri, zi, runtype, top_option,bottom_option,beam_option,-alpha,alpha);
%% 
% bellhop test
% plotshd('test.shd')
[ ~, ~, ~, ~, ~, Pos, pressure ] = read_shd( sprintf('%s.shd', envfil) );
pressure = squeeze(pressure);
depth = Pos.r.z;
range = Pos.r.r;
%指定深度
n = 1;
Depth = n*zi;
% [~,idx] = find(depth == Depth);
pres_n = 1e6*pressure(n,:);
dpres_n = pres_n(2:end) - pres_n(1:end-1);
dpres_n = dpres_n-mean(dpres_n);
figure
plot(range(50:end), dpres_n(49:end));
%% 
x = pres_n(20:end); % 替换为您的数据
xmean = mean(x);
% 定义Savitzky-Golay滤波器的参数
order = 3; % 多项式阶数
framelen = 11; % 帧长度，必须为奇数

% 应用Savitzky-Golay滤波器
y = sgolayfilt(x, order, framelen);

% 可视化原始数据和滤波后的数据
plot(x, 'b:', 'LineWidth', 1.5);
hold on;
plot(y, 'r-', 'LineWidth', 1.5);
legend('原始数据', '滤波后数据');
xlabel('样本');
ylabel('值');
title('Savitzky-Golay滤波');
grid on;
yline(xmean)