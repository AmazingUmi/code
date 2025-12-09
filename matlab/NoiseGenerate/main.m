%% 初始化
clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
index = strfind(tmp.Filename, '\') ;
pathstr = tmp.Filename(1:index(end)-1);
cd(pathstr);
addpath(pathstr);addpath([pathstr,'\function']);addpath([pathstr,'\function\env']);
clear pathstr tmp index;
%% 环境噪声生成
opts = struct('Fs',48000,'duration',100,'w_ms',10,'seed',42);
[y_wind, ~, ~] = windNoiseWenz10k(opts);
wind_noise = y_wind;
%% 信道生成
cd function\env\
bellhop('TEST_sd10_rd50_lon116_lat15');
[ Arr, Pos ] = read_arrivals_asc('TEST_sd10_rd50_lon116_lat15.arr');
save('channel',"Arr","Pos")
%% 目标信号生成
cfg = struct('fs',48000,'T',100,'prop_rpm',180,'prop_blades',4,...
             'Lbb_target_dB',120,'cal_mode','global', ...
             'Delta_shaft0',12,'Delta_blade0',15,'Delta_side0',8,'seed',42);
cfg.channel = struct('apply',true,'ifbellhop',true,'Gamma_surf',-1,'Gamma_bot_mag',0.6, ...
                     'Gamma_bot_phase_deg',0,'spread_exp',1,'absorption_on',true, ...
                     'pad_margin_s',0.5,'seed',42);
[y_ship_channel, meta_channel] = shipNoiseGenerate(cfg);
shipNoiseValidatePlot(meta_channel);     % 画验证图
ship_noise = y_ship_channel;
%% 混合信号
y_mix = ship_noise + wind_noise;

[f,H] = ffft(ship_noise);
TL = -20*log10(abs(H));
figure
plot(f,TL)

[f,H_mix] = ffft(y_mix);
TL_mix = -20*log10(abs(H_mix));
hold on
plot(f,TL_mix)
set(gca,'YDir','reverse') 